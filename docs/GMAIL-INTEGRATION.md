# Gmail 연동 가이드

> **상태**: ✅ **운영 중** (2026-01-31) | E2E 테스트 성공

---

## 📊 현재 운영 구성

| 항목 | 값 |
|------|-----|
| **연동 방식** | Google Apps Script (5분 폴링) |
| **Apps Script 프로젝트** | Email2ADO-Trigger |
| **Gmail 필터** | `Microsoft OR MVP` 키워드 |
| **Gmail 레이블** | Email2ADO → Email2ADO/Processed |
| **HTTP Trigger** | HTTP_Trigger |
| **Logic App** | email2ado-logic-prod |
| **워크플로우** | Email2ADO-HTTP |

---

## 📋 목차

1. [아키텍처](#1-아키텍처)
2. [V1 커넥터 제한사항](#2-v1-커넥터-제한사항)
3. [현재 해결책: Google Apps Script](#3-현재-해결책-google-apps-script)
4. [Gmail 필터 설정](#4-gmail-필터-설정)
5. [필드 매핑 참조](#5-필드-매핑-참조)
6. [대안 옵션](#6-대안-옵션)
7. [문제 해결](#7-문제-해결)

---

## 1. 아키텍처

### 현재 운영 아키텍처 (v2.4.0)

```
┌─────────────┐     ┌──────────────────────┐     ┌────────────────────┐
│   Gmail     │     │  Gmail Filter        │     │  Google Apps       │
│   Inbox     │────▶│  (Microsoft OR MVP)  │────▶│  Script            │
│             │     │  → Email2ADO 레이블   │     │  (5분 폴링)        │
└─────────────┘     └──────────────────────┘     └─────────┬──────────┘
                                                           │
                                                    HTTP POST
                                                           │
┌──────────────────────────────────────────────────────────▼──────────┐
│                      Email2ADO-HTTP (Logic App Standard)            │
├─────────────────────────────────────────────────────────────────────┤
│  HTTP_Trigger → 중복체크 → AI분석 → Work Item 생성 → Teams 알림    │
└─────────────────────────────────────────────────────────────────────┘
```

### 왜 이 아키텍처인가?

| 항목 | Email2ADO-Gmail (사용 불가) | Email2ADO-HTTP (현재 사용) |
|------|---------------------------|---------------------------|
| 트리거 | Gmail V1 커넥터 | HTTP Trigger + Apps Script |
| 상태 | ❌ Unhealthy | ✅ Healthy |
| 폴링 | V1 제한으로 불가 | Apps Script 5분 간격 |
| 인증 | Easy Auth 필요 | SAS 서명 (익명 허용) |

---

## 2. V1 커넥터 제한사항

### 문제점

Logic App **Standard**에서 Gmail V1 커넥터는 다음 제한이 있습니다:

```
❌ connectionRuntimeUrl 미지원
❌ ApiConnectionNotification 트리거 불가
❌ 실제 폴링 수행 안 함
```

### 증상

```powershell
# 워크플로우 상태 확인 시 Unhealthy
az rest --method GET \
  --uri ".../workflows/Email2ADO-Gmail?api-version=2023-01-01" \
  | ConvertFrom-Json | Select-Object -ExpandProperty properties | Select-Object health
# 결과: { "state": "Unhealthy" }
```

### 근본 원인

- Logic App **Consumption**에서는 V1 Gmail 커넥터 정상 동작
- Logic App **Standard**에서는 V2 커넥터만 완전 지원
- Gmail은 V2 커넥터 미제공 (2026년 1월 기준)

---

## 3. 현재 해결책: Google Apps Script

### 3.1 사전 요구사항

- Google 계정 (Gmail 접근 권한)
- Logic App HTTP Trigger URL

### 3.2 Apps Script 설정

1. **[script.google.com](https://script.google.com)** 접속

2. **새 프로젝트 생성**: `Email2ADO-Trigger`

3. **코드 붙여넣기**: `scripts/gmail-trigger.gs` 전체 복사

4. **저장** (Ctrl+S)

### 3.3 트리거 설정

1. 좌측 **⏰ 트리거** 클릭
2. **"+ 트리거 추가"** 클릭
3. 설정:
   - 실행할 함수: `processNewEmails`
   - 이벤트 소스: `시간 기반`
   - 유형: `분 단위 타이머`
   - 간격: `5분마다`
4. **저장**

### 3.4 권한 승인

첫 실행 시 Google 권한 요청:

1. "권한 검토" 클릭
2. Google 계정 선택
3. "고급" > "Email2ADO-Trigger(으)로 이동(안전하지 않음)" 클릭
4. "허용" 클릭

> ⚠️ 본인 계정으로 만든 스크립트이므로 안전합니다.

### 3.5 HTTP Trigger URL

현재 운영 URL (gmail-trigger.gs에 설정됨):

```
https://email2ado-logic-prod.azurewebsites.net/api/Email2ADO-HTTP/triggers/HTTP_Trigger/invoke?api-version=2022-05-01&sp=%2Ftriggers%2FHTTP_Trigger%2Frun&sv=1.0&sig=56zywRE5kOrh-MToeiBsltqA1YcxgKn3DDB8U7tocrY
```

---

## 4. Gmail 필터 설정

자동으로 `Email2ADO` 레이블을 적용하려면 Gmail 필터를 설정합니다.

### 4.1 필터 생성

1. **Gmail** > ⚙️ **설정** > **모든 설정 보기**
2. **"필터 및 차단된 주소"** 탭
3. **"새 필터 만들기"** 클릭

### 4.2 현재 필터 조건

```
포함하는 단어: Microsoft OR MVP
```

> 💡 `OR`는 **대문자**로 입력

### 4.3 동작 설정

- ✅ **라벨 적용**: `Email2ADO`
- ✅ **일치하는 대화에도 필터 적용** (선택)

### 4.4 추가 필터 예시

| 목적 | 필터 조건 |
|------|----------|
| 특정 발신자 | `from:@microsoft.com` |
| 제목 키워드 | `subject:(Azure OR MVP)` |
| 복합 조건 | `from:@microsoft.com subject:MVP` |

---

## 5. 필드 매핑 참조

### Apps Script → Logic App 페이로드

| 필드 | 설명 | 예시 값 |
|------|------|---------|
| `messageId` | Gmail 메시지 ID (prefix: gmail-) | `gmail-19c125c8cdaf4de9` |
| `subject` | 이메일 제목 | `MVP TEST` |
| `body` | 본문 (최대 5000자) | `안녕하세요...` |
| `from` | 발신자 이메일 | `zerobig.kim@gmail.com` |
| `receivedDateTime` | 수신 시간 (ISO 8601) | `2026-01-31T04:43:00Z` |
| `source` | 소스 식별자 | `Gmail-AppsScript` |

### Gmail API 필드 (참조용)

| 데이터 | Gmail API | Apps Script |
|--------|-----------|-------------|
| Message ID | `id` | `message.getId()` |
| 제목 | `payload.headers[Subject]` | `message.getSubject()` |
| 본문 | `payload.body.data` | `message.getPlainBody()` |
| 발신자 | `payload.headers[From]` | `message.getFrom()` |
| 수신 시간 | `internalDate` | `message.getDate()` |

---

## 6. 대안 옵션

### Option B: Power Automate

**장점**: GUI 기반, Microsoft 365 통합

```
Power Automate 흐름:
Gmail 트리거 → HTTP 액션 (Logic App 호출)
```

**설정 복잡도**: 중간

### Option C: Azure Functions

**장점**: Azure 네이티브, 확장성

**단점**: Gmail OAuth2 구현 필요, Refresh Token 관리 복잡

**권장하지 않음** - Apps Script가 더 간단

---

## 7. 문제 해결

### 7.1 Apps Script 권한 오류

**증상**: `Exception: You do not have permission to call UrlFetchApp.fetch`

**해결**:
1. 트리거 삭제 후 재생성
2. `testWebhook` 함수 수동 실행으로 권한 재승인

### 7.2 HTTP 401 Unauthorized

**증상**: Logic App 호출 시 401 오류

**원인**: Easy Auth가 활성화된 경우

**해결**: 
- Easy Auth 비활성화 (현재 상태) 또는
- Service Principal Bearer Token 사용

```powershell
# Easy Auth 상태 확인
az webapp auth show --name email2ado-logic-prod --resource-group rg-zb-taskman --query enabled
# 결과: false (비활성화됨)
```

### 7.3 이메일이 처리되지 않음

**확인 순서**:

1. **Gmail 레이블 확인**: 이메일에 `Email2ADO` 레이블이 있는지
2. **Apps Script 로그 확인**: View > Logs
3. **Table Storage 확인**:
   ```powershell
   az storage entity query --table-name ProcessedEmails \
     --account-name stemail2adoprodxhum3jlfa \
     --query "items[-3:]" -o table
   ```

### 7.4 "처리할 새 이메일 없음" 로그

**원인**: `Email2ADO` 레이블이 있는 이메일이 없음

**해결**: Gmail 필터 설정 또는 수동으로 레이블 적용

---

## 📚 관련 문서

| 문서 | 내용 |
|------|------|
| [ARCHITECTURE.md](ARCHITECTURE.md) | 전체 시스템 아키텍처 |
| [TROUBLESHOOTING.md](TROUBLESHOOTING.md) | 전체 문제 해결 가이드 |
| [DEPLOY.md](DEPLOY.md) | Azure 배포 가이드 |

---

## 📝 변경 이력

| 날짜 | 버전 | 변경 내용 |
|------|------|----------|
| 2026-01-31 | v2.4.0 | Gmail 자동 연동 완료, E2E 테스트 성공 |
| 2026-01-31 | - | Easy Auth 비활성화, HTTP_Trigger URL 수정 |
| 2026-01-31 | - | Gmail 필터 설정 (Microsoft OR MVP) |
| 2026-01-31 | - | GMAIL-SETUP.md, GMAIL-FIELD-MAPPING.md 통합 |
