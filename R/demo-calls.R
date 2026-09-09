# Every live network call the tutorials, the decks and the app make, as a
# named list of zero-argument functions. This is the single source of truth
# for what the committed cache must contain.
#
#   scripts/warm-cache.R     runs them online and fails if any is not ok
#   scripts/check-offline.R  runs them with the network blocked and fails if
#                            any did not come back from disk
#
# A call that is not in this list is not guaranteed to work offline. If you
# add a call to a tutorial or the app, add it here too and re-warm.
#
# Failure demos (timeouts, 429s, breaker trips) are deliberately absent. They
# run against webfakes or an unreachable host and never touch the cache.

demo_calls <- function() {
  list(
    # tutorials/biohttp.qmd
    biohttp_mygene_tp53 = function() {
      biohttp::get_json(
        "https://mygene.info/v3",
        path = "gene/7157",
        query = list(fields = "symbol,name,taxid"),
        source = "MyGene"
      )
    },
    biohttp_mygene_many = function() {
      biohttp::get_json_many(
        "https://mygene.info/v3",
        path = "query",
        queries = lapply(
          c("BRCA1", "TP53", "EGFR"),
          function(g) list(q = g, fields = "symbol,entrezgene", size = 1)
        ),
        source = "MyGene",
        throttle = list(capacity = 10, fill_time_s = 60)
      )
    },

    # tutorials/bioclients.qmd
    bioclients_mygene_tp53 = function() bioclients::mygene_gene("TP53"),
    bioclients_mygene_missing = function() {
      bioclients::mygene_gene("NOTAREALGENE123")
    },
    bioclients_mygene_batch = function() {
      bioclients::mygene_genes(c("TP53", "NOTAREALGENE123", "BRAF"))
    },
    bioclients_gnomad_braf = function() bioclients::gnomad_constraint("BRAF"),
    bioclients_gnomad_batch = function() {
      bioclients::gnomad_constraints(c("BRAF", "TP53", "EGFR"))
    },
    bioclients_uniprot_p04637 = function() {
      bioclients::uniprot_diseases("P04637")
    },
    bioclients_reactome_nf1 = function() bioclients::reactome_pathways("NF1"),
    bioclients_reactome_ttn = function() bioclients::reactome_pathways("TTN"),

    # tutorials/pipeline.qmd and app/ (the pipeline gene list after repair)
    pipeline_mygene = function() {
      bioclients::mygene_genes(pipeline_genes())
    },
    pipeline_gnomad = function() {
      bioclients::gnomad_constraints(pipeline_genes())
    },
    pipeline_opentargets = function() {
      ids <- pipeline_ensembl_ids()
      lapply(ids, function(id) {
        bioclients::opentargets_gene_diseases(id, size = 3)
      })
    },

    # app/ default input after repair, plus the smaller subsets a click on the
    # default text produces before the user edits anything
    app_default_mygene = function() {
      bioclients::mygene_genes(c("TP53", "BRAF", "KMT2A"))
    },
    app_default_gnomad = function() {
      bioclients::gnomad_constraints(c("TP53", "BRAF", "KMT2A"))
    }
  )
}

# The pipeline input after biobouncer has repaired it. Kept as a function so
# the tutorial, the warm script and the app agree on one vector.
pipeline_genes <- function() {
  c("TP53", "BRAF", "NF1", "EGFR", "BRCA2", "TTN", "C9orf72", "KMT2A", "CARS1")
}

# Ensembl ids for the pipeline genes, as MyGene returns them. Resolved once
# through the cached MyGene batch so the Open Targets warm-up does not depend
# on call order.
pipeline_ensembl_ids <- function() {
  res <- bioclients::mygene_genes(pipeline_genes())
  ids <- res$data$ensembl_gene
  ids[!is.na(ids)]
}
