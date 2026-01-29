# 📧 Email to Azure DevOps Automation

> **한 줄 요약**: Outlook 메일을 받으면 AI가 분석하고, Azure DevOps Work Item을 자동 생성한 뒤, Teams로 알림을 보내는 시스템

**버전**: v1.0.0 | **최종 업데이트**: 2026-01-24 | **담당자**: 김영대 (azure-mvp@zerobig.kr)

---

## 🎯 이 문서 읽는 순서 (초급자 필독!)

| 순서 | 문서 | 목적 | 소요시간 |
|------|------|------|----------|
| 1️⃣ | **README.md** (현재 문서) | 전체 이해 + 빠른 시작 | 5분 |
| 2️⃣ | [ARCHITECTURE.md](ARCHITECTURE.md) | 상세 구조 이해 | 15분 |
| 3️⃣ | [REBUILD_INSIGHTS.md](REBUILD_INSIGHTS.md) | 재구축 시 필수 체크 | 20분 |
| 📌 | [TROUBLESHOOTING.md](TROUBLESHOOTING.md) | 문제 발생 시 참조 | 필요시 |
| 📌 | [CHANGELOG.md](CHANGELOG.md) | 변경 이력 확인 | 필요시 |

---

## 📋 30초 요약: 이 시스템이 하는 일

```
┌─────────────┐    ┌──────────────┐    ┌─────────────────┐    ┌──────────────┐    ┌────────────┐
│  📧 메일    │───▶│  🔍 중복체크  │───▶│  🤖 AI 분석     │───▶│  📝 Work Item │───▶│  💬 Teams   │
│  수신       │    │  (이미 처리?) │    │  (GPT-4o 요약)  │    │  자동 생성    │    │  알림       │
└─────────────┘    └──────┬───────┘    └─────────────────┘    └──────────────┘    └────────────┘
                          │ 신규 메일만 통과 ↑
                          ▼ 중복이면
                     ✅ 종료 (재처리 방지)
```

**실제 예시**:
1. 고객이 `azure-mvp@zerobig.kr`에게 문의 메일 발송
2. ⏱️ 1분 이내 Logic App이 감지
3. 🔍 이미 처리한 메일인지 확인 (중복 방지)
4. 🤖 GPT-4o가 메일 내용 분석 (요약, 인사이트, 액션 아이템)
5. 📝 Azure DevOps에 Issue 자동 생성 (담당자 자동 할당, 태그 부여)
6. 💬 Teams 채널에 알림 전송

---

## 🏗️ 프로젝트 구조 (가장 중요한 파일 3개)

```
zb-taskman/
│
├── Email2ADO-Workflow/
│   ├── IssueHandler/
│   │   └── ⭐ workflow.json      ← 핵심! 워크플로 로직 (이 파일을 주로 수정)
│   │
│   ├── ⭐ connections.json       ← 핵심! API 연결 설정 (Office365, Teams, ADO, OpenAI)
│   ├── ⭐ local.settings.json    ← 핵심! 환경 변수 (로컬 개발용, Git 제외)
│   └── host.json                 ← Logic App 런타임 설정
│
├── infra/
│   └── main.bicep                ← Azure 리소스 배포 코드 (IaC)
│
├── README.md                     ← 현재 문서 (시작점)
├── ARCHITECTURE.md               ← 상세 아키텍처
├── REBUILD_INSIGHTS.md           ← ⚠️ 재구축 시 필수! 시행착오 모음
├── TROUBLESHOOTING.md            ← 문제 해결 가이드
├── CHANGELOG.md                  ← 변경 이력
└── local.settings.template.json  ← 환경 변수 템플릿
```

---

## 🚀 5분 퀵스타트: 로컬 실행

### Step 1: 사전 준비
```powershell
# 필수 도구 설치 확인
az --version          # Azure CLI 2.50+
func --version        # Azure Functions Core Tools 4.x
dotnet --version      # .NET 8 SDK
```

### Step 2: 환경 설정
```powershell
# 프로젝트 클론
git clone https://dev.azure.com/tdg-zerobig/_git/CM-Worker-Demo
cd cm-worker-mail2ado/Email2ADO-Workflow

# local.settings.json 편집 (템플릿 복사 후 값 채우기)
cp ../local.settings.template.json local.settings.json
# 각 <placeholder> 값을 실제 값으로 교체
```

### Step 3: 로컬 실행
```powershell
# Azurite 시작 (Storage Emulator) - 별도 터미널
npm install -g azurite
azurite --silent

# 워크플로 실행
func start
```

### Step 4: 테스트
- 테스트 메일 발송 → 1분 내 트리거 확인
- Azure DevOps에서 Work Item 생성 확인

---

## ☁️ Azure 배포 (프로덕션)

### 현재 프로덕션 환경
| 항목 | 값 |
|------|-----|
| Resource Group | `rg-email2ado-prod` |
| Logic App | `em0911-workflow` |
| Storage Account | `em0911irgskutuqb2f4` |
| Azure OpenAI | `aoai-email2ado-prod` |
| Region | Korea Central |

