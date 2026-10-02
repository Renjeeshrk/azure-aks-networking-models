# User Assigned Managed Identity

resource "azurerm_user_assigned_identity" "aks_identity" {
  name                = "id-aks-demo-01"
  location            = azurerm_resource_group.rg-aks-demo-01.location
  resource_group_name = azurerm_resource_group.rg-aks-demo-01.name

  tags = {
    environment = "Production"
  }
}

# Network Contributor — Node Subnet

resource "azurerm_role_assignment" "aks_node_subnet_network_contributor" {
  scope                = data.azurerm_subnet.snet-aks-node-01.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.aks_identity.principal_id
}

# Network Contributor — Pod Subnetss

resource "azurerm_role_assignment" "aks_pod_subnet_network_contributor" {
  scope                = data.azurerm_subnet.snet-aks-pod-01.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.aks_identity.principal_id
}

# AKS Cluster

resource "azurerm_kubernetes_cluster" "aks-demo-01" {

  name                = "aks-demo-01"
  location            = azurerm_resource_group.rg-aks-demo-01.location
  resource_group_name = azurerm_resource_group.rg-aks-demo-01.name

  dns_prefix = "aks-demo-01"

  kubernetes_version = "1.35"

node_provisioning_profile {
  mode = "Manual"
}
  # -------------------------------------------------------
  # Managed Identity
  # -------------------------------------------------------

  identity {
    type         = "UserAssigned"
    identity_ids = [
      azurerm_user_assigned_identity.aks_identity.id
    ]
  }

  # -------------------------------------------------------
  # Default/System Node Pool
  # -------------------------------------------------------

  default_node_pool {

    name = "system"

    vm_size = "Standard_D2as_v5"

    node_count = 2

    type = "VirtualMachineScaleSets"

    # Node IPs come from this subnet
    vnet_subnet_id = data.azurerm_subnet.snet-aks-node-01.id

    # Pod IPs come from this subnet
    pod_subnet_id = data.azurerm_subnet.snet-aks-pod-01.id

    os_sku = "Ubuntu"

    upgrade_settings {
      max_surge = "33%"
    }
  }

  # -------------------------------------------------------
  # Azure CNI
  # -------------------------------------------------------

  network_profile {

    network_plugin = "azure"

    network_policy = "azure"

    network_data_plane = "azure"

    service_cidr = "10.20.0.0/16"

    dns_service_ip = "10.20.0.10"

    load_balancer_sku = "standard"

    outbound_type = "loadBalancer"
  }

  # -------------------------------------------------------
  # Tags
  # -------------------------------------------------------

  tags = {
    environment = "Production"
    component   = "AKS"
  }

  depends_on = [
    azurerm_role_assignment.aks_node_subnet_network_contributor,
    azurerm_role_assignment.aks_pod_subnet_network_contributor
  ]
}


resource "azurerm_kubernetes_cluster_node_pool" "user" {

  name                  = "user"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks-demo-01.id

  vm_size    = "Standard_D2as_v5"
  node_count = 2

  mode = "User"

  vnet_subnet_id = data.azurerm_subnet.snet-aks-node-01.id
  pod_subnet_id  = data.azurerm_subnet.snet-aks-pod-01.id

  os_type = "Linux"
  os_sku  = "Ubuntu"

  max_pods = 30

  upgrade_settings {
    max_surge = "33%"
  }

  tags = {
    environment = "Production"
    nodepool    = "user"
  }

  depends_on = [
    azurerm_role_assignment.aks_node_subnet_network_contributor,
    azurerm_role_assignment.aks_pod_subnet_network_contributor
  ]
}