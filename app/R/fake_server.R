# A local server for the transport lab. Failure demos never run against a
# real host, because biohttp never caches a failure, and a real outage demo
# would break the moment the talk is given offline.

start_fake_server <- function() {
  app <- webfakes::new_app()
  app$get("/limited", function(req, res) {
    res$set_status(429L)$set_header("Retry-After", "5")$send_json(
      list(error = "too many requests"),
      auto_unbox = TRUE
    )
  })
  app$get("/slow", function(req, res) {
    Sys.sleep(3)
    res$send_json(list(ok = TRUE), auto_unbox = TRUE)
  })
  app$get("/broken", function(req, res) {
    res$set_status(500L)$send_json(list(error = "boom"), auto_unbox = TRUE)
  })
  webfakes::new_app_process(app)
}
