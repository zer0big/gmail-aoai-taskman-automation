// ============================================================================
// 📋 main.bicep - Gmail 기반 이메일 자동화 시스템 메인 배포 파일
// ============================================================================
// 목적: Azure Logic Apps Standard 기반 이메일 자동화 시스템의 모든 리소스 배포
// 버전: v2.4.0
// 작성일: 2026-01-31
// 담당자: 김영대 (azure-mvp@zerobig.kr)
// 
// 📚 참조 문서:
// - Logic Apps: https://learn.microsoft.com/en-us/azure/logic-apps/
// - Bicep: https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/
// ============================================================================

// ============================================================================
// 🔧 파라미터 정의
// ============================================================================

@description('리소스 이름 접두사 (예: zbtask)')
@minLength(3)
@maxLength(10)
param namePrefix string

@description('배포 환경 (dev, prod)')
@allowed(['dev', 'prod'])
param environment string = 'dev'

@description('Azure 리전')
param location string = resourceGroup().location

@description('Azure DevOps 조직명')
param adoOrganization string = 'azure-mvp'

@description('Azure DevOps 프로젝트명')
param adoProject string = 'ZBTaskManager'

@description('Azure OpenAI 리소스 이름 (기존 리소스 참조)')
param openAIResourceName string = 'zb-taskman'

@description('Azure OpenAI 배포 이름')
param openAIDeploymentName string = 'gpt-4o'

@description('리소스 태그')
param tags object = {
  Project: 'ZBTaskManager'
  Environment: environment
  ManagedBy: 'Bicep'
  CreatedDate: '2026-01-29'
}

// ============================================================================
// 🏷️ 변수 정의
// ============================================================================

// 리소스 이름 생성 (명명 규칙: {prefix}-{resourceType}-{env})
// Storage Account 이름은 24자 이내, 소문자/숫자만 허용
var storageAccountName = toLower(take(replace('st${namePrefix}${environment}${uniqueString(resourceGroup().id)}', '-', ''), 24))
var logicAppName = '${namePrefix}-logic-${environment}'
var appServicePlanName = '${namePrefix}-asp-${environment}'
var appInsightsName = '${namePrefix}-appi-${environment}'
var keyVaultName = 'kv-${namePrefix}-${environment}'

// API Connection 이름
var gmailConnectionName = 'gmail-${environment}'
var teamsConnectionName = 'teams-${environment}'
var adoConnectionName = 'visualstudioteamservices-${environment}'

// ============================================================================
// 📦 모듈 배포
// ============================================================================

// Storage Account (Table Storage 포함)
module storage 'modules/storage.bicep' = {
  name: 'storage-deployment'
  params: {
    storageAccountName: storageAccountName
    location: location
    tags: tags
  }
}

// Logic App Standard (App Service Plan 포함)
module logicApp 'modules/logic-app.bicep' = {
  name: 'logicapp-deployment'
  params: {
    logicAppName: logicAppName
    appServicePlanName: appServicePlanName
    appInsightsName: appInsightsName
    location: location
    tags: tags
    storageAccountName: storage.outputs.storageAccountName
    storageAccountKey: storage.outputs.storageAccountKey
    adoOrganization: adoOrganization
    adoProject: adoProject
    openAIEndpoint: 'https://${openAIResourceName}.cognitiveservices.azure.com/'
    openAIDeploymentName: openAIDeploymentName
    keyVaultName: keyVaultName
  }
}

// API Connections (Gmail, Teams, Azure DevOps)
module apiConnections 'modules/api-connections.bicep' = {
  name: 'apiconnections-deployment'
  params: {
    location: location
    tags: tags
    gmailConnectionName: gmailConnectionName
    teamsConnectionName: teamsConnectionName
    adoConnectionName: adoConnectionName
  }
}

// Key Vault (ADO PAT 등 민감 정보 저장)
module keyVault 'modules/key-vault.bicep' = {
  name: 'keyvault-deployment'
  params: {
    keyVaultName: keyVaultName
    location: location
    tags: tags
    logicAppPrincipalId: logicApp.outputs.logicAppPrincipalId
  }
}

// ============================================================================
// 🔐 RBAC 역할 할당
// ============================================================================

// Logic App MSI에 Storage Table Data Contributor 역할 부여
// 📌 목적: Table Storage에 대한 읽기/쓰기 권한 (중복 메일 체크용)
// 📌 주의: guid 함수에는 배포 시작 시점에 계산 가능한 값만 사용
resource storageRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, logicAppName, storageAccountName, 'StorageTableDataContributor')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3') // Storage Table Data Contributor
    principalId: logicApp.outputs.logicAppPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// ============================================================================
// 📤 출력값
// ============================================================================

@description('Logic App 이름')
output logicAppName string = logicApp.outputs.logicAppName

@description('Logic App Principal ID (MSI)')
output logicAppPrincipalId string = logicApp.outputs.logicAppPrincipalId

@description('Storage Account 이름')
output storageAccountName string = storage.outputs.storageAccountName

@description('Gmail Connection Runtime URL (배포 후 Azure Portal에서 확인)')
output gmailConnectionName string = apiConnections.outputs.gmailConnectionName

@description('Teams Connection Runtime URL (배포 후 Azure Portal에서 확인)')
output teamsConnectionName string = apiConnections.outputs.teamsConnectionName

@description('ADO Connection Runtime URL (배포 후 Azure Portal에서 확인)')
output adoConnectionName string = apiConnections.outputs.adoConnectionName

@description('Azure OpenAI Endpoint')
output openAIEndpoint string = 'https://${openAIResourceName}.cognitiveservices.azure.com/'

@description('Key Vault 이름')
output keyVaultName string = keyVault.outputs.keyVaultName

@description('Key Vault URI')
output keyVaultUri string = keyVault.outputs.keyVaultUri
