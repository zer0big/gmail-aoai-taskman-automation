// ============================================================================
// 📦 Azure Key Vault 모듈
// ============================================================================
// 용도: ADO PAT 등 민감 정보의 보안 저장소
// 참조: https://learn.microsoft.com/en-us/azure/key-vault/
// ============================================================================

// ============================================================================
// 📥 파라미터
// ============================================================================

@description('Key Vault 이름')
param keyVaultName string

@description('Azure 리전')
param location string = resourceGroup().location

@description('Logic App Principal ID (MSI)')
param logicAppPrincipalId string

@description('태그')
param tags object = {}

// ============================================================================
// 🏗️ Key Vault 리소스
// ============================================================================

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  tags: tags
  properties: {
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    // ────────────────────────────────────────────
    // 🔐 RBAC 기반 액세스 제어 (권장)
    // ────────────────────────────────────────────
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
    enablePurgeProtection: false  // 개발 환경에서는 비활성화
    
    // ────────────────────────────────────────────
    // 🌐 네트워크 설정
    // ────────────────────────────────────────────
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
    }
  }
}

// ============================================================================
// 🔑 RBAC 역할 할당 - Logic App MSI에 Secret 읽기 권한 부여
// ============================================================================

// Key Vault Secrets User 역할 ID
var keyVaultSecretsUserRoleId = '4633458b-17de-408a-b874-0445c86b69e6'

resource logicAppSecretUserRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, logicAppPrincipalId, keyVaultSecretsUserRoleId)
  scope: keyVault
  properties: {
    principalId: logicAppPrincipalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', keyVaultSecretsUserRoleId)
    principalType: 'ServicePrincipal'
  }
}

// ============================================================================
// 📤 출력값
// ============================================================================

@description('Key Vault 이름')
output keyVaultName string = keyVault.name

@description('Key Vault URI')
output keyVaultUri string = keyVault.properties.vaultUri

@description('Key Vault ID')
output keyVaultId string = keyVault.id
