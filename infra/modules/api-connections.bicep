// ============================================================================
// 📋 api-connections.bicep - API Connections 모듈
// ============================================================================
// 목적: Logic App에서 사용할 API Connection (V2) 리소스 배포
//       - Gmail 커넥터: 이메일 트리거
//       - Teams 커넥터: 알림 전송
//       - Azure DevOps 커넥터: Work Item 생성
// 버전: v2.0.0
// 
// ⚠️ 중요 사항:
// - 모든 커넥터는 kind: 'V2'로 배포해야 MSI 인증 및 Access Policy 지원됨
// - Gmail 및 Teams 커넥터는 배포 후 Azure Portal에서 OAuth 승인 필요
// - ADO 커넥터는 PAT 기반 인증 또는 OAuth 승인 필요
// 
// 📚 참조 문서:
// - API Connections: https://learn.microsoft.com/en-us/azure/connectors/apis-list
// - Gmail Connector: https://learn.microsoft.com/en-us/connectors/gmail/
// - Teams Connector: https://learn.microsoft.com/en-us/connectors/teams/
// - ADO Connector: https://learn.microsoft.com/en-us/connectors/visualstudioteamservices/
// ============================================================================

// ============================================================================
// 🔧 파라미터 정의
// ============================================================================

@description('Azure 리전')
param location string

@description('리소스 태그')
param tags object

@description('Gmail API Connection 이름')
param gmailConnectionName string

@description('Teams API Connection 이름')
param teamsConnectionName string

@description('Azure DevOps API Connection 이름')
param adoConnectionName string

@description('Logic App Principal ID (Access Policy용)')
param logicAppPrincipalId string

// ============================================================================
// 📧 Gmail API Connection (V2)
// ============================================================================
// 📌 Gmail 트리거 요구사항:
//    - G-Suite/Workspace 계정: 제한 없음
//    - 소비자 계정 (@gmail.com): Google 승인 서비스만 가능
//    - BYOA (Bring Your Own App) 옵션으로 제한 우회 가능
// 
// ⚠️ 배포 후 필수 작업:
//    1. Azure Portal → API Connection → Gmail 선택
//    2. "Edit API connection" 클릭
//    3. "Authorize" 버튼으로 Google OAuth 인증 완료

resource gmailConnection 'Microsoft.Web/connections@2016-06-01' = {
  name: gmailConnectionName
  location: location
  tags: tags
  properties: {
    displayName: 'Gmail - Email2ADO Workflow'
    api: {
      id: subscriptionResourceId('Microsoft.Web/locations/managedApis', location, 'gmail')
      displayName: 'Gmail'
      description: 'Gmail connector for email triggers'
      iconUri: 'https://connectoricons-prod.azureedge.net/releases/v1.0.1673/1.0.1673.3557/gmail/icon.png'
      brandColor: '#EA4335'
    }
    // parameterValues는 OAuth 인증 후 자동 설정됨
    parameterValues: {}
  }
}

// Gmail Access Policy (Logic App MSI가 커넥션 사용 가능하도록)
resource gmailAccessPolicy 'Microsoft.Web/connections/accessPolicies@2016-06-01' = {
  parent: gmailConnection
  name: 'logicapp-policy'
  location: location
  properties: {
    principal: {
      type: 'ActiveDirectory'
      identity: {
        tenantId: subscription().tenantId
        objectId: logicAppPrincipalId
      }
    }
  }
}

// ============================================================================
// 💬 Microsoft Teams API Connection (V2)
// ============================================================================
// 📌 알림 채널 전송용
// 
// ⚠️ 배포 후 필수 작업:
//    1. Azure Portal → API Connection → Teams 선택
//    2. "Edit API connection" 클릭
//    3. "Authorize" 버튼으로 Microsoft 계정 인증 완료

resource teamsConnection 'Microsoft.Web/connections@2016-06-01' = {
  name: teamsConnectionName
  location: location
  tags: tags
  properties: {
    displayName: 'Microsoft Teams - Email2ADO Notifications'
    api: {
      id: subscriptionResourceId('Microsoft.Web/locations/managedApis', location, 'teams')
      displayName: 'Microsoft Teams'
      description: 'Teams connector for notifications'
      iconUri: 'https://connectoricons-prod.azureedge.net/releases/v1.0.1673/1.0.1673.3557/teams/icon.png'
      brandColor: '#4B53BC'
    }
    parameterValues: {}
  }
}

// Teams Access Policy
resource teamsAccessPolicy 'Microsoft.Web/connections/accessPolicies@2016-06-01' = {
  parent: teamsConnection
  name: 'logicapp-policy'
  location: location
  properties: {
    principal: {
      type: 'ActiveDirectory'
      identity: {
        tenantId: subscription().tenantId
        objectId: logicAppPrincipalId
      }
    }
  }
}

// ============================================================================
// 🛠️ Azure DevOps API Connection (V2)
// ============================================================================
// 📌 Work Item 생성용 (VSTS 커넥터)
// 
// ⚠️ 알려진 제약사항:
//    - VSTS 커넥터는 AssignedTo, Tags 필드 설정 무시됨
//    - 해결책: PAT + HTTP Action + JSON Patch 사용
//    - 이 커넥터는 기본 Work Item 생성용으로만 사용
// 
// ⚠️ 배포 후 필수 작업:
//    1. Azure Portal → API Connection → VSTS 선택
//    2. "Edit API connection" 클릭
//    3. "Authorize" 버튼으로 Azure DevOps 계정 인증

resource adoConnection 'Microsoft.Web/connections@2016-06-01' = {
  name: adoConnectionName
  location: location
  tags: tags
  properties: {
    displayName: 'Azure DevOps - ZBTaskManager'
    api: {
      id: subscriptionResourceId('Microsoft.Web/locations/managedApis', location, 'visualstudioteamservices')
      displayName: 'Azure DevOps'
      description: 'Azure DevOps connector for work item management'
      iconUri: 'https://connectoricons-prod.azureedge.net/releases/v1.0.1673/1.0.1673.3557/visualstudioteamservices/icon.png'
      brandColor: '#0078D7'
    }
    parameterValues: {}
  }
}

// ADO Access Policy
resource adoAccessPolicy 'Microsoft.Web/connections/accessPolicies@2016-06-01' = {
  parent: adoConnection
  name: 'logicapp-policy'
  location: location
  properties: {
    principal: {
      type: 'ActiveDirectory'
      identity: {
        tenantId: subscription().tenantId
        objectId: logicAppPrincipalId
      }
    }
  }
}

// ============================================================================
// 📤 출력값
// ============================================================================

@description('Gmail Connection 이름')
output gmailConnectionName string = gmailConnection.name

@description('Gmail Connection ID')
output gmailConnectionId string = gmailConnection.id

@description('Teams Connection 이름')
output teamsConnectionName string = teamsConnection.name

@description('Teams Connection ID')
output teamsConnectionId string = teamsConnection.id

@description('ADO Connection 이름')
output adoConnectionName string = adoConnection.name

@description('ADO Connection ID')
output adoConnectionId string = adoConnection.id
