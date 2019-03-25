/*

To configure Terraform please visit:

https://www.terraform.io/docs/providers/oci/index.html and set the required variables for your tenant in the machine you are running Terraform on

This is main Terraform code base to create demo of autoscaling environment in Oracle Cloud Infrastructure using OCI Resource Manager.

This will create the following resources:

Compartment

Virtual Cloud Network (VCN)

Nat Gateway

Internet Gateway

Public load balancer and a backend set which has instance pool as destination

Two public subnets for the load balancer and jump server including route table and security list (ports 22 and 80 are open)
One private subnet for the instance pool instances with route table and security list (ports 22 and 80 are open)

Instance configuration with standard linux image, instance pool with minimum of two servers, maximum of four servers and autoscaling group
which acts when there is certain CPU load on the server

One compute instance with the smallest shape to act as a jump server - the instance public IP will be displayed in the end. 



Use ssh private key with username "opc" to login into the server. Steps to create SSH key:

https://docs.oracle.com/en/cloud/iaas/compute-iaas-cloud/stcsg/generating-ssh-key-pair.html

Assign the public key on to variable ssh_public_key.


To remove resources:

terraform destroy

Author: Simo Vilmunen 25/03/2019
        

*/

provider "oci" {
  tenancy_ocid     = "${var.tenancy_ocid}"
  region           = "${var.region}"
}

// Get available Availability Domains
data "oci_identity_availability_domains" "ADs" {
  compartment_id = "${var.tenancy_ocid}"
}

// Get latest Linux shape but exclude GPU images using
// https://gist.github.com/scross01/bcd21c12b15787f3ae9d51d0d9b2df06#file-oraclelinux-7_5-latest-tf

data "oci_core_images" "oraclelinux" {
  compartment_id = "${oci_identity_compartment.CreateCompartment.id}"

  operating_system         = "${var.operating_system}"
  operating_system_version = "${var.operating_system_version}"

  # exclude GPU specific images
  filter {
    name   = "display_name"
    values = ["^([a-zA-z]+)-([a-zA-z]+)-([\\.0-9]+)-([\\.0-9-]+)$"]
    regex  = true
  }
}

//This part creates a compartment where the resources will be placed on. 

resource "oci_identity_compartment" "CreateCompartment" {
  #Required variables
  compartment_id = "${var.tenancy_ocid}"
  description    = "${var.compartment_description}"
  name           = "${var.compartment_name}"
}

//Create a VCN where subnets will be placed. CIDR block can be defined as required

resource "oci_core_virtual_network" "CreateVCN" {
  cidr_block     = "${var.vcn_cidr_block}"
  dns_label      = "${var.dns_label}"
  compartment_id = "${oci_identity_compartment.CreateCompartment.id}"
  display_name   = "${var.display_name}"
}

//Create NAT GW so private subnet will have access to Internet

resource "oci_core_nat_gateway" "CreateNatGateway" {
  compartment_id = "${oci_identity_compartment.CreateCompartment.id}"
  vcn_id         = "${oci_core_virtual_network.CreateVCN.id}"
  block_traffic  = "${var.nat_gateway_block_traffic}"
  display_name   = "${var.nat_gateway_display_name}"
}

//Create Internet Gateway for Public subnet

resource "oci_core_internet_gateway" "CreateIGW" {
  compartment_id = "${oci_identity_compartment.CreateCompartment.id}"
  enabled        = "${var.internet_gateway_enabled}"
  vcn_id         = "${oci_core_virtual_network.CreateVCN.id}"
  display_name   = "${var.internet_gateway_display_name}"
}

//Create two route tables - one public which has route to internet gateway and another one for private with a route to NAT GW

resource "oci_core_route_table" "CreatePublicRouteTable" {
  compartment_id = "${oci_identity_compartment.CreateCompartment.id}"

  route_rules = [{
    destination       = "${var.igw_route_cidr_block}"
    network_entity_id = "${oci_core_internet_gateway.CreateIGW.id}"
  }]

  vcn_id       = "${oci_core_virtual_network.CreateVCN.id}"
  display_name = "${var.public_route_table_display_name}"
}

resource "oci_core_route_table" "CreatePrivateRouteTable" {
  compartment_id = "${oci_identity_compartment.CreateCompartment.id}"

  route_rules = [{
    destination       = "${var.natgw_route_cidr_block}"
    network_entity_id = "${oci_core_nat_gateway.CreateNatGateway.id}"
  }]

  vcn_id       = "${oci_core_virtual_network.CreateVCN.id}"
  display_name = "${var.private_route_table_display_name}"
}

