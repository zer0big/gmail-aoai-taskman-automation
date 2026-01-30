# 🔧 문제 해결 가이드 (Troubleshooting)

Email2ADO 시스템 운영 중 발생할 수 있는 문제와 해결 방법을 정리합니다.

---

## 📋 목차

1. [워크플로우 상태 문제](#1-워크플로우-상태-문제)
2. [인증 관련 문제](#2-인증-관련-문제)
3. [Azure OpenAI 문제](#3-azure-openai-문제)
4. [Azure DevOps 문제](#4-azure-devops-문제)
5. [Teams 알림 문제](#5-teams-알림-문제)
6. [Table Storage 문제](#6-table-storage-문제)
7. [배포 문제](#7-배포-문제)

---

## 1. 워크플로우 상태 문제

### 1.1 Email2ADO-Gmail Unhealthy

**증상**: Gmail 트리거 워크플로우가 Unhealthy 상태

**원인**: V1 커넥터가 Logic App Standard에서 `connectionRuntimeUrl` 속성을 지원하지 않음

**해결책**: 
- ✅ **Email2ADO-HTTP** 워크플로우 사용 (HTTP Trigger 방식)
- Gmail 트리거 대신 Power Automate 또는 외부 시스템에서 HTTP POST 호출

```powershell
# 워크플로우 상태 확인
az rest --method GET `
  --uri "https://management.azure.com/subscriptions/{subId}/resourceGroups/rg-zb-taskman/providers/Microsoft.Web/sites/email2ado-logic-prod/workflows?api-version=2023-01-01" `
  | ConvertFrom-Json | ForEach-Object { $_.value | Select-Object name, @{n='health';e={$_.properties.health.state}} }
```

### 1.2 워크플로우 실행 실패

**진단 방법**:

```powershell
# 최근 실행 기록 조회
$runId = az rest --method GET `
  --uri "https://management.azure.com/subscriptions/{subId}/resourceGroups/rg-zb-taskman/providers/Microsoft.Web/sites/email2ado-logic-prod/hostruntime/runtime/webhooks/workflow/api/management/workflows/Email2ADO-HTTP/runs?api-version=2023-01-01" `
  | ConvertFrom-Json | Select-Object -ExpandProperty value | Select-Object -First 1 -ExpandProperty name

# 실행 상세 조회
az rest --method GET `
  --uri "https://management.azure.com/subscriptions/{subId}/resourceGroups/rg-zb-taskman/providers/Microsoft.Web/sites/email2ado-logic-prod/hostruntime/runtime/webhooks/workflow/api/management/workflows/Email2ADO-HTTP/runs/$runId?api-version=2023-01-01"
```

---

## 2. 인증 관련 문제

### 2.1 MSI 인증 실패 - "Unauthorized"

**증상**: 
```
The client '...' does not have authorization to perform action '...'
```

**해결책**:

1. **RBAC 역할 확인**:
```powershell
$logicAppPrincipalId = az functionapp identity show `
  --name email2ado-logic-prod `
  --resource-group rg-zb-taskman `
  --query principalId -o tsv

# 할당된 역할 확인
az role assignment list --assignee $logicAppPrincipalId --query "[].{role:roleDefinitionName, scope:scope}" -o table
```

2. **필요한 역할 할당**:
```powershell
# Storage Table Data Contributor
az role assignment create --assignee $logicAppPrincipalId `
  --role "Storage Table Data Contributor" `
  --scope "/subscriptions/{subId}/resourceGroups/rg-zb-taskman/providers/Microsoft.Storage/storageAccounts/{storageAccount}"

# Cognitive Services OpenAI User
az role assignment create --assignee $logicAppPrincipalId `
  --role "Cognitive Services OpenAI User" `
  --scope "/subscriptions/{subId}/resourceGroups/rg-zb-taskman/providers/Microsoft.CognitiveServices/accounts/zb-taskman"

# Key Vault Secrets User
az role assignment create --assignee $logicAppPrincipalId `
  --role "Key Vault Secrets User" `
  --scope "/subscriptions/{subId}/resourceGroups/rg-zb-taskman/providers/Microsoft.KeyVault/vaults/kv-zbtask-prod"
```

### 2.2 Key Vault 접근 실패

**증상**:
```
Access denied. Caller was not found on any access policy.
```

**해결책**:

1. Key Vault RBAC 모드 확인:
```powershell
az keyvault show --name kv-zbtask-prod --query "properties.enableRbacAuthorization" -o tsv
```

2. RBAC 모드가 `true`인 경우 역할 할당 필요
3. RBAC 모드가 `false`인 경우 Access Policy 추가 필요

### 2.3 Easy Auth 인증 실패

**증상**: HTTP 401 Unauthorized

**해결책**:

1. Bearer Token 확인:
```powershell
# 토큰 획득 (테스트용)
$token = az account get-access-token `
  --resource "api://c454a3ed-f41d-4180-82d0-4ab0704fc65c" `
  --query accessToken -o tsv

# 요청 시 Authorization 헤더 포함
Invoke-RestMethod -Uri $triggerUrl -Method POST `
  -Headers @{ Authorization = "Bearer $token" } `
  -Body $payload -ContentType "application/json"
```

---

## 3. Azure OpenAI 문제

### 3.1 "InvalidAuthenticationTokenAudience" 오류

**증상**:
```
The access token has been obtained from wrong audience or resource
```

**원인**: `audience` 값이 잘못됨

**해결책**: workflow.json에서 audience 확인
```json
"authentication": {
  "type": "ManagedServiceIdentity",
  "audience": "https://cognitiveservices.azure.com"  // ← 올바른 값
}
```

### 3.2 "DeploymentNotFound" 오류

**증상**:
```
The API deployment for this resource does not exist
```

**해결책**:

1. 배포 이름 확인:
```powershell
az cognitiveservices account deployment list `
  --name zb-taskman `
  --resource-group rg-zb-taskman `
  --query "[].name" -o tsv
```

2. App Setting 업데이트:
```powershell
az functionapp config appsettings set `
  --name email2ado-logic-prod `
  --resource-group rg-zb-taskman `
  --settings "AZURE_OPENAI_DEPLOYMENT_NAME=gpt-4o"
```

### 3.3 Rate Limit 초과

**증상**:
```
Requests to the ChatCompletions_Create Operation under Azure OpenAI API version have exceeded token rate limit
```

**해결책**:
- Retry Policy가 이미 적용되어 있으므로 자동 재시도됨
- 지속적인 문제 시 Azure OpenAI 할당량 증가 요청

---

## 4. Azure DevOps 문제

### 4.1 Work Item 생성 실패 - 401

**증상**:
```
TF400813: The user '' is not authorized to access this resource.
```

**원인**: PAT 만료 또는 권한 부족

**해결책**:

1. PAT 유효성 확인:
```powershell
$pat = az keyvault secret show `
  --vault-name kv-zbtask-prod `
  --name ado-pat `
  --query value -o tsv

# PAT 테스트
$base64Auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$pat"))
Invoke-RestMethod -Uri "https://dev.azure.com/azure-mvp/_apis/projects?api-version=7.1" `
  -Headers @{ Authorization = "Basic $base64Auth" }
```

2. 새 PAT 생성 및 Key Vault 업데이트:
```powershell
az keyvault secret set `
  --vault-name kv-zbtask-prod `
  --name ado-pat `
  --value "NEW_PAT_VALUE"
```

### 4.2 필드 업데이트 실패

**증상**: Work Item은 생성되지만 특정 필드가 업데이트되지 않음

**원인**: VSTS 커넥터 제약 (AssignedTo, Tags 필드)

**해결책**: HTTP Action + PAT 방식 사용 (현재 구현됨)

---

## 5. Teams 알림 문제

### 5.1 Incoming Webhook 오류

**증상**:
```
Connector configuration not found or connector has been disabled
```

**원인**: Microsoft가 Incoming Webhook을 지원 중단 (2025년 12월)

**해결책**: Power Automate Workflow 사용 (현재 구현됨)

### 5.2 Power Automate Workflow 실패

**증상**: Teams 알림이 수신되지 않음

**진단 방법**:

1. Workflow URL 확인:
```powershell
az functionapp config appsettings list `
  --name email2ado-logic-prod `
  --resource-group rg-zb-taskman `
  --query "[?name=='TEAMS_WORKFLOW_URL'].value" -o tsv
```

2. URL 직접 테스트:
```powershell
$workflowUrl = "YOUR_WORKFLOW_URL"
$testPayload = @{
  type = "message"
  attachments = @(
    @{
      contentType = "application/vnd.microsoft.card.adaptive"
      content = @{
        type = "AdaptiveCard"
        version = "1.4"
        body = @(@{ type = "TextBlock"; text = "Test Message" })
      }
    }
  )
} | ConvertTo-Json -Depth 10

Invoke-RestMethod -Uri $workflowUrl -Method POST -Body $testPayload -ContentType "application/json"
```

---

## 6. Table Storage 문제

### 6.1 테이블 조회 실패

**증상**:
```
The table specified does not exist
```

**해결책**:

1. 테이블 존재 확인:
```powershell
az storage table list `
  --account-name stemail2adoprodxhum3jlfa `
  --auth-mode login `
  --query "[].name" -o tsv
```

2. 테이블 생성:
```powershell
az storage table create `
  --name ProcessedEmails `
  --account-name stemail2adoprodxhum3jlfa `
  --auth-mode login
```

### 6.2 중복 체크 실패

**증상**: 동일한 이메일이 여러 번 처리됨

**원인**: MessageId 인코딩 문제

**확인**:
```powershell
# Table Storage 데이터 조회
az storage entity query `
  --table-name ProcessedEmails `
  --account-name stemail2adoprodxhum3jlfa `
  --auth-mode login `
  --query "items[*].{RowKey:RowKey, Subject:Subject, Status:Status}" -o table
```

---

## 7. 배포 문제

### 7.1 ZIP 배포 실패

**증상**:
```
Deployment endpoint responded with status code 500
```

**해결책**:

1. Logic App 상태 확인:
```powershell
az functionapp show `
  --name email2ado-logic-prod `
  --resource-group rg-zb-taskman `
  --query "state" -o tsv
```

2. Logic App 재시작:
```powershell
az functionapp restart `
  --name email2ado-logic-prod `
  --resource-group rg-zb-taskman
```

3. 다시 배포:
```powershell
az functionapp deployment source config-zip `
  --name email2ado-logic-prod `
  --resource-group rg-zb-taskman `
  --src "./deploy.zip"
```

### 7.2 Bicep 배포 실패

**증상**: 리소스 이름 충돌 또는 SKU 제한

**해결책**:

1. 배포 오류 상세 확인:
```powershell
az deployment group show `
  --resource-group rg-zb-taskman `
  --name main `
  --query "properties.error" -o json
```

2. 일반적인 해결책:
   - Storage Account 이름 고유성 확인 (24자 이내, 소문자/숫자만)
   - 리전별 SKU 가용성 확인

---

## 📞 지원 요청

위 방법으로 해결되지 않는 경우:

1. **Azure Support**: Azure Portal → Help + support
2. **ADO Work Item**: https://dev.azure.com/azure-mvp/ZBTaskManager/_workitems
3. **담당자**: azure-mvp@zerobig.kr

---

**작성**: 2026-01-30 | **버전**: v2.3.0
