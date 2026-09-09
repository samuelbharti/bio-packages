# Start the Shiny app in a background R process, fetch its front page, stop it.
#
#   Rscript scripts/smoke-app.R

port <- 3839L
p <- callr::r_bg(
  function(port) {
    shiny::runApp("app", port = port, launch.browser = FALSE)
  },
  args = list(port = port),
  stdout = "|",
  stderr = "|"
)

ok <- FALSE
for (i in seq_len(60)) {
  Sys.sleep(0.5)
  res <- tryCatch(
    curl::curl_fetch_memory(sprintf("http://127.0.0.1:%d/", port)),
    error = function(e) NULL
  )
  if (!is.null(res) && res$status_code == 200L) {
    html <- rawToChar(res$content)
    ok <- grepl("bio-packages", html, fixed = TRUE)
    cat(sprintf("HTTP %d, title found: %s\n", res$status_code, ok))
    break
  }
  if (!p$is_alive()) {
    break
  }
}
if (!ok) {
  cat(p$read_all_error_lines(), sep = "\n")
}
p$kill()
quit(status = if (ok) 0 else 1)
