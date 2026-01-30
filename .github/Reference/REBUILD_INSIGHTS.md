# 💡 재구축 핵심 인사이트

**버전**: v1.0.0  
**최종 업데이트**: 2026-01-24  
**목적**: 새로운 환경에서 처음부터 재구축할 때 반드시 알아야 할 핵심 사항

> ⚠️ **중요**: 이 문서는 실제 구축 과정에서 겪은 시행착오와 해결책을 정리한 것입니다.  
> 동일한 실수를 반복하지 않도록 반드시 숙지 후 진행하세요.

---

## 🚨 핵심 이슈 요약 (2026-01-24 기준)

| 순번 | 이슈 | 증상 | 해결책 | 중요도 |
|------|------|------|--------|--------|
| 1 | **Azure OpenAI 연동 불가** | 커넥터 설정 없이 호출 시 실패 | Built-in OpenAI 커넥터 + API Key 방식 | 🔴 Critical |
| 2 | **ADO Work Item 담당자 할당 불가** | VSTS 커넥터 assignedTo 필드 무시됨 | PAT + HTTP Action + JSON Patch | 🔴 Critical |
| 3 | **ADO Work Item 태그 할당 불가** | VSTS 커넥터 tags 필드 무시됨 | PAT + HTTP Action + JSON Patch | 🔴 Critical |
| 4 | **MSI 직접 ADO 인증 불가** | HTTP 401 Unauthorized | API Connection V2 + OAuth + Access Policy | 🟠 High |
| 5 | **V1 vs V2 Connector 차이** | Access Policy 지원 안 됨 | V2 Connector 필수 (kind: "V2") | 🟠 High |

---

## 🔥 Issue #1: Azure OpenAI AI 분석 연동 불가

### 문제 상황
```
AI 분석 액션이 실행되지 않거나 "Connection configuration not found" 오류 발생
```

### 원인
- Logic Apps Standard에서 Azure OpenAI 호출 시 **Built-in OpenAI 커넥터** 사용 필요
- HTTP 직접 호출 시 인증 헤더 관리 복잡성 증가
- Managed API Connection은 Azure OpenAI를 지원하지 않음

### ✅ 해결책: Built-in OpenAI 커넥터 (ServiceProvider 방식)

**connections.json 설정:**
```json
{
  "serviceProviderConnections": {
    "azureOpenAI": {
      "parameterValues": {
        "openAIKey": "@appsetting('AZURE_OPENAI_API_KEY')",
        "openAIEndpoint": "@appsetting('AZURE_OPENAI_ENDPOINT')"
      },
      "serviceProvider": {
        "id": "/serviceProviders/openai"
      },
      "displayName": "Azure OpenAI - Email AI Analyzer"
    }
  }
}
```

**workflow.json 액션 (getChatCompletions):**
```json
{
  "Analyze_Email_With_AI": {
    "type": "ServiceProvider",
    "inputs": {
      "serviceProviderConfiguration": {
        "connectionName": "azureOpenAI",
        "operationId": "getChatCompletions",
        "serviceProviderId": "/serviceProviders/openai"
      },
      "parameters": {
        "deploymentId": "@appsetting('AZURE_OPENAI_DEPLOYMENT_NAME')",
        "messages": [
          { "role": "system", "content": "메일 분석 전문가..." },
          { "role": "user", "content": "메일 내용..." }
        ],
        "temperature": 0.3,
        "max_tokens": 1000
      }
    }
  }
}
```

**필수 App Settings:**
| 설정명 | 설명 | 예시 |
|--------|------|------|
| `AZURE_OPENAI_ENDPOINT` | Azure OpenAI 엔드포인트 | `https://aoai-email2ado-prod.openai.azure.com/` |
| `AZURE_OPENAI_API_KEY` | API Key (Key Vault 권장) | (Key Vault Reference 사용 권장) |
| `AZURE_OPENAI_DEPLOYMENT_NAME` | 배포된 모델명 | `gpt-4o-deploy` |

