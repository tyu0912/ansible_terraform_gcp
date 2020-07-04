/**
 * Copyright 2017 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */


locals {
  address = var.create_address ? join("", google_compute_global_address.default.*.address) : var.address
  url_map = var.create_url_map ? join("", google_compute_url_map.default.*.self_link) : var.url_map
}

resource "google_compute_global_forwarding_rule" "http" {
  project    = var.project
  count      = var.http_forward ? 1 : 0
  name       = var.name
  target     = google_compute_target_http_proxy.default[0].self_link
  ip_address = local.address
  port_range = "80"
}

resource "google_compute_global_forwarding_rule" "https" {
  project    = var.project
  count      = var.ssl ? 1 : 0
  name       = "${var.name}-https"
  target     = google_compute_target_https_proxy.default[0].self_link
  ip_address = local.address
  port_range = "443"
}

resource "google_compute_global_address" "default" {
  count      = var.create_address ? 1 : 0
  project    = var.project
  name       = "${var.name}-address"
  ip_version = var.ip_version
}

# HTTP proxy when http forwarding is true
resource "google_compute_target_http_proxy" "default" {
  project = var.project
  count   = var.http_forward ? 1 : 0
  name    = "${var.name}-http-proxy"
  url_map = local.url_map
}

# HTTPS proxy when ssl is true
resource "google_compute_target_https_proxy" "default" {
  project = var.project
  count   = var.ssl ? 1 : 0
  name    = "${var.name}-https-proxy"
  url_map = local.url_map

  ssl_certificates = compact(concat(var.ssl_certificates, google_compute_ssl_certificate.default.*.self_link, ), )
  ssl_policy       = var.ssl_policy
  quic_override    = var.quic ? "ENABLE" : null
}

resource "google_compute_ssl_certificate" "default" {
  project     = var.project
  count       = var.ssl && ! var.use_ssl_certificates ? 1 : 0
  name_prefix = "${var.name}-certificate-"
  private_key = var.private_key
  certificate = var.certificate

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_url_map" "default" {
  project         = var.project
  count           = var.create_url_map ? 1 : 0
  name            = "${var.name}-url-map"
  default_service = google_compute_backend_service.default[keys(var.backends)[0]].self_link

}

resource "google_compute_backend_service" "default" {
  provider = google-beta
  for_each = var.backends

  project = var.project
  name    = "${var.name}-backend-${each.key}"

  port_name                       = each.value.port_name
  protocol                        = each.value.protocol
  timeout_sec                     = lookup(each.value, "timeout_sec", null)
  description                     = lookup(each.value, "description", null)
  connection_draining_timeout_sec = lookup(each.value, "connection_draining_timeout_sec", null)
  enable_cdn                      = lookup(each.value, "enable_cdn", false)
  security_policy                 = var.security_policy
  health_checks                   = [google_compute_health_check.default[each.key].self_link]
  session_affinity                = lookup(each.value, "session_affinity", null)
  affinity_cookie_ttl_sec         = lookup(each.value, "affinity_cookie_ttl_sec", null)

  dynamic "backend" {
    for_each = toset(each.value["groups"])
    content {
      balancing_mode               = lookup(backend.value, "balancing_mode")
      capacity_scaler              = lookup(backend.value, "capacity_scaler")
      description                  = lookup(backend.value, "description")
      group                        = lookup(backend.value, "group")
      max_connections              = lookup(backend.value, "max_connections")
      max_connections_per_instance = lookup(backend.value, "max_connections_per_instance")
      max_connections_per_endpoint = lookup(backend.value, "max_connections_per_endpoint")
      max_rate                     = lookup(backend.value, "max_rate")
      max_rate_per_instance        = lookup(backend.value, "max_rate_per_instance")
      max_rate_per_endpoint        = lookup(backend.value, "max_rate_per_endpoint")
      max_utilization              = lookup(backend.value, "max_utilization")
    }
  }

  log_config {
    enable      = lookup(lookup(each.value, "log_config", {}), "enable", true)
    sample_rate = lookup(lookup(each.value, "log_config", {}), "sample_rate", "1.0")
  }

  depends_on = [google_compute_health_check.default]

}

resource "google_compute_health_check" "default" {
  provider = google-beta
  for_each = var.backends
  project  = var.project
  name     = "${var.name}-hc-${each.key}"

  check_interval_sec  = lookup(each.value["health_check"], "check_interval_sec", 5)
  timeout_sec         = lookup(each.value["health_check"], "timeout_sec", 5)
  healthy_threshold   = lookup(each.value["health_check"], "healthy_threshold", 2)
  unhealthy_threshold = lookup(each.value["health_check"], "unhealthy_threshold", 2)

  log_config {
    enable = lookup(each.value["health_check"], "logging", false)
  }

  dynamic "http_health_check" {
    for_each = each.value["protocol"] == "HTTP" ? [
      {
        host         = lookup(each.value["health_check"], "host", null)
        request_path = lookup(each.value["health_check"], "request_path", null)
        port         = lookup(each.value["health_check"], "port", null)
      }
    ] : []

    content {
      host         = lookup(http_health_check.value, "host", null)
      request_path = lookup(http_health_check.value, "request_path", null)
      port         = lookup(http_health_check.value, "port", null)
    }
  }

  dynamic "https_health_check" {
    for_each = each.value["protocol"] == "HTTPS" ? [
      {
        host         = lookup(each.value["health_check"], "host", null)
        request_path = lookup(each.value["health_check"], "request_path", null)
        port         = lookup(each.value["health_check"], "port", null)
      }
    ] : []

    content {
      host         = lookup(https_health_check.value, "host", null)
      request_path = lookup(https_health_check.value, "request_path", null)
      port         = lookup(https_health_check.value, "port", null)
    }
  }

  dynamic "http2_health_check" {
    for_each = each.value["protocol"] == "HTTP2" ? [
      {
        host         = lookup(each.value["health_check"], "host", null)
        request_path = lookup(each.value["health_check"], "request_path", null)
        port         = lookup(each.value["health_check"], "port", null)
      }
    ] : []

    content {
      host         = lookup(http2_health_check.value, "host", null)
      request_path = lookup(http2_health_check.value, "request_path", null)
      port         = lookup(http2_health_check.value, "port", null)
    }
  }

}

resource "google_compute_firewall" "default-hc" {
  count   = length(var.firewall_networks)
  project = length(var.firewall_networks) == 1 && var.firewall_projects[0] == "default" ? var.project : var.firewall_projects[count.index]
  name    = "${var.name}-hc-${count.index}"
  network = var.firewall_networks[count.index]
  source_ranges = [
    "130.211.0.0/22",
    "35.191.0.0/16"
  ]
  target_tags             = length(var.target_tags) > 0 ? var.target_tags : null
  target_service_accounts = length(var.target_service_accounts) > 0 ? var.target_service_accounts : null

  dynamic "allow" {
    for_each = var.backends
    content {
      protocol = "tcp"
      ports    = [allow.value.port]
    }
  }
}
