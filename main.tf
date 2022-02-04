# -
# - Data gathering
# -
data "azurerm_resource_group" "vm" {
  name = var.vm_resource_group_name
}

data "azurerm_recovery_services_vault" "vault" {
  count               = var.recovery_services_vault_name == "" ? 0 : 1
  name                = var.recovery_services_vault_name
  resource_group_name = var.recovery_services_vault_rgname == "" ? var.vm_resource_group_name : var.recovery_services_vault_rgname
}

data "azurerm_key_vault" "vault" {
  count               = var.key_vault_name == "" ? 0 : 1
  name                = var.key_vault_name
  resource_group_name = var.key_vault_rgname == "" ? var.vm_resource_group_name : var.key_vault_rgname
}

data "azurerm_log_analytics_workspace" "log" {
  count               = var.workspace_name == "" ? 0 : 1
  name                = var.workspace_name
  resource_group_name = var.workspace_resource_rgname == "" ? var.vm_resource_group_name : var.workspace_resource_rgname
}

# -
# - Global local variables
# -
locals {
  tags                = merge(var.vm_additional_tags, data.azurerm_resource_group.vm.tags)
  location            = var.vm_location == "" ? data.azurerm_resource_group.vm.location : var.vm_location
  custom_data_content = file("${path.module}/files/InitializeVM.ps1")
}

# -
# - Records secret in the Key Vault
# -

resource "azurerm_key_vault_secret" "admin_username" {
  count        = var.key_vault_name == "" ? 0 : 1
  name         = var.admin_username
  value        = var.admin_password
  key_vault_id = element(data.azurerm_key_vault.vault.*.id, 0)
}

# -
# - Log Monitor
# -

resource "azurerm_log_analytics_solution" "ServiceMap" {
  count                 = var.workspace_name == "" || var.enable_service_map != true ? 0 : 1
  solution_name         = "ServiceMap"
  location              = element(data.azurerm_log_analytics_workspace.log.*.location, 0)
  resource_group_name   = element(data.azurerm_log_analytics_workspace.log.*.resource_group_name, 0)
  workspace_resource_id = element(data.azurerm_log_analytics_workspace.log.*.id, 0)
  workspace_name        = element(data.azurerm_log_analytics_workspace.log.*.name, 0)
  tags                  = local.tags
  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/ServiceMap"
  }
}

# -
# - Log Monitor for Linux
# -
locals {
  linux_vms_with_log_analytics_dependencies_keys   = [for x in var.linux_vms : "${x.suffix_name}${x.id}" if var.enable_log_analytics_dependencies == true]
  linux_vms_with_log_analytics_dependencies_values = [for x in var.linux_vms : { enable_log_analytics_dependencies = var.enable_log_analytics_dependencies } if var.enable_log_analytics_dependencies == true]
  linux_vms_with_log_analytics_dependencies        = zipmap(local.linux_vms_with_log_analytics_dependencies_keys, local.linux_vms_with_log_analytics_dependencies_values)
}

resource "azurerm_virtual_machine_extension" "OmsAgentForLinux" {
  depends_on                 = [azurerm_log_analytics_solution.ServiceMap]
  for_each                   = local.linux_vms_with_log_analytics_dependencies
  name                       = "OmsAgentForLinux"
  virtual_machine_id         = azurerm_virtual_machine.linux_vms[each.key].id
  publisher                  = var.OmsAgentForLinux["publisher"]
  type                       = var.OmsAgentForLinux["type"]
  type_handler_version       = var.OmsAgentForLinux["type_handler_version"]
  auto_upgrade_minor_version = var.OmsAgentForLinux["auto_upgrade_minor_version"]
  tags                       = local.tags
  settings                   = <<-BASE_SETTINGS
 {
   "workspaceId" : "${element(data.azurerm_log_analytics_workspace.log.*.workspace_id, 0)}"
 }
BASE_SETTINGS
  protected_settings         = <<-PROTECTED_SETTINGS
 {
   "workspaceKey" : "${element(data.azurerm_log_analytics_workspace.log.*.primary_shared_key, 0)}"
 }
PROTECTED_SETTINGS
}

