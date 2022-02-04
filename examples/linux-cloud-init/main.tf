#Set the terraform backend
terraform {
  backend "azurerm" {
    storage_account_name = "infrasdbx1vpcjdld1"
    container_name       = "tfstate"
    key                  = "Az-Vm.master.linux.tfstate"
    resource_group_name  = "infr-jdld-noprd-rg1"
  }
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
variable "linux_cloud_init_files" {
  description = "A list of local cloud init files located"
  default = {
    mount_three_disk = {
      filepath = "/cloud-init-mount-three-disk.init"
      vars = {
        datadisk_lun_0_name = "mydisk0"
        datadisk_lun_1_name = "mydisk1"
        datadisk_lun_2_name = "mydisk2"
      }
    }
  }
}

variable "linux_vms" {
  default = {
    myappvm001 = {
      suffix_name = "vm"  #(Mandatory) suffix of the vm
      id          = "001" #(Mandatory) Id of the VM
      storage_data_disks = [
        {
          id                = "001" #Disk id
          lun               = "0"
          disk_size_gb      = "32"
          managed_disk_type = "Premium_LRS"
          caching           = "ReadWrite"
          create_option     = "Empty"
        },

        {
          id                = "002" #Disk id
          lun               = "1"
          disk_size_gb      = "32"
          managed_disk_type = "Premium_LRS"
          caching           = "ReadWrite"
          create_option     = "Empty"
        },

        {
          id                = "003" #Disk id
          lun               = "2"
          disk_size_gb      = "32"
          managed_disk_type = "Premium_LRS"
          caching           = "ReadWrite"
          create_option     = "Empty"
        },
      ]                                                  #(Mandatory) For no data disks set []     
      linux_cloud_init_file_key     = "mount_three_disk" #(Optional)
      snet_key                      = "demo1"            #Key of the Subnet
      zones                         = ["1"]              #(Optional) Availability Zone id, could be 1, 2 or 3, if you don't need to set it to "", WARNING you could not have Availabilitysets and AvailabilityZones
      nsg_key                       = null               #(Optional) Key of the Network Security Group, set to null if there is no Network Security Groups
      enable_accelerated_networking = false              #(Optional) 
      vm_size                       = "Standard_DS1_v2"  #(Mandatory) 
      managed_disk_type             = "Premium_LRS"      #(Mandatory) 
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
  name                = "myproductvm-perimeter-npd-vnet2"
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

data "template_file" "cloudconfig" {
  for_each = var.linux_cloud_init_files
  template = file("${path.module}${each.value.filepath}")
  vars     = lookup(each.value, "vars", null)
}

data "template_cloudinit_config" "config" {
  for_each      = var.linux_cloud_init_files
  gzip          = true
  base64_encode = true

  part {
    content_type = "text/cloud-config"
    content      = data.template_file.cloudconfig[each.key].rendered
  }
}

#Call module
module "Az-Vm-Demo" {
  source = "git::https://github.com/JamesDLD/terraform-azurerm-Az-Vm.git//?ref=master"
  #source = "../../"
  #source                    = "JamesDLD/Az-Vm/azurerm"
  #version                   = "0.3.0"
  sa_bootdiag_storage_uri   = "https://infrasdbx1vpcjdld1.blob.core.windows.net/" #(Mandatory)
  subnets                   = { for x, y in azurerm_virtual_network.Demo.subnet : x.name => y }
  linux_vms                 = var.linux_vms                         #(Mandatory)
  linux_cloud_init_contents = data.template_cloudinit_config.config #(Optional)
  windows_vms               = {}                                    #(Mandatory)
  vm_resource_group_name    = data.azurerm_resource_group.rg.name
  vm_prefix                 = "myproductvm"                     #(Optional)
  admin_username            = "myadmlogin"                      #(Optional) Use the one in the vm map if not provided
  admin_password            = "Myadmlogin_StoredInASecretFile?" #(Optional) Use the one in the vm map if not provided, #Warning : When set you can delete this line this will delete the password from the tfstate. All arguments including the administrator login and password will be stored in the raw state as plain-text. Read more about sensitive data in state : https://www.terraform.io/docs/state/sensitive-data.html.
  vm_additional_tags        = var.additional_tags               #(Optional)
}
