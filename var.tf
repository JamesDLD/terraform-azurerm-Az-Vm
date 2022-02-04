

variable "sa_bootdiag_storage_uri" {
  type        = string
  description = "Azure Storage Account Primary Queue Service Endpoint."
}

variable "linux_storage_image_reference" {
  type        = map(string)
  description = "Could containt an 'id' of a custom image or the following parameters for an Azure public 'image publisher','offer','sku', 'version'"
  default = {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "Latest"
  }
}

variable "linux_vms" {
  description = "Linux VMs list."
  type        = any
}

variable "linux_cloud_init_contents" {
  description = "Linux VMs list, sample : https://docs.microsoft.com/azure/virtual-machines/linux/tutorial-automate-vm-deployment?WT.mc_id=AZ-MVP-5003548"
  type        = any
  default     = {}
}

variable "windows_vms" {
  description = "Windows VMs list."
  type        = any
}

variable "windows_storage_image_reference" {
  type        = map(string)
  description = "Could containt an 'id' of a custom image or the following parameters for an Azure public 'image publisher','offer','sku', 'version'"
  default = {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "Latest"
  }
}

variable "vm_location" {
  description = "VM's location if different that the resource group's location."
  type        = string
  default     = ""
}

variable "vm_resource_group_name" {
  description = "VM's resource group name."
}

variable "vm_prefix" {
  description = "Prefix used for the VM, Disk and Nic names."
  default     = ""
}

variable "vm_additional_tags" {
  description = "Tags pushed on the VM, Disk and Nic in addition to the resource group tags."
  type        = map(string)
}

variable "admin_username" {
  description = "Specifies the name of the local administrator account."
  default     = ""
}

variable "admin_password" {
  description = "The password associated with the local administrator account."
  default     = ""
}

variable "ssh_key" {
  description = "(Optional) This field is required if disable_password_authentication is set to true."
  default     = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDMelxhig6IY80GykqTf0wkozE860GPkd7RU5231b2UEMVyj1BBiPwTYCbAzY/8xBNyz9VL5uzjM6+S9N+OpIZKAMITzU1IVGzo7DtucNwKkRZ6egq+kfFG2JiKs945XOB6xhfFbzoneBu++yEToOrNLHM9Eu5eFFS07Ow+I2YIrTPpfw/UZCNUGFZun2iwm9MkKSWrBR8+/kE54WOAbrGq9symayBvD1A3aHBJ3HPL/geIzNAWw4y6YYsaCWOht1pVMfxf+LSf42XKJ/T8HjO0Ea2lKq5Nmh5cv5aKm6nVprF/L6SlQ3dNSUYPprnDiDBlPBGaBvtz2Hj0sseiu0YH"
}

variable "enable_log_analytics_dependencies" {
  description = "Decide to disable log analytics dependencies"
  default     = false
}
variable "enable_service_map" {
  description = "Does Service map should be enabled on the Log Analytics Worksapce : https://docs.microsoft.com/en-us/azure/azure-monitor/vm/service-map?WT.mc_id=AZ-MVP-5003548"
  default     = true
}
variable "workspace_name" {
  description = "Log Analysitcs workspace name."
  default     = ""
}

variable "workspace_resource_rgname" {
  description = "Log Analysitcs workspace resource group name, use the context's RG if not provided."
  default     = ""
}

variable "OmsAgentForLinux" {
  type = map(string)
  default = {
    publisher                  = "Microsoft.EnterpriseCloud.Monitoring"
    type                       = "OmsAgentForLinux"
    type_handler_version       = "1.13" #https://docs.microsoft.com/en-us/azure/virtual-machines/extensions/oms-linux
    auto_upgrade_minor_version = "true"
  }
}

variable "DependencyAgentLinux" {
  type = map(string)
  default = {
    publisher                  = "Microsoft.Azure.Monitoring.DependencyAgent"
    type                       = "DependencyAgentLinux"
    type_handler_version       = "9.5"
    auto_upgrade_minor_version = "true"
  }
}

variable "DependencyAgentWindows" {
  type = map(string)
  default = {
    publisher                  = "Microsoft.Azure.Monitoring.DependencyAgent"
    type                       = "DependencyAgentWindows"
    type_handler_version       = "9.5"
    auto_upgrade_minor_version = "true"
  }
}

variable "OmsAgentForWindows" {
  type = map(string)
  default = {
    publisher                  = "Microsoft.EnterpriseCloud.Monitoring"
    type                       = "MicrosoftMonitoringAgent"
    type_handler_version       = "1.0" #https://docs.microsoft.com/en-us/azure/virtual-machines/extensions/oms-windows
    auto_upgrade_minor_version = "true"
  }
}

variable "subnets" {
  description = "A map of subnet with keys containing the subnet 'id'."
  type        = any
}

variable "internal_lb_backend_address_pools" {
  description = "A map of Network Interfaces internal load balancers containing the backend 'id'."
  type        = any
  default     = {}
}

variable "public_lb_backend_address_pools" {
  description = "A map of Network Interfaces public load balancers containing the backend 'id'."
  type        = any
  default     = {}
}

variable "network_security_groups" {
  description = "A map of network security groups containing their 'id'."
  type        = any
  default     = {}
}

variable "public_ips" {
  description = "A map of Public Ips containing their 'id'."
  type        = any
  default     = {}
}

# -
# - Linux Virtual Machines Backup
# -

variable "recovery_services_vault_name" {
  description = "Recovery services vault name."
  default     = ""
}

variable "recovery_services_vault_rgname" {
  description = "Recovery services vault resource group name, if not provided the context RG will be used."
  default     = ""
}

# -
# - Key vault
# -
variable "key_vault_name" {
  description = "Key vault name."
  default     = ""
}

variable "key_vault_rgname" {
  description = "Key vault resource group name, if not provided the context RG will be used."
  default     = ""
}

variable "managed_identity" {
  description = "Managed Service Identity"
  default = [
    {
      type = "SystemAssigned"
    }
  ]
}
