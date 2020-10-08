output "primary_ip" {
    value = google_compute_address.this.address
    description = "The public IP of the primary Panorama"
}

# I have to use the join because if I tried to access [0] and it isn't created then it errors out. Since there is only one management
# interface then the output will eithe be nothing or the IP of the second Panorama instance. If conditional output ever happen this 
# should be adjusted.
output "secondary_ip" {
    value = join(",", google_compute_address.secondary[*].address)
    description = "The public IP of the secondary Panorama"
}

output "primary_private_ip" {
    value = google_compute_instance.this.network_interface.0.network_ip
    description = "The private IP of the primary Panorama"
}

# I have to use the join because if I tried to access [0] and it isn't created then it errors out. Since there is only one management
# interface then the output will eithe be nothing or the IP of the second Panorama instance. If conditional output ever happen this 
# should be adjusted.
output "secondary_private_ip" {
    value = join(",", google_compute_instance.secondary[*].network_interface.0.network_ip)
    description = "The public IP of the secondary Panorama"
}