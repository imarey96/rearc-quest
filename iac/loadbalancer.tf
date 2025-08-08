resource "google_compute_region_network_endpoint_group" "quest_neg" {
  name                  = "quest-neg"
  region                = "us-east1"
  network_endpoint_type = "SERVERLESS"
  cloud_run {
    service = "quest-app"
  }
}

resource "google_compute_backend_service" "quest_backend" {
  name                  = "quest-backend"
  load_balancing_scheme = "EXTERNAL"
  protocol              = "HTTP"
  port_name             = "http"
  timeout_sec           = 30

  custom_request_headers = [
    "Host: quest-app-407179321768.us-east1.run.app"
  ]

  backend {
group = google_compute_region_network_endpoint_group.quest_neg.self_link
  }
}

resource "google_compute_url_map" "quest_map" {
  name            = "quest-url-map"
  default_service = google_compute_backend_service.quest_backend.id
}

resource "google_compute_target_http_proxy" "quest_proxy" {
  name    = "quest-proxy"
  url_map = google_compute_url_map.quest_map.id
}


resource "google_compute_global_address" "quest_ip" {
  name = "quest-ip"
}

resource "google_compute_global_forwarding_rule" "quest_http_rule" {
  name                  = "quest-fw-http"
  load_balancing_scheme = "EXTERNAL"
  target                = google_compute_target_http_proxy.quest_proxy.id
  port_range            = "80"
  ip_protocol           = "TCP"
  ip_address            = google_compute_global_address.quest_ip.address
}

resource "tls_private_key" "quest_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "quest_cert" {
  private_key_pem       = tls_private_key.quest_key.private_key_pem
  validity_period_hours = 8760 
  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]

  subject {
    common_name  = "quest-ip"
    organization = "RearcQuest"
  }

  ip_addresses = [google_compute_global_address.quest_ip.address]
}

resource "google_compute_ssl_certificate" "quest_ssl" {
  name        = "quest-selfmanaged"
  private_key = tls_private_key.quest_key.private_key_pem
  certificate = tls_self_signed_cert.quest_cert.cert_pem
}

resource "google_compute_target_https_proxy" "quest_https_proxy" {
  name             = "quest-https-proxy"
  url_map          = google_compute_url_map.quest_map.id
  ssl_certificates = [google_compute_ssl_certificate.quest_ssl.id]
}

resource "google_compute_global_forwarding_rule" "quest_https_rule" {
  name                  = "quest-fw-https"
  load_balancing_scheme = "EXTERNAL"
  ip_address            = google_compute_global_address.quest_ip.address
  target                = google_compute_target_https_proxy.quest_https_proxy.id
  port_range            = "443"
  ip_protocol           = "TCP"
}
