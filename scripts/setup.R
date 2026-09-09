# One-time setup. Installs the dependency set declared in DESCRIPTION from
# r-universe (biobouncer, biohttp, bioclients) and CRAN (everything else), then
# checks the version floors the tutorials rely on, then resolves the Python
# side of biobouncer through reticulate so the wheel is in the uv cache.
#
# Run from the repo root:  Rscript scripts/setup.R
# Needs a network. Everything after this runs offline.

root <- normalizePath(".")
if (!file.exists(file.path(root, "DESCRIPTION"))) {
  stop("Run this from the repo root: Rscript scripts/setup.R", call. = FALSE)
}

options(
  repos = c(
    samuelbharti = "https://samuelbharti.r-universe.dev",
    CRAN = "https://cloud.r-project.org"
  )
)

if (!requireNamespace("pak", quietly = TRUE)) {
  install.packages("pak")
}

message("== installing dependencies from DESCRIPTION ==")
pak::local_install_deps(root, upgrade = TRUE, ask = FALSE)

message("== checking version floors ==")
floors <- c(biobouncer = "0.2.0", biohttp = "0.1.3", bioclients = "0.1.1")
for (pkg in names(floors)) {
  have <- as.character(packageVersion(pkg))
  if (utils::compareVersion(have, floors[[pkg]]) < 0) {
    stop(
      sprintf(
        "%s %s is installed but the tutorials need >= %s. Check the r-universe repo.",
        pkg,
        have,
        floors[[pkg]]
      ),
      call. = FALSE
    )
  }
  message(sprintf("  %-12s %s", pkg, have))
}
if (!exists("transport_stats", asNamespace("biohttp"))) {
  stop(
    "biohttp::transport_stats() is missing. CRAN 0.1.2 is too old.",
    call. = FALSE
  )
}

message("== resolving Python biobouncer through reticulate ==")
reticulate::py_require("biobouncer==0.2.0", python_version = "3.12")
cfg <- reticulate::py_config()
message("  python: ", cfg$python)
bb <- reticulate::import("biobouncer")
message("  biobouncer (python): ", bb$`__version__`)

message("== done ==")
