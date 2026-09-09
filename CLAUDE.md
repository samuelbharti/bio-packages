# bio-packages

Tutorials, slide decks and a Shiny demo for three R packages: biobouncer
(validate identifiers), biohttp (transport that returns an envelope) and
bioclients (29 biological web services on biohttp). Content lives in
`tutorials/` and `slides/`, the app in `app/`, infrastructure in `R/` and
`scripts/`.

## Ground rules

- Every live network call made anywhere in this repo is listed in
  `R/demo-calls.R`. `scripts/warm-cache.R` warms them, `scripts/check-offline.R`
  proves they replay from `.cache/biohttp/` with the network blocked.
- Never change `BIOHTTP_CACHE_SALT` or `BIOHTTP_CALLER_IDENTITY` in
  `R/demo-env.R` without re-warming the cache. Both feed the cache key.
- Failure demos use webfakes or an unreachable host, never a real outage.
  biohttp never caches a failure, so a real outage demo breaks offline.
- Decks render by explicit path (`bash scripts/build-decks.sh main`). Assets are
  copies under `assets/`, never references into sibling repos.
- No renv. Dependencies are declared in `DESCRIPTION` and installed by
  `scripts/setup.R` from r-universe and CRAN.
- Decks contain no executed code. Every number on a slide comes from a
  rendered tutorial and the NUMBERS line in the notes says which one.

## Git

- Work on `main`. Small commits, Conventional Commit titles (`feat:`, `fix:`,
  `docs:`, `build:`, `chore:`). Show the message before committing.
- No AI attribution trailers. Never commit `.Renviron`, `.env` or a key.
- `docs/local/` is gitignored. Plans go in `docs/local/plans/`.

## Style

- No em dashes anywhere. Plain sentences, no AI tone.
- R is formatted with air, Python with ruff. Hooks run through prek.

## Before you push

```sh
prek run --all-files
Rscript scripts/check-offline.R
bash scripts/check-assets.sh main
```
