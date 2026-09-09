# Screenshots of the app for the decks, through shinytest2 (headless Chrome).
# Runs offline: every fetch the default input makes is in the committed cache.
#
#   Rscript scripts/screenshots.R

# shinytest2 refuses to start outside a test run unless this is set.
Sys.setenv(NOT_CRAN = "true")

out <- file.path("assets", "screenshots")
dir.create(out, recursive = TRUE, showWarnings = FALSE)

app <- shinytest2::AppDriver$new(
  "app",
  name = "bio-packages",
  height = 900,
  width = 1400,
  load_timeout = 60000,
  seed = 1
)
on.exit(app$stop(), add = TRUE)

app$click("go")
app$wait_for_idle(timeout = 30000)
app$get_screenshot(file.path(out, "app-ok.png"))
cat("wrote app-ok.png\n")

app$set_inputs(outage = TRUE)
app$click("go")
app$wait_for_idle(timeout = 30000)
app$get_screenshot(file.path(out, "app-skipped.png"))
cat("wrote app-skipped.png\n")

app$set_inputs(outage = FALSE)
app$click("lab_429")
app$wait_for_idle(timeout = 30000)
app$get_screenshot(file.path(out, "app-lab-429.png"))
cat("wrote app-lab-429.png\n")
