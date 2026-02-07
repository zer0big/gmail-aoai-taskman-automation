// ============================================================================
// 📋 zbtaskman.bicepparam - rg-zb-taskman 리소스 그룹용 파라미터 파일
// ============================================================================
// 목적: rg-zb-taskman 리소스 그룹에 배포하기 위한 파라미터
// 버전: v2.0.0
// 
// 📌 특징:
//    - 기존 Azure OpenAI 리소스(zb-taskman) 활용
//    - Gmail 트리거 기반 워크플로우
// 
// 📚 사용법:
//    # What-if 검증
//    az deployment group what-if \
//      --resource-group rg-zb-taskman \
//      --template-file ../main.bicep \
//      --parameters zbtaskman.bicepparam
// 
//    # 실제 배포
//    az deployment group create \
//      --resource-group rg-zb-taskman \
//      --template-file ../main.bicep \
//      --parameters zbtaskman.bicepparam
// ============================================================================

using '../main.bicep'

// ============================================================================
// 🔧 기본 파라미터
// ============================================================================

// 리소스 이름 접두사
param namePrefix = 'email2ado'

// 배포 환경
param environment = 'prod'

// Azure 리전 (Korea Central)
param location = 'koreacentral'

// ============================================================================
// 🛠️ Azure DevOps 설정
// ============================================================================

param adoOrganization = 'azure-mvp'
param adoProject = 'ZBTaskManager'

// ============================================================================
// 🤖 Azure OpenAI 설정 (기존 리소스 참조)
// ============================================================================
// 📌 rg-zb-taskman에 이미 존재하는 Azure OpenAI 리소스 사용

param openAIResourceName = 'zb-taskman'
param openAIDeploymentName = 'gpt-4o'

// ============================================================================
// 🏷️ 리소스 태그
// ============================================================================

param tags = {
  Project: 'ZBTaskManager'
  Environment: 'prod'
  ManagedBy: 'Bicep'
  CreatedDate: '2026-01-29'
  Owner: '<your-email>'
  CostCenter: 'Email2ADO'
  GmailAccount: '<your-gmail-account>'
}
