# =========================================================
# AKS - Azure CNI Node Subnet
# =========================================================



# ---------------------------------------------------------
# AKS Managed Identity
# ---------------------------------------------------------

resource "azurerm_user_assigned_identity" "aks_identity" {
  name                = "id-aks-demo-01"
  location            = azurerm_resource_group.rg-aks-demo-01.location
  resource_group_name = azurerm_resource_group.rg-aks-demo-01.name

  tags = {
    environment = "Production"
  }
}


# ---------------------------------------------------------
# Network Contributor - AKS Node Subnet
# ---------------------------------------------------------

resource "azurerm_role_assignment" "aks_node_subnet_network_contributor" {
  scope                = data.azurerm_subnet.snet-aks-node-01.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.aks_identity.principal_id
}


# ---------------------------------------------------------
# AKS Cluster
# ---------------------------------------------------------

resource "azurerm_kubernetes_cluster" "aks-demo-01" {

  name                = "aks-demo-01"
  location            = azurerm_resource_group.rg-aks-demo-01.location
  resource_group_name = azurerm_resource_group.rg-aks-demo-01.name

  dns_prefix = "aks-demo-01"

  kubernetes_version = "1.35"

  # -------------------------------------------------------
  # Node Provisioning
  # -------------------------------------------------------

  node_provisioning_profile {
    mode = "Manual"
  }

  # -------------------------------------------------------
  # Managed Identity
  # -------------------------------------------------------

  identity {
    type = "UserAssigned"

    identity_ids = [
      azurerm_user_assigned_identity.aks_identity.id
    ]
  }

  # -------------------------------------------------------
  # System Node Pool
  # -------------------------------------------------------

  default_node_pool {

    name       = "system"
    vm_size    = "Standard_D2as_v5"
    node_count = 2

    type = "VirtualMachineScaleSets"

    # Azure CNI Node Subnet
    vnet_subnet_id = data.azurerm_subnet.snet-aks-node-01.id

    os_sku = "Ubuntu"

    upgrade_settings {
      max_surge = "33%"
    }
  }

  # -------------------------------------------------------
  # Azure CNI Node Subnet
  # -------------------------------------------------------

  network_profile {

    network_plugin = "azure"

    network_policy = "azure"

    network_data_plane = "azure"

    service_cidr   = "10.20.0.0/16"
    dns_service_ip = "10.20.0.10"

    load_balancer_sku = "standard"

    outbound_type = "loadBalancer"
  }

  tags = {
    environment = "Production"
    component   = "AKS"
    network     = "Azure-CNI-Node-Subnet"
  }

  depends_on = [
    azurerm_role_assignment.aks_node_subnet_network_contributor
  ]
}

# =========================================================
# AKS User Node Pool
# =========================================================

resource "azurerm_kubernetes_cluster_node_pool" "user" {

  name                  = "user"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks-demo-01.id

  vm_size    = "Standard_D2as_v5"
  node_count = 2

  mode = "User"

  # Same Azure CNI Node Subnet
  vnet_subnet_id = data.azurerm_subnet.snet-aks-node-01.id

  os_type = "Linux"
  os_sku  = "Ubuntu"

  max_pods = 30

  node_labels = {
    workload = "application"
  }

  upgrade_settings {
    max_surge = "33%"
  }

  tags = {
    environment = "Production"
    nodepool    = "user"
  }

  depends_on = [
    azurerm_role_assignment.aks_node_subnet_network_contributor
  ]
}