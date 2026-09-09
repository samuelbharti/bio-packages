# bio-packages demo app: validate with biobouncer, fetch with bioclients,
# branch on biohttp envelopes. Under 200 lines, and no tryCatch() anywhere.
#
# Run from the repo root:  shiny::runApp("app")

source(here::here("R", "demo-env.R"))
library(shiny)
library(bslib)
library(biobouncer)
library(biohttp)
library(bioclients)

fake <- start_fake_server()
onStop(function() try(fake$stop(), silent = TRUE))

ui <- page_sidebar(
  title = "bio-packages: validate, fetch, branch",
  theme = bs_theme(preset = "shiny"),
  sidebar = sidebar(
    width = 300,
    textAreaInput(
      "ids",
      "Gene symbols, one per line",
      value = "TP53\nBRAF\nMLL\nTP35",
      rows = 6
    ),
    radioButtons(
      "how",
      "Validation mode",
      choices = c(
        "pattern (shape only)" = "pattern",
        "cache (dated snapshot)" = "cache"
      ),
      selected = "cache"
    ),
    actionButton("go", "Validate and fetch", class = "btn-primary"),
    hr(),
    input_switch("outage", "Simulate an outage", value = FALSE),
    helpText(
      "Opens the circuit breaker for MyGene and gnomAD and bypasses the",
      "cache, so every fetch comes back skipped. Nothing crashes."
    )
  ),
  layout_columns(
    col_widths = c(6, 6),
    card(
      card_header("1. Validation (biobouncer)"),
      tableOutput("validation")
    ),
    card(
      card_header("2. Transport status (biohttp envelopes)"),
      uiOutput("strip")
    )
  ),
  layout_columns(
    col_widths = c(6, 6),
    card(
      card_header("3. Gene identity (bioclients: MyGene)"),
      tableOutput("mygene")
    ),
    card(
      card_header("4. Constraint (bioclients: gnomAD)"),
      tableOutput("gnomad")
    )
  ),
  card(
    card_header("Transport lab: a local server that misbehaves on demand"),
    layout_columns(
      actionButton("lab_429", "429 rate limited"),
      actionButton("lab_timeout", "Timeout"),
      actionButton("lab_500", "500 error")
    ),
    verbatimTextOutput("lab")
  )
)

server <- function(input, output, session) {
  # shinyvalidate rule from biobouncer. It returns one message for the whole
  # vector; the per-id verdicts are in the validation table below.
  iv <- shinyvalidate::InputValidator$new()
  iv$add_rule("ids", function(value) {
    ids <- trimws(strsplit(value, "\n")[[1]])
    ids <- ids[nzchar(ids)]
    if (length(ids) == 0) {
      return("Enter at least one symbol")
    }
    NULL
  })
  iv$enable()

  # The outage switch trips the breaker by hand: three transport failures
  # recorded against each host, which is what three refused connections would
  # do on their own. Changing the salt makes every cache key miss, so the call
  # actually reaches the breaker instead of being answered from disk.
  observeEvent(input$outage, {
    if (isTRUE(input$outage)) {
      Sys.setenv(BIOHTTP_CACHE_SALT = "outage")
      for (host in c("mygene.info", "gnomad.broadinstitute.org")) {
        for (i in 1:3) {
          breaker_record(host, reachable = FALSE)
        }
      }
    } else {
      Sys.setenv(BIOHTTP_CACHE_SALT = "bio-packages-v1")
      breaker_reset()
    }
  })

  run <- eventReactive(input$go, {
    req(iv$is_valid())
    ids <- trimws(strsplit(input$ids, "\n")[[1]])
    ids <- ids[nzchar(ids)]
    chk <- check_id(ids, "hgnc", how = input$how)
    clean <- ifelse(chk$valid, chk$normalized, chk$suggestion)
    clean <- clean[!is.na(clean)]
    list(
      chk = chk,
      mygene = if (length(clean)) {
        mygene_genes(clean)
      } else {
        status_no_data("MyGene")
      },
      gnomad = if (length(clean)) {
        gnomad_constraints(clean)
      } else {
        status_no_data("gnomAD")
      }
    )
  })

  output$validation <- renderTable({
    chk <- run()$chk
    data.frame(
      input = chk$input,
      valid = chk$valid,
      use = ifelse(chk$valid, chk$normalized, chk$suggestion),
      note = ifelse(
        chk$valid,
        "",
        ifelse(is.na(chk$suggestion), "rejected", "repaired")
      )
    )
  })

  output$strip <- renderUI({
    r <- run()
    layout_columns(
      status_box("MyGene", r$mygene),
      status_box("gnomAD", r$gnomad)
    )
  })

  output$mygene <- renderTable({
    r <- run()$mygene
    if (!isTRUE(r$ok)) {
      return(data.frame(status = r$status, message = r$error))
    }
    r$data[, c("symbol", "name", "entrez", "ensembl_gene")]
  })

  output$gnomad <- renderTable({
    r <- run()$gnomad
    if (!isTRUE(r$ok)) {
      return(data.frame(status = r$status, message = r$error))
    }
    r$data[, c("symbol", "pli", "loeuf", "mis_z")]
  })

  lab <- reactiveVal(NULL)
  observeEvent(input$lab_429, {
    lab(get_json(fake$url(), path = "limited", source = "Lab", max_tries = 1))
  })
  observeEvent(input$lab_timeout, {
    lab(get_json(
      fake$url(),
      path = "slow",
      source = "Lab",
      timeout = 1,
      max_tries = 1
    ))
  })
  observeEvent(input$lab_500, {
    lab(get_json(fake$url(), path = "broken", source = "Lab", max_tries = 1))
  })
  output$lab <- renderPrint({
    r <- lab()
    if (is.null(r)) {
      cat(
        "Press a button. The envelope comes back as a value, never a condition."
      )
    } else {
      str(r[c("ok", "status", "http", "error", "retry_after")])
    }
  })
}

shinyApp(ui, server)