resource "azurerm_virtual_machine_extension" "DependencyAgentLinux" {
  depends_on                 = [azurerm_virtual_machine_extension.OmsAgentForLinux]
  for_each                   = local.linux_vms_with_log_analytics_dependencies
  name                       = "DependencyAgent"
  virtual_machine_id         = azurerm_virtual_machine.linux_vms[each.key].id
  publisher                  = var.DependencyAgentLinux["publisher"]
  type                       = var.DependencyAgentLinux["type"]
  type_handler_version       = var.DependencyAgentLinux["type_handler_version"]
  auto_upgrade_minor_version = var.DependencyAgentLinux["auto_upgrade_minor_version"]
  tags                       = local.tags
}

# -
# - Linux Network interfaces
# -
resource "azurerm_network_interface" "linux_nics" {
  for_each                      = var.linux_vms
  name                          = "${var.vm_prefix}${each.value["suffix_name"]}${each.value["id"]}nic001"
  location                      = local.location
  resource_group_name           = var.vm_resource_group_name
  internal_dns_name_label       = lookup(each.value, "internal_dns_name_label", null)
  enable_ip_forwarding          = lookup(each.value, "enable_ip_forwarding", null)
  enable_accelerated_networking = lookup(each.value, "enable_accelerated_networking", null)
  dns_servers                   = lookup(each.value, "dns_servers", null)

  ip_configuration {
    name                          = "${var.vm_prefix}${each.value["suffix_name"]}${each.value["id"]}nic001-CFG"
    subnet_id                     = lookup(var.subnets, each.value["snet_key"], null)["id"]
    private_ip_address_allocation = lookup(each.value, "static_ip", null) == null ? "dynamic" : "static"
    private_ip_address            = lookup(each.value, "static_ip", null)
    public_ip_address_id          = lookup(each.value, "public_ip_key", null) == null ? null : lookup(var.public_ips, each.value["public_ip_key"], null)["id"]
  }

  tags = local.tags
}

# -
# - Linux Network interfaces - Network Security Groups
# -

locals {
  linux_nics_with_nsg_keys = [for x in var.linux_vms : "${x.suffix_name}${x.id}" if lookup(x, "nsg_key", null) != null]
  linux_nics_with_nsg_values = [for x in var.linux_vms : {
    nsg_key = x.nsg_key
  } if lookup(x, "nsg_key", null) != null]
  linux_nics_with_nsg = zipmap(local.linux_nics_with_nsg_keys, local.linux_nics_with_nsg_values)
}

resource "azurerm_network_interface_security_group_association" "linux_nics_with_nsg" {
  depends_on                = [azurerm_network_interface.linux_nics, azurerm_virtual_machine.linux_vms] #did add the depedency because of the following issue : https://github.com/terraform-providers/terraform-provider-azurerm/issues/4330
  for_each                  = local.linux_nics_with_nsg
  network_interface_id      = azurerm_network_interface.linux_nics[each.key].id
  network_security_group_id = lookup(var.network_security_groups, each.value["nsg_key"], null)["id"]
}

# -
# - Linux Network interfaces - Internal backend pools
# -
resource "azurerm_network_interface_backend_address_pool_association" "linux_nics_with_internal_backend_pools" {
  depends_on              = [azurerm_network_interface.linux_nics, azurerm_virtual_machine.linux_vms] #did add the depedency because of the following issue : https://github.com/terraform-providers/terraform-provider-azurerm/issues/4330
  for_each                = { for x, y in var.linux_vms : x => y if lookup(y, "internal_lb_key", null) == null ? false : true }
  network_interface_id    = azurerm_network_interface.linux_nics[each.key].id
  ip_configuration_name   = "${var.vm_prefix}${each.value["suffix_name"]}${each.value["id"]}nic001-CFG"
  backend_address_pool_id = lookup(var.internal_lb_backend_address_pools, each.value["internal_lb_key"], null)["id"]
}

