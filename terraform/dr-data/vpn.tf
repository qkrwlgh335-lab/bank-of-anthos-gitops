resource "google_compute_ha_vpn_gateway" "aws" {
  name    = "phase1-bank-aws-ha-vpn"
  project = var.gcp_project_id
  region  = var.gcp_region
  network = data.google_compute_network.dr.id
}

resource "aws_customer_gateway" "gcp" {
  for_each = {
    interface-0 = google_compute_ha_vpn_gateway.aws.vpn_interfaces[0].ip_address
    interface-1 = google_compute_ha_vpn_gateway.aws.vpn_interfaces[1].ip_address
  }

  bgp_asn    = var.gcp_router_asn
  ip_address = each.value
  type       = "ipsec.1"

  tags = {
    Name = "phase1-bank-gcp-${each.key}"
  }
}

resource "aws_vpn_gateway" "gcp" {
  vpc_id          = data.aws_vpc.primary.id
  amazon_side_asn = var.aws_router_asn

  tags = {
    Name = "phase1-bank-gcp-vgw"
  }
}

resource "random_password" "vpn_psk" {
  for_each = toset(["a1", "a2", "b1", "b2"])

  length  = 32
  special = false
}

resource "aws_vpn_connection" "gcp_interface_0" {
  customer_gateway_id = aws_customer_gateway.gcp["interface-0"].id
  vpn_gateway_id      = aws_vpn_gateway.gcp.id
  type                = "ipsec.1"
  static_routes_only  = false

  tunnel1_inside_cidr   = "169.254.21.0/30"
  tunnel2_inside_cidr   = "169.254.22.0/30"
  tunnel1_preshared_key = random_password.vpn_psk["a1"].result
  tunnel2_preshared_key = random_password.vpn_psk["a2"].result

  tunnel1_ike_versions = ["ikev2"]
  tunnel2_ike_versions = ["ikev2"]

  tunnel1_phase1_encryption_algorithms = ["AES256"]
  tunnel2_phase1_encryption_algorithms = ["AES256"]
  tunnel1_phase1_integrity_algorithms  = ["SHA2-256"]
  tunnel2_phase1_integrity_algorithms  = ["SHA2-256"]
  tunnel1_phase1_dh_group_numbers      = [14]
  tunnel2_phase1_dh_group_numbers      = [14]

  tunnel1_phase2_encryption_algorithms = ["AES256"]
  tunnel2_phase2_encryption_algorithms = ["AES256"]
  tunnel1_phase2_integrity_algorithms  = ["SHA2-256"]
  tunnel2_phase2_integrity_algorithms  = ["SHA2-256"]
  tunnel1_phase2_dh_group_numbers      = [14]
  tunnel2_phase2_dh_group_numbers      = [14]

  tags = {
    Name = "phase1-bank-gcp-interface-0"
  }
}

resource "aws_vpn_connection" "gcp_interface_1" {
  customer_gateway_id = aws_customer_gateway.gcp["interface-1"].id
  vpn_gateway_id      = aws_vpn_gateway.gcp.id
  type                = "ipsec.1"
  static_routes_only  = false

  tunnel1_inside_cidr   = "169.254.23.0/30"
  tunnel2_inside_cidr   = "169.254.24.0/30"
  tunnel1_preshared_key = random_password.vpn_psk["b1"].result
  tunnel2_preshared_key = random_password.vpn_psk["b2"].result

  tunnel1_ike_versions = ["ikev2"]
  tunnel2_ike_versions = ["ikev2"]

  tunnel1_phase1_encryption_algorithms = ["AES256"]
  tunnel2_phase1_encryption_algorithms = ["AES256"]
  tunnel1_phase1_integrity_algorithms  = ["SHA2-256"]
  tunnel2_phase1_integrity_algorithms  = ["SHA2-256"]
  tunnel1_phase1_dh_group_numbers      = [14]
  tunnel2_phase1_dh_group_numbers      = [14]

  tunnel1_phase2_encryption_algorithms = ["AES256"]
  tunnel2_phase2_encryption_algorithms = ["AES256"]
  tunnel1_phase2_integrity_algorithms  = ["SHA2-256"]
  tunnel2_phase2_integrity_algorithms  = ["SHA2-256"]
  tunnel1_phase2_dh_group_numbers      = [14]
  tunnel2_phase2_dh_group_numbers      = [14]

  tags = {
    Name = "phase1-bank-gcp-interface-1"
  }
}

