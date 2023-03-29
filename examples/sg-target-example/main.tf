##############################################################################
# Resource Group
# (if var.resource_group is null, create a new RG using var.prefix)
##############################################################################

resource "ibm_resource_group" "resource_group" {
  count = var.resource_group != null ? 0 : 1
  name  = "${var.prefix}-rg"

}

data "ibm_resource_group" "existing_resource_group" {
  count = var.resource_group != null ? 1 : 0
  name  = var.resource_group
}

##############################################################################
# Create new VPC
# (if var.vpc_id is null, create a new VPCs using var.prefix)
##############################################################################

resource "ibm_is_vpc" "vpc" {
  count                       = var.vpc_id != null ? 0 : 1
  name                        = "${var.prefix}-vpc"
  resource_group              = var.resource_group != null ? data.ibm_resource_group.existing_resource_group[0].id : ibm_resource_group.resource_group[0].id
  classic_access              = var.classic_access
  address_prefix_management   = var.use_manual_address_prefixes == false ? null : "manual"
  default_network_acl_name    = var.default_network_acl_name
  default_security_group_name = var.default_security_group_name
  default_routing_table_name  = var.default_routing_table_name
  tags                        = var.resource_tags
}

data "ibm_is_vpc" "existing_vpc" {
  count = var.vpc_id != null ? 1 : 0
  name  = var.vpc_id
}

##############################################################################
# Create VPC routing table
##############################################################################

resource "ibm_is_vpc_routing_table" "rt" {
  name = "${var.prefix}-routing-table"
  vpc  = var.vpc_id != null ? data.ibm_is_vpc.existing_vpc[0].id : ibm_is_vpc.vpc[0].id
}

##############################################################################
# Create subnet
##############################################################################

resource "ibm_is_subnet" "subnet" {
  name            = "${var.prefix}-subnet"
  vpc             = var.vpc_id != null ? data.ibm_is_vpc.existing_vpc[0].id : ibm_is_vpc.vpc[0].id
  zone            = var.zone
  ipv4_cidr_block = var.ipv4_cidr_block
  routing_table   = ibm_is_vpc_routing_table.rt.routing_table
  ip_version      = var.ip_version
  access_tags     = var.access_tags
  resource_group  = var.resource_group != null ? data.ibm_resource_group.existing_resource_group[0].id : ibm_resource_group.resource_group[0].id
}

##############################################################################
# Create application load balancer
##############################################################################

resource "ibm_is_lb" "sg_lb" {
  name        = "${var.prefix}-load-balancer"
  subnets     = [ibm_is_subnet.subnet.id]
  access_tags = var.access_tags
}

##############################################################################
# Update security group
##############################################################################

module "create_sgr_rule" {
  source               = "../.."
  security_group_rules = var.security_group_rules
  security_group_id    = var.security_group_id
  resource_group       = var.resource_group != null ? data.ibm_resource_group.existing_resource_group[0].id : ibm_resource_group.resource_group[0].id
  target_ids           = flatten([ibm_is_lb.sg_lb.id])
  vpc_id               = var.vpc_id != null ? data.ibm_is_vpc.existing_vpc[0].id : ibm_is_vpc.vpc[0].id
}