# -
# - Linux Network interfaces - Public backend pools
# -
resource "azurerm_network_interface_backend_address_pool_association" "linux_nics_with_public_backend_pools" {
  depends_on              = [azurerm_network_interface.linux_nics, azurerm_virtual_machine.linux_vms] #did add the depedency because of the following issue : https://github.com/terraform-providers/terraform-provider-azurerm/issues/4330
  for_each                = { for x, y in var.linux_vms : x => y if lookup(y, "public_lb_key", null) == null ? false : true }
  network_interface_id    = azurerm_network_interface.linux_nics[each.key].id
  ip_configuration_name   = "${var.vm_prefix}${each.value["suffix_name"]}${each.value["id"]}nic001-CFG"
  backend_address_pool_id = lookup(var.public_lb_backend_address_pools, each.value["public_lb_key"], null)["id"]
}

# -
# - Linux Virtual Machines
# -
resource "azurerm_virtual_machine" "linux_vms" {
  for_each                         = var.linux_vms
  name                             = "${var.vm_prefix}${each.value["suffix_name"]}${each.value["id"]}"
  location                         = local.location
  resource_group_name              = var.vm_resource_group_name
  network_interface_ids            = [lookup(azurerm_network_interface.linux_nics, each.key)["id"]]
  zones                            = lookup(each.value, "zones", null)
  vm_size                          = each.value["vm_size"]
  delete_os_disk_on_termination    = lookup(each.value, "delete_os_disk_on_termination", true)
  delete_data_disks_on_termination = lookup(each.value, "delete_data_disks_on_termination", true)
  boot_diagnostics {
    enabled     = var.enable_log_analytics_dependencies
    storage_uri = var.sa_bootdiag_storage_uri
  }

  os_profile_linux_config {
    disable_password_authentication = lookup(each.value, "disable_password_authentication", false)

    ssh_keys {
      path     = "/home/${lookup(each.value, "admin_username", var.admin_username)}/.ssh/authorized_keys"
      key_data = var.ssh_key
    }
  }

  storage_os_disk {
    name              = "${var.vm_prefix}${each.value["suffix_name"]}${each.value["id"]}dsk000"
    caching           = lookup(each.value, "storage_os_disk_caching", "ReadWrite")
    create_option     = lookup(each.value, "storage_os_disk_create_option", "FromImage")
    managed_disk_type = each.value["managed_disk_type"]
  }

  storage_image_reference {
    id        = lookup(each.value, "storage_image_reference_id", lookup(var.linux_storage_image_reference, "id", null))
    offer     = lookup(each.value, "storage_image_reference_offer", lookup(var.linux_storage_image_reference, "offer", null))
    publisher = lookup(each.value, "storage_image_reference_publisher", lookup(var.linux_storage_image_reference, "publisher", null))
    sku       = lookup(each.value, "storage_image_reference_sku", lookup(var.linux_storage_image_reference, "sku", null))
    version   = lookup(each.value, "storage_image_reference_version", lookup(var.linux_storage_image_reference, "version", null))
  }

  dynamic "storage_data_disk" {
    for_each = lookup(each.value, "storage_data_disks", null)

    content {
      name                      = "${var.vm_prefix}${each.value["suffix_name"]}${each.value["id"]}dsk${lookup(storage_data_disk.value, "id", "null")}"
      caching                   = lookup(storage_data_disk.value, "caching", null)
      create_option             = lookup(storage_data_disk.value, "create_option", null)
      disk_size_gb              = lookup(storage_data_disk.value, "disk_size_gb", null)
      lun                       = lookup(storage_data_disk.value, "lun", lookup(var.linux_storage_image_reference, "lun", lookup(storage_data_disk.value, "id", "null")))
      write_accelerator_enabled = lookup(storage_data_disk.value, "write_accelerator_enabled", null)
      managed_disk_type         = lookup(storage_data_disk.value, "managed_disk_type", null)
      managed_disk_id           = lookup(storage_data_disk.value, "managed_disk_id", null)
    }
  }

  os_profile {
    computer_name  = "${var.vm_prefix}${each.value["suffix_name"]}${each.value["id"]}"
    admin_username = lookup(each.value, "admin_username", var.admin_username)
    admin_password = lookup(each.value, "admin_password", var.admin_password)
    custom_data    = lookup(each.value, "linux_cloud_init_file_key", null) == null ? null : var.linux_cloud_init_contents[each.value.linux_cloud_init_file_key].rendered #(Optional) Specifies custom data to supply to the machine. On Linux-based systems, this can be used as a cloud-init script. On other systems, this will be copied as a file on disk. Internally, Terraform will base64 encode this value before sending it to the API. The maximum length of the binary array is 65535 bytes.
  }

  dynamic "identity" {
    for_each = lookup(each.value, "identity", var.managed_identity)
    content {
      type         = lookup(identity.value, "type", null)
      identity_ids = lookup(identity.value, "identity_ids", null)
    }
  }

  tags = local.tags
}

