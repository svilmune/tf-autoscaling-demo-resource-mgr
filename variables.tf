/*

These are variables to create basic environment in Oracle Cloud Infrastructure.

Depending on requirement variables can be modified. Following environment variables must be set in the resource manager variables section:

* region
* tenancy_ocid
* ssh_public_key

For more detailed instructions review main.tf

Author: Simo Vilmunen 25/03/2019

*/

variable "tenancy_ocid" {} // Your tenancy's OCID
variable "region" {} // Which region is used in OCI eg. eu-frankfurt-1 
variable "ssh_public_key" {} // Your ssh key to be used for login into instances 

// ORACLE LINUX VERSION AND OS NAME

variable "operating_system" {
  default = "Oracle Linux"
} // Name for the OS

variable "operating_system_version" {
  default = "7.6"
} // OS Version

// COMPARTMENT VARIABLES
variable "compartment_name" {
  default = "MyCompartment"
} // Name for the compartment

variable "compartment_description" {
  default = "This compartment holds all the DEMO resources"
} // Description for the compartment

// VCN VARIABLES
variable "vcn_cidr_block" {
  default = "172.16.0.0/16"
} // Define the CIDR block for your OCI cloud

variable "display_name" {
  default = "My VCN"
} // VCN Name

variable "dns_label" {
  default = "oci"
} // DNS Label for VCN

// NAT GW VARIABLES
variable "nat_gateway_display_name" {
  default = "NatGateway"
} // Name for the NAT GW

variable "nat_gateway_block_traffic" {
  default = "false"
} // Is NAT GW active or not

// INTERNET GW VARIABLES

variable "internet_gateway_display_name" {
  default = "InternetGateway"
} // Name for the IGW

variable "internet_gateway_enabled" {
  default = "true"
} // Is IGW enabled or not

// PUBLIC AND PRIVATE ROUTETABLE VARIABLES

variable "public_route_table_display_name" {
  default = "PublicRoute"
} // Name for the public routetable

variable "private_route_table_display_name" {
  default = "PrivateRoute"
} // Name for the private routetable

variable "igw_route_cidr_block" {
  default = "0.0.0.0/0"
}

variable "natgw_route_cidr_block" {
  default = "0.0.0.0/0"
}

// PUBLIC AND PRIVATE SECURITYLIST VARIABLES

variable "public_sl_display_name" {
  default = "PublicSL"
} // Name for the public securitylist

variable "private_sl_display_name" {
  default = "PrivateSL"
} // Name for the private securitylist

variable "egress_destination" {
  default = "0.0.0.0/0"
} // Outside traffic is allowed

variable "tcp_protocol" {
  default = "6"
} // 6 for TCP traffic

variable "public_ssh_sl_source" {
  default = "0.0.0.0/0"
}

variable "public_http_sl_source" {
  default = "0.0.0.0/0"
}

variable "rule_stateless" {
  default = "false"
} // All rules are stateful by default so no need to define rules both ways

variable "public_sl_ssh_tcp_port" {
  default = "22"
} // Open port 22 for SSH access

variable "private_sl_ssh_tcp_port" {
  default = "22"
} // Open port 22 for SSH access

variable "private_sl_http_tcp_port" {
  default = "80"
} // Open port 80 for HTTP

variable "public_sl_http_tcp_port" {
  default = "80"
} // Open port 80 for HTTP

// PUBLIC AND PRIVATE SUBNET VARIABLES
variable "public_subnet_display_name" {
  default = "PublicSubnet"
} // Name for public subnet

variable "private_subnet_display_name" {
  default = "PrivateSubnet"
} // Name for private subnet

variable "public_subnet_dns_label" {
  default = "pub"
} // DNS Label for public subnet

variable "private_subnet_dns_label" {
  default = "pri"
} // DNS label for private subnet

variable "public_prohibit_public_ip_on_vnic" {
  default = "false"
} // Can instances in public subnet get public IP

variable "private_prohibit_public_ip_on_vnic" {
  default = "true"
} // Can instances in private subnet get public IP

// INSTANCE VARIABLES

variable "instance_shape_name" {
  default = "VM.Standard2.1"
} // Shape what to be used. Smallest shape selected by default
variable "source_type" {
  default = "image"
} // What type the image source is

variable "assign_public_ip" {
  default = "true"
} // This is server in public subnet it will have a public IP
variable "instance_display_name" {
  default = "MyPublicServer"
} // Name for the instance

variable "instance_create_vnic_details_hostname_label" {
  default = "public-1"
}

variable "is_monitoring_disabled" {
  default = false
}

// INSTANCE POOL VARIABLES

variable "instance_pool_load_balancers_port" {
  default = "80"
} // What port load balancer listener is on