**API Key 조회:**
```powershell
az cognitiveservices account keys list `
  --name "aoai-email2ado-prod" `
  --resource-group "rg-email2ado-prod" `
  --query "key1" -o tsv
```

### 핵심 교훈
> 💡 **Built-in OpenAI 커넥터**는 `serviceProviderConnections`에 설정하며,  
> `managedApiConnections`가 아닌 별도 섹션에서 관리된다.

---

## 🔥 Issue #2 & #3: ADO Work Item 담당자(Assigned To) 및 태그(Tags) 할당 불가

### 문제 상황
```
- VSTS 커넥터의 body에 assignedTo, tags 필드를 추가해도 Work Item에 반영되지 않음
- userEnteredAssignedTo, dynamicFields 등 다양한 방법 시도했으나 모두 실패
```

### 시도한 방법 및 결과

| 시도 | 코드 예시 | 결과 |
|------|----------|------|
| body에 직접 추가 | `"assignedTo": "@{variables('Email')}"` | ❌ 무시됨 |
| userEntered 접두사 | `"userEnteredAssignedTo": "..."` | ❌ 무시됨 |
| dynamicFields 사용 | `"dynamicFields": {"System.AssignedTo": "..."}` | ❌ 무시됨 |
| HTTP + Managed Identity | `"authentication": {"type": "ManagedServiceIdentity"}` | ❌ 401 Unauthorized |
| VSTS `/httprequest` | `"path": "/httprequest"` | ❌ NotFound |
| **HTTP + PAT + JSON Patch** | 아래 참조 | ✅ **성공** |

### ✅ 최종 해결책: PAT + HTTP Action + JSON Patch

**원인 분석:**
- VSTS 커넥터는 Work Item 생성 시 일부 필드만 지원 (title, description 등 기본 필드)
- **System.AssignedTo**, **System.Tags**는 커넥터가 내부적으로 무시함
- Managed Identity는 Azure DevOps에 직접 인증 불가 (MSI가 ADO에 등록된 사용자가 아님)

**해결책: 별도 HTTP Action으로 Work Item 업데이트**

```json
{
  "Update_ADO_WorkItem_Fields": {
    "type": "Http",
    "runAfter": { "Create_ADO_WorkItem": ["Succeeded"] },
    "inputs": {
      "method": "PATCH",
      "uri": "https://dev.azure.com/@{appsetting('ADO_ORGANIZATION')}/@{appsetting('ADO_PROJECT')}/_apis/wit/workitems/@{body('Create_ADO_WorkItem')?['id']}?api-version=7.1",
      "headers": {
        "Content-Type": "application/json-patch+json",
        "Authorization": "Basic @{base64(concat(':', appsetting('ADO_PAT')))}"
      },
      "body": [
        {
          "op": "add",
          "path": "/fields/System.AssignedTo",
          "value": "@{variables('RecipientEmail')}"
        },
        {
          "op": "add",
          "path": "/fields/System.Tags",
          "value": "CM Worker Manager"
        }
      ]
    }
  }
}
```

### PAT (Personal Access Token) 설정 방법

**1. PAT 생성 (Azure DevOps Portal):**
```
Azure DevOps → User Settings → Personal Access Tokens
→ New Token
→ Scopes: Work Items (Read & Write)
→ 만료: 1년 권장
```

**2. App Setting에 저장:**
```powershell
az webapp config appsettings set `
  --name "em0911-workflow" `
  --resource-group "rg-email2ado-prod" `
  --settings "ADO_PAT=<your-pat-token>"
```

**3. Authorization 헤더 형식:**
```
Basic base64(:PAT)  # 콜론(:) 앞에 사용자명 없이 PAT만 사용
```

### 핵심 교훈
> ⚠️ **VSTS 커넥터 한계**: Work Item 생성 시 `assignedTo`, `tags`는 지원되지 않음  
> ✅ **해결책**: Work Item 생성 후 **별도 HTTP Action**으로 필드 업데이트  
> ✅ **인증**: PAT 토큰 + Basic Auth (MSI 불가)  
> ✅ **Body 형식**: JSON Patch 배열 (`application/json-patch+json`)