/*

Create two security lists - for both subnets we will allow traffic outside without restrictions
Public subnet will allow traffic for port 22 
Private subnet will only allow traffic from Public subnet to ports 22 and 1521

*/

resource "oci_core_security_list" "CreatePublicSecurityList" {
  compartment_id = "${oci_identity_compartment.CreateCompartment.id}"
  vcn_id         = "${oci_core_virtual_network.CreateVCN.id}"
  display_name   = "${var.public_sl_display_name}"

  // Allow outbound tcp traffic on all ports
  egress_security_rules {
    destination = "${var.egress_destination}"
    protocol    = "${var.tcp_protocol}"
  }

  // allow inbound ssh traffic from a specific port
  ingress_security_rules = [{
    protocol  = "${var.tcp_protocol}"         // tcp = 6
    source    = "${var.public_ssh_sl_source}" // Can be restricted for specific IP address
    stateless = "${var.rule_stateless}"

    tcp_options {
      // These values correspond to the destination port range.
      "min" = "${var.public_sl_ssh_tcp_port}"
      "max" = "${var.public_sl_ssh_tcp_port}"
    }
  },
    {
      protocol  = "${var.tcp_protocol}"          // tcp = 6
      source    = "${var.public_http_sl_source}" // Can be restricted for specific IP address
      stateless = "${var.rule_stateless}"

      tcp_options {
        // These values correspond to the destination port range.
        "min" = "${var.public_sl_http_tcp_port}"
        "max" = "${var.public_sl_http_tcp_port}"
      }
    },
    {
      protocol  = "${var.tcp_protocol}"   // tcp = 6
      source    = "${var.vcn_cidr_block}" // open all ports for VCN CIDR and do not block subnet traffic 
      stateless = "${var.rule_stateless}"
    },
  ]
}

resource "oci_core_security_list" "CreatePrivateSecurityList" {
  compartment_id = "${oci_identity_compartment.CreateCompartment.id}"
  vcn_id         = "${oci_core_virtual_network.CreateVCN.id}"
  display_name   = "${var.private_sl_display_name}"

  // Allow outbound tcp traffic on all ports
  egress_security_rules {
    destination = "${var.egress_destination}"
    protocol    = "${var.tcp_protocol}"
  }

  // allow inbound traffic from VCN
  ingress_security_rules = [
    {
      protocol  = "${var.tcp_protocol}"   // tcp = 6
      source    = "${var.vcn_cidr_block}" // VCN CIDR as allowed source and do not block subnet traffic 
      stateless = "${var.rule_stateless}"

      tcp_options {
        // These values correspond to the destination port range.
        "min" = "${var.private_sl_ssh_tcp_port}"
        "max" = "${var.private_sl_ssh_tcp_port}"
      }
    },
    {
      protocol  = "${var.tcp_protocol}"   // tcp = 6
      source    = "${var.vcn_cidr_block}" // open all ports for VCN CIDR and do not block subnet traffic 
      stateless = "${var.rule_stateless}"

      tcp_options {
        // These values correspond to the destination port range.
        "min" = "${var.private_sl_http_tcp_port}"
        "max" = "${var.private_sl_http_tcp_port}"
      }
    },
  ]
}

//Create two subnets - one public where we will place a jump server and a another one where customer specific private resources are created

resource "oci_core_subnet" "CreatePublicSubnet" {
  availability_domain        = "${lookup(data.oci_identity_availability_domains.ADs.availability_domains[0],"name")}"
  cidr_block                 = "${cidrsubnet(var.vcn_cidr_block, 8, 0)}"
  display_name               = "${var.public_subnet_display_name}"
  dns_label                  = "${var.public_subnet_dns_label}"
  compartment_id             = "${oci_identity_compartment.CreateCompartment.id}"
  vcn_id                     = "${oci_core_virtual_network.CreateVCN.id}"
  security_list_ids          = ["${oci_core_security_list.CreatePublicSecurityList.id}"]
  route_table_id             = "${oci_core_route_table.CreatePublicRouteTable.id}"
  dhcp_options_id            = "${oci_core_virtual_network.CreateVCN.default_dhcp_options_id}"
  prohibit_public_ip_on_vnic = "${var.public_prohibit_public_ip_on_vnic}"
}

