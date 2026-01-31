# 📘 Azure SecOps 자동화 구축 핸즈온 가이드

> **APIM 에러 자동 모니터링 & Azure DevOps Work Item 자동 생성 시스템**  
> 초보 Azure 클라우드 엔지니어를 위한 Step-by-Step 구축 절차서

**버전**: v1.0.0  
**작성일**: 2026-01-31  
**예상 소요시간**: 약 1.5~2시간  
**GitHub**: https://github.com/zer0big/azure-secops-automation-demo

---

## 📋 목차

1. [개요](#1-개요)
2. [사전 조건](#2-사전-조건)
3. [Step 1: Azure DevOps 설정](#step-1-azure-devops-설정)
4. [Step 2: Log Analytics Workspace 설정](#step-2-log-analytics-workspace-설정)
5. [Step 3: Azure API Management 설정](#step-3-azure-api-management-설정)
6. [Step 4: Teams 채널 설정](#step-4-teams-채널-설정)
7. [Step 5: 소스 코드 다운로드 및 파라미터 설정](#step-5-소스-코드-다운로드-및-파라미터-설정)
8. [Step 6: Logic App 배포 (ARM 템플릿)](#step-6-logic-app-배포-arm-템플릿)
9. [Step 7: API Connection 인증](#step-7-api-connection-인증)
10. [Step 8: Managed Identity 권한 설정](#step-8-managed-identity-권한-설정)
11. [Step 9: E2E 테스트](#step-9-e2e-테스트)
12. [문제 해결](#문제-해결)
13. [다음 단계](#다음-단계)

---

## 1. 개요

### 1.1 시스템 아키텍처

```
┌─────────────────────────────────────────────────────────────────┐
│                        Azure Logic App                          │
│                 (logicapp-apim-aoai-monitoring)                 │
│                                                                 │
│  ┌──────────────┐                                              │
│  │  Recurrence  │  매일 오전 7시 (KST)                         │
│  │   Trigger    │                                              │
│  └──────┬───────┘                                              │
│         │                                                       │
│         ▼                                                       │
│  ┌──────────────────────────┐                                  │
│  │  Query_APIM_Logs (HTTP)  │                                  │
│  │  • Log Analytics API     │◄──── Managed Identity 인증       │
│  │  • 24시간 에러 로그 조회   │                                  │
│  └──────────┬───────────────┘                                  │
│             │                                                   │
│             ▼                                                   │
│  ┌─────────────────────┐                                       │
│  │  조건 분기           │  에러가 있으면...                     │
│  └──────┬──────────────┘                                       │
│         │                                                       │
│    ┌────┴────┬──────────┬───────────┐                         │
│    ▼         ▼          ▼           ▼                         │
│ ┌──────┐ ┌──────┐ ┌──────────┐ ┌──────────┐                  │
│ │Teams │ │Email │ │ DevOps   │ │ DevOps   │                  │
│ │알림  │ │알림  │ │ HTTP     │ │ Connector│                  │
│ │      │ │      │ │ (PAT)    │ │ (Legacy) │                  │
│ └──────┘ └──────┘ └──────────┘ └──────────┘                  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 1.2 구성 요소

| 구성 요소 | 역할 | 인증 방식 |
|----------|------|----------|
| Azure Logic App | 워크플로우 오케스트레이션 | - |
| Log Analytics | APIM 로그 저장 및 쿼리 | Managed Identity |
| Azure APIM | API 게이트웨이 (모니터링 대상) | - |
| Azure DevOps | Work Item 자동 생성 | PAT (Basic Auth) |
| Microsoft Teams | 알림 전송 | API Connection (OAuth) |
| Office 365 | 이메일 알림 | API Connection (OAuth) |

### 1.3 주요 기능

| 기능 | 설명 |
|------|------|
| 🔍 **자동 에러 감지** | 24시간 APIM 로그 모니터링 및 에러 자동 수집 |
| 🔔 **멀티채널 알림** | Teams / 이메일 / DevOps Work Item 자동 생성 |
| 🔐 **보안** | Managed Identity (Log Analytics) + PAT (DevOps) |
| ⏰ **자동 스케줄** | 매일 오전 7시 KST 자동 실행 |
| 🚀 **배포 간편** | ARM 템플릿 기반 (1회 배포로 완성) |

---

## 2. 사전 조건

### 2.1 필수 계정

| 계정 | 용도 | 확인 방법 |
|------|------|----------|
| ✅ Azure 구독 | Azure 리소스 배포 | [portal.azure.com](https://portal.azure.com) |
| ✅ Azure DevOps 조직 | Work Item 관리 | [dev.azure.com](https://dev.azure.com) |
| ✅ Microsoft 365 | Teams/Email 알림 | Teams 앱 설치 확인 |
| ✅ GitHub 계정 (선택) | 소스 코드 클론 | [github.com](https://github.com) |

### 2.2 필수 도구 설치

#### 2.2.1 Windows 환경

```powershell
# 1. Azure CLI 설치
winget install Microsoft.AzureCLI

# 설치 확인 (2.50 이상)
az --version

# 2. Git 설치
winget install Git.Git

# 설치 확인
git --version

# 3. Visual Studio Code 설치 (선택)
winget install Microsoft.VisualStudioCode

# 4. jq 설치 (JSON 처리용, 선택)
winget install jqlang.jq
```

### 2.3 필요 권한

| 범위 | 권한 | 확인 방법 |
|------|------|----------|
| Azure 구독 | Contributor 이상 | `az role assignment list --assignee $(az account show --query user.name -o tsv)` |
| Resource Group | Owner 또는 User Access Administrator | RBAC 역할 할당 필요 |
| Azure DevOps | Project Administrator | ADO > Project Settings > Permissions |
| Microsoft 365 | Teams 채널 접근 권한 | Teams 앱에서 확인 |

### 2.4 Azure 로그인 확인

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

---

## Step 1: Azure DevOps 설정

### 1.1 Azure DevOps 조직/프로젝트 생성

> 📌 이미 조직/프로젝트가 있다면 1.3으로 건너뛰세요.

1. **[dev.azure.com](https://dev.azure.com)** 접속
2. **Start free** 클릭
3. Microsoft 계정으로 로그인
4. 조직 이름 입력 (예: `my-organization`)
5. **+ New project** 클릭
6. 프로젝트 정보 입력:
   - **Project name**: `SecOps-Demo`
   - **Visibility**: Private
   - **Work item process**: Agile
7. **Create** 클릭

### 1.2 Personal Access Token (PAT) 생성

> ⚠️ **중요**: PAT는 한 번만 표시됩니다. 반드시 안전한 곳에 저장하세요!

1. Azure DevOps 우측 상단 **User settings** (사람 아이콘) 클릭
2. **Personal access tokens** 선택
3. **+ New Token** 클릭
4. 토큰 정보 입력:
   - **Name**: `SecOps-PAT`
   - **Organization**: 본인 조직 선택
   - **Expiration**: Custom defined → **365 days**
   - **Scopes**: Custom defined
     - ✅ **Work Items**: Read & Write
     - ✅ **Project and Team**: Read
5. **Create** 클릭
6. **⚠️ 생성된 PAT를 복사하여 안전한 곳에 저장**

### 1.3 PAT Base64 인코딩

> 📌 ARM 템플릿에서 사용하기 위해 PAT를 Base64로 인코딩해야 합니다.

```powershell
# PAT 값 설정 (실제 PAT로 교체)
$pat = "YOUR_PAT_HERE"

# Base64 인코딩
$base64Pat = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$pat"))

# 결과 출력 (이 값을 parameters.json에 사용)
Write-Host "Base64 PAT: $base64Pat"
```

### 1.4 설정 값 기록

```
[Azure DevOps 설정]
- 조직 이름: YOUR_ORG (예: my-organization)
- 프로젝트 이름: SecOps-Demo
- PAT (원본): xxxxxxxxxx
- PAT (Base64): xxxxxxxxxx (위 명령어 결과)
- 담당자 이메일: your-email@domain.com
```

---

## Step 2: Log Analytics Workspace 설정

### 2.1 Log Analytics Workspace 생성

```powershell
# 변수 설정
$resourceGroup = "rg-secops-demo"
$location = "koreacentral"
$lawName = "law-secops-demo"

# 리소스 그룹 생성
az group create `
  --name $resourceGroup `
  --location $location `
  --tags Project=SecOps-Demo Environment=handson

# Log Analytics Workspace 생성
az monitor log-analytics workspace create `
  --resource-group $resourceGroup `
  --workspace-name $lawName `
  --location $location `
  --retention-time 30

# 생성 확인
az monitor log-analytics workspace show `
  --resource-group $resourceGroup `
  --workspace-name $lawName `
  --query "{name:name, customerId:customerId}" -o table
```

### 2.2 Workspace ID 확인

```powershell
# Workspace ID (GUID) 조회 - parameters.json에 사용
$workspaceId = az monitor log-analytics workspace show `
  --resource-group $resourceGroup `
  --workspace-name $lawName `
  --query "customerId" -o tsv

Write-Host "Log Analytics Workspace ID: $workspaceId"
```

### 2.3 설정 값 기록

```
[Log Analytics 설정]
- Workspace 이름: law-secops-demo
- Workspace ID (GUID): xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

---

## Step 3: Azure API Management 설정

> 📌 이미 APIM이 있다면 3.2로 건너뛰세요.  
> ⚠️ APIM 생성에는 30-45분 소요됩니다 (Consumption 티어는 더 빠름).

### 3.1 APIM 생성 (옵션 A: Consumption 티어 - 빠른 배포)

```powershell
# APIM 생성 (Consumption 티어 - 약 5분)
$apimName = "apim-secops-demo-$(Get-Random -Maximum 9999)"

az apim create `
  --name $apimName `
  --resource-group $resourceGroup `
  --location $location `
  --publisher-name "Your Company" `
  --publisher-email "admin@yourcompany.com" `
  --sku-name Consumption

Write-Host "APIM Name: $apimName"
```

### 3.2 APIM 진단 설정 (Log Analytics 연결)

```powershell
# APIM 리소스 ID 조회
$apimId = az apim show `
  --name $apimName `
  --resource-group $resourceGroup `
  --query "id" -o tsv

# Log Analytics Workspace 리소스 ID 조회
$lawId = az monitor log-analytics workspace show `
  --resource-group $resourceGroup `
  --workspace-name $lawName `
  --query "id" -o tsv

# 진단 설정 생성
az monitor diagnostic-settings create `
  --name "apim-to-law" `
  --resource $apimId `
  --workspace $lawId `
  --logs '[{"categoryGroup": "allLogs", "enabled": true}]' `
  --metrics '[{"category": "AllMetrics", "enabled": true}]'

# 확인
az monitor diagnostic-settings show `
  --name "apim-to-law" `
  --resource $apimId `
  --query "{name:name, workspaceId:workspaceId}" -o table
```

### 3.3 테스트 API 생성 (에러 로그 생성용)

```powershell
# Echo API 추가 (테스트용)
az apim api create `
  --resource-group $resourceGroup `
  --service-name $apimName `
  --api-id "echo-api" `
  --display-name "Echo API" `
  --path "echo" `
  --protocols https `
  --service-url "https://httpbin.org"

# GET 작업 추가
az apim api operation create `
  --resource-group $resourceGroup `
  --service-name $apimName `
  --api-id "echo-api" `
  --operation-id "get-echo" `
  --display-name "Get Echo" `
  --method GET `
  --url-template "/get"
```

### 3.4 설정 값 기록

```
[APIM 설정]
- APIM 이름: apim-secops-demo-xxxx
- 리소스 그룹: rg-secops-demo
- 진단 설정: apim-to-law (Log Analytics 연결 완료)
```

---

## Step 4: Teams 채널 설정

### 4.1 Teams 채널 준비

1. **Microsoft Teams** 앱 열기
2. 알림을 받을 팀 선택 (없으면 새 팀 생성)
3. 알림용 채널 생성:
   - 팀 이름 옆 **⋯** > **채널 추가**
   - **채널 이름**: `SecOps-Alerts`
   - **채널 설명**: APIM 에러 자동 알림 채널
   - **만들기** 클릭

### 4.2 Teams Group ID 및 Channel ID 조회

> 📌 Teams에서 채널 링크를 복사하여 ID를 추출합니다.

1. Teams에서 채널 이름 우클릭
2. **채널에 대한 링크 가져오기** 클릭
3. 링크에서 ID 추출:

```
https://teams.microsoft.com/l/channel/19%3Axxxxxxxx%40thread.tacv2/SecOps-Alerts?groupId=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx&tenantId=...
```

- **groupId**: `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` (GUID)
- **channelId**: `19:xxxxxxxx@thread.tacv2` (URL 디코딩 필요)

### 4.3 Channel ID URL 디코딩

```powershell
# URL 인코딩된 Channel ID 디코딩
$encodedChannelId = "19%3Axxxxxxxx%40thread.tacv2"
$channelId = [System.Web.HttpUtility]::UrlDecode($encodedChannelId)
Write-Host "Channel ID: $channelId"
```

### 4.4 설정 값 기록

```
[Teams 설정]
- Group ID: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
- Channel ID: 19:xxxxxxxx@thread.tacv2
```

---

## Step 5: 소스 코드 다운로드 및 파라미터 설정

### 5.1 프로젝트 소스 코드 다운로드

```powershell
# 작업 디렉토리 생성
mkdir C:\Hands-On\SecOps
cd C:\Hands-On\SecOps

# GitHub에서 클론
git clone https://github.com/zer0big/azure-secops-automation-demo.git .

# 디렉토리 구조 확인
dir
```

**예상 결과**:
```
Mode                 LastWriteTime         Length Name
----                 -------------         ------ ----
d-----         2026-01-31   12:00                docs
d-----         2026-01-31   12:00                scripts
d-----         2026-01-31   12:00                templates
-a----         2026-01-31   12:00                logicapp-deployment.json
-a----         2026-01-31   12:00                parameters.example.json
-a----         2026-01-31   12:00                README.md
```

### 5.2 파라미터 파일 생성

```powershell
# 예제 파일 복사
Copy-Item parameters.example.json parameters.json

# 파일 열기
code parameters.json
```

### 5.3 parameters.json 수정

아래 내용을 앞서 기록한 값으로 수정합니다:

```json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "logicAppName": {
      "value": "logicapp-secops-monitoring"
    },
    "location": {
      "value": "koreacentral"
    },
    "lawWorkspaceId": {
      "value": "YOUR_WORKSPACE_ID_GUID"
    },
    "devOpsOrganization": {
      "value": "YOUR_ADO_ORG"
    },
    "devOpsProject": {
      "value": "SecOps-Demo"
    },
    "devOpsPat": {
      "value": "YOUR_BASE64_ENCODED_PAT"
    },
    "devOpsAssignee": {
      "value": "your-email@domain.com"
    },
    "emailRecipient": {
      "value": "your-email@domain.com"
    },
    "teamsGroupId": {
      "value": "YOUR_TEAMS_GROUP_ID"
    },
    "teamsChannelId": {
      "value": "YOUR_TEAMS_CHANNEL_ID"
    },
    "scheduleTimeZone": {
      "value": "Korea Standard Time"
    },
    "scheduleHour": {
      "value": "7"
    }
  }
}
```

### 5.4 필수 파라미터 체크리스트

| 파라미터 | 설명 | 값 확인 |
|----------|------|--------|
| `logicAppName` | Logic App 이름 | ✅ |
| `lawWorkspaceId` | Log Analytics GUID | Step 2.2에서 확인 |
| `devOpsOrganization` | DevOps 조직명 | Step 1에서 확인 |
| `devOpsProject` | DevOps 프로젝트명 | Step 1에서 확인 |
| `devOpsPat` | Base64 인코딩된 PAT | Step 1.3에서 생성 |
| `devOpsAssignee` | Work Item 담당자 이메일 | 본인 이메일 |
| `emailRecipient` | 알림 받을 이메일 | 본인 이메일 |
| `teamsGroupId` | Teams 그룹 GUID | Step 4에서 확인 |
| `teamsChannelId` | Teams 채널 ID | Step 4에서 확인 |

---

## Step 6: Logic App 배포 (ARM 템플릿)

### 6.1 배포 미리보기 (What-If)

```powershell
cd C:\Hands-On\SecOps

# 배포 미리보기
az deployment group what-if `
  --resource-group $resourceGroup `
  --template-file logicapp-deployment.json `
  --parameters @parameters.json
```

### 6.2 배포 실행

```powershell
# 배포 실행
az deployment group create `
  --resource-group $resourceGroup `
  --template-file logicapp-deployment.json `
  --parameters @parameters.json `
  --name "SecOps-Deploy-$(Get-Date -Format 'yyyyMMddHHmmss')"
```

> ⏱️ **예상 소요시간**: 약 2-3분

### 6.3 배포 결과 확인

```powershell
# 배포 상태 확인
az deployment group show `
  --resource-group $resourceGroup `
  --name (az deployment group list -g $resourceGroup --query "[0].name" -o tsv) `
  --query "{name:name, state:properties.provisioningState}" -o table

# 생성된 리소스 목록
az resource list `
  --resource-group $resourceGroup `
  --query "[].{name:name, type:type}" -o table
```

**예상 결과**:
```
Name                           Type
-----------------------------  --------------------------------
logicapp-secops-monitoring     Microsoft.Logic/workflows
office365                      Microsoft.Web/connections
teams                          Microsoft.Web/connections
```

### 6.4 Logic App 상태 확인

```powershell
# Logic App 상태 확인
az resource show `
  --resource-group $resourceGroup `
  --resource-type "Microsoft.Logic/workflows" `
  --name "logicapp-secops-monitoring" `
  --query "{name:name, state:properties.state}" -o table
```

**예상 결과**: `Enabled`

---

## Step 7: API Connection 인증

> 📌 ARM 템플릿으로 배포된 API Connection은 수동 인증이 필요합니다.

### 7.1 Office 365 Connection 인증

1. **Azure Portal** (https://portal.azure.com) 접속
2. 상단 검색창에 `API connections` 입력 후 선택
3. `office365` 클릭
4. 좌측 메뉴 **Edit API connection** 클릭
5. **Authorize** 버튼 클릭
6. Microsoft 365 계정으로 로그인
7. **Save** 클릭

### 7.2 Teams Connection 인증

1. API connections 목록에서 `teams` 클릭
2. **Edit API connection** 클릭
3. **Authorize** 버튼 클릭
4. Microsoft 365 계정으로 로그인
5. **Save** 클릭

### 7.3 연결 상태 확인

Azure Portal에서 각 Connection 클릭 후:
- **Status**가 **Connected**인지 확인

또는 CLI로 확인:
```powershell
az resource list `
  --resource-group $resourceGroup `
  --resource-type "Microsoft.Web/connections" `
  --query "[].{name:name}" -o table
```

---

## Step 8: Managed Identity 권한 설정

### 8.1 Logic App Managed Identity 확인

```powershell
$logicAppName = "logicapp-secops-monitoring"

# Managed Identity Principal ID 조회
$principalId = az resource show `
  --resource-group $resourceGroup `
  --resource-type "Microsoft.Logic/workflows" `
  --name $logicAppName `
  --query "identity.principalId" -o tsv

Write-Host "Logic App Principal ID: $principalId"
```

### 8.2 Log Analytics Reader 역할 할당

```powershell
# Log Analytics Workspace 리소스 ID
$lawId = az monitor log-analytics workspace show `
  --resource-group $resourceGroup `
  --workspace-name $lawName `
  --query "id" -o tsv

# Log Analytics Reader 역할 할당
az role assignment create `
  --assignee $principalId `
  --role "Log Analytics Reader" `
  --scope $lawId

# 역할 할당 확인
az role assignment list `
  --assignee $principalId `
  --scope $lawId `
  --query "[].{role:roleDefinitionName, scope:scope}" -o table
```

**예상 결과**: `Log Analytics Reader`

### 8.3 (선택) Azure DevOps에 Managed Identity 권한 부여

> 📌 현재 템플릿은 PAT를 사용하지만, Managed Identity로 전환하려면:

1. Azure DevOps Portal 접속
2. **Organization Settings** > **Users**
3. **Add users** 클릭
4. Logic App의 Managed Identity 추가 (서비스 주체)
5. 프로젝트에서 **Contributor** 권한 부여

---

## Step 9: E2E 테스트

### 9.1 Logic App 수동 실행

```powershell
$subscriptionId = az account show --query id -o tsv

# Logic App 수동 트리거
az rest `
  --method POST `
  --uri "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.Logic/workflows/$logicAppName/triggers/Recurrence/run?api-version=2016-06-01"
```

### 9.2 실행 결과 확인

```powershell
# 실행 기록 조회
az rest `
  --method GET `
  --uri "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.Logic/workflows/$logicAppName/runs?api-version=2016-06-01" `
  | ConvertFrom-Json | Select-Object -ExpandProperty value | Select-Object -First 1 | ForEach-Object {
    Write-Host "Run ID: $($_.name)"
    Write-Host "Status: $($_.properties.status)"
    Write-Host "Start: $($_.properties.startTime)"
    Write-Host "End: $($_.properties.endTime)"
  }
```

### 9.3 APIM 에러 로그 생성 (테스트용)

> 📌 에러 로그가 없으면 Logic App은 "에러 없음" 상태로 종료됩니다.  
> 테스트를 위해 의도적으로 에러를 발생시킵니다.

```powershell
# APIM 게이트웨이 URL 조회
$apimGatewayUrl = az apim show `
  --resource-group $resourceGroup `
  --name $apimName `
  --query "gatewayUrl" -o tsv

# 존재하지 않는 API 호출 (404 에러 발생)
Invoke-RestMethod -Uri "$apimGatewayUrl/nonexistent-api" -Method GET -ErrorAction SilentlyContinue

# 여러 번 호출하여 로그 생성
1..5 | ForEach-Object {
  try {
    Invoke-RestMethod -Uri "$apimGatewayUrl/test-error-$_" -Method GET -ErrorAction SilentlyContinue
  } catch {
    Write-Host "Error $_ generated"
  }
}
```

### 9.4 Log Analytics에서 로그 확인

> ⚠️ 로그가 Log Analytics에 수집되기까지 5-15분 소요됩니다.

```powershell
# KQL 쿼리로 APIM 에러 로그 확인
$query = "ApiManagementGatewayLogs | where TimeGenerated > ago(1h) | where ResponseCode >= 400 | take 10"

az monitor log-analytics query `
  --workspace $workspaceId `
  --analytics-query $query `
  --query "[].{Time:TimeGenerated, Method:Method, Url:Url, ResponseCode:ResponseCode}" -o table
```

### 9.5 알림 확인

1. **Azure DevOps** > `SecOps-Demo` 프로젝트 > **Boards** > **Work Items**
   - 새로운 Issue가 생성되었는지 확인

2. **Microsoft Teams** > `SecOps-Alerts` 채널
   - 알림 메시지 확인

3. **이메일** 수신함
   - APIM 에러 알림 이메일 확인

### 9.6 Azure Portal에서 실행 상세 확인

1. Azure Portal > **Logic Apps** > `logicapp-secops-monitoring`
2. **Overview** > **Runs history**
3. 최근 실행 클릭
4. 각 액션의 입력/출력 확인

---

## 문제 해결

### 일반적인 문제

| 증상 | 원인 | 해결책 |
|------|------|--------|
| Logic App 실행 실패 | API Connection 미인증 | Step 7 재수행 |
| Log Analytics 쿼리 실패 | Managed Identity 권한 없음 | Step 8.2 재수행 |
| DevOps Work Item 생성 실패 | PAT 만료 또는 권한 부족 | PAT 재생성 후 재배포 |
| Teams 알림 안옴 | Teams Connection 미인증 | Step 7.2 재수행 |
| 에러 로그가 없음 | APIM 진단 설정 미구성 | Step 3.2 확인 |

### Logic App 실행 로그 확인

```powershell
# 실패한 실행 조회
az rest `
  --method GET `
  --uri "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.Logic/workflows/$logicAppName/runs?api-version=2016-06-01&\$filter=status eq 'Failed'" `
  | ConvertFrom-Json | Select-Object -ExpandProperty value | Select-Object -First 3 | ForEach-Object {
    Write-Host "Failed Run: $($_.name) at $($_.properties.startTime)"
  }
```

### API Connection 상태 확인

```powershell
# Connection 상태 확인
az resource list `
  --resource-group $resourceGroup `
  --resource-type "Microsoft.Web/connections" `
  --query "[].{name:name, id:id}" -o table
```

### Managed Identity 역할 확인

```powershell
# 할당된 역할 확인
az role assignment list `
  --assignee $principalId `
  --query "[].{role:roleDefinitionName, scope:scope}" -o table
```

---

## 다음 단계

### 운영 환경 고려사항

| 항목 | 권장 사항 |
|------|----------|
| 스케줄 조정 | 조직 운영 시간에 맞게 조정 |
| 알림 채널 | 중복 알림 방지를 위해 채널 선택적 비활성화 |
| 에러 임계값 | 심각도에 따른 분기 추가 |
| 보안 | PAT 대신 Managed Identity 전환 검토 |

### 확장 옵션

- **다중 APIM 모니터링**: 여러 APIM 인스턴스 통합 모니터링
- **커스텀 KQL 쿼리**: 특정 에러 패턴 필터링
- **알림 템플릿 커스터마이징**: HTML 이메일 템플릿 수정
- **자동 복구 액션**: 특정 에러 시 자동 조치 수행

### 비용 예상 (월간)

| 리소스 | 예상 비용 |
|--------|----------|
| Logic App | ~$5-10 (실행 횟수 기반) |
| Log Analytics | ~$2-5/GB (수집된 로그) |
| APIM (Consumption) | 사용량 기반 |

---

## 📚 참고 자료

- [Azure Logic Apps 공식 문서](https://learn.microsoft.com/azure/logic-apps/)
- [Log Analytics KQL 쿼리](https://learn.microsoft.com/azure/azure-monitor/logs/get-started-queries)
- [Azure APIM 모니터링](https://learn.microsoft.com/azure/api-management/api-management-howto-use-azure-monitor)
- [Azure DevOps REST API](https://learn.microsoft.com/rest/api/azure/devops/)

---

## 📝 문서 정보

| 항목 | 내용 |
|------|------|
| **프로젝트** | azure-secops-automation-demo |
| **GitHub** | https://github.com/zer0big/azure-secops-automation-demo |
| **작성일** | 2026-01-31 |
| **버전** | v1.0.0 |

---

**작성**: 2026-01-31 | **버전**: v1.0.0
