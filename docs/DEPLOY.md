# 🚀 Azure 배포 가이드

이 문서는 Email2ADO 시스템을 **새로운 Azure 환경에 처음부터 배포**하는 방법을 단계별로 설명합니다.

**예상 소요 시간**: 약 30분

---

## 📋 목차

1. [사전 요구사항](#1-사전-요구사항)
2. [리소스 그룹 생성](#2-리소스-그룹-생성)
3. [Bicep 인프라 배포](#3-bicep-인프라-배포)
4. [Key Vault Secret 설정](#4-key-vault-secret-설정)
5. [API Connection OAuth 인증](#5-api-connection-oauth-인증)
6. [워크플로우 배포](#6-워크플로우-배포)
7. [Easy Auth 구성](#7-easy-auth-구성)
8. [Teams Workflow 설정](#8-teams-workflow-설정)
9. [E2E 테스트](#9-e2e-테스트)
10. [문제 해결](#10-문제-해결)

---

## 1. 사전 요구사항

### 필수 도구

```powershell
# Azure CLI 버전 확인 (2.50 이상)
az --version

# Azure Functions Core Tools 버전 확인 (4.x)
func --version

# 설치가 필요한 경우
# Azure CLI: https://learn.microsoft.com/ko-kr/cli/azure/install-azure-cli
# Functions Core Tools: https://learn.microsoft.com/ko-kr/azure/azure-functions/functions-run-local
```

### Azure 로그인

```powershell
# Azure 로그인
az login

# 구독 확인
az account show --query "{name:name, id:id}" -o table

# 구독 변경 (필요시)
az account set --subscription "YOUR_SUBSCRIPTION_ID"
```

### 필요한 권한

| 권한 | 용도 |
|------|------|
| Subscription Contributor | 리소스 그룹 및 리소스 생성 |
| Microsoft Entra ID App Registration | Easy Auth 구성 |
| Azure DevOps Project Admin | Work Item 생성 권한 |

---

## 2. 리소스 그룹 생성

```powershell
# 변수 설정
$resourceGroup = "rg-email2ado-prod"
$location = "koreacentral"

# 리소스 그룹 생성
az group create --name $resourceGroup --location $location --tags Project=Email2ADO Environment=prod

# 확인
az group show --name $resourceGroup --query "{name:name, location:location}" -o table
```

---

## 3. Bicep 인프라 배포

### 3.1 파라미터 파일 수정

`infra/parameters/zbtaskman.bicepparam` 파일을 환경에 맞게 수정합니다:

```bicep
using '../main.bicep'

// 리소스 이름 접두사 (3-10자, 영숫자)
param namePrefix = 'email2ado'

// 환경 (dev 또는 prod)
param environment = 'prod'

// Azure DevOps 설정
param adoOrganization = 'YOUR_ADO_ORG'
param adoProject = 'YOUR_ADO_PROJECT'

// 기존 Azure OpenAI 리소스 이름 (없으면 새로 생성 필요)
param openAIResourceName = 'YOUR_OPENAI_RESOURCE'
param openAIDeploymentName = 'gpt-4o'
```

### 3.2 배포 실행

```powershell
cd infra

# 배포 미리보기 (what-if)
az deployment group what-if `
  --resource-group $resourceGroup `
  --template-file main.bicep `
  --parameters parameters/zbtaskman.bicepparam

# 실제 배포
az deployment group create `
  --resource-group $resourceGroup `
  --template-file main.bicep `
  --parameters parameters/zbtaskman.bicepparam `
  --query "{status:properties.provisioningState, outputs:properties.outputs}" `
  -o json
```

### 3.3 배포 출력값 확인

```powershell
# 배포된 리소스 확인
az deployment group show `
  --resource-group $resourceGroup `
  --name main `
  --query "properties.outputs" -o json
```

**주요 출력값**:
- `logicAppName`: Logic App 이름
- `storageAccountName`: Storage Account 이름
- `keyVaultName`: Key Vault 이름

---

## 4. Key Vault Secret 설정

### 4.1 ADO PAT 생성

1. Azure DevOps → User Settings → Personal Access Tokens
2. **New Token** 클릭
3. 설정:
   - Name: `Email2ADO-PAT`
   - Expiration: 1년 (권장)
   - Scopes: 
     - Work Items: Read & Write
     - Project and Team: Read

### 4.2 Key Vault에 PAT 저장

```powershell
$keyVaultName = "kv-email2ado-prod"  # 배포된 Key Vault 이름
$adoPat = "YOUR_ADO_PAT_HERE"

# Secret 저장
az keyvault secret set `
  --vault-name $keyVaultName `
  --name "ado-pat" `
  --value $adoPat

# 확인
az keyvault secret show `
  --vault-name $keyVaultName `
  --name "ado-pat" `
  --query "{name:name, enabled:attributes.enabled}" -o table
```

---

## 5. API Connection OAuth 인증

Azure Portal에서 각 API Connection에 대해 OAuth 인증을 수행합니다.

### 5.1 Gmail Connection

1. Azure Portal → API Connections → `gmail-prod`
2. **Edit API connection** 클릭
3. **Authorize** 클릭
4. Google 계정으로 로그인 및 권한 허용
5. **Save** 클릭

### 5.2 Teams Connection

1. Azure Portal → API Connections → `teams-prod`
2. **Edit API connection** 클릭
3. **Authorize** 클릭
4. Microsoft 365 계정으로 로그인
5. **Save** 클릭

### 5.3 Azure DevOps Connection

1. Azure Portal → API Connections → `visualstudioteamservices-prod`
2. **Edit API connection** 클릭
3. **Authorize** 클릭
4. Azure DevOps 계정으로 로그인
5. **Save** 클릭

---

## 6. 워크플로우 배포

### 6.1 App Settings 확인/수정

```powershell
$logicAppName = "email2ado-logic-prod"

# 현재 App Settings 확인
az functionapp config appsettings list `
  --name $logicAppName `
  --resource-group $resourceGroup `
  --query "[].{name:name, value:value}" -o table

# 필요한 App Settings 추가
az functionapp config appsettings set `
  --name $logicAppName `
  --resource-group $resourceGroup `
  --settings `
    "KEY_VAULT_NAME=kv-email2ado-prod" `
    "TEAMS_WORKFLOW_URL=YOUR_TEAMS_WORKFLOW_URL" `
    "AZURE_OPENAI_ENDPOINT=https://YOUR_OPENAI.cognitiveservices.azure.com/"
```

### 6.2 워크플로우 ZIP 배포

```powershell
cd src/Email2ADO-Workflow

# ZIP 파일 생성
Compress-Archive -Path "./*" -DestinationPath "./deploy.zip" -Force

# 배포
az functionapp deployment source config-zip `
  --name $logicAppName `
  --resource-group $resourceGroup `
  --src "./deploy.zip"

# 배포 상태 확인
az functionapp deployment list `
  --name $logicAppName `
  --resource-group $resourceGroup `
  --query "[0].{status:status, endTime:endTime}" -o table
```

### 6.3 워크플로우 상태 확인

```powershell
# 워크플로우 Health 상태 확인
az rest --method GET `
  --uri "https://management.azure.com/subscriptions/{subscriptionId}/resourceGroups/$resourceGroup/providers/Microsoft.Web/sites/$logicAppName/workflows?api-version=2023-01-01" `
  | ConvertFrom-Json | Select-Object -ExpandProperty value | ForEach-Object { Write-Host "$($_.name): $($_.properties.health.state)" }
```

**예상 결과**:
```
Email2ADO-HTTP: Healthy
Email2ADO-Gmail: Healthy (또는 Unhealthy - V1 제한)
```

---

## 7. Easy Auth 구성

HTTP Trigger에 Microsoft Entra ID 인증을 추가합니다.

### 7.1 App Registration 생성

```powershell
$appName = "Email2ADO-HTTP-Auth"
$replyUrl = "https://$logicAppName.azurewebsites.net/.auth/login/aad/callback"

# 기존 앱 확인
$existingApp = az ad app list --display-name $appName --query "[0].appId" -o tsv

if ($existingApp) {
    Write-Host "기존 App Registration 사용: $existingApp"
    $appId = $existingApp
} else {
    # 새 App Registration 생성
    $appId = az ad app create `
      --display-name $appName `
      --sign-in-audience "AzureADMyOrg" `
      --web-redirect-uris $replyUrl `
      --query "appId" -o tsv
    Write-Host "App Registration 생성: $appId"
}
```

### 7.2 Easy Auth 활성화

```powershell
$tenantId = az account show --query "tenantId" -o tsv

az webapp auth update `
  --name $logicAppName `
  --resource-group $resourceGroup `
  --enabled true `
  --action LoginWithAzureActiveDirectory `
  --aad-client-id $appId `
  --aad-token-issuer-url "https://sts.windows.net/$tenantId/"
```

---

## 8. Teams Workflow 설정

Teams Incoming Webhook이 지원 중단되므로 Power Automate Workflow를 사용합니다.

### 8.1 Teams에서 Workflow 생성

1. Microsoft Teams → 알림을 받을 채널 선택
2. 채널 옵션(⋯) → **Workflows** 클릭
3. **"Post to a channel when a webhook request is received"** 템플릿 선택
4. 생성 완료 후 **Workflow URL** 복사

### 8.2 App Setting 업데이트

```powershell
$teamsWorkflowUrl = "https://prod-xx.xxx.logic.azure.com:443/workflows/..."

az functionapp config appsettings set `
  --name $logicAppName `
  --resource-group $resourceGroup `
  --settings "TEAMS_WORKFLOW_URL=$teamsWorkflowUrl"
```

---

## 9. E2E 테스트

### 9.1 HTTP Trigger URL 조회

```powershell
# Callback URL 조회
az rest --method POST `
  --uri "https://management.azure.com/subscriptions/{subscriptionId}/resourceGroups/$resourceGroup/providers/Microsoft.Web/sites/$logicAppName/hostruntime/runtime/webhooks/workflow/api/management/workflows/Email2ADO-HTTP/triggers/HTTP_Trigger/listCallbackUrl?api-version=2023-01-01" `
  | ConvertFrom-Json | Select-Object -ExpandProperty value
```

### 9.2 테스트 요청 전송

```powershell
$triggerUrl = "YOUR_TRIGGER_URL_HERE"

$testPayload = @{
    messageId = "test-" + (Get-Date -Format "yyyyMMddHHmmss")
    subject = "[E2E Test] 배포 검증 테스트"
    body = "이것은 배포 검증을 위한 테스트 이메일입니다."
    from = "test@example.com"
    to = "admin@example.com"
    receivedTime = (Get-Date -Format "o")
} | ConvertTo-Json

# POST 요청
Invoke-RestMethod -Uri $triggerUrl -Method POST -Body $testPayload -ContentType "application/json"
```

### 9.3 결과 확인

1. **Azure DevOps**: 새 Work Item 생성 확인
2. **Teams 채널**: 알림 메시지 수신 확인
3. **Table Storage**: ProcessedEmails 테이블에 레코드 확인

---

## 10. 문제 해결

문제가 발생하면 [docs/TROUBLESHOOTING.md](TROUBLESHOOTING.md)를 참조하세요.

### 빠른 확인 목록

| 확인 항목 | 확인 방법 |
|----------|----------|
| 워크플로우 상태 | Azure Portal → Logic App → Workflows |
| 실행 기록 | Azure Portal → Logic App → Workflow runs |
| App Settings | Azure Portal → Logic App → Configuration |
| Key Vault 접근 | Key Vault → Access policies (MSI 확인) |
| RBAC 역할 | Azure Portal → Logic App → Identity → Role assignments |

---

## 📚 관련 문서

- [README.md](../README.md) - 프로젝트 개요
- [ARCHITECTURE.md](ARCHITECTURE.md) - 아키텍처 설계
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - 문제 해결
- [GMAIL-SETUP.md](GMAIL-SETUP.md) - Gmail 설정

---

**작성**: 2026-01-30 | **버전**: v2.3.0
