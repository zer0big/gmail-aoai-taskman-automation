# 로컬 테스트 환경 구성 가이드

> **Phase 4** - 로컬 개발 및 테스트 환경 설정 가이드

## 📋 목차

1. [사전 요구사항](#사전-요구사항)
2. [개발 환경 설치](#개발-환경-설치)
3. [프로젝트 설정](#프로젝트-설정)
4. [Azurite 로컬 스토리지](#azurite-로컬-스토리지)
5. [워크플로우 실행](#워크플로우-실행)
6. [디버깅](#디버깅)
7. [트러블슈팅](#트러블슈팅)

---

## 사전 요구사항

### 필수 소프트웨어

| 도구 | 버전 | 용도 |
|------|------|------|
| **Node.js** | 18.x LTS | Azure Functions 런타임 |
| **Azure Functions Core Tools** | 4.x | 로컬 Functions 호스트 |
| **Azurite** | 최신 | 로컬 Storage 에뮬레이터 |
| **Visual Studio Code** | 최신 | IDE |
| **Azure Logic Apps (Standard) 확장** | 최신 | 워크플로우 디자이너 |

### VS Code 확장 프로그램

```plaintext
필수:
- Azure Logic Apps (Standard)
- Azure Functions
- Azurite

권장:
- Azure Account
- REST Client
```

---

## 개발 환경 설치

### 1. Node.js 설치

```powershell
# winget을 사용한 설치
winget install OpenJS.NodeJS.LTS

# 설치 확인
node --version
npm --version
```

### 2. Azure Functions Core Tools 설치

```powershell
# npm을 사용한 전역 설치
npm install -g azure-functions-core-tools@4 --unsafe-perm true

# 또는 winget 사용
winget install Microsoft.Azure.FunctionsCoreTools

# 설치 확인
func --version
```

### 3. Azurite 설치

```powershell
# npm을 사용한 전역 설치
npm install -g azurite

# 설치 확인
azurite --version
```

### 4. VS Code 확장 설치

```powershell
# 명령줄에서 확장 설치
code --install-extension ms-azuretools.vscode-azurelogicapps
code --install-extension ms-azuretools.vscode-azurefunctions
code --install-extension Azurite.azurite
```

---

## 프로젝트 설정

### 1. 로컬 설정 파일 생성

```powershell
# 템플릿 파일 복사
cd src/Email2ADO-Workflow
Copy-Item local.settings.template.json local.settings.json
```

### 2. local.settings.json 수정

```json
{
  "IsEncrypted": false,
  "Values": {
    "AzureWebJobsStorage": "UseDevelopmentStorage=true",
    "FUNCTIONS_WORKER_RUNTIME": "node",
    "FUNCTIONS_EXTENSION_VERSION": "~4",
    "APP_KIND": "workflowApp",
    
    // Azure 구독 정보
    "AZURE_SUBSCRIPTION_ID": "<YOUR_SUBSCRIPTION_ID>",
    "AZURE_RESOURCE_GROUP": "rg-email2ado-dev",
    
    // Table Storage (로컬에서는 Azurite 사용)
    "TABLE_STORAGE_CONNECTION": "UseDevelopmentStorage=true",
    "TABLE_NAME": "ProcessedEmails",
    
    // Teams 정보 (AutoTaskMan 채널)
    "TEAMS_TEAM_ID": "<YOUR_TEAMS_TEAM_ID>",
    "TEAMS_CHANNEL_ID": "<YOUR_TEAMS_CHANNEL_ID>",
    
    // Azure OpenAI (기존 리소스)
    "AZURE_OPENAI_ENDPOINT": "https://zb-taskman.openai.azure.com/",
    "AZURE_OPENAI_DEPLOYMENT_NAME": "gpt-4o"
  }
}
```

> ⚠️ **주의**: `local.settings.json`은 `.gitignore`에 포함되어 있어 Git에 커밋되지 않습니다.

---

## Azurite 로컬 스토리지

### Azurite 시작

#### 방법 1: VS Code 명령 팔레트

1. `Ctrl+Shift+P` → "Azurite: Start" 선택
2. 상태 표시줄에서 Azurite 상태 확인

#### 방법 2: 터미널

```powershell
# 기본 설정으로 시작
azurite --silent --location .azurite --debug .azurite/debug.log

# 특정 포트 지정
azurite --blobPort 10000 --queuePort 10001 --tablePort 10002
```

### 연결 문자열

로컬 개발 시 다음 연결 문자열을 사용합니다:

```plaintext
UseDevelopmentStorage=true
```

또는 전체 연결 문자열:

```plaintext
DefaultEndpointsProtocol=http;AccountName=devstoreaccount1;AccountKey=Eby8vdM02xNOcqFlqUwJPLlmEtlCDXJ1OUzFT50uSRZ6IFsuFq2UVErCz4I6tq/K1SZFPTOtr/KBHBeksoGMGw==;BlobEndpoint=http://127.0.0.1:10000/devstoreaccount1;QueueEndpoint=http://127.0.0.1:10001/devstoreaccount1;TableEndpoint=http://127.0.0.1:10002/devstoreaccount1;
```

### Table Storage 초기화

Azurite 시작 후 테이블을 자동 생성하려면:

```powershell
# Azure Storage Explorer 또는 Azure CLI 사용
az storage table create --name ProcessedEmails --connection-string "UseDevelopmentStorage=true"
```

---

## 워크플로우 실행

### 1. Functions 호스트 시작

```powershell
cd src/Email2ADO-Workflow

# 워크플로우 호스트 시작
func host start
```

예상 출력:

```plaintext
Azure Functions Core Tools
Core Tools Version: 4.x
Functions Runtime Version: 4.x

Functions:
    Email2ADO-Gmail: [GET,POST] http://localhost:7071/api/Email2ADO-Gmail/triggers/manual/invoke
```

### 2. 워크플로우 디자이너 사용

1. VS Code에서 `workflow.json` 파일 열기
2. 우클릭 → "Open Designer"
3. 디자이너에서 워크플로우 시각화 및 편집

### 3. 수동 트리거 테스트

```powershell
# HTTP 트리거로 워크플로우 테스트
Invoke-RestMethod -Uri "http://localhost:7071/api/Email2ADO-Gmail/triggers/manual/invoke" -Method POST
```

---

## 디버깅

### VS Code 디버그 구성

`.vscode/launch.json`:

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Attach to Logic App",
      "type": "node",
      "request": "attach",
      "port": 9229,
      "preLaunchTask": "func: host start"
    }
  ]
}
```

### 디버그 시작

1. `F5` 키 또는 Run → Start Debugging
2. 브레이크포인트 설정 후 워크플로우 트리거
3. Variables 패널에서 변수 값 확인

### 로그 확인

```powershell
# 실시간 로그 스트리밍
func host start --verbose

# Application Insights (로컬)
# local.settings.json에 APPINSIGHTS_INSTRUMENTATIONKEY 추가 시 활성화
```

---

## 트러블슈팅

### 일반적인 오류

#### 1. "AzureWebJobsStorage" 오류

```plaintext
Error: Microsoft.Azure.WebJobs.Host: Unable to load application settings file.
```

**해결책**:
```powershell
# Azurite가 실행 중인지 확인
azurite --version

# local.settings.json 확인
# "AzureWebJobsStorage": "UseDevelopmentStorage=true"
```

#### 2. "APP_KIND must be workflowApp" 오류

**해결책**:
```json
// local.settings.json에 추가
"APP_KIND": "workflowApp"
```

#### 3. 포트 충돌

```plaintext
Error: Address already in use :::7071
```

**해결책**:
```powershell
# 다른 포트 사용
func host start --port 7072

# 또는 기존 프로세스 종료
Get-Process -Name func | Stop-Process
```

#### 4. API Connection 인증 오류

로컬에서 Managed API Connections (Gmail, Teams, ADO)는 직접 테스트하기 어렵습니다.

**권장 방법**:
1. Azure에 배포 후 Portal에서 API Connection 승인
2. Mock 데이터로 로컬 테스트
3. 개별 HTTP 액션만 테스트

### Mock 테스트 예시

`test/mock-email.json`:

```json
{
  "from": "test@example.com",
  "subject": "[버그] 테스트 이메일",
  "body": "이것은 테스트 이메일입니다.\n\n우선순위: 높음\n카테고리: 버그",
  "receivedDateTime": "2026-01-29T10:00:00Z"
}
```

---

## 다음 단계

로컬 테스트 환경 구성이 완료되면:

1. **Phase 5**: Azure 배포 및 E2E 테스트
2. API Connections 인증
3. 실제 이메일로 통합 테스트

---

## 참고 자료

- [Logic Apps Standard 로컬 개발](https://learn.microsoft.com/azure/logic-apps/create-standard-workflows-visual-studio-code)
- [Azure Functions Core Tools](https://learn.microsoft.com/azure/azure-functions/functions-run-local)
- [Azurite 에뮬레이터](https://learn.microsoft.com/azure/storage/common/storage-use-azurite)
- [local.settings.json 참조](https://learn.microsoft.com/azure/logic-apps/edit-app-settings-host-settings)
