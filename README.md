Test
-----
[![Build Status](https://dev.azure.com/jamesdld23/vpc_lab/_apis/build/status/JamesDLD.terraform-azurerm-Az-Vm?branchName=master)](https://dev.azure.com/jamesdld23/vpc_lab/_build/latest?definitionId=15&branchName=master)

Requirement
-----
Terraform v0.12.6 and above. 

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

variable "virtual_networks" {
  default = {

    vnet1 = {
      id            = "1"
      prefix        = "npd"
      address_space = ["10.0.128.0/24", "198.18.2.0/24"]
    }

  }
}

variable "subnets" {
  default = {

    snet1 = {
      vnet_key       = "vnet1"         #(Mandatory) 
      name           = "demo1"         #(Mandatory) 
      address_prefix = "10.0.128.0/28" #(Mandatory) 
    }

    snet2 = {
      vnet_key          = "vnet1"                                #(Mandatory) 
      name              = "demo2"                                #(Mandatory) 
      address_prefix    = "10.0.128.16/28"                       #(Mandatory) 
      service_endpoints = ["Microsoft.Sql", "Microsoft.Storage"] #(Optional) delete this line for no NSG
    }
    /*
    snet3 = {
      vnet_key       = "vnet1"              #(Mandatory) 
      name           = "AzureBastionSubnet" #(Mandatory) 
      address_prefix = "10.0.128.32/27"     #(Mandatory) 
    }
    */
  }
}

variable "Lbs" {
  default = {
    lb1 = {
      id               = "1"      #Id of the load balancer use as a suffix of the load balancer name
      suffix_name      = "demovm" #It must equals the Vm suffix_name
      subnet_iteration = "0"      #Id of the Subnet
      static_ip        = "10.0.128.5"
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
      subnet_iteration     = "1"               #(Mandatory) Id of the Subnet
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
      ]                                                 #(Mandatory) For no data disks set []
      internal_lb_iteration         = "0"               #(Optional) Id of the Internal Load Balancer, set to null or delete the line if there is no Load Balancer
      public_lb_iteration           = null              #(Optional) Id of the public Load Balancer, set to null or delete the line if there is no public Load Balancer
      public_ip_iteration           = null              #(Optional) Id of the public Ip, set to null if there is no public Ip
      subnet_iteration              = "0"               #(Mandatory) Id of the Subnet
      zones                         = ["1"]             #(Optional) Availability Zone id, could be 1, 2 or 3, if you don't need to set it to "", WARNING you could not have Availabilitysets and AvailabilityZones
      security_group_iteration      = null              #(Optional) Id of the Network Security Group, set to null if there is no Network Security Groups
      static_ip                     = "10.0.128.4"      #(Optional) Set null to get dynamic IP or delete this line
      enable_accelerated_networking = false             #(Optional) 
      enable_ip_forwarding          = false             #(Optional) 
      vm_size                       = "Standard_DS1_v2" #(Mandatory) 
      managed_disk_type             = "Premium_LRS"     #(Mandatory) 
      #backup_policy_name            = "BackupPolicy-Schedule1" #(Optional) Set null to disable backup (WARNING, this will delete previous backup) otherwise set a backup policy like BackupPolicy-Schedule1
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
      enable_ip_forwarding              = true                     #(Optional) 
      subnet_iteration                  = "1"                      #(Mandatory) Id of the Subnet
      zones                             = ["1"]                    #Availability Zone id, could be 1, 2 or 3, if you don't need to set it to "", WARNING you could not have Availabilitysets and AvailabilityZones
      vm_size                           = "Standard_DS1_v2"        #(Mandatory) 
      managed_disk_type                 = "Premium_LRS"            #(Mandatory) 
    }
  }
}

variable "additional_tags" {
  default = {
    iac = "terraform"
  }
}

#Call module
module "Az-VirtualNetwork-Demo" {
  source                      = "JamesDLD/Az-VirtualNetwork/azurerm"
  version                     = "0.1.1"
  net_prefix                  = "myproductvm-perimeter"
  network_resource_group_name = "infr-jdld-noprd-rg1"
  virtual_networks            = var.virtual_networks
  subnets                     = var.subnets
  route_tables                = []
  network_security_groups     = []
  net_additional_tags         = var.additional_tags
}

module "Create-AzureRmLoadBalancer-Demo" {
  source                 = "JamesDLD/Az-LoadBalancer/azurerm"
  version                = "0.1.1"
  Lbs                    = var.Lbs
  LbRules                = var.LbRules
  lb_prefix              = "myproductvm-perimeter"
  lb_location            = element(module.Az-VirtualNetwork-Demo.vnet_locations, 0)
  lb_resource_group_name = "infr-jdld-noprd-rg1"
  Lb_sku                 = "basic"
  subnets_ids            = module.Az-VirtualNetwork-Demo.subnet_ids
  lb_additional_tags     = var.additional_tags
}

module "Az-Vm-Demo" {
  source                  = "JamesDLD/Az-Vm/azurerm"
  sa_bootdiag_storage_uri = "https://infrasdbx1vpcjdld1.blob.core.windows.net/" #(Mandatory)
  subnets_ids             = module.Az-VirtualNetwork-Demo.subnet_ids           #(Mandatory)
  linux_vms               = var.linux_vms                                      #(Mandatory)
  windows_vms             = var.windows_vms                                    #(Mandatory)
  vm_resource_group_name  = "infr-jdld-noprd-rg1"
  vm_prefix               = "myproductvm" #(Optional)
  admin_username          = "myadmlogin"
  admin_password          = "Myadmlogin_StoredInASecretFile?"
  internal_lb_backend_ids = module.Create-AzureRmLoadBalancer-Demo.lb_backend_ids #(Optional)
  vm_additional_tags      = var.additional_tags                                   #(Optional)
  key_vault_name          = "leccaasgalqualkv1"                                   #(Optional)
  key_vault_rgname        = "caas-infra1-svcd-gal-qual-rg1"                       #(Optional) Use the RG's location if not set

  #All other optional values
  /*
  vm_location                       = element(module.Az-VirtualNetwork-Demo.vnet_locations, 0) #(Optional) Use the RG's location if not set
  workspace_name                    = ""                                                       #(Optional)
  workspace_resource_rgname         = ""                                                       #(Optional) Use the RG's location if not set
  enable_log_analytics_dependencies = "true"                                                   #(Optional) Default is false
  nsgs_ids                          = module.Az-VirtualNetwork-Demo.network_security_group_ids #(Optional)
  public_ip_ids                     = module.Az-VirtualNetwork-Demo.public_ip_ids              #(Optional)
  public_lb_backend_ids             = ["public_backend_id1", "public_backend_id1"]             #(Optional)
  recovery_services_vault_name      = "infra-jdld-infr-rsv1"                                   #(Optional)
  recovery_services_vault_rgname    = "infr-jdld-noprd-rg1"                                    #(Optional) Use the RG's location if not set
*/

}

```