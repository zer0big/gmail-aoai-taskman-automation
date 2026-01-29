// ============================================================================
// 📋 prod.bicepparam - 프로덕션 환경 파라미터 파일
// ============================================================================
// 목적: 프로덕션(prod) 환경용 Bicep 파라미터 정의
// 버전: v2.0.0
// 
// ⚠️ 주의사항:
//    - 프로덕션 배포 전 반드시 what-if 검증 수행
//    - 리소스 그룹: rg-zbtask-prod (사전 생성 필요)
// 
// 📚 사용법:
//    # What-if 검증
//    az deployment group what-if \
//      --resource-group rg-zbtask-prod \
//      --template-file ../main.bicep \
//      --parameters prod.bicepparam
// 
//    # 실제 배포
//    az deployment group create \
//      --resource-group rg-zbtask-prod \
//      --template-file ../main.bicep \
//      --parameters prod.bicepparam
// ============================================================================

using '../main.bicep'

// ============================================================================
// 🔧 기본 파라미터
// ============================================================================

// 리소스 이름 접두사
param namePrefix = 'zbtask'

// 배포 환경
param environment = 'prod'

// Azure 리전 (Korea Central 권장)
param location = 'koreacentral'

// ============================================================================
// 🛠️ Azure DevOps 설정
// ============================================================================

param adoOrganization = 'azure-mvp'
param adoProject = 'ZBTaskManager'

// ============================================================================
// 🤖 Azure OpenAI 설정 (기존 리소스 참조)
// ============================================================================
// 📌 프로덕션에서는 동일한 Azure OpenAI 리소스 사용
// 📌 필요시 별도 프로덕션 Azure OpenAI 리소스 생성 가능

param openAIResourceName = 'zb-taskman'
param openAIDeploymentName = 'gpt-4o'

// ============================================================================
// 🏷️ 리소스 태그
// ============================================================================
// 📌 프로덕션 태그에는 CostCenter, SLA 등 추가 정보 포함

param tags = {
  Project: 'ZBTaskManager'
  Environment: 'prod'
  ManagedBy: 'Bicep'
  CreatedDate: '2026-01-29'
  Owner: 'azure-mvp@zerobig.kr'
  CostCenter: 'Email2ADO-Prod'
  SLA: 'Standard'
  DataClassification: 'Internal'
}
