# Terraform Stuff

Collection of various Terraform configs/modules/etc.

# Descriptions

## Azure

* [azure/basic_vm_rg.tf](azure/basic_vm_rg.tf):
Creates a resource group and Standard_B2s Ubuntu 16.04 LTS VM. Also creates an NSG with rule to allow SSH from my public IP. Add a .tfvars file to specify SSH public key and resource names, or specify through CLI.