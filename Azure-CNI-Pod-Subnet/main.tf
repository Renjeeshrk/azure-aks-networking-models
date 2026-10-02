terraform {
  required_version = "v1.16.4"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 5.8.0"

    }

  }
}

provider "azurerm" {
  features {

  }

}

# Resource group

resource "azurerm_resource_group" "rg-aks-demo-01" {
  name     = "rg-aks-demo-01"
  location = "centralindia"
}

## Hub Virtual network

resource "azurerm_virtual_network" "vnet-aks-demo-hub" {
  name                = "vnet-aks-demo-hub"
  location            = azurerm_resource_group.rg-aks-demo-01.location
  resource_group_name = azurerm_resource_group.rg-aks-demo-01.name
  address_space       = ["10.0.0.0/16"]

  subnet {
    name             = "snet-aks-waf-01"
    address_prefixes = ["10.0.1.0/24"]
  }
  tags = {
    environment = "Production"
  }
}

# Spoke 1 vNet

resource "azurerm_virtual_network" "vnet-aks-demo-spoke1" {
  name                = "vnet-aks-demo-spoke1"
  location            = azurerm_resource_group.rg-aks-demo-01.location
  resource_group_name = azurerm_resource_group.rg-aks-demo-01.name
  address_space       = ["10.1.0.0/16"]

  subnet {
    name             = "snet-aks-node-01"
    address_prefixes = ["10.1.1.0/24"]
  }

  subnet {
    name             = "snet-aks-pod-01"
    address_prefixes = ["10.1.2.0/24"]
  }


  tags = {
    environment = "Production"
  }
}

## Peering

resource "azurerm_virtual_network_peering" "hubtospoke1" {
  name                      = "hubtospoke"
  resource_group_name       = azurerm_resource_group.rg-aks-demo-01.name
  virtual_network_name      = azurerm_virtual_network.vnet-aks-demo-hub.name
  remote_virtual_network_id = azurerm_virtual_network.vnet-aks-demo-spoke1.id
  allow_forwarded_traffic   = true
  allow_gateway_transit     = true


}

resource "azurerm_virtual_network_peering" "spoke1tohub" {
  name                      = "spoke1tohub"
  resource_group_name       = azurerm_resource_group.rg-aks-demo-01.name
  virtual_network_name      = azurerm_virtual_network.vnet-aks-demo-spoke1.name
  remote_virtual_network_id = azurerm_virtual_network.vnet-aks-demo-hub.id
  allow_forwarded_traffic   = true
  # use_remote_gateways       = true  // gateway not deployed 

}

# Create public IP for Applicaion Gateway
resource "azurerm_public_ip" "appgw" {
  name                = "pip-aks-demo-appgw"
  location            = azurerm_resource_group.rg-aks-demo-01.location
  resource_group_name = azurerm_resource_group.rg-aks-demo-01.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

## Create application gateway

resource "azurerm_application_gateway" "appgw" {

  name                = "appgw-aks-demo"
  location            = azurerm_resource_group.rg-aks-demo-01.location
  resource_group_name = azurerm_resource_group.rg-aks-demo-01.name

  # Standard Application Gateway - NO WAF
  sku {
    name = "Standard_v2"
    tier = "Standard_v2"
  }

  autoscale_configuration {
    min_capacity = 1
    max_capacity = 2
  }

  gateway_ip_configuration {
    name      = "appgw-ip-config"
    subnet_id = data.azurerm_subnet.snet-aks-waf-01.id
  }

  # -------------------------------------------------------
  # Frontend
  # -------------------------------------------------------

  frontend_ip_configuration {
    name                 = "appgw-public-frontend"
    public_ip_address_id = azurerm_public_ip.appgw.id
  }

  frontend_port {
    name = "http-port"
    port = 80
  }

  # -------------------------------------------------------
  # Backend
  # -------------------------------------------------------

  backend_address_pool {
    name = "aks-backend-pool"
  }

  # -------------------------------------------------------
  # HTTP Settings
  # -------------------------------------------------------

  backend_http_settings {
    name                  = "http-settings"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 30
  }

  # -------------------------------------------------------
  # Listener
  # -------------------------------------------------------

  http_listener {
    name                           = "http-listener"
    frontend_ip_configuration_name = "appgw-public-frontend"
    frontend_port_name             = "http-port"
    protocol                       = "Http"
  }

  # -------------------------------------------------------
  # Routing Rule
  # -------------------------------------------------------

  request_routing_rule {
    name                       = "default-routing-rule"
    priority                   = 100
    rule_type                  = "Basic"
    http_listener_name         = "http-listener"
    backend_address_pool_name  = "aks-backend-pool"
    backend_http_settings_name = "http-settings"
  }

  tags = {
    Environment = "Demo"
    Component   = "ApplicationGateway"
  }
}