# 📘 Email2ADO 구축 핸즈온 가이드

> **Gmail → Azure OpenAI → Azure DevOps Work Item 자동 생성 시스템**  
> 초보 Azure 클라우드 엔지니어를 위한 Step-by-Step 구축 절차서

**버전**: v1.0.0  
**작성일**: 2026-01-31  
**예상 소요시간**: 약 2~3시간

---

## 📋 목차

1. [개요](#1-개요)
2. [사전 조건](#2-사전-조건)
3. [Step 1: Azure DevOps 설정](#step-1-azure-devops-설정)
4. [Step 2: Teams Workflow 설정](#step-2-teams-workflow-설정)
5. [Step 3: Azure 리소스 배포 (IaC)](#step-3-azure-리소스-배포-iac)
6. [Step 4: Key Vault 설정](#step-4-key-vault-설정)
7. [Step 5: API Connection 인증](#step-5-api-connection-인증)
8. [Step 6: Logic App 워크플로우 배포](#step-6-logic-app-워크플로우-배포)
9. [Step 7: Gmail 환경 구성](#step-7-gmail-환경-구성)
10. [Step 8: Google Apps Script 설정](#step-8-google-apps-script-설정)
11. [Step 9: E2E 테스트](#step-9-e2e-테스트)
12. [문제 해결](#문제-해결)
13. [다음 단계](#다음-단계)

---

## 1. 개요

### 1.1 시스템 아키텍처

```
┌─────────────┐     ┌──────────────────┐     ┌─────────────────────────┐
│   Gmail     │     │  Gmail Filter    │     │  Google Apps Script     │
│   (이메일)   │────▶│  (키워드 필터)    │────▶│  (5분 폴링)             │
└─────────────┘     └──────────────────┘     └───────────┬─────────────┘
                                                         │
                                                   HTTP POST (SAS)
                                                         ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                     Azure Logic App Standard                            │
├─────────────────────────────────────────────────────────────────────────┤
│  HTTP Trigger → 중복체크 → AI분석(GPT-4o) → Work Item 생성 → Teams 알림 │
│                (Table Storage)  (Azure OpenAI)   (ADO REST API)         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 1.2 구성 요소

| 구성 요소 | 역할 | 기술 |
|----------|------|------|
| Gmail | 이메일 수신 | Gmail Filter + Labels |
| Apps Script | Gmail 모니터링 및 HTTP 호출 | Google Apps Script |
| Logic App | 핵심 워크플로우 처리 | Azure Logic Apps Standard |
| Azure OpenAI | 이메일 내용 AI 분석 | GPT-4o |
| Table Storage | 중복 이메일 방지 | Azure Storage Tables |
| Key Vault | 보안 정보 저장 | Azure Key Vault |
| Azure DevOps | Work Item 자동 생성 | REST API + PAT |
| Teams | 알림 전송 | Power Automate Workflow |

---

## 2. 사전 조건

### 2.1 필수 계정

| 계정 | 용도 | 확인 방법 |
|------|------|----------|
| ✅ Azure 구독 | Azure 리소스 배포 | [portal.azure.com](https://portal.azure.com) |
| ✅ Azure DevOps 조직 | Work Item 관리 | [dev.azure.com](https://dev.azure.com) |
| ✅ Microsoft 365 | Teams 알림 | Teams 앱 설치 확인 |
| ✅ Gmail 계정 | 이메일 수신 | [gmail.com](https://gmail.com) |
| ✅ GitHub 계정 (선택) | 소스 코드 클론 | [github.com](https://github.com) |

### 2.2 필수 도구 설치

#### 2.2.1 Windows 환경

```powershell
# 1. Azure CLI 설치
winget install Microsoft.AzureCLI

# 설치 확인 (2.50 이상)
az --version

# 2. Azure Functions Core Tools 설치
winget install Microsoft.Azure.FunctionsCoreTools

# 설치 확인 (4.x)
func --version

# 3. Git 설치
winget install Git.Git

# 설치 확인
git --version

# 4. Visual Studio Code 설치 (선택)
winget install Microsoft.VisualStudioCode
```

#### 2.2.2 VS Code 확장 프로그램 (권장)

| 확장 | ID | 용도 |
|------|---|------|
| Azure Logic Apps | ms-azuretools.vscode-azurelogicapps | 워크플로우 디자이너 |
| Azure Functions | ms-azuretools.vscode-azurefunctions | 로컬 디버깅 |
| Bicep | ms-azuretools.vscode-bicep | IaC 편집 |

### 2.3 필요 권한

| 범위 | 권한 | 확인 방법 |
|------|------|----------|
| Azure 구독 | Contributor 이상 | `az role assignment list --assignee $(az account show --query user.name -o tsv)` |
| Azure DevOps | Project Administrator | ADO > Project Settings > Permissions |
| Microsoft 365 | Teams 채널 관리자 | Teams > 채널 설정 접근 가능 |
| Gmail | 계정 소유자 | Gmail 설정 접근 가능 |

### 2.4 프로젝트 소스 코드 다운로드

```powershell
# 작업 디렉토리 생성
mkdir C:\Hands-On\Email2ADO
cd C:\Hands-On\Email2ADO

# GitHub에서 클론
git clone https://github.com/zer0big/gmail-aoai-taskman-automation.git .

# 디렉토리 구조 확인
dir
```

**예상 결과**:
```
Mode                 LastWriteTime         Length Name
----                 -------------         ------ ----
d-----         2026-01-31   12:00                docs
d-----         2026-01-31   12:00                infra
d-----         2026-01-31   12:00                scripts
d-----         2026-01-31   12:00                src
-a----         2026-01-31   12:00           8000 README.md
```

---

## Step 1: Azure DevOps 설정

### 1-1. Azure DevOps 조직 생성 (없는 경우)

1. **[dev.azure.com](https://dev.azure.com)** 접속
2. **Start free** 클릭
3. Microsoft 계정으로 로그인
4. 조직 이름 입력 (예: `my-organization`)
5. 프로젝트 지역 선택 (예: `Korea`)
6. **Continue** 클릭

### 1-2. 프로젝트 생성

1. Azure DevOps 홈 > **+ New project**
2. 프로젝트 정보 입력:
   - **Project name**: `Email2ADO-Demo`
   - **Visibility**: Private
   - **Version control**: Git
   - **Work item process**: Agile
3. **Create** 클릭

### 1-3. Personal Access Token (PAT) 생성

> ⚠️ **중요**: PAT는 한 번만 표시됩니다. 반드시 안전한 곳에 저장하세요!

1. Azure DevOps 우측 상단 **User settings** (톱니바퀴 아이콘) 클릭
2. **Personal access tokens** 선택
3. **+ New Token** 클릭
4. 토큰 정보 입력:
   - **Name**: `Email2ADO-PAT`
   - **Organization**: 본인 조직 선택
   - **Expiration**: Custom defined → **365 days**
   - **Scopes**: Custom defined
     - ✅ **Work Items**: Read & Write
     - ✅ **Project and Team**: Read
5. **Create** 클릭
6. **⚠️ 생성된 PAT를 복사하여 안전한 곳에 저장**

```
예시 PAT (실제 값으로 대체):
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

### 1-4. 설정 값 기록

다음 단계에서 사용할 값을 메모장에 기록합니다:

```
[Azure DevOps 설정]
- 조직 URL: https://dev.azure.com/{YOUR_ORG}
- 프로젝트 이름: Email2ADO-Demo
- PAT: (위에서 복사한 값)
```

---

## Step 2: Teams Workflow 설정

> 📌 **배경**: Microsoft는 2025년 12월부로 Incoming Webhook을 지원 중단했습니다.  
> Power Automate Workflow를 사용하여 Teams 알림을 구현합니다.

### 2-1. Teams 채널 준비

1. **Microsoft Teams** 앱 열기
2. 알림을 받을 팀 선택 (없으면 새 팀 생성)
3. 알림용 채널 생성:
   - 팀 이름 옆 **⋯** > **채널 추가**
   - **채널 이름**: `Email2ADO-Notifications`
   - **채널 설명**: 이메일 자동화 알림 채널
   - **만들기** 클릭

### 2-2. Workflow 생성

1. 생성한 채널로 이동
2. 채널 이름 옆 **⋯** (더보기) 클릭
3. **Workflows** 선택
4. **"Post to a channel when a webhook request is received"** 템플릿 검색 후 선택
5. Workflow 이름 입력: `Email2ADO-Alert`
6. **다음** 클릭
7. 게시할 채널 확인 후 **워크플로 추가** 클릭

### 2-3. Workflow URL 복사

1. Workflow 생성 완료 화면에서 **URL 복사** 클릭
2. URL 형식 확인:
   ```
   https://prod-xx.westus.logic.azure.com:443/workflows/xxxxxxxx/triggers/manual/paths/invoke?api-version=2016-06-01&sp=...
   ```

### 2-4. 설정 값 기록

```
[Teams Workflow 설정]
- Workflow URL: (위에서 복사한 URL)
```

---

## Step 3: Azure 리소스 배포 (IaC)

### 3.1 Azure 로그인

```powershell
# Azure 로그인
az login

# 계정 확인
az account show --query "{name:name, id:id, user:user.name}" -o table

# 구독 목록 확인
az account list --query "[].{name:name, id:id, isDefault:isDefault}" -o table

# 필요시 구독 변경
az account set --subscription "YOUR_SUBSCRIPTION_NAME_OR_ID"
```

### 3.2 리소스 그룹 생성

```powershell
# 변수 설정
$resourceGroup = "rg-email2ado-handson"
$location = "koreacentral"

# 리소스 그룹 생성
az group create `
  --name $resourceGroup `
  --location $location `
  --tags Project=Email2ADO Environment=handson Owner=$env:USERNAME

# 생성 확인
az group show --name $resourceGroup --query "{name:name, location:location}" -o table
```

**예상 결과**:
```
Name                   Location
---------------------  ------------
rg-email2ado-handson   koreacentral
```

### 3.3 Azure OpenAI 리소스 확인/생성

> ⚠️ Azure OpenAI는 별도 승인이 필요한 서비스입니다.  
> 이미 승인된 리소스가 있다면 해당 리소스 이름을 사용하세요.

```powershell
# 기존 Azure OpenAI 리소스 확인
az cognitiveservices account list `
  --query "[?kind=='OpenAI'].{name:name, resourceGroup:resourceGroup, location:location}" `
  -o table
```

**기존 리소스가 있는 경우**: 해당 리소스 이름과 배포 이름을 기록

**기존 리소스가 없는 경우**: Azure Portal에서 Azure OpenAI 서비스 신청 필요

```
[Azure OpenAI 설정]
- 리소스 이름: YOUR_OPENAI_RESOURCE_NAME
- 배포 이름: gpt-4o (또는 gpt-35-turbo)
```

### 3.4 Bicep 파라미터 파일 수정

프로젝트 디렉토리의 `infra/parameters/` 폴더에 새 파라미터 파일을 생성합니다.

```powershell
# 파라미터 파일 생성
cd C:\Hands-On\Email2ADO\infra\parameters

# 새 파일 생성 (VS Code 또는 메모장)
code handson.bicepparam
```

**handson.bicepparam** 파일 내용:

```bicep
using '../main.bicep'

// === 리소스 이름 설정 ===
// 3-10자 영숫자, 소문자로 시작
param namePrefix = 'email2ado'

// 환경 (dev, prod)
param environment = 'handson'

// === Azure DevOps 설정 ===
// Step 1에서 기록한 값 입력
param adoOrganization = 'YOUR_ADO_ORG'        // 예: my-organization
param adoProject = 'Email2ADO-Demo'           // 프로젝트 이름

// === Azure OpenAI 설정 ===
// Step 3.3에서 확인한 값 입력
param openAIResourceName = 'YOUR_OPENAI_RESOURCE'   // Azure OpenAI 리소스 이름
param openAIResourceGroup = 'YOUR_OPENAI_RG'        // Azure OpenAI 리소스 그룹
param openAIDeploymentName = 'gpt-4o'               // 모델 배포 이름
```

### 3.5 Bicep 배포 실행

```powershell
cd C:\Hands-On\Email2ADO\infra

# 배포 미리보기 (실제 배포 전 확인)
az deployment group what-if `
  --resource-group $resourceGroup `
  --template-file main.bicep `
  --parameters parameters/handson.bicepparam

# 결과 확인 후 실제 배포
az deployment group create `
  --resource-group $resourceGroup `
  --template-file main.bicep `
  --parameters parameters/handson.bicepparam `
  --name "email2ado-deploy-$(Get-Date -Format 'yyyyMMdd-HHmm')"
```

> ⏱️ **예상 소요시간**: 약 5-10분

### 3.6 배포 결과 확인

```powershell
# 배포된 리소스 목록 확인
az resource list `
  --resource-group $resourceGroup `
  --query "[].{name:name, type:type}" `
  -o table
```

**예상 결과**:
```
Name                          Type
----------------------------  ------------------------------------------------
stemail2adohandsonxxxxx       Microsoft.Storage/storageAccounts
email2ado-logic-handson       Microsoft.Web/sites
kv-email2ado-handson          Microsoft.KeyVault/vaults
gmail-handson                 Microsoft.Web/connections
teams-handson                 Microsoft.Web/connections
visualstudioteamservices-...  Microsoft.Web/connections
```

### 3.7 배포 값 기록

```powershell
# Logic App 이름 확인
$logicAppName = az resource list -g $resourceGroup --query "[?type=='Microsoft.Web/sites'].name" -o tsv
Write-Host "Logic App: $logicAppName"

# Key Vault 이름 확인
$keyVaultName = az resource list -g $resourceGroup --query "[?type=='Microsoft.KeyVault/vaults'].name" -o tsv
Write-Host "Key Vault: $keyVaultName"

# Storage Account 이름 확인
$storageAccountName = az resource list -g $resourceGroup --query "[?type=='Microsoft.Storage/storageAccounts'].name" -o tsv
Write-Host "Storage Account: $storageAccountName"
```

```
[Azure 리소스 설정]
- Resource Group: rg-email2ado-handson
- Logic App: (위 명령어 결과)
- Key Vault: (위 명령어 결과)
- Storage Account: (위 명령어 결과)
```

---

## Step 4: Key Vault 설정

### 4.1 ADO PAT를 Key Vault에 저장

```powershell
# Step 1에서 복사해둔 PAT 값 사용
$adoPat = "YOUR_ADO_PAT_HERE"  # 실제 PAT로 교체

# Key Vault에 Secret 저장
az keyvault secret set `
  --vault-name $keyVaultName `
  --name "ado-pat" `
  --value $adoPat

# 저장 확인
az keyvault secret show `
  --vault-name $keyVaultName `
  --name "ado-pat" `
  --query "{name:name, enabled:attributes.enabled}" -o table
```

**예상 결과**:
```
Name     Enabled
-------  ---------
ado-pat  True
```

### 4.2 Logic App MSI 권한 확인

```powershell
# Logic App의 Managed Identity Principal ID 확인
$principalId = az functionapp identity show `
  --name $logicAppName `
  --resource-group $resourceGroup `
  --query "principalId" -o tsv

Write-Host "Logic App MSI Principal ID: $principalId"

# Key Vault RBAC 역할 확인
az role assignment list `
  --assignee $principalId `
  --scope "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$resourceGroup/providers/Microsoft.KeyVault/vaults/$keyVaultName" `
  --query "[].roleDefinitionName" -o tsv
```

**예상 결과**: `Key Vault Secrets User`

---

## Step 5: API Connection 인증

> 📌 이 단계는 **Azure Portal**에서 수행합니다.

### 5.1 Gmail Connection 인증

1. **Azure Portal** (https://portal.azure.com) 접속
2. 상단 검색창에 `API connections` 입력 후 선택
3. `gmail-handson` (또는 유사한 이름) 클릭
4. 좌측 메뉴 **Edit API connection** 클릭
5. **Authorize** 버튼 클릭
6. Google 계정 로그인 팝업에서:
   - 이메일을 모니터링할 Gmail 계정 선택
   - 권한 허용
7. **Save** 클릭

### 5.2 Teams Connection 인증

1. API connections 목록에서 `teams-handson` 클릭
2. **Edit API connection** 클릭
3. **Authorize** 버튼 클릭
4. Microsoft 365 계정으로 로그인
5. **Save** 클릭

### 5.3 Azure DevOps Connection 인증

1. API connections 목록에서 `visualstudioteamservices-handson` 클릭
2. **Edit API connection** 클릭
3. **Authorize** 버튼 클릭
4. Azure DevOps 계정으로 로그인
5. **Save** 클릭

### 5.4 연결 상태 확인

```powershell
# 모든 API Connection 상태 확인
az resource list `
  --resource-group $resourceGroup `
  --resource-type "Microsoft.Web/connections" `
  --query "[].{name:name}" -o table
```

Azure Portal에서 각 Connection의 상태가 **Connected**인지 확인합니다.

---

## Step 6: Logic App 워크플로우 배포

### 6.1 App Settings 구성

```powershell
# Step 2에서 복사한 Teams Workflow URL 설정
$teamsWorkflowUrl = "YOUR_TEAMS_WORKFLOW_URL"  # 실제 URL로 교체

# Azure OpenAI 엔드포인트 설정
$openAIEndpoint = "https://YOUR_OPENAI_RESOURCE.cognitiveservices.azure.com/"  # 실제 값으로 교체

# App Settings 업데이트
az functionapp config appsettings set `
  --name $logicAppName `
  --resource-group $resourceGroup `
  --settings `
    "KEY_VAULT_NAME=$keyVaultName" `
    "TEAMS_WORKFLOW_URL=$teamsWorkflowUrl" `
    "AZURE_OPENAI_ENDPOINT=$openAIEndpoint" `
    "AZURE_OPENAI_DEPLOYMENT_NAME=gpt-4o" `
    "ADO_ORGANIZATION=YOUR_ADO_ORG" `
    "ADO_PROJECT=Email2ADO-Demo"

# 설정 확인
az functionapp config appsettings list `
  --name $logicAppName `
  --resource-group $resourceGroup `
  --query "[?name=='KEY_VAULT_NAME' || name=='TEAMS_WORKFLOW_URL' || name=='AZURE_OPENAI_ENDPOINT'].{name:name, value:value}" `
  -o table
```

### 6.2 워크플로우 ZIP 배포

```powershell
cd C:\Hands-On\Email2ADO\src\Email2ADO-Workflow

# 기존 ZIP 파일 삭제 (있는 경우)
Remove-Item -Path ".\deploy.zip" -Force -ErrorAction SilentlyContinue

# ZIP 파일 생성
Compress-Archive -Path "./*" -DestinationPath "./deploy.zip" -Force

# ZIP 파일 확인
Get-Item "./deploy.zip" | Select-Object Name, Length

# 워크플로우 배포
az functionapp deployment source config-zip `
  --name $logicAppName `
  --resource-group $resourceGroup `
  --src "./deploy.zip"
```

> ⏱️ **예상 소요시간**: 약 2-3분

### 6.3 워크플로우 상태 확인

```powershell
# 잠시 대기 (배포 반영 시간)
Start-Sleep -Seconds 30

# 워크플로우 목록 및 상태 확인
$subscriptionId = az account show --query id -o tsv

az rest --method GET `
  --uri "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.Web/sites/$logicAppName/workflows?api-version=2023-01-01" `
  | ConvertFrom-Json | Select-Object -ExpandProperty value | ForEach-Object { 
    Write-Host "$($_.name): $($_.properties.health.state)" 
  }
```

**예상 결과**:
```
Email2ADO-HTTP: Healthy
Email2ADO-Gmail: Unhealthy (V1 커넥터 제한 - 정상)
```

> ⚠️ `Email2ADO-Gmail`이 Unhealthy인 것은 **정상**입니다.  
> V1 Gmail 커넥터의 제한으로 인해 Google Apps Script를 사용합니다.

### 6.4 HTTP Trigger URL 조회

```powershell
# HTTP Trigger의 Callback URL 조회
$callbackUrl = az rest --method POST `
  --uri "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.Web/sites/$logicAppName/hostruntime/runtime/webhooks/workflow/api/management/workflows/Email2ADO-HTTP/triggers/HTTP_Trigger/listCallbackUrl?api-version=2023-01-01" `
  | ConvertFrom-Json | Select-Object -ExpandProperty value

Write-Host "HTTP Trigger URL:"
Write-Host $callbackUrl
```

**⚠️ 이 URL을 안전한 곳에 복사해 두세요!** (Step 8에서 사용)

```
[Logic App 설정]
- HTTP Trigger URL: (위 명령어 결과)
```

---

## Step 7: Gmail 환경 구성

### 7.1 Gmail 레이블 생성

1. **Gmail** (https://gmail.com) 접속
2. 좌측 메뉴 최하단 **더보기** 클릭
3. **새 라벨 만들기** 클릭
4. 라벨 이름: `Email2ADO`
5. **만들기** 클릭
6. 다시 **새 라벨 만들기** 클릭
7. 라벨 이름: `Email2ADO/Processed`
   - ✅ **다음 라벨 아래에 중첩**: Email2ADO
8. **만들기** 클릭

### 7.2 Gmail 필터 생성

1. Gmail 우측 상단 **⚙️ 설정** 클릭
2. **모든 설정 보기** 클릭
3. **필터 및 차단된 주소** 탭 선택
4. **새 필터 만들기** 클릭
5. 필터 조건 입력:
   - **포함하는 단어**: `Azure OR MVP OR MCT`
   - (OR는 반드시 **대문자**)
6. **필터 만들기** 클릭
7. 동작 설정:
   - ✅ **라벨 적용**: `Email2ADO`
   - ✅ (선택) **일치하는 대화에도 필터 적용**
8. **필터 만들기** 클릭

### 7.3 필터 확인

설정된 필터 확인:
```
조건: Azure OR MVP OR MCT
동작: Email2ADO 라벨 적용
```

---

## Step 8: Google Apps Script 설정

### 8.1 Apps Script 프로젝트 생성

1. **Google Apps Script** (https://script.google.com) 접속
2. **+ 새 프로젝트** 클릭
3. 프로젝트 이름 변경: `Email2ADO-Trigger`

### 8.2 스크립트 코드 붙여넣기

1. 기본 `Code.gs` 파일의 모든 내용 삭제
2. 프로젝트의 `scripts/gmail-trigger.gs` 파일 내용 전체 복사
3. Apps Script 에디터에 붙여넣기
4. **Ctrl + S** 저장

### 8.3 Webhook URL 설정 (중요!)

> ⚠️ **보안**: URL은 코드에 하드코딩하지 않고 Script Properties에 저장합니다.

1. Apps Script 좌측 메뉴 **⚙️ 프로젝트 설정** 클릭
2. 아래로 스크롤하여 **스크립트 속성** 섹션 찾기
3. **스크립트 속성 추가** 클릭
4. 입력:
   - **속성**: `WEBHOOK_URL`
   - **값**: Step 6.4에서 복사한 HTTP Trigger URL 전체
5. **저장** 클릭

### 8.4 URL 설정 확인

1. Apps Script 에디터로 돌아가기
2. 함수 선택 드롭다운에서 `checkWebhookUrl` 선택
3. **▶ 실행** 클릭
4. 첫 실행 시 권한 요청:
   - **권한 검토** 클릭
   - Google 계정 선택
   - **고급** 클릭
   - **Email2ADO-Trigger(으)로 이동(안전하지 않음)** 클릭
   - **허용** 클릭
5. **View > 로그** 에서 결과 확인:
   ```
   ✅ Webhook URL 설정됨: https://email2ado-logic-handson...[MASKED]
   ```

### 8.5 트리거 설정

1. Apps Script 좌측 메뉴 **⏰ 트리거** 클릭
2. 우측 하단 **+ 트리거 추가** 클릭
3. 트리거 설정:
   - **실행할 함수 선택**: `processNewEmails`
   - **실행할 배포 선택**: `Head`
   - **이벤트 소스 선택**: `시간 기반`
   - **시간 기반 트리거 유형 선택**: `분 단위 타이머`
   - **분 간격 선택**: `5분마다`
4. **저장** 클릭

### 8.6 수동 테스트

1. Apps Script 에디터에서 함수 선택: `testWebhook`
2. **▶ 실행** 클릭
3. **View > 로그** 에서 결과 확인:
   ```
   Status: 202
   Response: {"workflowRunId":"..."}
   ```

**Status: 202**가 나오면 성공입니다!

---

## Step 9: E2E 테스트

### 9.1 테스트 이메일 전송

1. 다른 이메일 계정에서 Gmail 계정으로 테스트 이메일 전송
2. 이메일 내용:
   - **제목**: `[MVP] 테스트 이메일`
   - **본문**: `Azure MVP 프로그램 관련 테스트 메시지입니다.`

### 9.2 Gmail 필터 동작 확인

1. Gmail에서 수신된 이메일 확인
2. `Email2ADO` 라벨이 자동으로 적용되었는지 확인

### 9.3 Apps Script 실행 확인

1. Apps Script > **⏰ 트리거** 메뉴
2. `processNewEmails` 트리거의 **마지막 실행 시간** 확인
3. 또는 수동으로 `processNewEmails` 함수 실행

### 9.4 Azure DevOps Work Item 확인

1. **Azure DevOps** (https://dev.azure.com) 접속
2. `Email2ADO-Demo` 프로젝트 선택
3. **Boards > Work Items** 클릭
4. 새로 생성된 Issue 확인
5. Work Item 내용 확인:
   - Title: 이메일 제목 기반
   - Description: AI 분석 결과
   - Tags: `Email2ADO`, `Auto-Generated`

### 9.5 Teams 알림 확인

1. **Microsoft Teams** 열기
2. `Email2ADO-Notifications` 채널 확인
3. 새로운 알림 메시지 확인

### 9.6 Table Storage 중복 방지 확인

```powershell
# Table Storage 데이터 조회
az storage entity query `
  --table-name ProcessedEmails `
  --account-name $storageAccountName `
  --auth-mode key `
  --query "items[*].{RowKey:RowKey,Subject:Subject,Status:Status}" `
  -o table
```

**동일한 이메일 재처리 테스트**:
1. Gmail에서 처리된 이메일을 다시 `Email2ADO` 레이블로 이동
2. Apps Script 수동 실행
3. 로그에서 "중복 메일" 메시지 확인
4. ADO에 새 Work Item이 생성되지 않음 확인

---

## 문제 해결

### 일반적인 문제

| 증상 | 원인 | 해결책 |
|------|------|--------|
| Apps Script 실행 오류 | WEBHOOK_URL 미설정 | Script Properties 확인 |
| HTTP 401 Unauthorized | API Connection 인증 만료 | Portal에서 재인증 |
| Work Item 생성 안됨 | PAT 만료 또는 권한 부족 | Key Vault에서 PAT 재설정 |
| Teams 알림 안옴 | Workflow URL 오류 | App Settings 확인 |

### 상세 로그 확인

```powershell
# Logic App 실행 기록 조회
az rest --method GET `
  --uri "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.Web/sites/$logicAppName/hostruntime/runtime/webhooks/workflow/api/management/workflows/Email2ADO-HTTP/runs?api-version=2023-01-01" `
  | ConvertFrom-Json | Select-Object -ExpandProperty value | Select-Object -First 5 | ForEach-Object { 
    Write-Host "Run: $($_.name) - Status: $($_.properties.status)" 
  }
```

### 추가 문서

- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - 상세 문제 해결
- [ARCHITECTURE.md](ARCHITECTURE.md) - 아키텍처 상세

---

## 다음 단계

### 운영 환경 고려사항

| 항목 | 권장 사항 |
|------|----------|
| 보안 | Easy Auth 활성화, SAS 서명 정기 갱신 |
| 모니터링 | Application Insights 연동 |
| 백업 | Key Vault 백업 정책 설정 |
| 비용 | Logic App 실행 횟수 모니터링 |

### 확장 옵션

- **다중 Gmail 계정**: 여러 Apps Script 프로젝트 구성
- **고급 필터링**: Apps Script에 키워드 필터 추가
- **커스텀 AI 분석**: Azure OpenAI 프롬프트 커스터마이징

---

## 📚 참고 자료

- [Azure Logic Apps 공식 문서](https://learn.microsoft.com/azure/logic-apps/)
- [Azure Key Vault 공식 문서](https://learn.microsoft.com/azure/key-vault/)
- [Google Apps Script 가이드](https://developers.google.com/apps-script)
- [Azure DevOps REST API](https://learn.microsoft.com/rest/api/azure/devops/)

---

**작성**: 2026-01-31 | **최종 수정**: 2026-02-07 | **버전**: v1.1.0
