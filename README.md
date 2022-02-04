Test
-----
[![Build Status](https://dev.azure.com/jamesdld23/vpc_lab/_apis/build/status/JamesDLD.terraform-azurerm-Az-Vm?branchName=master)](https://dev.azure.com/jamesdld23/vpc_lab/_build/latest?definitionId=15&branchName=master)

Requirement
-----
- Terraform v1.1.3 and above. 
- AzureRm provider version v2.93 and above.

Terraform resources used within the module
-----
| Resource | Description |
|------|-------------|
| [data azurerm_resource_group](https://www.terraform.io/docs/providers/azurerm/d/resource_group.html) | Get the Resource Group, re use it's tags for the sub resources. |
| [data azurerm_recovery_services_vault & azurerm_recovery_services_protected_vm](https://www.terraform.io/docs/providers/azurerm/d/recovery_services_vault.html) | Get the Recovery Service vault if provided, re use it's resource id to enroll a VM. |
| [data azurerm_key_vault & azurerm_key_vault_secret](https://www.terraform.io/docs/providers/azurerm/d/key_vault.html) | Get the Key vault if provided, re use it to add the VM login's secrets. |
| [data azurerm_log_analytics_workspace & azurerm_log_analytics_solution](https://www.terraform.io/docs/providers/azurerm/d/log_analytics_workspace.html) | Get the Log Monitor if provided, re use it's resource id to enroll a VM and create the ServiceMap solution. |
| [azurerm_virtual_machine_extension](https://www.terraform.io/docs/providers/azurerm/r/virtual_machine_extension.html) | If the Log Monitor has been provided, will install the OmsAgent and the DependencyAgent. If asked it will enable ip forwarding on the OS. |
| [azurerm_network_interface](https://www.terraform.io/docs/providers/azurerm/r/network_interface.html) | Manages a Network Interface located in a Virtual Network. |
| [azurerm_network_interface_backend_address_pool_association](https://www.terraform.io/docs/providers/azurerm/r/network_interface_backend_address_pool_association.html) | Manages the association between a Network Interface and a Load Balancer's Backend Address Pool. |
| [azurerm_virtual_machine](https://www.terraform.io/docs/providers/azurerm/r/virtual_machine.html) | Manages a Virtual Machine. |


Examples
-----
| Name | Description |
|------|-------------|
| complete | Create the following objects : vnet, subnet, load balancer, linux and windows virtual machines. |
| linux | Create a Linux VM 3 Data Disks mounted throught a [cloud init file](https://cloudinit.readthedocs.io/en/latest/topics/examples.html). |