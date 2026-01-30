# Gmail 설정 가이드

> Gmail API Connection 설정 및 OAuth 인증 가이드

## 📧 사용 계정 정보

| 항목 | 값 |
|------|-----|
| **Gmail 계정** | `zerobig.kim@gmail.com` |
| **계정 유형** | 소비자 계정 (@gmail.com) |
| **연결 방식** | V1 API Connection + OAuth 2.0 + MSI 인증 |

---

## 사전 요구사항

### 1. Gmail 계정 설정

1. **2단계 인증 활성화** (권장)
   - [Google 계정 보안](https://myaccount.google.com/security) 접속
   - "2단계 인증" 활성화

2. **덜 안전한 앱 액세스** (필요한 경우)
   - 일반적으로 OAuth를 사용하므로 불필요
   - Azure Connector는 OAuth 2.0 사용

### 2. Google Cloud Console (선택사항: BYOA)

> ⚠️ **참고**: Azure의 Gmail Connector를 사용하면 BYOA 없이도 작동합니다.
> BYOA는 커스텀 앱이 필요한 경우에만 설정하세요.

BYOA (Bring Your Own App) 설정이 필요한 경우:

1. [Google Cloud Console](https://console.cloud.google.com/) 접속
2. 새 프로젝트 생성 또는 기존 프로젝트 선택
3. APIs & Services → Library → Gmail API 활성화
4. APIs & Services → Credentials → OAuth 2.0 Client ID 생성
5. Authorized redirect URIs에 Azure 콜백 URL 추가

---

## Azure Portal에서 Gmail 연결

### 1. API Connection 배포

Bicep 배포 후 자동으로 Gmail API Connection이 생성됩니다:

```powershell
# infra 배포
az deployment group create \
  --resource-group rg-email2ado-dev \
  --template-file infra/main.bicep \
  --parameters infra/parameters/dev.bicepparam
```

### 2. OAuth 인증 (필수)

1. **Azure Portal** 접속
2. **리소스 그룹** → `rg-email2ado-dev` 이동
3. **API Connection** → `gmail-dev` 선택
4. 왼쪽 메뉴에서 **Edit API connection** 클릭
5. **Authorize** 버튼 클릭
6. Google 로그인 창에서 `zerobig.kim@gmail.com` 로그인
7. 권한 요청 승인:
   - Gmail 메시지 읽기
   - Gmail 메시지 보내기 (선택)
8. **Save** 클릭

### 3. 연결 상태 확인

```powershell
# 연결 상태 확인
az resource show \
  --resource-group rg-email2ado-dev \
  --resource-type "Microsoft.Web/connections" \
  --name gmail-dev \
  --query "properties.statuses[0].status"
```

예상 결과: `"Connected"`

---

## Logic Apps에서 Gmail 트리거 설정

### 트리거 구성

`workflow.json`의 Gmail 트리거 설정:

```json
{
  "When_a_new_email_arrives": {
    "type": "ApiConnectionNotification",
    "inputs": {
      "host": {
        "connection": {
          "referenceName": "gmail"
        }
      },
      "fetch": {
        "method": "get",
        "pathTemplate": {
          "template": "/v2/Mail/OnNewEmail"
        },
        "queries": {
          "importance": "All",
          "fetchOnlyWithAttachment": false,
          "includeAttachments": false,
          "folderPath": "Inbox"
        }
      },
      "subscribe": {
        "method": "post",
        "pathTemplate": {
          "template": "/v2/Mail/OnNewEmail"
        },
        "queries": {
          "importance": "All",
          "fetchOnlyWithAttachment": false,
          "includeAttachments": false,
          "folderPath": "Inbox"
        }
      }
    },
    "splitOn": "@triggerOutputs()?['body/value']"
  }
}
```

### 주요 설정 옵션

| 옵션 | 설명 | 기본값 |
|------|------|--------|
| `folderPath` | 모니터링할 폴더 | `Inbox` |
| `importance` | 중요도 필터 | `All` |
| `fetchOnlyWithAttachment` | 첨부파일 있는 메일만 | `false` |
| `includeAttachments` | 첨부파일 포함 여부 | `false` |

---

## 트러블슈팅

### 1. "Authorization Failed" 오류

**원인**: OAuth 인증이 완료되지 않음

**해결**:
1. Azure Portal → API Connection → gmail-dev
2. Edit API connection → Authorize 다시 시도
3. 브라우저 캐시 삭제 후 재시도

### 2. "Access Blocked" Google 오류

**원인**: Google에서 앱 접근 차단

**해결**:
1. [Google 보안 설정](https://myaccount.google.com/security) 확인
2. "서드파티 앱 액세스" 허용
3. 필요시 BYOA 설정

### 3. 트리거가 실행되지 않음

**원인**: Webhook 등록 실패

**해결**:
1. Logic App 워크플로우 비활성화 후 재활성화
2. API Connection 연결 상태 확인
3. Gmail 받은편지함에 테스트 이메일 발송

### 4. "Quota Exceeded" 오류

**원인**: Gmail API 할당량 초과

**해결**:
1. [Google API Console](https://console.cloud.google.com/apis/dashboard)에서 할당량 확인
2. 폴링 간격 조정 (기본: 3분)
3. 필요시 할당량 증가 요청

---

## 보안 권장사항

### ✅ 권장

- 2단계 인증 활성화
- 정기적인 연결 상태 모니터링
- 불필요한 권한 최소화 (읽기만 필요한 경우 쓰기 권한 제거)

### ❌ 금지

- Gmail 비밀번호를 코드나 설정 파일에 저장
- 앱 비밀번호 사용 (OAuth 대신)
- 프로덕션에서 "덜 안전한 앱" 옵션 활성화

---

## 참고 자료

- [Gmail Connector 공식 문서](https://learn.microsoft.com/en-us/connectors/gmail/)
- [Logic Apps API Connection 인증](https://learn.microsoft.com/en-us/azure/logic-apps/logic-apps-securing-a-logic-app#authenticate-connections)
- [Google OAuth 2.0 가이드](https://developers.google.com/identity/protocols/oauth2)
