variable "panorama_bootstrap_key" {
    default =""
}

resource "random_string" "randomstring" {
  length      = 5
  min_lower   = 2
  min_numeric = 3
  special     = false
}

resource "google_storage_bucket" "vmseries-inbound" {
  name            = join("", list("vmseries-inbound", "-", random_string.randomstring.result))
  storage_class   = "REGIONAL"
  location        = var.gcp_region
  project         = data.terraform_remote_state.shared-vpc.outputs.host_project
}

resource "google_storage_bucket_object" "inbound-init-cft_txt" {
  bucket  = google_storage_bucket.vmseries-inbound.name
  name    = "config/init-cfg.txt"
  content = <<-EOF
            type=dhcp-client
            panorama-server=${data.terraform_remote_state.panorama.outputs.primary_private_ip}
            panorama-server=${data.terraform_remote_state.panorama.outputs.secondary_private_ip}
            tplname=${panos_panorama_template_stack.inbound.name}
            dgname=${panos_panorama_device_group.inbound.name}
            dns-primary=169.254.169.254
            vm-auth-key=${var.panorama_bootstrap_key}
            dhcp-accept-server-hostname=yes
            dhcp-accept-server-domain=yes
            EOF
}

resource "google_storage_bucket_object" "inbound-software" {
  bucket = google_storage_bucket.vmseries-inbound.name
  name   = "software/"
  content = "/dev/null"
}

resource "google_storage_bucket_object" "inbound-license" {
  bucket = google_storage_bucket.vmseries-inbound.name
  name    = "license/authcodes"
  content = var.authcode
}

resource "google_storage_bucket_object" "inbound-content" {
  bucket = google_storage_bucket.vmseries-inbound.name
  name   = "content/"
  content = "/dev/null"
}