### 배포 명령어
```powershell
# 1. 워크플로 배포
cd Email2ADO-Workflow
Compress-Archive -Path * -DestinationPath "$env:TEMP\wf.zip" -Force
az webapp deployment source config-zip `
  --resource-group "rg-email2ado-prod" `
  --name "em0911-workflow" `
  --src "$env:TEMP\wf.zip" --timeout 300

# 2. 재시작
az webapp restart --name "em0911-workflow" --resource-group "rg-email2ado-prod"
```

---

## ⚙️ 필수 환경 변수 (App Settings)

| 변수명 | 설명 | 예시 |
|--------|------|------|
| **Azure 기본** |||
| `WORKFLOWS_SUBSCRIPTION_ID` | Azure 구독 ID | `0ca2d2d9-...` |
| `WORKFLOWS_RESOURCE_GROUP_NAME` | 리소스 그룹 | `rg-email2ado-prod` |
| `WORKFLOWS_LOCATION_NAME` | 리전 | `koreacentral` |
| **API Connections** |||
| `OFFICE365_CONNECTION_RUNTIME_URL` | Office 365 연결 | Azure Portal에서 복사 |
| `TEAMS_CONNECTION_RUNTIME_URL` | Teams 연결 | Azure Portal에서 복사 |
| `ADO_CONNECTION_RUNTIME_URL` | ADO 연결 | Azure Portal에서 복사 |
| **Azure DevOps** |||
| `ADO_ORGANIZATION` | ADO 조직 | `tdg-zerobig` |
| `ADO_PROJECT` | ADO 프로젝트 | `CM-Worker-Demo` |
| `ADO_PAT` | Personal Access Token | ADO에서 생성 |
| **Azure OpenAI** |||
| `AZURE_OPENAI_ENDPOINT` | OpenAI 엔드포인트 | `https://xxx.openai.azure.com/` |
| `AZURE_OPENAI_API_KEY` | API Key | (보안 관리 필요) |
| `AZURE_OPENAI_DEPLOYMENT_NAME` | 모델 배포명 | `gpt-4o-deploy` |
| **Teams** |||
| `TEAMS_TEAM_ID` | Teams 팀 ID | Graph API로 조회 |
| `TEAMS_CHANNEL_ID` | Teams 채널 ID | Graph API로 조회 |
| **Storage** |||
| `STORAGE_ACCOUNT_NAME` | 스토리지 계정 | `em0911irgskutuqb2f4` |

---

## 🔧 자주 수정하는 작업 TOP 3

### 1️⃣ Work Item에 필드 추가하기
**파일**: `Email2ADO-Workflow/IssueHandler/workflow.json`

`Update_ADO_WorkItem_Fields` 액션의 body 배열에 추가:
```json
{
  "op": "add",
  "path": "/fields/Microsoft.VSTS.Common.Priority",
  "value": 2
}
```

### 2️⃣ AI 프롬프트 수정하기
**파일**: `Email2ADO-Workflow/IssueHandler/workflow.json`

`Analyze_Email_With_AI` 액션의 `messages[0].content` (system 메시지) 수정

### 3️⃣ 알림 메시지 변경하기
**파일**: `Email2ADO-Workflow/IssueHandler/workflow.json`

`Send_Teams_Notification` 액션의 `body.body.content` 수정

---

## ⚠️ 재구축 시 반드시 읽어야 할 것

**[REBUILD_INSIGHTS.md](REBUILD_INSIGHTS.md)** 를 반드시 먼저 읽으세요!

핵심 함정들:
| 함정 | 왜 안 되는가 | 해결책 |
|------|-------------|--------|
| VSTS 커넥터로 담당자/태그 설정 | 커넥터가 필드 무시 | HTTP + PAT + JSON Patch |
| MSI로 ADO 직접 인증 | MSI는 ADO 인증 불가 | API Connection V2 (OAuth) |
| V1 API Connection 사용 | Access Policy 지원 안 함 | V2 Connector 필수 |

---

## 📞 문제 발생 시

1. **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** 확인
2. **Azure Portal** → Logic App → Run History → 실패한 액션 클릭 → 오류 메시지 확인
3. **Application Insights** → Logs → 쿼리 실행

```kusto
traces
| where customDimensions.Category contains "Workflow"
| where timestamp > ago(1h)
| order by timestamp desc
```

---

## 📚 참고 자료

| 주제 | 링크 |
|------|------|
| Logic Apps Standard | [Microsoft Learn](https://learn.microsoft.com/azure/logic-apps/single-tenant-overview-compare) |
| Azure DevOps Work Items API | [REST API 문서](https://learn.microsoft.com/rest/api/azure/devops/wit/work-items) |
| Azure OpenAI | [서비스 문서](https://learn.microsoft.com/azure/ai-services/openai/) |
| Teams Graph API | [채널 메시지](https://learn.microsoft.com/graph/api/channel-post-messages) |

---

## 📄 라이선스

Internal Use Only - TDG

---

*이 문서가 이해되지 않으면 [ARCHITECTURE.md](ARCHITECTURE.md)에서 상세 구조를 확인하세요.*
