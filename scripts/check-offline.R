# Prove that every demo call replays from the committed cache with the network
# blocked. Points every proxy variable at a port nothing listens on, so any
# call that reaches for the network fails fast instead of hanging.
#
#   Rscript scripts/check-offline.R

Sys.setenv(
  http_proxy = "http://127.0.0.1:9",
  https_proxy = "http://127.0.0.1:9",
  HTTP_PROXY = "http://127.0.0.1:9",
  HTTPS_PROXY = "http://127.0.0.1:9",
  no_proxy = ""
)

source(file.path("R", "demo-env.R"))
source(file.path("R", "demo-calls.R"))
biohttp::transport_stats_reset()

# A no_data envelope is a settled answer: the transport response (a 200 with
# an empty body) is what biohttp caches, and the client turns it into no_data
# on every replay. Only a transport or HTTP failure means nothing was stored.
settled <- function(r) r$status %in% c("ok", "no_data")

calls <- demo_calls()
bad <- character(0)
for (name in names(calls)) {
  res <- calls[[name]]()
  oks <- if (!is.null(res$status)) {
    settled(res)
  } else {
    all(vapply(res, settled, logical(1)))
  }
  cat(sprintf("  %-28s %s\n", name, if (oks) "from cache" else "MISSED"))
  if (!oks) {
    bad <- c(bad, name)
  }
}

stats <- biohttp::transport_stats()
dispatched <- if (nrow(stats) == 0) 0L else sum(stats$dispatched)
cat(sprintf("\nbatched requests dispatched: %d (must be 0)\n", dispatched))

if (length(bad) > 0 || dispatched > 0) {
  cat("offline check FAILED: ", paste(bad, collapse = ", "), "\n")
  quit(status = 1)
}
cat("offline check passed\n")