---

## 🔥 Issue #4: MSI 직접 ADO 인증 불가

### 문제 상황
```
TF401444: Please sign-in at least once as dddd4071-e969-4d36-aa5f-091e40ad53c1
또는 HTTP 401 Unauthorized
```

### 원인
- Managed Identity는 Azure DevOps에 **직접 인증할 수 없음**
- MSI는 Azure AD에 등록된 앱이지만, ADO는 별도 인증 흐름 필요

### ✅ 해결책 2가지

**방법 1: API Connection V2 + OAuth + Access Policy (Work Item 생성 시)**

```
graph LR
    A[Logic App MSI] -->|Access Policy| B[API Connection V2]
    B -->|OAuth Token| C[Azure DevOps]
```

**구현 단계:**
1. **V2 Connector 생성** (kind: "V2" 필수)
2. **OAuth 동의 완료** (사용자가 브라우저에서 인증)
3. **Access Policy 부여** (MSI가 Connection 사용할 수 있도록)
4. **connections.json 구성** (connectionRuntimeUrl 필수)
5. **App Settings 추가** (ADO_CONNECTION_RUNTIME_URL)

**방법 2: PAT + HTTP Action (필드 업데이트 시)**
- 위 Issue #2 & #3 해결책 참조
- Work Item 생성 후 추가 필드 업데이트에 사용

---

## 🔥 Issue #5: V1 vs V2 API Connection 차이

### 문제 상황
```
- V1 Connector 사용 시 Access Policy 부여 불가
- Logic App Standard에서 Managed Identity 인증 미작동
```

### 핵심 차이점

| 특성 | V1 Connector | V2 Connector |
|------|-------------|--------------|
| `kind` 속성 | 없음 | `"V2"` **필수** |
| Access Policy | ❌ 지원 안 함 | ✅ 지원 |
| connectionRuntimeUrl | ❌ | ✅ 필수 |
| Logic App Standard | ⚠️ 호환성 문제 | ✅ 권장 |
| MSI 인증 | ❌ | ✅ (Access Policy 통해) |

### ✅ V2 Connector 생성 명령

```powershell
$body = @{
    location = "koreacentral"
    kind = "V2"  # ⚠️ 핵심!
    properties = @{
        api = @{ 
            id = "/subscriptions/<sub-id>/providers/Microsoft.Web/locations/koreacentral/managedApis/visualstudioteamservices" 
        }
        displayName = "visualstudioteamservices"
    }
} | ConvertTo-Json -Depth 5

az rest --method PUT `
  --uri "https://management.azure.com/subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.Web/connections/visualstudioteamservices?api-version=2018-07-01-preview" `
  --body $body
```

### Access Policy 부여

```powershell
$body = @{
    properties = @{
        principal = @{
            type = "ActiveDirectory"
            identity = @{
                tenantId = "<tenant-id>"
                objectId = "<msi-principal-id>"  # Logic App MSI
            }
        }
    }
} | ConvertTo-Json -Depth 5

az rest --method PUT `
  --uri "https://management.azure.com/subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.Web/connections/visualstudioteamservices/accessPolicies/<policy-name>?api-version=2018-07-01-preview" `
  --body $body
```

### 핵심 교훈
> ⚠️ **V1 Connector는 사용하지 마세요!**  
> Logic App Standard에서는 반드시 `kind: "V2"` Connector를 사용해야 합니다.

---