# -
# - Linux Network interfaces - Ip forwarding
# -
resource "azurerm_virtual_machine_extension" "linux_vms_with_enable_enable_ip_forwarding" {
  for_each             = { for x, y in var.linux_vms : x => y if lookup(y, "enable_ip_forwarding", null) == true ? true : false }
  name                 = "enable_accelerated_networking-for-${var.vm_prefix}${each.key}"
  virtual_machine_id   = azurerm_virtual_machine.linux_vms[each.key].id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.0"

  settings = <<SETTINGS
    {
        "commandToExecute": "sed -i 's/#net.ipv4.ip_forward/net.ipv4.ip_forward/g' /etc/sysctl.conf && sysctl -p"
    }
SETTINGS

  tags = local.tags
}

# -
# - Linux Virtual Machines Backup
# -
locals {
  linux_vms_to_backup_keys = [for x in var.linux_vms : "${x.suffix_name}${x.id}" if lookup(x, "backup_policy_name", null) != null && var.recovery_services_vault_name != ""]
  linux_vms_to_backup_values = [for x in var.linux_vms : {
    backup_policy_name = x.backup_policy_name
  } if lookup(x, "backup_policy_name", null) != null && var.recovery_services_vault_name != ""]
  linux_vms_to_backup = zipmap(local.linux_vms_to_backup_keys, local.linux_vms_to_backup_values)
}

resource "azurerm_backup_protected_vm" "linux_vm_resources_to_backup" {
  for_each            = local.linux_vms_to_backup
  resource_group_name = element(data.azurerm_recovery_services_vault.vault.*.resource_group_name, 0)
  recovery_vault_name = element(data.azurerm_recovery_services_vault.vault.*.name, 0)
  source_vm_id        = azurerm_virtual_machine.linux_vms[each.key].id
  backup_policy_id    = "${element(data.azurerm_recovery_services_vault.vault.*.id, 0)}/backupPolicies/${each.value["backup_policy_name"]}"
}

# -
# - Log Monitor for Windows
# -
locals {
  windows_vms_with_log_analytics_dependencies_keys   = [for x in var.windows_vms : "${x.suffix_name}${x.id}" if var.enable_log_analytics_dependencies == true]
  windows_vms_with_log_analytics_dependencies_values = [for x in var.windows_vms : { enable_log_analytics_dependencies = var.enable_log_analytics_dependencies } if var.enable_log_analytics_dependencies == true]
  windows_vms_with_log_analytics_dependencies        = zipmap(local.windows_vms_with_log_analytics_dependencies_keys, local.windows_vms_with_log_analytics_dependencies_values)
}

resource "azurerm_virtual_machine_extension" "OmsAgentForWindows" {
  depends_on                 = [azurerm_log_analytics_solution.ServiceMap]
  for_each                   = local.windows_vms_with_log_analytics_dependencies
  name                       = "OmsAgentForWindows"
  virtual_machine_id         = azurerm_virtual_machine.windows_vms[each.key].id
  publisher                  = var.OmsAgentForWindows["publisher"]
  type                       = var.OmsAgentForWindows["type"]
  type_handler_version       = var.OmsAgentForWindows["type_handler_version"]
  auto_upgrade_minor_version = var.OmsAgentForWindows["auto_upgrade_minor_version"]
  tags                       = local.tags
  settings                   = <<-BASE_SETTINGS
 {
   "workspaceId" : "${element(data.azurerm_log_analytics_workspace.log.*.workspace_id, 0)}"
 }
BASE_SETTINGS
  protected_settings         = <<-PROTECTED_SETTINGS
 {
   "workspaceKey" : "${element(data.azurerm_log_analytics_workspace.log.*.primary_shared_key, 0)}"
 }
PROTECTED_SETTINGS
}

