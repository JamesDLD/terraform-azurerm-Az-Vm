## 0.3.1 (November 10, 2022)

FEATURES:
* Upgrade to Terraform 1.3.4 and above.
* Upgrade to AzureRm provider 3.31.0 and above.

ENHANCEMENTS:
* Delete the deprecated version constraint in the azurerm provider.
* Code formatting with IntelliJ and `terraform fmt -recursive`.
* Add a change log file.

BUG FIXES:
* Ensure that the option `private_ip_address_allocation` of the resource `azurerm_network_interface` is one of [Dynamic Static]
