# tf-autoscaling-demo-resource-mgr

Creates demo stack with Oracle Cloud Infrastructure (OCI) Resource Manager using Terraform which creates an autoscaling demo environment.

Running this in OCI Resource Manager creates following resources:


* Compartment
* Virtual Cloud Network (VCN)
* Nat Gateway
* Internet Gateway
* Public load balancer and a backend set which has instance pool as destination
* Two public subnets for the load balancer and jump server including route table and security list (ports 22 and 80 are open)
* One private subnet for the instance pool instances with route table and security list (ports 22 and 80 are open)
* Public & Private routetables - Public RT will have a route to Internet Gateway and Private RT route to NAT Gateway
* Public & Private securitylists - Both allow traffic to ports 22 and 80 only. By default they allow traffic from any source but this can be modified to allow only traffic from CIDR block deemed necessary
* One compute instance with the smallest shape to act as a jump server and a 7.6 linux image - the instance public IP will be displayed in the end. 

## Requirements and install instructions

1. Valid OCI account to install these components
2. Download these .tf files as a zip and navigate in OCI under *Resource Manager*
3. Press "Create Stack" and upload created zip file as your new stack
4. Navigate inside the stack and from the left side menu "Resources" click *Variables* and *Edit Variables*
5. Add following variables:
* region (the name of region you are operating for example eu-frankfurt-1)
* tenancy_ocid (your tenancy's OCID - from left side menu *Administration -> Tenancy Details*)
* ssh_public_key (ssh key to be used - you can find create instructions from [here](https://docs.cloud.oracle.com/iaas/Content/GSG/Tasks/creatingkeys.htm)) Note that you should not paste keys here if you would use this in any other than demo purposes
6. Navigate inside stack and press *Terraform Actions -> Plan*, this usually runs 2-3 minutes
7. If Plan succeeded without issues run *Terraform Actions -> Apply*, this creates resources and will run around 60-90 minutes
8. Review the public IP of compute instance and the private IP's for compute and database instance. You can use the private ssh key and *opc* user to login to these instances

## Removal of stack

In case you want to remove created stack:

* Navigate inside stack and press *Terraform Actions -> Destroy*, this will remove all the created resources

## Additional notes

You can freely change the variables in the variables.tf depending what you need. One could potentially scale down the database shape, open different ports in security list or change database version. Try and test!

Thanks for [Stephen Cross](https://gist.github.com/scross01/bcd21c12b15787f3ae9d51d0d9b2df06) for the filtering of OCI images using specific OS version. 

## Using without resource manager

Incase you don't want to use this with Resource Manager there are slight edits you will need in variables.tf and main.tf. Also you should have following environment variables set in your machine where you are running Terraform and set up your keys in OCI for the user.

Set following environment variables:

* TF_VAR_tenancy_ocid - Your tenancy OCID
* TF_VAR_user_ocid - Your user OCID which you are connecting to OCI
* TF_VAR_fingerprint - Fingerprint for your key found from user details
* TF_VAR_private_key_path - Path to your private key on your machine
* TF_VAR_region - region which you are using

Running Terraform:

* terraform init
* terraform plan !! Remember to review the plan !!
* terraform apply

To remove resources:

* terraform destroy

Edit main.tf provider:

```hcl
provider "oci" {
  tenancy_ocid     = "${var.tenancy_ocid}"
  user_ocid        = "${var.user_ocid}"
  fingerprint      = "${var.fingerprint}"
  private_key_path = "${var.private_key_path}"
  region           = "${var.region}"
}
```
Edit variables.tf and add:

```hcl
variable "tenancy_ocid" {} // Your tenancy's OCID
variable "user_ocid" {} // Your user's OCID
variable "fingerprint" {} // Fingerprint for the user key, can be found under user in console
variable "private_key_path" {} // Where your private key is located on the server you are running these scripts
variable "region" {} // Which region is used in OCI eg. eu-frankfurt-1 
```
