# bio-packages

Tutorials, slide decks and a Shiny demo for three R packages by the same
author:

| package | what it does | where it lives |
|---|---|---|
| [biobouncer](https://www.samuelbharti.com/biobouncer/) | validates biological identifiers before they reach a tool (R, Python, JavaScript) | CRAN 0.2.0, PyPI 0.2.0 |
| [biohttp](https://www.samuelbharti.com/biohttp/) | HTTP transport that returns an envelope instead of raising; cache, circuit breaker, rate limits, batching | CRAN 0.1.2, r-universe 0.1.3 |
| [bioclients](https://www.samuelbharti.com/bioclients/) | 29 biological web services on biohttp, one table shape, one row per input | r-universe 0.1.1 |

The story the decks tell: validate, then fetch, then branch on what came
back. Everything here runs with the network off, because of the packages it
is about.

This repository is private. It carries speaker notes written for one reader.

## Artifacts

| What | File | How to open |
|---|---|---|
| Main talk, 20 minutes | `slides/main.html`, `slides/main.pdf` | Double-click. Self-contained. Press `S` for speaker notes. |
| biobouncer deck, 6 minutes | `slides/biobouncer.html`, `.pdf` | Same. |
| biohttp deck, 8 minutes | `slides/biohttp.html`, `.pdf` | Same. |
| bioclients deck, 7 minutes | `slides/bioclients.html`, `.pdf` | Same. |
| Tutorials | `tutorials/*.qmd` | `bash scripts/render-tutorials.sh`, then open the html. Not tracked. |
| Shiny app | `app/` | `shiny::runApp("app")` from the repo root. |

Every content slide carries a seven field notes block in a fixed order:
`ONE JOB`, `SCRIPT`, `NUMBERS`, `HONESTY`, `MEME`, `CLOCK`, `IF ASKED`. The
slides are sparse on purpose; the notes carry the talk.

## Setup

Once, online, from the repo root:

```sh
Rscript scripts/setup.R      # installs from r-universe and CRAN, checks versions
prek install                 # git hooks
```

`scripts/setup.R` installs the dependency set declared in `DESCRIPTION`
(this is not an R package; the file exists so pak can read it), asserts the
version floors the tutorials rely on, and resolves the Python side of
biobouncer through reticulate so the wheel is in the uv cache. There is no
renv.

If you need an NCBI key, copy `.Renviron.example` to `.Renviron`. It is
gitignored.

## Offline demo

Every live call the tutorials and the app make is listed in
`R/demo-calls.R`. The biohttp disk cache that answers them is committed under
`.cache/biohttp/`, and `R/demo-env.R` points every R session at it with a
one year lifetime and a fixed salt. That file is sourced first by every
tutorial, by the app, and by the scripts.

```sh
Rscript scripts/warm-cache.R      # online: run every call once, store the successes
Rscript scripts/check-offline.R   # proxy to a dead port: every call must replay from disk
```

Rules that keep this working:

- Never change `BIOHTTP_CACHE_SALT` or `BIOHTTP_CALLER_IDENTITY` in
  `R/demo-env.R` without re-warming. Both feed the cache key.
- Never call `biohttp::cache_reset()` after `demo-env.R` has run. With the
  settings unchanged it clears the disk tier too.
- Failure demos use `webfakes` or an unreachable host, never a real outage.
  biohttp never caches a failure, so a real outage demo cannot replay.
- If you add a network call to a tutorial or the app, add it to
  `R/demo-calls.R` and re-warm.

The cache is a demo device. In production keep biohttp's defaults: 30
minutes in memory, 7 days on disk, and a salt per deployment.

## Build

```sh
bash scripts/render-tutorials.sh        # four tutorials to html (not tracked)
bash scripts/build-decks.sh all         # four decks to html and pdf (tracked)
bash scripts/check-assets.sh main       # the gate: refs, self-containment, size, page count
Rscript scripts/smoke-app.R             # start the app in a child process, fetch it, stop it
Rscript scripts/screenshots.R           # shinytest2 screenshots for the decks
```

Always render a deck by explicit path, or through `build-decks.sh`. A bare
`quarto render` would rebuild everything in `_quarto.yml`, and a broken
tutorial must never block a deck.

### Why the PDF comes from Chrome

`quarto render --to pdf` does not work on a revealjs document: it routes to
the LaTeX pipeline. Reveal's PDF export is a browser print of the
`?print-pdf` route, which `build-decks.sh` drives through headless Chrome.
Two things bite if you do it by hand:

- `?print-pdf` is mandatory. Without it reveal stays in single-viewport mode
  and the PDF has one page.
- Manual route: open `slides/main.html?print-pdf`, print, Landscape, Margins
  None, Background graphics on. Skip that last one and every colour vanishes.

### Verifying the theme applied

Do not grep the rendered HTML for a CSS selector. With `embed-resources`
Quarto inlines stylesheets as percent-encoded `data:` URIs, so a plain grep
reports a false negative. `check-assets.sh` runs the extractor:

```sh
python scripts/extract-css.py slides/main.html .kicker .payoff .bignums
```

## Windows notes

- The bash scripts run under Git Bash. `build-decks.sh` uses `cygpath` to
  hand Chrome a `file:///E:/...` URL and a Windows output path; without that
  the PDF comes out blank.
- Run R entry points as script files (`Rscript scripts/x.R`). The `Rscript`
  shim on this machine mangles quoted `-e` expressions.
- `.gitattributes` normalises line endings to LF. A `.sh` with CRLF fails
  under bash on `\r`.

## Layout

```text
R/            demo-env.R (cache settings), demo-calls.R (every live call)
scripts/      setup, warm, offline check, render, build, check, smoke, screenshots
tutorials/    biobouncer, biohttp, bioclients, pipeline (Quarto, knitr)
slides/       main, biobouncer, biohttp, bioclients (Quarto revealjs), custom.scss
app/          app.R, R/status.R (status to value box), R/fake_server.R (webfakes)
data/         the messy inputs the tutorials use
fixtures/     stored response bodies copied from the bioclients test suite
assets/       logos, diagrams, screenshots (copies, never cross-references)
.cache/       the warmed biohttp disk cache
docs/local/   plans and notes, gitignored
```

## Do not add

renv lockfiles, video, secrets, app code that needs a server to view, or a
network call that is not in `R/demo-calls.R`.
