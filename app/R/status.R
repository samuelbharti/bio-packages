# One envelope status to one bslib value box. This is the entire mapping the
# app needs, and it is the reason the app has no tryCatch(): every outcome a
# call can have is a row here.

status_theme <- c(
  ok = "success",
  no_data = "secondary",
  stale = "warning",
  rate_limited = "warning",
  timeout = "danger",
  skipped = "dark",
  error = "danger"
)

status_line <- function(res) {
  switch(
    res$status,
    ok = sprintf("%d rows", NROW(res$data)),
    no_data = "Nothing for this query",
    stale = "Cached, past freshness",
    rate_limited = sprintf("Rate limited, retry in %s s", res$retry_after),
    timeout = res$error,
    skipped = "Source paused (breaker open)",
    error = res$error
  )
}

status_box <- function(title, res) {
  # detail is for the log, never for the screen
  if (!isTRUE(res$ok) && !is.null(res$detail)) {
    message(title, ": ", res$detail)
  }
  bslib::value_box(
    title = title,
    value = res$status,
    p(status_line(res)),
    theme = status_theme[[res$status]]
  )
}