resource "azurerm_virtual_machine_extension" "DependencyAgentWindows" {
  depends_on                 = [azurerm_virtual_machine_extension.OmsAgentForWindows]
  for_each                   = local.windows_vms_with_log_analytics_dependencies
  name                       = "DependencyAgent"
  virtual_machine_id         = azurerm_virtual_machine.windows_vms[each.key].id
  publisher                  = var.DependencyAgentWindows["publisher"]
  type                       = var.DependencyAgentWindows["type"]
  type_handler_version       = var.DependencyAgentWindows["type_handler_version"]
  auto_upgrade_minor_version = var.DependencyAgentWindows["auto_upgrade_minor_version"]
  tags                       = local.tags
}

# -
# - Windows Network interfaces
# -
resource "azurerm_network_interface" "windows_nics" {
  for_each                      = var.windows_vms
  name                          = "${var.vm_prefix}${each.value["suffix_name"]}${each.value["id"]}nic001"
  location                      = local.location
  resource_group_name           = var.vm_resource_group_name
  internal_dns_name_label       = lookup(each.value, "internal_dns_name_label", null)
  enable_ip_forwarding          = lookup(each.value, "enable_ip_forwarding", null)
  enable_accelerated_networking = lookup(each.value, "enable_accelerated_networking", null)
  dns_servers                   = lookup(each.value, "dns_servers", null)

  ip_configuration {
    name                          = "${var.vm_prefix}${each.value["suffix_name"]}${each.value["id"]}nic001-CFG"
    subnet_id                     = lookup(var.subnets, each.value["snet_key"], null)["id"]
    private_ip_address_allocation = lookup(each.value, "static_ip", null) == null ? "dynamic" : "static"
    private_ip_address            = lookup(each.value, "static_ip", null)
    public_ip_address_id          = lookup(each.value, "public_ip_key", null) == null ? null : lookup(var.public_ips, each.value["public_ip_key"], null)["id"]
  }

  tags = local.tags
}

# -
# - Windows Network interfaces - Network Security Groups
# -

locals {
  windows_nics_with_nsg_keys = [for x in var.windows_vms : "${x.suffix_name}${x.id}" if lookup(x, "nsg_key", null) != null]
  windows_nics_with_nsg_values = [for x in var.windows_vms : {
    nsg_key = x.nsg_key
  } if lookup(x, "nsg_key", null) != null]
  windows_nics_with_nsg = zipmap(local.windows_nics_with_nsg_keys, local.windows_nics_with_nsg_values)
}

resource "azurerm_network_interface_security_group_association" "windows_nics_with_nsg" {
  depends_on                = [azurerm_network_interface.linux_nics, azurerm_virtual_machine.linux_vms] #did add the depedency because of the following issue : https://github.com/terraform-providers/terraform-provider-azurerm/issues/4330
  for_each                  = local.windows_nics_with_nsg
  network_interface_id      = azurerm_network_interface.windows_nics[each.key].id
  network_security_group_id = lookup(var.network_security_groups, each.value["nsg_key"], null)["id"]
}

# -
# - Windows Network interfaces - Internal backend pools
# -

locals {
  windows_nics_with_internal_bp_keys = [for x in var.windows_vms : "${x.suffix_name}${x.id}" if lookup(x, "internal_lb_key", null) != null]
  windows_nics_with_internal_bp_values = [for x in var.windows_vms : {
    internal_lb_key = x.internal_lb_key
  } if lookup(x, "internal_lb_key", null) != null]
  windows_nics_with_internal_bp = zipmap(local.windows_nics_with_internal_bp_keys, local.windows_nics_with_internal_bp_values)
}

