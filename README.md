# 📧 ZBTaskManager - Gmail 기반 이메일 자동화 시스템

> **한 줄 요약**: Gmail 메일을 받으면 AI가 분석하고, Azure DevOps Work Item을 자동 생성한 뒤, Teams로 알림을 보내는 시스템

**버전**: v2.0.0 | **최종 업데이트**: 2026-01-30 | **담당자**: 김영대 (azure-mvp@zerobig.kr)

---

## 📚 문서 읽는 순서 (초급 SA 필독!)

| 순서 | 문서 | 목적 | 소요시간 |
|------|------|------|----------|
| 1️⃣ | **README.md** (현재 문서) | 전체 이해 + 빠른 시작 | 5분 |
| 2️⃣ | [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | 상세 구조 이해 | 15분 |
| 3️⃣ | [docs/GMAIL-SETUP.md](docs/GMAIL-SETUP.md) | Gmail 설정 가이드 | 10분 |
| 4️⃣ | [docs/LOCAL-TESTING.md](docs/LOCAL-TESTING.md) | 로컬 테스트 환경 | 10분 |
| 📌 | [docs/GMAIL-FIELD-MAPPING.md](docs/GMAIL-FIELD-MAPPING.md) | Gmail 필드 매핑 | 필요시 |
| 📌 | [docs/CHANGELOG.md](docs/CHANGELOG.md) | 변경 이력 | 필요시 |

---

## 🎯 시스템 개요

```
┌─────────────┐    ┌──────────────┐    ┌─────────────────┐    ┌──────────────┐    ┌────────────┐
│  📧 Gmail   │───▶│  🔍 중복체크  │───▶│  🤖 AI 분석     │───▶│  📝 Work Item │───▶│  💬 Teams   │
│  메일 수신  │    │  (이미 처리?) │    │  (GPT-4o 요약)  │    │  자동 생성    │    │  알림       │
└─────────────┘    └──────┬───────┘    └─────────────────┘    └──────────────┘    └────────────┘
                          │ 신규 메일만 통과 ↑
                          ▼ 중복이면
                     ✅ 종료 (재처리 방지)
```

---

## 📁 프로젝트 구조

```
ZBTaskManager/
├── 📁 docs/                    # 📚 문서
│   ├── ARCHITECTURE.md         # 아키텍처 설계
│   ├── DEPLOY.md               # 배포 가이드
│   ├── GMAIL-SETUP.md          # Gmail 설정 가이드
│   ├── TROUBLESHOOTING.md      # 문제 해결
│   └── CHANGELOG.md            # 변경 이력
│
├── 📁 src/                     # 소스 코드
│   └── Email2ADO-Workflow/     # Logic App 워크플로
│       ├── IssueHandler/
│       │   └── workflow.json   # 핵심 워크플로 정의
│       ├── connections.json    # API 연결 설정
│       └── host.json           # 런타임 설정
│
├── 📁 infra/                   # Infrastructure as Code
│   ├── main.bicep              # 메인 배포 파일
│   └── modules/                # Bicep 모듈
│
├── 📁 scripts/                 # 운영 스크립트
│   ├── deploy.ps1              # 배포 스크립트
│   └── setup-connections.ps1   # API Connection 설정
│
├── 📁 tests/                   # 테스트
│   └── e2e-test-guide.md       # E2E 테스트 가이드
│
└── 📁 .github/                 # GitHub/Copilot 설정
    ├── copilot-instructions.md # Copilot 지침
    └── Reference/              # 참조 문서 (기존 버전)
```

---

## 🚀 빠른 시작

### 사전 요구사항

```powershell
# 필수 도구 확인
az --version          # Azure CLI 2.50+
func --version        # Azure Functions Core Tools 4.x
```

### 로컬 실행

```powershell
# 1. 프로젝트 클론
git clone https://dev.azure.com/azure-mvp/ZBTaskManager/_git/ZBTaskManager
cd ZBTaskManager

# 2. 환경 설정
cp src/Email2ADO-Workflow/local.settings.template.json src/Email2ADO-Workflow/local.settings.json
# local.settings.json 편집 (값 채우기)

# 3. 로컬 실행
cd src/Email2ADO-Workflow
func start
```

---

## ☁️ Azure 리소스

| 리소스 | 이름 | 용도 |
|--------|------|------|
| Resource Group | `rg-zb-taskman` | 리소스 그룹 |
| Logic App | `email2ado-logic-prod` | 워크플로 실행 |
| Storage Account | `stemail2adoprodxhum3jlfa` | Table Storage (중복 방지) |
| Azure OpenAI | `zb-taskman` | GPT-4o AI 분석 |
| API Connection (Gmail) | `gmail-prod` | Gmail 트리거 |
| API Connection (Teams) | `teams-prod` | Teams 알림 |
| API Connection (ADO) | `visualstudioteamservices-prod` | Work Item 생성 |

---

## 🔗 관련 링크

- **ADO 프로젝트**: https://dev.azure.com/azure-mvp/ZBTaskManager
- **Work Items**: https://dev.azure.com/azure-mvp/ZBTaskManager/_workitems
- **Git 저장소**: https://dev.azure.com/azure-mvp/ZBTaskManager/_git/ZBTaskManager

---

## 📋 변경 이력 요약

| 버전 | 날짜 | 변경 내용 |
|------|------|----------|
| v2.0.0 | 2026-01-30 | Gmail 트리거 전환 완료, rg-zb-taskman 배포 |
| v2.0.0-dev | 2026-01-29 | Gmail 트리거 전환 시작 |
| v1.0.0 | 2026-01-24 | Office 365 기반 초기 버전 |

상세 내용은 [docs/CHANGELOG.md](docs/CHANGELOG.md) 참조
