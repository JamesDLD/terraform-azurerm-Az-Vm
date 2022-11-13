Test
-----
[![Build Status](https://dev.azure.com/jamesdld23/vpc_lab/_apis/build/status/JamesDLD.terraform-azurerm-Az-Vm?branchName=master)](https://dev.azure.com/jamesdld23/vpc_lab/_build/latest?definitionId=15&branchName=master)

Content
-----
Create the following objects : vnet, subnet, load balancer, linux and windows virtual machines.

Requirement
-----

- Terraform v1.3.4 and above.
- AzureRm provider version v3.31 and above.

Usage
-----

```hcl
#Set the terraform backend
terraform {
  backend "local" {} #Using a local backend just for the demo, the reco is to use a remote backend, see : https://jamesdld.github.io/terraform/Best-Practice/BestPractice-1/
}

#Set the Provider
provider "azurerm" {
  tenant_id       = var.tenant_id
  subscription_id = var.subscription_id
  client_id       = var.client_id
  client_secret   = var.client_secret
  features {}
}

#Set authentication variables
variable "tenant_id" {
  description = "Azure tenant Id."
}

variable "subscription_id" {
  description = "Azure subscription Id."
}

variable "client_id" {
  description = "Azure service principal application Id."
}

variable "client_secret" {
  description = "Azure service principal application Secret."
}

#Set resource variables

variable "Lbs" {
  default = {
    lb1 = {
      id          = "1"      #Id of the load balancer use as a suffix of the load balancer name
      suffix_name = "demovm" #It must equals the Vm suffix_name
      snet_key    = "demo1"  #Key of the Subnet
      static_ip   = "10.0.128.5"
    }
  }
}

variable "LbRules" {
  default = {
    lbrules1 = {
      Id                = "1"      #Id of a the rule within the Load Balancer 
      lb_key            = "lb1"    #Id of the Load Balancer
      suffix_name       = "demovm" #It must equals the Lbs suffix_name
      lb_port           = "22"
      probe_port        = "22"
      backend_port      = "22"
      probe_protocol    = "Tcp"
      request_path      = "/"
      load_distribution = "SourceIPProtocol"
    }
  }
}

variable "linux_vms" {
  default = {
    vm1 = {
      suffix_name          = "nva"             #(Mandatory) suffix of the vm
      id                   = "1"               #(Mandatory) Id of the VM
      storage_data_disks   = []                #(Mandatory) For no data disks set []
      snet_key             = "demo2"           #Key of the Subnet
      zones                = ["1"]             #Availability Zone id, could be 1, 2 or 3, if you don't need to set it to null or delete the line
      vm_size              = "Standard_DS1_v2" #(Mandatory) 
      managed_disk_type    = "Premium_LRS"     #(Mandatory) 
      enable_ip_forwarding = true              #(Optional)
    }

    vm2 = {
      suffix_name = "ssh" #(Mandatory) suffix of the vm
      id          = "1"   #(Mandatory)Id of the VM
      storage_data_disks = [
        {
          id                = "1" #Disk id
          lun               = "0"
          disk_size_gb      = "32"
          managed_disk_type = "Premium_LRS"
          caching           = "ReadWrite"
          create_option     = "Empty"
        },
      ]                                                        #(Mandatory) For no data disks set []
      internal_lb_key               = "lb1"                    #(Optional) Key of the Internal Load Balancer, set to null or delete the line if there is no Load Balancer
      public_lb_key                 = null                     #(Optional) Key of the public Load Balancer, set to null or delete the line if there is no public Load Balancer
      public_ip_iteration           = null                     #(Optional) Id of the public Ip, set to null if there is no public Ip
      snet_key                      = "demo1"                  #Key of the Subnet
      zones                         = ["1"]                    #(Optional) Availability Zone id, could be 1, 2 or 3, if you don't need to set it to "", WARNING you could not have Availabilitysets and AvailabilityZones
      nsg_key                       = null                     #(Optional) Key of the Network Security Group, set to null if there is no Network Security Groups
      static_ip                     = "10.0.128.4"             #(Optional) Set null to get dynamic IP or delete this line
      enable_accelerated_networking = false                    #(Optional) 
      enable_ip_forwarding          = false                    #(Optional) 
      vm_size                       = "Standard_DS1_v2"        #(Mandatory) 
      managed_disk_type             = "Premium_LRS"            #(Mandatory) 
      backup_policy_name            = "BackupPolicy-Schedule1" #(Optional) Set null to disable backup (WARNING, this will delete previous backup) otherwise set a backup policy like BackupPolicy-Schedule1
    }
  }
}

variable "windows_vms" {
  default = {
    vm1 = {
      suffix_name                       = "rds"                    #(Mandatory) suffix of the vm
      id                                = "1"                      #(Mandatory) Id of the VM
      storage_image_reference_offer     = "WindowsServer"          #(Optional)
      storage_image_reference_publisher = "MicrosoftWindowsServer" #(Optional)
      storage_image_reference_sku       = "2019-Datacenter"        #(Optional)
      storage_image_reference_version   = "Latest"                 #(Optional)
      storage_data_disks                = []                       #(Mandatory) For no data disks set []
      enable_accelerated_networking     = true                     #(Optional) 
      snet_key                          = "demo2"                  #Key of the Subnet
      zones                             = ["1"]                    #Availability Zone id, could be 1, 2 or 3, if you don't need to set it to "", WARNING you could not have Availabilitysets and AvailabilityZones
      vm_size                           = "Standard_F4s_v2"        #"Standard_DS1_v2"        #(Mandatory) 
      managed_disk_type                 = "Premium_LRS"            #(Mandatory) 
    }
  }
}

variable "additional_tags" {
  default = {
    iac = "terraform"
  }
}
#Call native Terraform resources

data "azurerm_resource_group" "rg" {
  name = "infr-jdld-noprd-rg1"
}

resource "azurerm_virtual_network" "Demo" {
  name                = "myproductvm-perimeter-npd-vnet1"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  address_space       = ["10.0.128.0/24", "198.18.2.0/24"]
  tags                = data.azurerm_resource_group.rg.tags

  subnet {
    name           = "demo1"
    address_prefix = "10.0.128.0/28"
  }

  subnet {
    name           = "demo2"
    address_prefix = "10.0.128.16/28"
  }
}

#Call module

module "Create-AzureRmLoadBalancer-Demo" {
  source                 = "JamesDLD/Az-LoadBalancer/azurerm"
  version                = "0.2.1"
  Lbs                    = var.Lbs
  LbRules                = var.LbRules
  lb_prefix              = "myproductvm-perimeter"
  lb_location            = data.azurerm_resource_group.rg.location
  lb_resource_group_name = data.azurerm_resource_group.rg.name
  Lb_sku                 = "Basic"
  subnets                = { for x, y in azurerm_virtual_network.Demo.subnet : x.name => y }
  lb_additional_tags     = var.additional_tags
}

module "Az-Vm-Demo" {
  source                            = "JamesDLD/Az-Vm/azurerm"
  version                           = "0.3.1"
  sa_bootdiag_storage_uri           = "https://infrasdbx1vpcjdld1.blob.core.windows.net/" #(Mandatory)
  subnets                           = { for x, y in azurerm_virtual_network.Demo.subnet : x.name => y }
  linux_vms                         = var.linux_vms   #(Mandatory)
  windows_vms                       = var.windows_vms #(Mandatory)
  vm_resource_group_name            = data.azurerm_resource_group.rg.name
  vm_prefix                         = "myproductvm" #(Optional)
  admin_username                    = "myadmlogin"
  admin_password                    = "Myadmlogin_StoredInASecretFile?"
  internal_lb_backend_address_pools = module.Create-AzureRmLoadBalancer-Demo.lb_backend_address_pools #(Optional)
  vm_additional_tags                = var.additional_tags                                             #(Optional)
}

```