resource "azurerm_network_interface_backend_address_pool_association" "windows_nics_with_internal_backend_pools" {
  depends_on              = [azurerm_network_interface.windows_nics, azurerm_virtual_machine.windows_vms] #did add the depedency because of the following issue : https://github.com/terraform-providers/terraform-provider-azurerm/issues/4330
  for_each                = local.windows_nics_with_internal_bp
  network_interface_id    = azurerm_network_interface.windows_nics[each.key].id
  ip_configuration_name   = "${var.vm_prefix}${each.key}nic001-CFG"
  backend_address_pool_id = lookup(var.internal_lb_backend_address_pools, each.value["internal_lb_key"], null)["id"]
}

# -
# - Windows Network interfaces - Public backend pools
# -

locals {
  windows_nics_with_public_bp_keys = [for x in var.windows_vms : "${x.suffix_name}${x.id}" if lookup(x, "public_lb_key", null) != null]
  windows_nics_with_public_bp_values = [for x in var.windows_vms : {
    public_lb_key = x.public_lb_key
  } if lookup(x, "public_lb_key", null) != null]
  windows_nics_with_public_bp = zipmap(local.windows_nics_with_public_bp_keys, local.windows_nics_with_public_bp_values)
}

resource "azurerm_network_interface_backend_address_pool_association" "windows_nics_with_public_backend_pools" {
  depends_on              = [azurerm_network_interface.windows_nics, azurerm_virtual_machine.windows_vms] #did add the depedency because of the following issue : https://github.com/terraform-providers/terraform-provider-azurerm/issues/4330
  for_each                = local.windows_nics_with_public_bp
  network_interface_id    = azurerm_network_interface.windows_nics[each.key].id
  ip_configuration_name   = "${var.vm_prefix}${each.key}nic001-CFG"
  backend_address_pool_id = lookup(var.public_lb_backend_address_pools, each.value["public_lb_key"], null)["id"]
}

# -
# - Windows Virtual Machines
# -
resource "azurerm_virtual_machine" "windows_vms" {
  for_each                         = var.windows_vms
  name                             = "${var.vm_prefix}${each.value["suffix_name"]}${each.value["id"]}"
  location                         = local.location
  resource_group_name              = var.vm_resource_group_name
  network_interface_ids            = [lookup(azurerm_network_interface.windows_nics, each.key)["id"]]
  zones                            = lookup(each.value, "zones", null)
  vm_size                          = each.value["vm_size"]
  license_type                     = lookup(each.value, "license_type", null) # (Optional) Specifies the BYOL Type for this Virtual Machine. This is only applicable to Windows Virtual Machines. Possible values are Windows_Client and Windows_Server.
  delete_os_disk_on_termination    = lookup(each.value, "delete_os_disk_on_termination", true)
  delete_data_disks_on_termination = lookup(each.value, "delete_data_disks_on_termination", true)
  boot_diagnostics {
    enabled     = var.enable_log_analytics_dependencies
    storage_uri = var.sa_bootdiag_storage_uri
  }

  os_profile_windows_config {
    provision_vm_agent        = lookup(each.value, "provision_vm_agent", true)
    enable_automatic_upgrades = lookup(each.value, "enable_automatic_upgrades", true)
  }

  storage_os_disk {
    name              = "${var.vm_prefix}${each.value["suffix_name"]}${each.value["id"]}dsk000"
    caching           = lookup(each.value, "storage_os_disk_caching", "ReadWrite")
    create_option     = lookup(each.value, "storage_os_disk_create_option", "FromImage")
    managed_disk_type = each.value["managed_disk_type"]
  }


  storage_image_reference {
    id        = lookup(each.value, "storage_image_reference_id", lookup(var.windows_storage_image_reference, "id", null))
    offer     = lookup(each.value, "storage_image_reference_offer", lookup(var.windows_storage_image_reference, "offer", null))
    publisher = lookup(each.value, "storage_image_reference_publisher", lookup(var.windows_storage_image_reference, "publisher", null))
    sku       = lookup(each.value, "storage_image_reference_sku", lookup(var.windows_storage_image_reference, "sku", null))
    version   = lookup(each.value, "storage_image_reference_version", lookup(var.windows_storage_image_reference, "version", null))
  }

  dynamic "storage_data_disk" {
    for_each = lookup(each.value, "storage_data_disks", null)

    content {
      name                      = "${var.vm_prefix}${each.value["suffix_name"]}${each.value["id"]}dsk${lookup(storage_data_disk.value, "id", "null")}"
      caching                   = lookup(storage_data_disk.value, "caching", null)
      create_option             = lookup(storage_data_disk.value, "create_option", null)
      disk_size_gb              = lookup(storage_data_disk.value, "disk_size_gb", null)
      lun                       = lookup(storage_data_disk.value, "lun", lookup(var.windows_storage_image_reference, "lun", lookup(storage_data_disk.value, "id", "null")))
      write_accelerator_enabled = lookup(storage_data_disk.value, "write_accelerator_enabled", null)
      managed_disk_type         = lookup(storage_data_disk.value, "managed_disk_type", null)
      managed_disk_id           = lookup(storage_data_disk.value, "managed_disk_id", null)
    }
  }

  os_profile {
    computer_name  = "${var.vm_prefix}${each.value["suffix_name"]}${each.value["id"]}"
    admin_username = lookup(each.value, "admin_username", var.admin_username)
    admin_password = lookup(each.value, "admin_password", var.admin_password)
  }

  tags = local.tags
}

