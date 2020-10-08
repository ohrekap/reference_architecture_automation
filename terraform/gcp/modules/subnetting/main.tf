
/* This module returns the number of bits required to get to a /24 if you have a /16 - /23. 
   If you have a /24 - /30 it sets newbits to 1 so that you will have two subnets. */

variable cidr_block {
    type = string
}

variable mymap {
    type  = map
    default = {
        "0" = "8"
        "128" = "7"
        "192" = "6"
        "224" = "5"
        "240" = "4"
        "248" = "3"
        "252" = "2"
        "254" = "1"
        "255" = "1"
  }
}

output "newbits" {
    value = var.mymap[split(".",cidrnetmask(var.cidr_block))[2]]
}

