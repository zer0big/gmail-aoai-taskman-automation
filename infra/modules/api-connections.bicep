// ============================================================================
// 📋 api-connections.bicep - API Connections 모듈
// ============================================================================
// 목적: Logic App에서 사용할 API Connection 리소스 배포
//       - Gmail 커넥터: 이메일 트리거
//       - Teams 커넥터: 알림 전송
//       - Azure DevOps 커넥터: Work Item 생성
// 버전: v2.1.0
// 
// ⚠️ 중요 사항:
// - Gmail, Teams, ADO 커넥터는 V1 연결 사용 (V2는 미지원 또는 제한적)
// - 배포 후 Azure Portal에서 OAuth 승인 필수
// - Logic App workflow에서 Raw 인증 방식 사용
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

@description('Logic App Principal ID (참조용)')
param logicAppPrincipalId string

// ============================================================================
// 📧 Gmail API Connection (V1)
// ============================================================================
// 📌 Gmail 트리거 요구사항:
//    - 소비자 계정 (@gmail.com): zerobig.kim@gmail.com
//    - 배포 후 Azure Portal에서 OAuth 승인 필요
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
    displayName: 'Gmail - zerobig.kim@gmail.com'
    api: {
      id: subscriptionResourceId('Microsoft.Web/locations/managedApis', location, 'gmail')
    }
  }
}

// ============================================================================
// 💬 Microsoft Teams API Connection (V1)
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
    }
  }
}

// ============================================================================
// 🛠️ Azure DevOps API Connection (V1)
// ============================================================================
// 📌 Work Item 생성용 (VSTS 커넥터)
// 
// ⚠️ 알려진 제약사항:
//    - VSTS 커넥터는 AssignedTo, Tags 필드 설정 무시됨
//    - 해결책: PAT + HTTP Action + JSON Patch 사용
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
