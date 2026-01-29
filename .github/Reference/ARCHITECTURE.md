# 🏗️ 아키텍처 문서

**목적**: 이 시스템의 구조와 동작 원리를 상세히 설명  
**대상**: 초급~중급 엔지니어  
**버전**: v1.0.0 | **최종 업데이트**: 2026-01-24

---

## 📖 목차

1. [전체 아키텍처](#1-전체-아키텍처)
2. [워크플로 실행 순서](#2-워크플로-실행-순서)
3. [각 액션 상세 설명](#3-각-액션-상세-설명)
4. [인증 방식](#4-인증-방식)
5. [파일 구조](#5-파일-구조)
6. [데이터 흐름](#6-데이터-흐름)

---

## 1. 전체 아키텍처

### 시스템 구성도

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                              Azure Cloud (Korea Central)                             │
│  ┌─────────────────────────────────────────────────────────────────────────────────┐ │
│  │                        Resource Group: rg-zb-taskman                         │ │
│  │                                                                                   │ │
│  │  ┌─────────────────┐     ┌─────────────────┐     ┌─────────────────────────────┐ │ │
│  │  │   Office 365    │     │   Logic App     │     │     Azure OpenAI            │ │ │
│  │  │   Outlook       │────▶│   Standard      │────▶│     GPT-4o                  │ │ │
│  │  │                 │     │   em0911-       │     │     (AI 메일 분석)           │ │ │
│  │  │   (메일 수신)   │     │   workflow      │     │                             │ │ │
│  │  └─────────────────┘     └────────┬────────┘     └─────────────────────────────┘ │ │
│  │                                   │                                               │ │
│  │                     ┌─────────────┼─────────────┐                                 │ │
│  │                     │             │             │                                 │ │
│  │                     ▼             ▼             ▼                                 │ │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐                   │ │
│  │  │  Table Storage  │  │  Azure DevOps   │  │  Microsoft      │                   │ │
│  │  │  ProcessedEmails│  │  Work Items     │  │  Teams          │                   │ │
│  │  │  (중복 방지)     │  │  (Issue 생성)   │  │  (알림 발송)     │                   │ │
│  │  └─────────────────┘  └─────────────────┘  └─────────────────┘                   │ │
│  │                                                                                   │ │
│  └─────────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                       │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### 컴포넌트 역할

| 컴포넌트 | 리소스명 | 역할 | 왜 필요한가? |
|---------|---------|------|-------------|
| **Logic App** | em0911-workflow | 전체 오케스트레이션 | 모든 서비스를 연결하는 허브 |
| **Table Storage** | ProcessedEmails | 처리된 메일 ID 저장 | 같은 메일 재처리 방지 (멱등성) |
| **Azure OpenAI** | zb-taskman | 메일 AI 분석 | 요약, 인사이트, 액션아이템 추출 |
| **Azure DevOps** | azure-mvp | Work Item 저장소 | 이슈 트래킹 및 관리 |
| **Microsoft Teams** | - | 알림 채널 | 담당자에게 즉시 알림 |

---

## 2. 워크플로 실행 순서

### 전체 흐름도

```
[트리거] 새 메일 수신 (1분 폴링)
    │
    ▼
[변수 초기화] MessageId, Subject, Body, SenderEmail, RecipientEmail, ReceivedTimeKST
    │
    ▼
[중복 체크] Table Storage에서 MessageId 조회
    │
    ├── 존재함 → [종료] 중복 메일, 처리 안 함
    │
    └── 존재 안 함 ↓
            │
            ▼
        [저장] MessageId를 Table Storage에 기록
            │
            ▼
        [AI 분석] Azure OpenAI GPT-4o로 메일 분석
            │
            ▼
        [Work Item 생성] ADO Issue 생성 (API Connection)
            │
            ▼
        [필드 업데이트] 담당자/태그 설정 (HTTP + PAT)
            │
            ▼
        [Teams 알림] 채널에 메시지 전송
            │
            ▼
        [완료]
```

### 액션 실행 순서 (workflow.json 순서대로)

| 순서 | 액션 ID | 설명 | 의존성 |
|------|---------|------|--------|
| 1 | `When_a_new_email_arrives_(V3)` | 트리거: 메일 수신 감지 | - |
| 2 | `Initialize_MessageId` | 메일 고유 ID 추출 | 트리거 |
| 3 | `Initialize_Subject` | 메일 제목 추출 | MessageId |
| 4 | `Initialize_Body` | 메일 본문 추출 | Subject |
| 5 | `Initialize_ReceivedTimeKST` | 수신 시간 (KST 변환) | Body |
| 6 | `Initialize_SenderEmail` | 발신자 이메일 | ReceivedTimeKST |
| 7 | `Initialize_RecipientEmail` | 수신자 이메일 | SenderEmail |
| 8 | `Initialize_AI_Analysis_Result` | AI 결과 저장용 변수 | RecipientEmail |
| 9 | `Check_MessageId_Exists_In_TableStorage` | 중복 확인 | AI_Analysis_Result |
| 10 | `Condition_MessageId_Duplicate` | 분기: 중복 여부 | Check_MessageId |
| 11a | ↳ `Terminate_Duplicate_Mail` | (중복 시) 종료 | Condition=True |
| 11b | ↳ `Insert_MessageId_To_TableStorage` | (신규 시) ID 저장 | Condition=False |
| 12 | `Analyze_Email_With_AI` | AI 분석 호출 | Insert |
| 13 | `Set_AI_Analysis_Result` | 결과 변수에 저장 | Analyze |
| 14 | `Create_ADO_WorkItem` | Work Item 생성 | Set_AI |
| 15 | `Update_ADO_WorkItem_Fields` | 담당자/태그 설정 | Create_ADO |
| 16 | `Send_Teams_Notification` | Teams 알림 | Update_ADO |

---

## 3. 각 액션 상세 설명

### 3.1 트리거: 메일 수신

```json
{
  "When_a_new_email_arrives_(V3)": {
    "type": "ApiConnection",
    "recurrence": {
      "frequency": "Minute",
      "interval": 1
    },
    "inputs": {
      "path": "/v3/Mail/OnNewEmail",
      "queries": {
        "folderPath": "Inbox",
        "importance": "Any"
      }
    }
  }
}
```

**동작**:
- 1분마다 Inbox 폴더 확인
- 새 메일 발견 시 워크플로 실행
- `splitOn`으로 메일별 개별 실행

### 3.2 중복 체크 (Table Storage)

```json
{
  "Check_MessageId_Exists_In_TableStorage": {
    "type": "Http",
    "inputs": {
      "method": "GET",
      "uri": "https://{storage}.table.core.windows.net/ProcessedEmails(PartitionKey='yyyy-MM',RowKey='messageId')",
      "authentication": {
        "type": "ManagedServiceIdentity",
        "audience": "https://storage.azure.com/"
      }
    }
  }
}
```

**테이블 구조**:
| PartitionKey | RowKey | Subject | ProcessedTime |
|--------------|--------|---------|---------------|
| 2026-01 | `<abc123@mail.com>` | 메일 제목 | 2026-01-24T12:00:00Z |

**왜 이렇게 설계했나?**:
- **PartitionKey**: 월 단위로 분리 → 성능 최적화
- **RowKey**: MessageId → 중복 확인 O(1)

### 3.3 AI 분석 (Azure OpenAI)

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
          { "role": "system", "content": "메일 분석 전문가입니다..." },
          { "role": "user", "content": "발신자: @{...} 제목: @{...} 본문: @{...}" }
        ],
        "temperature": 0.3,
        "max_tokens": 1000
      }
    }
  }
}
```

**AI 출력 형식**:
```
## 📜 요약
(2-3문장 요약)

## 💡 인사이트
(핵심 포인트)

## ✔ 액션 아이템
1. 첫 번째 할 일
2. 두 번째 할 일
```

### 3.4 Work Item 생성 + 필드 업데이트

**왜 2단계로 나뉘었나?**

```
┌─────────────────────────┐     ┌─────────────────────────┐
│  Create_ADO_WorkItem    │────▶│  Update_ADO_Fields      │
│  (API Connection)       │     │  (HTTP + PAT)           │
│                         │     │                         │
│  • title ✅             │     │  • System.AssignedTo ✅ │
│  • description ✅       │     │  • System.Tags ✅       │
│  • assignedTo ❌ 안됨   │     │                         │
│  • tags ❌ 안됨         │     │                         │
└─────────────────────────┘     └─────────────────────────┘
```

**핵심 이유**:
- VSTS 커넥터는 `assignedTo`, `tags` 필드를 **지원하지 않음**
- 별도 HTTP 액션으로 JSON Patch 형식 업데이트 필요

**Update 액션 코드**:
```json
{
  "Update_ADO_WorkItem_Fields": {
    "type": "Http",
    "inputs": {
      "method": "PATCH",
      "uri": "https://dev.azure.com/{org}/{project}/_apis/wit/workitems/{id}?api-version=7.1",
      "headers": {
        "Content-Type": "application/json-patch+json",
        "Authorization": "Basic @{base64(concat(':', appsetting('ADO_PAT')))}"
      },
      "body": [
        { "op": "add", "path": "/fields/System.AssignedTo", "value": "@{variables('RecipientEmail')}" },
        { "op": "add", "path": "/fields/System.Tags", "value": "CM Worker Manager" }
      ]
    }
  }
}
```

---

## 4. 인증 방식

### 한눈에 보기

| 서비스 | 인증 방식 | 설정 위치 | 비고 |
|--------|----------|----------|------|
| **Office 365** | OAuth (API Connection V2) | connections.json | 토큰 자동 갱신 |
| **Table Storage** | Managed Identity | workflow.json | MSI + RBAC |
| **Azure OpenAI** | API Key | App Settings | Key Vault 권장 |
| **ADO (Work Item 생성)** | OAuth (API Connection V2) | connections.json | 사용자 동의 필요 |
| **ADO (필드 업데이트)** | PAT (Basic Auth) | App Settings | ⚠️ 만료 관리 필요 |
| **Teams** | OAuth (API Connection V2) | connections.json | Graph API /beta |

### 왜 ADO는 두 가지 인증을 쓰나?

```
[문제] MSI로 ADO 직접 인증 → ❌ 401 Unauthorized
       VSTS 커넥터로 담당자/태그 → ❌ 필드 무시됨

[해결] Work Item 생성: API Connection (OAuth) ✅
       필드 업데이트: HTTP + PAT (Basic Auth) ✅
```

---

## 5. 파일 구조

### 핵심 파일 3개

```
Email2ADO-Workflow/
├── IssueHandler/
│   └── workflow.json         ← 모든 로직이 여기에!
│
├── connections.json          ← API 연결 정의
│   ├── serviceProviderConnections (Azure OpenAI)
│   └── managedApiConnections (Office365, Teams, ADO)
│
└── local.settings.json       ← 환경 변수 (Git 제외)
```

### workflow.json 구조

```json
{
  "definition": {
    "actions": {
      "Initialize_MessageId": {},
      "Initialize_Subject": {},
      "...": "...",
      "Create_ADO_WorkItem": {},
      "Update_ADO_WorkItem_Fields": {},
      "Send_Teams_Notification": {}
    },
    "triggers": {
      "When_a_new_email_arrives_(V3)": {}
    }
  }
}
```

### connections.json 구조

```json
{
  "serviceProviderConnections": {
    "azureOpenAI": {
      "parameterValues": {
        "openAIKey": "@appsetting('AZURE_OPENAI_API_KEY')",
        "openAIEndpoint": "@appsetting('AZURE_OPENAI_ENDPOINT')"
      }
    }
  },
  "managedApiConnections": {
    "office365": { "connectionRuntimeUrl": "@appsetting(...)" },
    "teams": { "connectionRuntimeUrl": "@appsetting(...)" },
    "visualstudioteamservices": { "connectionRuntimeUrl": "@appsetting(...)" }
  }
}
```

---

## 6. 데이터 흐름

### 메일 → Work Item 데이터 매핑

| 메일 필드 | 변수명 | Work Item 필드 |
|----------|--------|---------------|
| `internetMessageId` | `MessageId` | (중복 체크용) |
| `subject` | `Subject` | `System.Title` |
| `bodyPreview` | `Body` | `System.Description` (일부) |
| `from` | `SenderEmail` | Description에 포함 |
| `toRecipients[0]` | `RecipientEmail` | `System.AssignedTo` |
| `receivedDateTime` | `ReceivedTimeKST` | Description에 포함 |
| (AI 분석 결과) | `AIAnalysisResult` | Description에 포함 |

### Work Item Description 구조

```html
<h2>🤖 AI 분석 결과</h2>
<div style="background:#f0f7ff; padding:15px;">
  (AI 분석 결과 - 요약, 인사이트, 액션아이템)
</div>

<hr/>

<h2>📧 원본 메일 정보</h2>
<table>
  <tr><td>발신자</td><td>{SenderEmail}</td></tr>
  <tr><td>수신자</td><td>{RecipientEmail}</td></tr>
  <tr><td>수신 시간</td><td>{ReceivedTimeKST} (KST)</td></tr>
</table>

<h3>📝 본문 내용</h3>
<div>{Body}</div>
```

---

## 📚 다음 단계

- 문제 해결: [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
- 재구축 시: [REBUILD_INSIGHTS.md](REBUILD_INSIGHTS.md)
- 변경 이력: [CHANGELOG.md](CHANGELOG.md)

---

*문서 버전: v1.0.0 | 최종 업데이트: 2026-01-24*