## 📋 현재 구현된 아키텍처 (v1.0.0)

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                                  프로덕션 환경                                       │
│                                                                                       │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────────────────┐      │
│  │   Office 365    │───▶│   Logic App     │───▶│     Azure OpenAI            │      │
│  │   (Trigger)     │    │   em0911-       │    │     GPT-4o                  │      │
│  │   OAuth V2      │    │   workflow      │    │     (API Key)               │      │
│  └─────────────────┘    └────────┬────────┘    └─────────────────────────────┘      │
│                                  │                                                   │
│               ┌──────────────────┼──────────────────┐                               │
│               ▼                  ▼                  ▼                               │
│  ┌─────────────────┐  ┌─────────────────────┐  ┌─────────────────┐                  │
│  │  Table Storage  │  │    Azure DevOps     │  │  Microsoft      │                  │
│  │  ProcessedEmails│  │ ┌─────────────────┐ │  │  Teams          │                  │
│  │  (MSI 인증)     │  │ │ VSTS Connector  │ │  │  (OAuth V2)     │                  │
│  └─────────────────┘  │ │ (OAuth V2)      │ │  └─────────────────┘                  │
│                       │ │ Work Item 생성   │ │                                       │
│                       │ └────────┬────────┘ │                                       │
│                       │          │          │                                       │
│                       │ ┌────────▼────────┐ │                                       │
│                       │ │ HTTP + PAT      │ │                                       │
│                       │ │ 담당자/태그 설정 │ │                                       │
│                       │ │ (JSON Patch)    │ │                                       │
│                       │ └─────────────────┘ │                                       │
│                       └─────────────────────┘                                       │
│                                                                                       │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### 인증 방식 요약

| 서비스 | 인증 방식 | 설정 위치 |
|--------|----------|----------|
| Office 365 | OAuth (API Connection V2) | connections.json |
| Azure OpenAI | API Key | App Settings (AZURE_OPENAI_API_KEY) |
| Table Storage | Managed Identity | workflow.json (inline) |
| ADO Work Item 생성 | OAuth (API Connection V2) | connections.json |
| ADO 필드 업데이트 | PAT (Basic Auth) | App Settings (ADO_PAT) |
| Microsoft Teams | OAuth (API Connection V2) | connections.json |

---

## 🔧 필수 App Settings 목록

| 설정명 | 설명 | 예시 |
|--------|------|------|
| `WORKFLOWS_SUBSCRIPTION_ID` | Azure 구독 ID | `xxxxxxxx-xxxx-...` |
| `WORKFLOWS_RESOURCE_GROUP_NAME` | 리소스 그룹명 | `rg-email2ado-prod` |
| `WORKFLOWS_LOCATION_NAME` | 리전 | `koreacentral` |
| `STORAGE_ACCOUNT_NAME` | 스토리지 계정명 | `em0911irgskutuqb2f4` |
| `OFFICE365_CONNECTION_RUNTIME_URL` | Office 365 연결 URL | (Azure Portal에서 복사) |
| `TEAMS_CONNECTION_RUNTIME_URL` | Teams 연결 URL | (Azure Portal에서 복사) |
| `ADO_CONNECTION_RUNTIME_URL` | ADO 연결 URL | (Azure Portal에서 복사) |
| `ADO_ORGANIZATION` | ADO 조직명 | `tdg-zerobig` |
| `ADO_PROJECT` | ADO 프로젝트명 | `CM-Worker-Demo` |
| `ADO_PAT` | Personal Access Token | (ADO에서 생성) |
| `TEAMS_TEAM_ID` | Teams 팀 ID | (Graph API로 조회) |
| `TEAMS_CHANNEL_ID` | Teams 채널 ID | (Graph API로 조회) |
| `AZURE_OPENAI_ENDPOINT` | Azure OpenAI 엔드포인트 | `https://xxx.openai.azure.com/` |
| `AZURE_OPENAI_API_KEY` | Azure OpenAI API Key | (Key Vault 권장) |
| `AZURE_OPENAI_DEPLOYMENT_NAME` | 배포된 모델명 | `gpt-4o-deploy` |

---

## 📋 재구축 체크리스트 (Updated v1.0.0)

### Phase 0: 인프라 준비
- [ ] Resource Group 생성
- [ ] Logic App Standard 배포 (Bicep 또는 Portal)
- [ ] Storage Account 생성 + ProcessedEmails 테이블 생성
- [ ] MSI 권한 부여 (Storage Table Data Contributor)
- [ ] **Azure OpenAI 리소스 생성** (GPT-4o 모델 배포)

