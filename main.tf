variable "cluster_name" {}
variable "cluster_storage_account" {}
variable "location" {}
variable "kubernetes_version" {}



# RESOURCE GROUPS

resource "azurerm_resource_group" "rg_persistence" {
  name     = "${var.cluster_name}-persistence"
  location = var.location
}

resource "azurerm_resource_group" "rg_network" {
  name     = "${var.cluster_name}-network"
  location = var.location
}

resource "azurerm_resource_group" "rg_cluster" {
  name     = "${var.cluster_name}-cluster"
  location = var.location
}



# MANAGED IDENTITIES

resource "azurerm_user_assigned_identity" "rg_cluster" {
  resource_group_name = azurerm_resource_group.rg_cluster.name
  location            = var.location
  name                = "${var.cluster_name}-identity"
}

locals {
    cluster-identity = azurerm_user_assigned_identity.rg_cluster.principal_id
}

# Just in case you are courious how it looks :P
#output cluster-identity-test {
#  value = local.cluster-identity
#}



# ROLE ASIGNMENT

resource "azurerm_role_assignment" "persistence-role" {
  scope                = "${azurerm_resource_group.rg_persistence.id}"
  role_definition_name = "Network Contributor"
  principal_id         = local.cluster-identity
}

resource "azurerm_role_assignment" "network-role" {
  scope                = "${azurerm_resource_group.rg_network.id}"
  role_definition_name = "Contributor"
  principal_id         = local.cluster-identity
}

resource "azurerm_role_assignment" "cluster-role" {
  scope                = "${azurerm_resource_group.rg_cluster.id}"
  role_definition_name = "Contributor"
  principal_id         = local.cluster-identity
}



# PUBLIC IP

resource "azurerm_public_ip" "cluster-ip" {
  name                = "${var.cluster_name}-publicIP"
  resource_group_name = azurerm_resource_group.rg_persistence.name
  location            = azurerm_resource_group.rg_persistence.location
  #location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
}



# NETWORKING

resource "azurerm_virtual_network" "virtual_network" {
  name                = "${var.cluster_name}-vnet"
  resource_group_name = azurerm_resource_group.rg_network.name
  location            = azurerm_resource_group.rg_network.location
  address_space       = ["10.100.0.0/16"]
  #dns_servers         = ["10.0.0.4", "10.0.0.5"]

  #ddos_protection_plan {
  #  id     = azurerm_network_ddos_protection_plan.example.id
  #  enable = true

  # Referring to this object is annoying!
  # azurerm_virtual_network.virtual_network.subnet.[0].id
  #subnet {
  #  name           = "${var.cluster_name}-cluster-subnet"
  #  address_prefix = 
  #}
}

resource "azurerm_subnet" "subnet" {
  name                 = "${var.cluster_name}-cluster-subnet"
  resource_group_name  = azurerm_resource_group.rg_network.name
  virtual_network_name = azurerm_virtual_network.virtual_network.name
  address_prefixes       = ["10.100.0.0/24"]
}



# STORAGE ACCOUNT

resource "azurerm_storage_account" "storage_account" {
  name                     = var.cluster_storage_account
  resource_group_name      = azurerm_resource_group.rg_persistence.name
  location                 = azurerm_resource_group.rg_persistence.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  
}

locals {
    # ?
    storage-account-connetionString = azurerm_storage_account.storage_account.primary_connection_string
    storage-account-key             = azurerm_storage_account.storage_account.primary_access_key
}



# FILE SHARE

resource "azurerm_storage_share" "storage_share" {
  name                 = "${var.cluster_storage_account}share"
  storage_account_name = azurerm_storage_account.storage_account.name
}



# KUBERNETES

resource "azurerm_kubernetes_cluster" "kubernetes_cluster" {
  name                       = var.cluster_name
  location                   = azurerm_resource_group.rg_cluster.location
  resource_group_name        = azurerm_resource_group.rg_cluster.name
  kubernetes_version         = var.kubernetes_version
  private_cluster_enabled    = false
  dns_prefix                 = "${var.cluster_name}-dns"

  default_node_pool {
    name           = "default"
    node_count     = 2
    vm_size        = "Standard_B2s"
    type           = "VirtualMachineScaleSets"
    vnet_subnet_id = azurerm_subnet.subnet.id

    # availability_zones    = var.default_node_pool.zones
    # availability_zones  = ["1", "2", "3"]
  }

  identity {
    type = "UserAssigned"
    user_assigned_identity_id = azurerm_user_assigned_identity.rg_cluster.id
  }

  network_profile {
    network_plugin = "azure"
    network_policy = "azure"
  }
  
  addon_profile {
    azure_policy {
      enabled = false
    }
  }

  role_based_access_control {
    enabled = true
    azure_active_directory {
      managed = true
      admin_group_object_ids = [ "590b7574-2884-4d3c-b249-6d99b713d9e6" ]
    }
  }

  #tags = {
  #  Environment = "Production"
  #}
}

#az aks create \
#    --aad-admin-group-object-ids $IDENTITY_GROUP_ID \
#    --enable-aad \
#    --enable-managed-identity \

