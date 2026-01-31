# Gmail → Email2ADO-HTTP 자동 연동 가이드

Gmail에서 새 이메일 수신 시 자동으로 Email2ADO-HTTP 워크플로우를 호출하는 방법을 설명합니다.

---

## 📋 목차

1. [개요](#1-개요)
2. [Option A: Google Apps Script (권장)](#2-option-a-google-apps-script-권장)
3. [Option B: Power Automate](#3-option-b-power-automate)
4. [Option C: Azure Functions](#4-option-c-azure-functions)
5. [테스트 방법](#5-테스트-방법)
6. [문제 해결](#6-문제-해결)

---

## 1. 개요

### 배경
- Logic App Standard의 V1 커넥터(Gmail)가 `connectionRuntimeUrl`을 지원하지 않음
- Email2ADO-Gmail 워크플로우는 Unhealthy 상태로 Gmail 폴링 불가
- **해결책**: Email2ADO-HTTP 워크플로우를 외부에서 호출

### 아키텍처

```
┌─────────────┐     ┌──────────────────────┐     ┌────────────────────┐
│   Gmail     │────▶│  Trigger Service     │────▶│  Email2ADO-HTTP    │
│   Inbox     │     │  (Apps Script/       │     │  (Logic App)       │
│             │     │   Power Automate/    │     │                    │
│             │     │   Azure Functions)   │     │                    │
└─────────────┘     └──────────────────────┘     └────────────────────┘
```

---

## 2. Option A: Google Apps Script (권장)

**장점**: 무료, Gmail과 동일 Google 계정, 간단한 설정

### 2.1 사전 준비

1. **Logic App 트리거 URL 확인**:
   - Azure Portal > Logic App > `email2ado-logic-prod`
   - Workflows > `Email2ADO-HTTP` > Overview
   - **Workflow URL** 복사

2. **Gmail 레이블 생성**:
   - Gmail > 좌측 메뉴 > "더보기" > "새 라벨 만들기"
   - 라벨 이름: `Email2ADO`

### 2.2 Apps Script 설정

1. [Google Apps Script](https://script.google.com) 접속

2. **새 프로젝트 생성**:
   - "+ 새 프로젝트" 클릭
   - 프로젝트 이름: `Email2ADO-Trigger`

3. **코드 붙여넣기**:
   - `scripts/gmail-trigger.gs` 파일 내용 복사
   - Apps Script 에디터에 붙여넣기

4. **WEBHOOK_URL 수정** (이미 설정된 실제 URL):
   ```javascript
   const WEBHOOK_URL = "https://email2ado-logic-prod.azurewebsites.net/api/Email2ADO-HTTP/triggers/HTTP_Trigger/invoke?api-version=2022-05-01&sp=%2Ftriggers%2FHTTP_Trigger%2Frun&sv=1.0&sig=56zywRE5kOrh-MToeiBsltqA1YcxgKn3DDB8U7tocrY";
   ```
   > ⚠️ 위 URL은 실제 운영 환경 URL입니다. 변경하지 마세요.

5. **저장**: Ctrl+S

### 2.3 트리거 설정

1. 좌측 메뉴에서 **"트리거"** (시계 아이콘) 클릭

2. **"+ 트리거 추가"** 클릭

3. 설정:
   - 실행할 함수: `processNewEmails`
   - 이벤트 소스: `시간 기반`
   - 시간 기반 트리거 유형: `분 단위 타이머`
   - 분 간격: `5분마다`

4. **저장**

### 2.4 권한 승인

1. 첫 실행 시 권한 요청 팝업 표시
2. "권한 검토" 클릭
3. Google 계정 선택
4. "고급" > "Email2ADO-Trigger(안전하지 않음)(으)로 이동" 클릭
5. "허용" 클릭

### 2.5 테스트

1. Gmail에서 테스트 이메일에 `Email2ADO` 레이블 적용
2. Apps Script에서 `processNewEmails` 함수 직접 실행 (▶ 버튼)
3. 실행 로그 확인 (View > Logs)

---

## 3. Option B: Power Automate

**장점**: GUI 기반, Microsoft 365 통합

### 3.1 Power Automate 흐름 생성

1. [Power Automate](https://make.powerautomate.com) 접속

2. **"+ 만들기"** > **"자동화된 클라우드 흐름"**

3. **트리거 선택**: `Gmail - 새 이메일이 도착하는 경우`

4. **Gmail 연결**: Google 계정으로 로그인

5. **HTTP 액션 추가**:
   - "+ 새 단계" > "HTTP"
   - 메서드: `POST`
   - URI: `<Logic App Trigger URL>`
   - 헤더: `Content-Type: application/json`
   - 본문:
   ```json
   {
     "messageId": "@{triggerOutputs()?['body/id']}",
     "subject": "@{triggerOutputs()?['body/subject']}",
     "body": "@{triggerOutputs()?['body/body']}",
     "from": "@{triggerOutputs()?['body/from']}",
     "receivedDateTime": "@{utcNow()}",
     "source": "Gmail-PowerAutomate"
   }
   ```

6. **저장 및 테스트**

---

## 4. Option C: Azure Functions

**장점**: Azure 네이티브, 확장성

### 4.1 Azure Functions 생성

```powershell
# Function App 생성
az functionapp create \
  --name email2ado-gmail-trigger \
  --resource-group rg-zb-taskman \
  --storage-account stemail2adoprodxhum3jlfa \
  --runtime python \
  --runtime-version 3.11 \
  --functions-version 4 \
  --os-type Linux

# Gmail API 연동 구현 필요 (OAuth2)
```

### 4.2 구현 복잡도

- Gmail OAuth2 인증 구현 필요
- Refresh Token 관리 필요
- **권장하지 않음** (Apps Script가 더 간단)

---

## 5. 테스트 방법

### 5.1 수동 HTTP 호출 테스트

```powershell
$triggerUrl = "YOUR_LOGIC_APP_TRIGGER_URL"
$payload = @{
    messageId = "test-$(Get-Date -Format 'yyyyMMddHHmmss')"
    subject = "[테스트] Gmail 연동 테스트"
    body = "이 메시지는 수동 테스트입니다."
    from = "test@gmail.com"
    receivedDateTime = (Get-Date).ToUniversalTime().ToString("o")
    source = "Manual-Test"
} | ConvertTo-Json

Invoke-RestMethod -Uri $triggerUrl -Method POST -Body $payload -ContentType "application/json"
```

### 5.2 확인 사항

1. **Table Storage 확인**:
   ```powershell
   az storage entity query --table-name ProcessedEmails \
     --account-name stemail2adoprodxhum3jlfa \
     --auth-mode key \
     --query "items[-1]" -o json
   ```

2. **ADO Work Item 확인**:
   - https://dev.azure.com/azure-mvp/ZBTaskManager/_workitems

3. **Teams 알림 확인**:
   - AutoTaskMan 채널

---

## 6. 문제 해결

### 6.1 Apps Script 실행 오류

**증상**: `Exception: You do not have permission to call UrlFetchApp.fetch`

**해결**: 권한 재승인
1. 트리거 삭제 후 재생성
2. 수동 실행으로 권한 팝업 트리거

### 6.2 HTTP 401 Unauthorized

**증상**: Logic App 호출 시 401 오류

**원인**: Easy Auth가 활성화된 경우 Bearer Token 필요

**해결**:
1. Easy Auth 비활성화 (테스트용)
2. 또는 Service Principal 토큰 획득 로직 추가

### 6.3 레이블이 없는 이메일 처리

**증상**: 모든 이메일이 아닌 레이블이 있는 이메일만 처리됨

**해결**: Gmail 필터 설정
1. Gmail > 설정 > 필터 및 차단된 주소
2. 필터 만들기: 특정 발신자 → `Email2ADO` 레이블 자동 적용

---

## 📝 권장 설정

| 항목 | 권장값 | 비고 |
|------|--------|------|
| 트리거 방식 | Google Apps Script | 무료, 간단 |
| 폴링 간격 | 5분 | 비용/적시성 균형 |
| Gmail 레이블 | `Email2ADO` | 처리 대상 필터링 |
| 처리 완료 레이블 | `Email2ADO/Processed` | 중복 처리 방지 |

---

**작성**: 2026-01-31 | **버전**: v1.0.0