### Phase 1: API Connections 생성
- [ ] **Office365 V2 Connector** 생성 → OAuth 동의 → Access Policy
- [ ] **Teams V2 Connector** 생성 → OAuth 동의 → Access Policy
- [ ] **visualstudioteamservices V2 Connector** 생성 → OAuth 동의 → Access Policy
- [ ] 각 Connection의 Runtime URL 복사
- [ ] **ADO PAT 토큰 생성** (Work Items Read & Write 권한)

### Phase 2: App Settings 설정
- [ ] `WORKFLOWS_SUBSCRIPTION_ID`
- [ ] `WORKFLOWS_RESOURCE_GROUP_NAME`
- [ ] `WORKFLOWS_LOCATION_NAME`
- [ ] `STORAGE_ACCOUNT_NAME`
- [ ] `OFFICE365_CONNECTION_RUNTIME_URL`
- [ ] `TEAMS_CONNECTION_RUNTIME_URL`
- [ ] `ADO_CONNECTION_RUNTIME_URL`
- [ ] `ADO_ORGANIZATION`
- [ ] `ADO_PROJECT`
- [ ] **`ADO_PAT`** (Personal Access Token)
- [ ] `TEAMS_TEAM_ID`
- [ ] `TEAMS_CHANNEL_ID`
- [ ] **`AZURE_OPENAI_ENDPOINT`**
- [ ] **`AZURE_OPENAI_API_KEY`**
- [ ] **`AZURE_OPENAI_DEPLOYMENT_NAME`**

### Phase 3: 워크플로 배포
- [ ] workflow.json 업로드
- [ ] connections.json 업로드 (serviceProviderConnections + managedApiConnections)
- [ ] 워크플로 Enable
- [ ] **테스트 1**: 메일 발송 → Work Item 생성 확인
- [ ] **테스트 2**: AI 분석 결과 확인
- [ ] **테스트 3**: 담당자 할당 확인
- [ ] **테스트 4**: 태그 "CM Worker Manager" 확인
- [ ] **테스트 5**: Teams 알림 확인

---

## ⚠️ 흔한 실수 및 해결책 (Updated v1.0.0)

### 실수 1: V1 Connector 사용
```
오류: Access Policy를 설정할 수 없음
해결: V1 삭제 → V2 재생성 (kind: "V2")
```

### 실수 2: OAuth 동의 누락
```
오류: "Unauthorized" 또는 "Connection not authenticated"
해결: Azure Portal → API Connection → Edit → Authorize 클릭 → 사용자 인증
```

### 실수 3: Access Policy 미부여
```
오류: "Forbidden" 또는 "Access denied"
해결: az rest로 Access Policy 부여 (MSI objectId 사용)
```

### 실수 4: VSTS 커넥터로 담당자/태그 설정 시도
```
오류: 필드가 Work Item에 반영되지 않음
원인: VSTS 커넥터는 assignedTo, tags 필드를 지원하지 않음
해결: 별도 HTTP Action + PAT + JSON Patch로 업데이트
```

### 실수 5: HTTP Action에서 MSI로 ADO 인증 시도
```
오류: HTTP 401 Unauthorized
원인: MSI는 Azure DevOps에 직접 인증 불가
해결: PAT 토큰 + Basic Auth 사용
```

### 실수 6: JSON Patch Content-Type 누락
```
오류: "You must pass a valid patch document in the body of the request."
해결: Content-Type: application/json-patch+json 헤더 추가
```

### 실수 7: Azure OpenAI 연결 설정 누락
```
오류: "Connection configuration not found" 또는 AI 액션 실패
해결: connections.json에 serviceProviderConnections.azureOpenAI 섹션 추가
```

### 실수 8: connectionRuntimeUrl 누락
```
오류: "Connection configuration not found"
해결: connections.json에 connectionRuntimeUrl 추가, App Settings에 값 설정
```

