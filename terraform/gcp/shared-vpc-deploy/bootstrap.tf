variable "panorama_bootstrap_key" {
    default =""
}

#************************************************************************************
# CREATE 2 S3 BUCKETS FOR FW1 & FW2
#************************************************************************************
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
  project         = module.host-project.project_id
}

resource "google_storage_bucket" "vmseries-obew" {
  #name            = join("", list("vmseries-obew", "-", random_string.randomstring.result))
  name            = "vmseris-obew"
  storage_class   = "REGIONAL"
  location        = var.gcp_region
  project         = module.host-project.project_id
} 

#************************************************************************************
# CREATE FW1 DIRECTORIES & UPLOAD FILES FROM /bootstrap_files/fw1 DIRECTORY
#************************************************************************************

/*resource "aws_s3_bucket_object" "a-init-cft_txt" {
  bucket  = google_storage_bucket.vmseries-inbound.name
  name    = "config/init-cfg.txt"
  content = <<-EOF
            type=dhcp-client
            panorama-server=${data.terraform_remote_state.panorama.outputs.primary_private_ip}
            panorama-server=${data.terraform_remote_state.panorama.outputs.secondary_private_ip}
            tplname=${panos_panorama_template_stack.a.name}
            dgname=${panos_panorama_device_group.this.name}
            hostname=${module.vmseries-a.instance_name}
            dns-primary=169.254.169.254
            vm-auth-key=${var.panorama_bootstrap_key}
            dhcp-accept-server-hostname=yes
            dhcp-accept-server-domain=yes
            EOF
}*/

resource "google_storage_bucket_object" "obew-init-cft_txt" {
  bucket  = google_storage_bucket.vmseries-obew.name
  name    = "config/init-cfg.txt"
  content = <<-EOF
            type=dhcp-client
            panorama-server=${data.terraform_remote_state.panorama.outputs.primary_private_ip}
            panorama-server=${data.terraform_remote_state.panorama.outputs.secondary_private_ip}
            tplname=${panos_panorama_template_stack.obew.name}
            dgname=${panos_panorama_device_group.obew.name}
            dns-primary=169.254.169.254
            vm-auth-key=${var.panorama_bootstrap_key}
            dhcp-accept-server-hostname=yes
            dhcp-accept-server-domain=yes
            EOF
}

resource "google_storage_bucket_object" "obew-software" {
  bucket = google_storage_bucket.vmseries-obew.name
  name   = "software/"
  content = "/dev/null"
}

resource "google_storage_bucket_object" "inbound-license" {
  bucket = google_storage_bucket.vmseries-obew.name
  name    = "license/authcodes"
  content = var.authcode
}

resource "google_storage_bucket_object" "inbound-content" {
  bucket = google_storage_bucket.vmseries-obew.name
  name   = "content/"
  content = "/dev/null"
}