variable "instance_pool_load_balancers_vnic_selection" {
  default = "PrimaryVnic"
} // Use primary VCNIC

variable "user-data" {
  default = <<EOF
#!/bin/bash -x
echo '################### webserver userdata begins #####################'
touch ~opc/userdata.`date +%s`.start
# echo '########## yum update all ###############'
# yum update -y
echo '########## basic webserver ##############'
yum install -y httpd stress
systemctl enable  httpd.service
systemctl start  httpd.service
echo '<html><head></head><body><pre><code>' > /var/www/html/index.html
hostname >> /var/www/html/index.html
echo '' >> /var/www/html/index.html
cat /etc/os-release >> /var/www/html/index.html
echo '</code></pre></body></html>' >> /var/www/html/index.html
#firewall-offline-cmd --add-service=http
systemctl disable  firewalld
systemctl stop  firewalld
touch ~opc/userdata.`date +%s`.finish
echo '################### webserver userdata ends #######################'
EOF
} // User data to install httpd server and disable firewalld

// LOAD BALANCER VARIABLES

variable "lb_shape" {
  default = "100Mbps"
}

variable "lb_name" {
  default = "MyLB"
}

variable "lb_is_private" {
  default = false
}

variable "lb_be_name" {
  default = "MyLBBE1"
}

variable "lb_be_policy" {
  default = "ROUND_ROBIN"
}

variable "lb_be_health_checker_port" {
  default = "80"
}

variable "lb_be_health_checker_protocol" {
  default = "HTTP"
}

variable "lb_be_health_checker_regex" {
  default = ".*"
}

variable "lb_be_health_checker_urlpath" {
  default = "/index.html"
}

variable "lb_be_session_cookie" {
  default = "lb-session1"
}

variable "lb_be_session_fallback" {
  default = true
}

variable "lb_listener_name" {
  default = "MyHTTPListener"
}

variable "lb_listener_port" {
  default = 80
}

variable "lb_listener_protocol" {
  default = "HTTP"
}

variable "lb_listener_connection_configuration_idle_timeout" {
  default = "300"
}

// INSTANCE CONFIGURATION VARIABLES

variable "instance_configuration_name" {
  default = "MyInstanceConfiguration"
}

variable "instance_configuration_type" {
  default = "compute"
}

variable "instance_configuration_launch_details_name" {
  default = "MyLaunchDetails"
}

variable "instance_configuration_vnic_details_assign_public_ip" {
  default = false
}

variable "instance_configuration_vnic_details_name" {
  default = "MyInstance"
}

variable "instance_configuration_vcnic_skip_source_dest_check" {
  default = false
}

variable "instance_configuration_source_details_source_type" {
  default = "image"
}

// INSTANCE POOL VARIABLES

variable "instance_pool_size" {
  default = 1
}

variable "instance_pool_state" {
  default = "RUNNING"
}

variable "instance_pool_name" {
  default = "MyInstancePool"
}

// AUTOSCALING VARIABLES
variable "autoscaling_cooldown_in_seconds" {
  default = "300"
}

variable "autoscaling_name" {
  default = "MyAutoScalingConfiguration"
}

variable "autoscaling_is_enabled" {
  default = true
}

variable "autoscaling_policies_initial" {
  default = "2"
}

variable "autoscaling_policies_max" {
  default = "4"
}

variable "autoscaling_policies_min" {
  default = "2"
}

variable "autoscaling_policy_name" {
  default = "MyScalingPolicy"
}

variable "autoscaling_type" {
  default = "threshold"
}

variable "autoscaling_rules_action_type_out" {
  default = "CHANGE_COUNT_BY"
}

variable "autoscaling_rules_action_value_out" {
  default = "1"
}

variable "autoscaling_rules_name_out" {
  default = "MyScaleOutRule"
}

variable "autoscaling_rules_metric_type_out" {
  default = "CPU_UTILIZATION"
}

variable "autoscaling_rules_metric_threshold_operator_out" {
  default = "GT"
}

variable "autoscaling_rules_metric_threshold_value_out" {
  default = "10"
}

variable "autoscaling_rules_action_type_in" {
  default = "CHANGE_COUNT_BY"
}

variable "autoscaling_rules_action_value_in" {
  default = "-1"
}

variable "autoscaling_rules_name_in" {
  default = "MyScaleInRule"
}

variable "autoscaling_rules_metric_type_in" {
  default = "CPU_UTILIZATION"
}

variable "autoscaling_rules_metric_threshold_operator_in" {
  default = "LT"
}

variable "autoscaling_rules_metric_threshold_value_in" {
  default = "10"
}

variable "autoscaling_resources_type" {
  default = "instancePool"
}