### 실수 9: Table Storage 권한 누락
```
오류: 403 Forbidden (Table Storage 접근 시)
해결: az role assignment create로 Storage Table Data Contributor 부여
```

---

## 📋 connections.json 전체 템플릿

```json
{
  "serviceProviderConnections": {
    "azureOpenAI": {
      "parameterValues": {
        "openAIKey": "@appsetting('AZURE_OPENAI_API_KEY')",
        "openAIEndpoint": "@appsetting('AZURE_OPENAI_ENDPOINT')"
      },
      "serviceProvider": {
        "id": "/serviceProviders/openai"
      },
      "displayName": "Azure OpenAI - Email AI Analyzer"
    }
  },
  "managedApiConnections": {
    "office365": {
      "api": {
        "id": "/subscriptions/@appsetting('WORKFLOWS_SUBSCRIPTION_ID')/providers/Microsoft.Web/locations/@appsetting('WORKFLOWS_LOCATION_NAME')/managedApis/office365"
      },
      "connection": {
        "id": "/subscriptions/@appsetting('WORKFLOWS_SUBSCRIPTION_ID')/resourceGroups/@appsetting('WORKFLOWS_RESOURCE_GROUP_NAME')/providers/Microsoft.Web/connections/office365"
      },
      "connectionRuntimeUrl": "@appsetting('OFFICE365_CONNECTION_RUNTIME_URL')",
      "authentication": { "type": "ManagedServiceIdentity" }
    },
    "teams": {
      "api": {
        "id": "/subscriptions/@appsetting('WORKFLOWS_SUBSCRIPTION_ID')/providers/Microsoft.Web/locations/@appsetting('WORKFLOWS_LOCATION_NAME')/managedApis/teams"
      },
      "connection": {
        "id": "/subscriptions/@appsetting('WORKFLOWS_SUBSCRIPTION_ID')/resourceGroups/@appsetting('WORKFLOWS_RESOURCE_GROUP_NAME')/providers/Microsoft.Web/connections/teams"
      },
      "connectionRuntimeUrl": "@appsetting('TEAMS_CONNECTION_RUNTIME_URL')",
      "authentication": { "type": "ManagedServiceIdentity" }
    },
    "visualstudioteamservices": {
      "api": {
        "id": "/subscriptions/@appsetting('WORKFLOWS_SUBSCRIPTION_ID')/providers/Microsoft.Web/locations/@appsetting('WORKFLOWS_LOCATION_NAME')/managedApis/visualstudioteamservices"
      },
      "connection": {
        "id": "/subscriptions/@appsetting('WORKFLOWS_SUBSCRIPTION_ID')/resourceGroups/@appsetting('WORKFLOWS_RESOURCE_GROUP_NAME')/providers/Microsoft.Web/connections/visualstudioteamservices"
      },
      "connectionRuntimeUrl": "@appsetting('ADO_CONNECTION_RUNTIME_URL')",
      "authentication": { "type": "ManagedServiceIdentity" }
    }
  }
}
```

---

## 📚 공식 참고 문서

