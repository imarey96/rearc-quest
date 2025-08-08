resource "google_cloud_run_service" "app" {
  name     = "quest-app"
  location = "us-east1"
  template {
    spec {
      containers {
        image = "us-east1-docker.pkg.dev/quest-i/quest/rearc-quest:v3"
        env {
          name = "SECRET_WORD"
          value_from {
            secret_key_ref {
              name = "secret_word"
              key = "1"
            }
          }
        }         
        ports {
          container_port = 3000
        }

        
      }
    }
  }
}
resource "google_cloud_run_service_iam_member" "public_invoker" {
  service = google_cloud_run_service.app.name
  location = google_cloud_run_service.app.location
  role   = "roles/run.invoker"
  member = "allUsers"
}