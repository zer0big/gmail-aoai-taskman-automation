// ============================================================================
// 📋 storage.bicep - Storage Account 모듈
// ============================================================================
// 목적: Azure Table Storage를 포함한 Storage Account 배포
//       - ProcessedEmails 테이블: 중복 이메일 방지용
// 버전: v2.0.0
// 
// 📚 참조 문서:
// - Storage Account: https://learn.microsoft.com/en-us/azure/storage/
// - Table Storage: https://learn.microsoft.com/en-us/azure/storage/tables/
// ============================================================================

// ============================================================================
// 🔧 파라미터 정의
// ============================================================================

@description('Storage Account 이름 (3-24자, 소문자 및 숫자만)')
@minLength(3)
@maxLength(24)
param storageAccountName string

@description('Azure 리전')
param location string

@description('리소스 태그')
param tags object

// ============================================================================
// 📦 Storage Account 배포
// ============================================================================

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  tags: tags
  sku: {
    name: 'Standard_LRS'  // 개발용: LRS, 운영용: GRS 권장
  }
  kind: 'StorageV2'
  properties: {
    // 🔐 보안 설정
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true  // Table Storage 접근용 (MSI 전환 시 false)
    
    // 🌐 네트워크 설정
    publicNetworkAccess: 'Enabled'  // Logic App 접근용
    networkAcls: {
      defaultAction: 'Allow'  // 필요시 'Deny' + VNet 규칙 추가
      bypass: 'AzureServices'
    }
    
    // 📊 기타 설정
    accessTier: 'Hot'
  }
}

// ============================================================================
// 📋 Table Storage 서비스 배포
// ============================================================================

resource tableService 'Microsoft.Storage/storageAccounts/tableServices@2023-05-01' = {
  parent: storageAccount
  name: 'default'
  properties: {}
}

// ============================================================================
// 📋 ProcessedEmails 테이블 배포
// ============================================================================
// 📌 용도: 처리된 이메일의 Message ID를 저장하여 중복 처리 방지
// 📌 스키마:
//     - PartitionKey: "Email" (고정값)
//     - RowKey: 이메일 Message ID (예: <msgid@mail.gmail.com>)
//     - ProcessedAt: 처리 시간 (ISO 8601)
//     - WorkItemId: 생성된 ADO Work Item ID
//     - Subject: 이메일 제목 (참조용)

resource processedEmailsTable 'Microsoft.Storage/storageAccounts/tableServices/tables@2023-05-01' = {
  parent: tableService
  name: 'ProcessedEmails'
}

// ============================================================================
// 📤 출력값
// ============================================================================

@description('Storage Account 이름')
output storageAccountName string = storageAccount.name

@description('Storage Account ID')
output storageAccountId string = storageAccount.id

@description('Storage Account Primary Key (Managed Identity 전환 전까지 사용)')
#disable-next-line outputs-should-not-contain-secrets
output storageAccountKey string = storageAccount.listKeys().keys[0].value

@description('Storage Account 연결 문자열')
#disable-next-line outputs-should-not-contain-secrets
output storageConnectionString string = 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[0].value};EndpointSuffix=core.windows.net'

@description('Table Service Endpoint')
output tableEndpoint string = storageAccount.properties.primaryEndpoints.table