| 주제 | 링크 |
|------|------|
| Logic App Standard API Connection | [Microsoft Learn](https://learn.microsoft.com/azure/logic-apps/create-managed-api-connections-standard-workflows) |
| API Connection Access Policy | [Microsoft Learn](https://learn.microsoft.com/azure/logic-apps/logic-apps-securing-a-logic-app#add-access-policies) |
| Azure DevOps Work Items API | [Microsoft Learn](https://learn.microsoft.com/rest/api/azure/devops/wit/work-items) |
| Azure DevOps 인증 가이드 | [Microsoft Learn](https://learn.microsoft.com/azure/devops/integrate/get-started/authentication/authentication-guidance) |
| Table Storage MSI 인증 | [Microsoft Learn](https://learn.microsoft.com/azure/storage/common/storage-auth-aad-msi) |
| Azure OpenAI Logic Apps 커넥터 | [Microsoft Learn](https://learn.microsoft.com/azure/logic-apps/connectors/built-in/reference/openai/) |
| Teams Graph API | [Microsoft Learn](https://learn.microsoft.com/graph/api/channel-post-messages) |

---

## 🔧 유용한 명령어 모음

### Azure OpenAI API Key 조회
```powershell
az cognitiveservices account keys list `
  --name "aoai-email2ado-prod" `
  --resource-group "rg-email2ado-prod" `
  --query "key1" -o tsv
```

### Logic App MSI Principal ID 조회
```powershell
az webapp identity show `
  --name "em0911-workflow" `
  --resource-group "rg-email2ado-prod" `
  --query "principalId" -o tsv
```

### App Settings 일괄 설정
```powershell
az webapp config appsettings set `
  --name "em0911-workflow" `
  --resource-group "rg-email2ado-prod" `
  --settings `
    "ADO_PAT=<your-pat>" `
    "ADO_ORGANIZATION=tdg-zerobig" `
    "ADO_PROJECT=CM-Worker-Demo" `
    "AZURE_OPENAI_ENDPOINT=https://xxx.openai.azure.com/" `
    "AZURE_OPENAI_API_KEY=<your-key>" `
    "AZURE_OPENAI_DEPLOYMENT_NAME=gpt-4o-deploy"
```

### 워크플로 배포
```powershell
cd "Email2ADO-Workflow"
Compress-Archive -Path * -DestinationPath "$env:TEMP\wf.zip" -Force
az webapp deployment source config-zip `
  --resource-group "rg-email2ado-prod" `
  --name "em0911-workflow" `
  --src "$env:TEMP\wf.zip" --timeout 300
az webapp restart --name "em0911-workflow" --resource-group "rg-email2ado-prod"
```

### 최근 실행 상태 확인
```powershell
az rest --method GET `
  --uri "https://management.azure.com/subscriptions/<sub-id>/resourceGroups/rg-email2ado-prod/providers/Microsoft.Web/sites/em0911-workflow/hostruntime/runtime/webhooks/workflow/api/management/workflows/IssueHandler/runs?api-version=2018-11-01" `
  --query "value[0].{id:name, status:properties.status, startTime:properties.startTime}" -o table
```

---

## 📊 예상 비용 (Korea Central 기준)

| 리소스 | SKU | 월 예상 비용 |
|--------|-----|-------------|
| Logic App Standard | WS1 | ~$150 |
| Storage Account | Standard LRS | ~$5 |
| Application Insights | Pay-as-you-go | ~$10 |
| API Connections | 사용량 기반 | ~$5 |
| Azure OpenAI | GlobalStandard GPT-4o | ~$20 (10K TPM) |
| **총합** | - | **~$190/월** |

*실제 비용은 실행 횟수, 데이터 양, AI 토큰 사용량에 따라 변동*

---

## 🎯 핵심 요약 (TL;DR)

1. **Azure OpenAI**: Built-in OpenAI 커넥터 사용 (`serviceProviderConnections`)
2. **담당자/태그 할당**: VSTS 커넥터 불가 → HTTP + PAT + JSON Patch 필수
3. **MSI로 ADO 직접 인증**: 불가능 → API Connection V2 + OAuth 또는 PAT 사용
4. **V1 vs V2 Connector**: 반드시 V2 사용 (`kind: "V2"`)
5. **인증 방식 혼용**: Work Item 생성은 OAuth, 필드 업데이트는 PAT

---

## 👥 기여자
- 김영대 (azure-mvp@zerobig.kr)

## 📄 라이선스
Internal Use Only

## 📅 변경 이력
| 버전 | 날짜 | 변경 내용 |
|------|------|----------|
| v1.0.0 | 2026-01-24 | AI 분석, 담당자/태그 할당 이슈 및 해결책 추가 |
| v0.8.0 | 2026-01-21 | 초기 작성 (MSI 인증, V1/V2 차이) |
