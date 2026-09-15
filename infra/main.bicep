targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the azd environment.')
param environmentName string

@minLength(1)
@description('Azure region for the deployment. Choose a region that supports Flex Consumption.')
@metadata({
  azd: {
    type: 'location'
  }
})
param location string

var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
var tags = {
  'azd-env-name': environmentName
}
var resourceGroupName = 'rg-${environmentName}'
var functionAppName = 'func-ehsdk-${resourceToken}'
var functionIdentityName = 'id-ehsdk-${resourceToken}'
var appServicePlanName = 'plan-ehsdk-${resourceToken}'
var storageAccountName = 'st${resourceToken}'
var deploymentStorageContainerName = 'app-package-${resourceToken}'
var eventHubNamespaceName = 'evhns-ehsdk-${resourceToken}'
var eventHubName = 'events'
var logAnalyticsName = 'log-ehsdk-${resourceToken}'
var applicationInsightsName = 'appi-ehsdk-${resourceToken}'

module rg 'br/public:avm/res/resources/resource-group:0.4.4' = {
  name: 'resource-group'
  params: {
    name: resourceGroupName
    location: location
    tags: tags
  }
}

module functionIdentity 'br/public:avm/res/managed-identity/user-assigned-identity:0.6.0' = {
  name: 'function-identity'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: functionIdentityName
    location: location
    tags: tags
  }
  dependsOn: [
    rg
  ]
}

module appServicePlan 'br/public:avm/res/web/serverfarm:0.7.0' = {
  name: 'flex-consumption-plan'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: appServicePlanName
    location: location
    skuName: 'FC1'
    kind: 'linux'
    reserved: true
    zoneRedundant: false
    tags: tags
  }
  dependsOn: [
    rg
  ]
}

module storage 'br/public:avm/res/storage/storage-account:0.33.0' = {
  name: 'function-storage'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: storageAccountName
    location: location
    skuName: 'Standard_LRS'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
    defaultToOAuthAuthentication: true
    minimumTlsVersion: 'TLS1_2'
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
    }
    blobServices: {
      containers: [
        {
          name: deploymentStorageContainerName
          publicAccess: 'None'
        }
      ]
    }
    roleAssignments: [
      {
        principalId: functionIdentity.outputs.principalId
        principalType: 'ServicePrincipal'
        roleDefinitionIdOrName: 'Storage Blob Data Owner'
      }
    ]
    tags: tags
  }
  dependsOn: [
    rg
  ]
}

module logAnalytics 'br/public:avm/res/operational-insights/workspace:0.16.1' = {
  name: 'log-analytics'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: logAnalyticsName
    location: location
    dataRetention: 30
    tags: tags
  }
  dependsOn: [
    rg
  ]
}

module applicationInsights 'br/public:avm/res/insights/component:0.8.0' = {
  name: 'application-insights'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: applicationInsightsName
    location: location
    workspaceResourceId: logAnalytics.outputs.resourceId
    disableLocalAuth: true
    roleAssignments: [
      {
        principalId: functionIdentity.outputs.principalId
        principalType: 'ServicePrincipal'
        roleDefinitionIdOrName: 'Monitoring Metrics Publisher'
      }
    ]
    tags: tags
  }
}

module eventHub 'br/public:avm/res/event-hub/namespace:0.15.0' = {
  name: 'event-hubs'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: eventHubNamespaceName
    location: location
    skuName: 'Standard'
    disableLocalAuth: true
    minimumTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled'
    eventhubs: [
      {
        name: eventHubName
        messageRetentionInDays: 1
        partitionCount: 2
      }
    ]
    roleAssignments: [
      {
        principalId: functionIdentity.outputs.principalId
        principalType: 'ServicePrincipal'
        roleDefinitionIdOrName: 'Azure Event Hubs Data Receiver'
      }
    ]
    diagnosticSettings: [
      {
        workspaceResourceId: logAnalytics.outputs.resourceId
      }
    ]
    tags: tags
  }
}

module functionApp 'br/public:avm/res/web/site:0.24.0' = {
  name: 'eventhub-function-app'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: functionAppName
    location: location
    kind: 'functionapp,linux'
    serverFarmResourceId: appServicePlan.outputs.resourceId
    managedIdentities: {
      userAssignedResourceIds: [
        functionIdentity.outputs.resourceId
      ]
    }
    functionAppConfig: {
      deployment: {
        storage: {
          type: 'blobContainer'
          value: '${storage.outputs.primaryBlobEndpoint}${deploymentStorageContainerName}'
          authentication: {
            type: 'UserAssignedIdentity'
            userAssignedIdentityResourceId: functionIdentity.outputs.resourceId
          }
        }
      }
      scaleAndConcurrency: {
        instanceMemoryMB: 2048
        maximumInstanceCount: 100
      }
      runtime: {
        name: 'python'
        version: '3.14'
      }
    }
    siteConfig: {
      alwaysOn: false
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
    }
    configs: [
      {
        name: 'appsettings'
        properties: {
          FUNCTIONS_EXTENSION_VERSION: '~4'
          FUNCTIONS_WORKER_RUNTIME: 'python'
          AzureWebJobsStorage__credential: 'managedidentity'
          AzureWebJobsStorage__clientId: functionIdentity.outputs.clientId
          AzureWebJobsStorage__blobServiceUri: storage.outputs.primaryBlobEndpoint
          EventHubConnection__fullyQualifiedNamespace: '${eventHub.outputs.name}.servicebus.windows.net'
          EventHubConnection__credential: 'managedidentity'
          EventHubConnection__clientId: functionIdentity.outputs.clientId
          EVENTHUB_NAME: eventHubName
          APPLICATIONINSIGHTS_CONNECTION_STRING: applicationInsights.outputs.connectionString
          APPLICATIONINSIGHTS_AUTHENTICATION_STRING: 'ClientId=${functionIdentity.outputs.clientId};Authorization=AAD'
        }
      }
    ]
    basicPublishingCredentialsPolicies: [
      {
        name: 'ftp'
        allow: false
      }
      {
        name: 'scm'
        allow: false
      }
    ]
    tags: union(tags, {
      'azd-service-name': 'eventhub'
    })
  }
}

output AZURE_LOCATION string = location
output AZURE_TENANT_ID string = tenant().tenantId
output EVENT_HUB_NAME string = eventHubName
output EVENT_HUB_NAMESPACE_NAME string = eventHub.outputs.name
output SERVICE_EVENTHUB_NAME string = functionApp.outputs.name
