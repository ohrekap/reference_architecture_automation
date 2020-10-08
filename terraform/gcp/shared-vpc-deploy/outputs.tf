output public_subnet {
    value = module.public-vpc.subnets_self_links[0]
}
output public_subnet_cidr {
    value = module.public-vpc.subnets_ips[0]
}
output private_subnet {
    value = module.private-vpc.subnets_self_links[0]
}
output private_subnet_cidr {
    value = module.private-vpc.subnets_ips[0]
}
output mgmt_subnet {
    value = module.management-vpc.subnets_self_links[0]
}
output mgmt_subnet_cidr {
    value = module.management-vpc.subnets_ips[0]
}
output host_project {
    value = module.host-project.project_id
}
output web_subnet {
    value = module.web-vpc.subnets_self_links[0]
}
output web_subnet_cidr {
    value = module.web-vpc.subnets_ips[0]
} 
output web_project {
    value = module.web-project.project_id
}
output public_network {
    value = module.public-vpc.network_self_link
}
output web_network {
    value =module.web-vpc.network_self_link
}