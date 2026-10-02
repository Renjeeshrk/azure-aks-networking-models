# ---------------------------------------------------------
# Fetch WAF Subnet
# ---------------------------------------------------------

data "azurerm_subnet" "snet-aks-waf-01" {
  name                 = "snet-aks-waf-01"
  virtual_network_name = azurerm_virtual_network.vnet-aks-demo-hub.name
  resource_group_name  = azurerm_resource_group.rg-aks-demo-01.name
}

# ---------------------------------------------------------
# Get existing AKS node subnet
# ---------------------------------------------------------

data "azurerm_subnet" "snet-aks-node-01" {
  name                 = "snet-aks-node-01"
  virtual_network_name = azurerm_virtual_network.vnet-aks-demo-spoke1.name
  resource_group_name  = azurerm_resource_group.rg-aks-demo-01.name
}