resource "oci_core_subnet" "CreatePublicSubnet2" {
  availability_domain        = "${lookup(data.oci_identity_availability_domains.ADs.availability_domains[1],"name")}"
  cidr_block                 = "${cidrsubnet(var.vcn_cidr_block, 8, 2)}"
  display_name               = "${var.public_subnet_display_name}"
  dns_label                  = "${var.public_subnet_dns_label}2"
  compartment_id             = "${oci_identity_compartment.CreateCompartment.id}"
  vcn_id                     = "${oci_core_virtual_network.CreateVCN.id}"
  security_list_ids          = ["${oci_core_security_list.CreatePublicSecurityList.id}"]
  route_table_id             = "${oci_core_route_table.CreatePublicRouteTable.id}"
  dhcp_options_id            = "${oci_core_virtual_network.CreateVCN.default_dhcp_options_id}"
  prohibit_public_ip_on_vnic = "${var.public_prohibit_public_ip_on_vnic}"
}

resource "oci_core_subnet" "CreatePrivateSubnet" {
  availability_domain        = "${lookup(data.oci_identity_availability_domains.ADs.availability_domains[0],"name")}"
  cidr_block                 = "${cidrsubnet(var.vcn_cidr_block, 8, 1)}"
  display_name               = "${var.private_subnet_display_name}"
  dns_label                  = "${var.private_subnet_dns_label}"
  compartment_id             = "${oci_identity_compartment.CreateCompartment.id}"
  vcn_id                     = "${oci_core_virtual_network.CreateVCN.id}"
  security_list_ids          = ["${oci_core_security_list.CreatePrivateSecurityList.id}"]
  route_table_id             = "${oci_core_route_table.CreatePrivateRouteTable.id}"
  dhcp_options_id            = "${oci_core_virtual_network.CreateVCN.default_dhcp_options_id}"
  prohibit_public_ip_on_vnic = "${var.private_prohibit_public_ip_on_vnic}"
}

// Create Load Balancer 

resource "oci_load_balancer" "CreateLoadBalancer" {
  shape          = "${var.lb_shape}"
  compartment_id = "${oci_identity_compartment.CreateCompartment.id}"

  subnet_ids = [
    "${oci_core_subnet.CreatePublicSubnet.id}",
    "${oci_core_subnet.CreatePublicSubnet2.id}",
  ]

  display_name = "${var.lb_name}"
  is_private   = "${var.lb_is_private}"
}

resource "oci_load_balancer_backend_set" "CreateLoadBalancerBackendSet" {
  name             = "${var.lb_be_name}"
  load_balancer_id = "${oci_load_balancer.CreateLoadBalancer.id}"
  policy           = "${var.lb_be_policy}"

  health_checker {
    port                = "${var.lb_be_health_checker_port}"
    protocol            = "${var.lb_be_health_checker_protocol}"
    response_body_regex = "${var.lb_be_health_checker_regex}"
    url_path            = "${var.lb_be_health_checker_urlpath}"
  }

  session_persistence_configuration {
    cookie_name      = "${var.lb_be_session_cookie}"
    disable_fallback = "${var.lb_be_session_fallback}"
  }
}

resource "oci_load_balancer_listener" "CreateListener" {
  load_balancer_id         = "${oci_load_balancer.CreateLoadBalancer.id}"
  name                     = "${var.lb_listener_name}"
  default_backend_set_name = "${oci_load_balancer_backend_set.CreateLoadBalancerBackendSet.name}"

  #hostname_names           = ["${oci_load_balancer_hostname.test_hostname1.name}", "${oci_load_balancer_hostname.test_hostname2.name}"]
  port     = "${var.lb_listener_port}"
  protocol = "${var.lb_listener_protocol}"

  #rule_set_names           = ["${oci_load_balancer_rule_set.test_rule_set.name}"]

  connection_configuration {
    idle_timeout_in_seconds = "${var.lb_listener_connection_configuration_idle_timeout}"
  }
}

// CREATE LINUX INSTANCE IN THE PUBLIC SUBNET

resource "oci_core_instance" "CreateInstance" {
  availability_domain = "${lookup(data.oci_identity_availability_domains.ADs.availability_domains[0],"name")}"
  compartment_id      = "${oci_identity_compartment.CreateCompartment.id}"
  shape               = "${var.instance_shape_name}"

  agent_config {
    is_monitoring_disabled = "${var.is_monitoring_disabled}"
  }

  source_details {
    source_id   = "${lookup(data.oci_core_images.oraclelinux.images[0],"id")}"
    source_type = "${var.source_type}"
  }

  create_vnic_details {
    subnet_id        = "${oci_core_subnet.CreatePublicSubnet.id}"
    assign_public_ip = "${var.assign_public_ip}"
    hostname_label   = "${var.instance_create_vnic_details_hostname_label}"
  }

  display_name = "${var.instance_display_name}"

  metadata {
    ssh_authorized_keys = "${var.ssh_public_key}"
    user_data           = "${base64encode(var.user-data)}"
  }

  subnet_id = "${oci_core_subnet.CreatePublicSubnet.id}"
}

