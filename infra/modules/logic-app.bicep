// ============================================================================
// 📋 logic-app.bicep - Logic App Standard 모듈
// ============================================================================
// 목적: Azure Logic Apps Standard 리소스 배포
//       - App Service Plan (WS1)
//       - Logic App Standard + Managed Identity
//       - Application Insights
// 버전: v2.0.0
// 
// 📚 참조 문서:
// - Logic Apps Standard: https://learn.microsoft.com/en-us/azure/logic-apps/single-tenant-overview-compare
// - Managed Identity: https://learn.microsoft.com/en-us/azure/logic-apps/create-managed-service-identity
// ============================================================================

// ============================================================================
// 🔧 파라미터 정의
// ============================================================================

@description('Logic App 이름')
param logicAppName string

@description('App Service Plan 이름')
param appServicePlanName string

@description('Application Insights 이름')
param appInsightsName string

@description('Azure 리전')
param location string

@description('리소스 태그')
param tags object

@description('Storage Account 이름 (Logic App 런타임용)')
param storageAccountName string

@description('Storage Account Primary Key')
@secure()
param storageAccountKey string

@description('Azure DevOps 조직명')
param adoOrganization string

@description('Azure DevOps 프로젝트명')
param adoProject string

@description('Azure OpenAI Endpoint')
param openAIEndpoint string

@description('Azure OpenAI 배포 이름')
param openAIDeploymentName string

@description('Key Vault 이름 (ADO PAT 저장용)')
param keyVaultName string = ''

// ============================================================================
// 📦 App Service Plan 배포
// ============================================================================
// 📌 Logic App Standard는 App Service Plan 필요
// 📌 WS1: Workflow Standard 1 (기본 프로덕션용)
// 📌 WS2/WS3: 더 많은 메모리/CPU 필요시

resource appServicePlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: appServicePlanName
  location: location
  tags: tags
  sku: {
    name: 'WS1'       // Workflow Standard 1
    tier: 'WorkflowStandard'
    size: 'WS1'
    family: 'WS'
    capacity: 1       // 인스턴스 수 (스케일링 가능)
  }
  kind: 'elastic'     // Logic App Standard용
  properties: {
    perSiteScaling: false
    elasticScaleEnabled: true
    maximumElasticWorkerCount: 20
    isSpot: false
    reserved: false   // Windows
    targetWorkerCount: 0
    targetWorkerSizeId: 0
    zoneRedundant: false  // 프로덕션에서는 true 권장
  }
}

// ============================================================================
// 📊 Application Insights 배포
// ============================================================================
// 📌 워크플로우 실행 모니터링 및 디버깅용

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    Request_Source: 'rest'
    RetentionInDays: 90
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// ============================================================================
// ⚙️ Logic App Standard 배포
// ============================================================================

resource logicApp 'Microsoft.Web/sites@2023-12-01' = {
  name: logicAppName
  location: location
  tags: tags
  kind: 'functionapp,workflowapp'  // Logic App Standard 지정
  
  // 🔐 System-assigned Managed Identity 활성화
  identity: {
    type: 'SystemAssigned'
  }
  
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    
    siteConfig: {
      // Logic App Standard 런타임 설정
      netFrameworkVersion: 'v6.0'
      use32BitWorkerProcess: false
      ftpsState: 'Disabled'
      alwaysOn: false  // WS 플랜에서는 자동 관리됨
      http20Enabled: true
      
      // 앱 설정 (환경 변수)
      appSettings: [
        // ────────────────────────────────────────────
        // 📦 필수 런타임 설정
        // ────────────────────────────────────────────
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'dotnet'  // Logic Apps Standard는 dotnet 런타임 사용
        }
        {
          name: 'WEBSITE_NODE_DEFAULT_VERSION'
          value: '~18'
        }
        
        // ────────────────────────────────────────────
        // 💾 Storage 설정 (Logic App 내부 저장소)
        // ────────────────────────────────────────────
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};AccountKey=${storageAccountKey};EndpointSuffix=core.windows.net'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};AccountKey=${storageAccountKey};EndpointSuffix=core.windows.net'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: toLower(logicAppName)
        }
        
        // ────────────────────────────────────────────
        // 📊 Application Insights 설정
        // ────────────────────────────────────────────
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsights.properties.InstrumentationKey
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsights.properties.ConnectionString
        }
        
        // ────────────────────────────────────────────
        // 🔧 워크플로우 커스텀 설정
        // ────────────────────────────────────────────
        {
          name: 'ADO_ORGANIZATION'
          value: adoOrganization
        }
        {
          name: 'ADO_PROJECT'
          value: adoProject
        }
        {
          name: 'AZURE_OPENAI_ENDPOINT'
          value: openAIEndpoint
        }
        {
          name: 'AZURE_OPENAI_DEPLOYMENT_NAME'
          value: openAIDeploymentName
        }
        {
          name: 'AZURE_OPENAI_API_VERSION'
          value: '2024-08-01-preview'
        }
        {
          name: 'TABLE_STORAGE_CONNECTION'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};AccountKey=${storageAccountKey};EndpointSuffix=core.windows.net'
        }
        {
          name: 'TABLE_NAME'
          value: 'ProcessedEmails'
        }
        // ────────────────────────────────────────────
        // 🔐 보안 설정 (Key Vault Reference)
        // ────────────────────────────────────────────
        // ADO Work Item 생성: OAuth API Connection 사용 (PAT 불필요)
        // ADO 필드 업데이트 (AssignedTo/Tags): VSTS 커넥터 제약으로 HTTP 직접 호출 필요 (PAT 필요)
        // 📌 Key Vault에서 참조: 배포 후 az keyvault secret set 명령으로 PAT 저장 필요
        {
          name: 'ADO_PAT'
          value: keyVaultName != '' ? '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=ado-pat)' : ''
        }
      ]
    }
  }
}

// ============================================================================
// 📤 출력값
// ============================================================================

@description('Logic App 이름')
output logicAppName string = logicApp.name

@description('Logic App ID')
output logicAppId string = logicApp.id

@description('Logic App Principal ID (Managed Identity)')
output logicAppPrincipalId string = logicApp.identity.principalId

@description('Logic App 기본 URL')
output logicAppUrl string = 'https://${logicApp.properties.defaultHostName}'

@description('Application Insights Instrumentation Key')
output appInsightsKey string = appInsights.properties.InstrumentationKey

@description('App Service Plan ID')
output appServicePlanId string = appServicePlan.id
