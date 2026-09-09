# Warm the committed biohttp disk cache. Needs a network. Run from the repo
# root, then commit .cache/biohttp/.
#
#   Rscript scripts/warm-cache.R
#
# Exits non-zero if any call did not come back ok, because biohttp never
# stores a failure and the demo would go to the network for it.

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
  # Batched helpers return a list of envelopes; the pipeline helper returns a
  # list too. Flatten to one ok flag per call.
  oks <- if (!is.null(res$status)) {
    settled(res)
  } else {
    all(vapply(res, settled, logical(1)))
  }
  status <- if (oks) "ok" else "FAILED"
  cat(sprintf("  %-28s %s\n", name, status))
  if (!oks) {
    bad <- c(bad, name)
  }
}

cat("\n== transport stats ==\n")
print(biohttp::transport_stats())

n <- length(list.files(cache_dir, pattern = "\\.rds$", recursive = TRUE))
cat(sprintf("\n%d entries in %s\n", n, cache_dir))

if (length(bad) > 0) {
  cat("\nnot cached: ", paste(bad, collapse = ", "), "\n")
  quit(status = 1)
}