resource "oci_core_instance_configuration" "CreateInstanceConfiguration" {
  compartment_id = "${oci_identity_compartment.CreateCompartment.id}"
  display_name   = "${var.instance_configuration_name}"

  instance_details {
    instance_type = "${var.instance_configuration_type}"

    launch_details {
      compartment_id = "${oci_identity_compartment.CreateCompartment.id}"
      shape          = "${var.instance_shape_name}"
      display_name   = "${var.instance_configuration_name}"

      create_vnic_details {
        assign_public_ip       = "${var.instance_configuration_vnic_details_assign_public_ip}"
        display_name           = "${var.instance_configuration_vnic_details_name}"
        skip_source_dest_check = "${var.instance_configuration_vcnic_skip_source_dest_check}"
      }

      extended_metadata {
        ssh_authorized_keys = "${var.ssh_public_key}"
        user_data           = "${base64encode(var.user-data)}"
      }

      source_details = {
        source_type = "${var.instance_configuration_source_details_source_type}"
        image_id    = "${lookup(data.oci_core_images.oraclelinux.images[1],"id")}"
      }
    }
  }
}

resource "oci_core_instance_pool" "CreateInstancePool" {
  compartment_id            = "${oci_identity_compartment.CreateCompartment.id}"
  instance_configuration_id = "${oci_core_instance_configuration.CreateInstanceConfiguration.id}"
  size                      = "${var.instance_pool_size}"
  state                     = "${var.instance_pool_state}"
  display_name              = "${var.instance_pool_name}"

  placement_configurations {
    availability_domain = "${lookup(data.oci_identity_availability_domains.ADs.availability_domains[0],"name")}"
    primary_subnet_id   = "${oci_core_subnet.CreatePrivateSubnet.id}"
  }

  load_balancers {
    #Required
    backend_set_name = "${oci_load_balancer_backend_set.CreateLoadBalancerBackendSet.name}"
    load_balancer_id = "${oci_load_balancer.CreateLoadBalancer.id}"
    port             = "${var.instance_pool_load_balancers_port}"
    vnic_selection   = "${var.instance_pool_load_balancers_vnic_selection}"
  }
}

resource "oci_autoscaling_auto_scaling_configuration" "CreateAutoScalingConfiguration" {
  compartment_id       = "${oci_identity_compartment.CreateCompartment.id}"
  cool_down_in_seconds = "${var.autoscaling_cooldown_in_seconds}"
  display_name         = "${var.autoscaling_name}"
  is_enabled           = "${var.autoscaling_is_enabled}"

  policies {
    capacity {
      initial = "${var.autoscaling_policies_initial}"
      max     = "${var.autoscaling_policies_max}"
      min     = "${var.autoscaling_policies_min}"
    }

    display_name = "${var.autoscaling_policy_name}"
    policy_type  = "${var.autoscaling_type}"

    rules {
      action {
        type  = "${var.autoscaling_rules_action_type_out}"
        value = "${var.autoscaling_rules_action_value_out}"
      }

      display_name = "${var.autoscaling_rules_name_out}"

      metric {
        metric_type = "${var.autoscaling_rules_metric_type_out}"

        threshold {
          operator = "${var.autoscaling_rules_metric_threshold_operator_out}"
          value    = "${var.autoscaling_rules_metric_threshold_value_out}"
        }
      }
    }

    rules {
      action {
        type  = "${var.autoscaling_rules_action_type_in}"
        value = "${var.autoscaling_rules_action_value_in}"
      }

      display_name = "${var.autoscaling_rules_name_in}"

      metric {
        metric_type = "${var.autoscaling_rules_metric_type_in}"

        threshold {
          operator = "${var.autoscaling_rules_metric_threshold_operator_in}"
          value    = "${var.autoscaling_rules_metric_threshold_value_in}"
        }
      }
    }
  }

  auto_scaling_resources {
    id   = "${oci_core_instance_pool.CreateInstancePool.id}"
    type = "${var.autoscaling_resources_type}"
  }
}
