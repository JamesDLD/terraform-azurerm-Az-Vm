output "linux_vms_resource_group_names" {
  value = [for x in azurerm_virtual_machine.linux_vms : x.resource_group_name]
}
output "linux_vms_names" {
  value = [for x in azurerm_virtual_machine.linux_vms : x.name]
}

output "windows_vms_resource_group_names" {
  value = [for x in azurerm_virtual_machine.windows_vms : x.resource_group_name]
}
output "windows_vms_names" {
  value = [for x in azurerm_virtual_machine.windows_vms : x.name]
}
