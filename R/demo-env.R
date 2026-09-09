# Environment for every tutorial, the app and the scripts.
#
# biohttp reads its cache settings from environment variables the first time
# the cache store is built, and the store is a lazy singleton. So this file
# sets the variables and then drops the store, and it must run before the
# first biohttp call. Every qmd, app.R and script sources it first.
#
# Why these values and not the defaults:
#   BIOHTTP_CACHE_DIR       inside the repo, so the warmed cache is committed and
#                           a fresh clone replays every call offline. The user
#                           Renviron on the machine that built this also sets
#                           BIOHTTP_CACHE_DISK=1 with a different dir, and this
#                           override is what keeps the two apart.
#   BIOHTTP_CACHE_TTL       one year. The default of 30 minutes is baked into each
#                           entry at write time, so a cache warmed the night
#                           before a talk would be dead by morning.
#   BIOHTTP_CACHE_DISK_TTL  one year, for the same reason, checked on read
#                           against file mtime.
#   BIOHTTP_CACHE_SALT      fixed. It is part of the cache key. Changing it
#                           silently invalidates every committed entry.
#
# This is a demo device. In production keep the defaults: 30 minutes in
# memory, 7 days on disk, and a salt per deployment.
#
# Never call biohttp::cache_reset() after this file has run. With the settings
# unchanged it clears the store in place, and the store includes the disk
# tier, so it would wipe the committed cache. The reset below only happens
# when the settings are about to change, which makes biohttp drop the old
# store object without touching any files.

cache_dir <- normalizePath(
  file.path(here::here(), ".cache", "biohttp"),
  winslash = "/",
  mustWork = FALSE
)
dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)

demo_env <- c(
  BIOHTTP_CACHE_DISK = "1",
  BIOHTTP_CACHE_DIR = cache_dir,
  BIOHTTP_CACHE_TTL = "31536000",
  BIOHTTP_CACHE_DISK_TTL = "31536000",
  BIOHTTP_CACHE_SALT = "bio-packages-v1",
  BIOHTTP_CALLER_IDENTITY = "bio-packages-demo"
)

already_set <- all(Sys.getenv(names(demo_env)) == demo_env)
if (!already_set) {
  do.call(Sys.setenv, as.list(demo_env))
  biohttp::cache_reset()
}
biohttp::breaker_reset()