resource "aws_vpn_gateway_route_propagation" "private" {
  for_each = data.aws_route_tables.private.ids

  route_table_id = each.value
  vpn_gateway_id = aws_vpn_gateway.gcp.id
}

locals {
  vpn_tunnels = {
    a1 = {
      gcp_interface  = 0
      peer_interface = 0
      outside_ip     = aws_vpn_connection.gcp_interface_0.tunnel1_address
      gcp_inside_ip  = aws_vpn_connection.gcp_interface_0.tunnel1_cgw_inside_address
      aws_inside_ip  = aws_vpn_connection.gcp_interface_0.tunnel1_vgw_inside_address
      inside_cidr    = aws_vpn_connection.gcp_interface_0.tunnel1_inside_cidr
      shared_secret  = random_password.vpn_psk["a1"].result
    }
    a2 = {
      gcp_interface  = 0
      peer_interface = 1
      outside_ip     = aws_vpn_connection.gcp_interface_0.tunnel2_address
      gcp_inside_ip  = aws_vpn_connection.gcp_interface_0.tunnel2_cgw_inside_address
      aws_inside_ip  = aws_vpn_connection.gcp_interface_0.tunnel2_vgw_inside_address
      inside_cidr    = aws_vpn_connection.gcp_interface_0.tunnel2_inside_cidr
      shared_secret  = random_password.vpn_psk["a2"].result
    }
    b1 = {
      gcp_interface  = 1
      peer_interface = 2
      outside_ip     = aws_vpn_connection.gcp_interface_1.tunnel1_address
      gcp_inside_ip  = aws_vpn_connection.gcp_interface_1.tunnel1_cgw_inside_address
      aws_inside_ip  = aws_vpn_connection.gcp_interface_1.tunnel1_vgw_inside_address
      inside_cidr    = aws_vpn_connection.gcp_interface_1.tunnel1_inside_cidr
      shared_secret  = random_password.vpn_psk["b1"].result
    }
    b2 = {
      gcp_interface  = 1
      peer_interface = 3
      outside_ip     = aws_vpn_connection.gcp_interface_1.tunnel2_address
      gcp_inside_ip  = aws_vpn_connection.gcp_interface_1.tunnel2_cgw_inside_address
      aws_inside_ip  = aws_vpn_connection.gcp_interface_1.tunnel2_vgw_inside_address
      inside_cidr    = aws_vpn_connection.gcp_interface_1.tunnel2_inside_cidr
      shared_secret  = random_password.vpn_psk["b2"].result
    }
  }
}

resource "google_compute_external_vpn_gateway" "aws" {
  name            = "phase1-bank-aws-peer"
  project         = var.gcp_project_id
  redundancy_type = "FOUR_IPS_REDUNDANCY"

  dynamic "interface" {
    for_each = local.vpn_tunnels

    content {
      id         = interface.value.peer_interface
      ip_address = interface.value.outside_ip
    }
  }
}

resource "google_compute_vpn_tunnel" "aws" {
  for_each = local.vpn_tunnels

  name                            = "phase1-bank-aws-${each.key}"
  project                         = var.gcp_project_id
  region                          = var.gcp_region
  vpn_gateway                     = google_compute_ha_vpn_gateway.aws.id
  vpn_gateway_interface           = each.value.gcp_interface
  peer_external_gateway           = google_compute_external_vpn_gateway.aws.id
  peer_external_gateway_interface = each.value.peer_interface
  router                          = var.gcp_router_name
  shared_secret                   = each.value.shared_secret
  ike_version                     = 2
}

resource "google_compute_router_interface" "aws" {
  for_each = local.vpn_tunnels

  name       = "phase1-bank-aws-${each.key}"
  project    = var.gcp_project_id
  region     = var.gcp_region
  router     = var.gcp_router_name
  ip_range   = "${each.value.gcp_inside_ip}/${split("/", each.value.inside_cidr)[1]}"
  vpn_tunnel = google_compute_vpn_tunnel.aws[each.key].name
}

resource "google_compute_router_peer" "aws" {
  for_each = local.vpn_tunnels

  name                      = "phase1-bank-aws-${each.key}"
  project                   = var.gcp_project_id
  region                    = var.gcp_region
  router                    = var.gcp_router_name
  interface                 = google_compute_router_interface.aws[each.key].name
  peer_ip_address           = each.value.aws_inside_ip
  peer_asn                  = var.aws_router_asn
  advertised_route_priority = 100
}