variable "enable_ip_forwarding_on_windows" {
  description = "Enable ip forwarding and reboot the VM."
  default     = <<EOF
Set-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters -Name IpEnableRouter -Value 1
Get-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters -Name IpEnableRouter
#Restart-Computer -Force #Not recommended see : https://docs.microsoft.com/en-us/azure/virtual-machines/extensions/custom-script-windows
EOF
}

locals {
  enable_ip_forwarding_on_windows = {
    script = "${compact(split("\n", var.enable_ip_forwarding_on_windows))}"
  }
}

# -
# - Windows Network interfaces - Ip forwarding
# -

locals {
  windows_vms_with_enable_enable_ip_forwarding_keys = [for x in var.windows_vms : "${x.suffix_name}${x.id}" if lookup(x, "enable_ip_forwarding", null) == true]
  windows_vms_with_enable_enable_ip_forwarding_values = [for x in var.windows_vms : {
    enable_ip_forwarding = x.enable_ip_forwarding
  } if lookup(x, "enable_ip_forwarding", null) == true]
  windows_vms_with_enable_enable_ip_forwarding = zipmap(local.windows_vms_with_enable_enable_ip_forwarding_keys, local.windows_vms_with_enable_enable_ip_forwarding_values)
}

resource "azurerm_virtual_machine_extension" "windows_vms_with_enable_enable_ip_forwarding" {
  for_each             = local.windows_vms_with_enable_enable_ip_forwarding
  name                 = "enable_accelerated_networking-for-${var.vm_prefix}${each.key}"
  virtual_machine_id   = azurerm_virtual_machine.windows_vms[each.key].id
  publisher            = "Microsoft.CPlat.Core"
  type                 = "RunCommandWindows"
  type_handler_version = "1.1"
  settings             = jsonencode(local.enable_ip_forwarding_on_windows)
  tags                 = local.tags
}

# -
# - Windows Virtual Machines Backup
# -

locals {
  windows_vms_to_backup_keys = [for x in var.windows_vms : "${x.suffix_name}${x.id}" if lookup(x, "backup_policy_name", null) != null && var.recovery_services_vault_name != ""]
  windows_vms_to_backup_values = [for x in var.windows_vms : {
    backup_policy_name = x.backup_policy_name
  } if lookup(x, "backup_policy_name", null) != null && var.recovery_services_vault_name != ""]
  windows_vms_to_backup = zipmap(local.windows_vms_to_backup_keys, local.windows_vms_to_backup_values)
}

resource "azurerm_backup_protected_vm" "windows_vm_resources_to_backup" {
  for_each            = local.windows_vms_to_backup
  resource_group_name = element(data.azurerm_recovery_services_vault.vault.*.resource_group_name, 0)
  recovery_vault_name = element(data.azurerm_recovery_services_vault.vault.*.name, 0)
  source_vm_id        = azurerm_virtual_machine.windows_vms[each.key].id
  backup_policy_id    = "${element(data.azurerm_recovery_services_vault.vault.*.id, 0)}/backupPolicies/${each.value["backup_policy_name"]}"
}
