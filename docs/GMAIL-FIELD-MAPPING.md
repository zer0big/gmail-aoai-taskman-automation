# Gmail 커넥터 필드 매핑 가이드

## 📋 개요
이 문서는 Office 365 Outlook 커넥터에서 Gmail 커넥터로 전환 시 필요한 필드 매핑 정보를 제공합니다.

## 🔄 필드 매핑 테이블

| 데이터 | Office 365 Outlook | Gmail | 비고 |
|--------|-------------------|-------|------|
| Message ID | `triggerBody()?['internetMessageId']` | `triggerBody()?['Id']` | Gmail은 내부 ID 사용 |
| 제목 | `triggerBody()?['subject']` | `triggerBody()?['Subject']` | 대소문자 차이 |
| 본문 | `triggerBody()?['bodyPreview']` | `triggerBody()?['Body']` 또는 `['Snippet']` | Gmail은 Body 또는 Snippet 사용 |
| 수신 시간 | `triggerBody()?['receivedDateTime']` | `triggerBody()?['DateTimeReceived']` | 필드명 차이 |
| 발신자 | `triggerBody()?['from']` | `triggerBody()?['From']` | 대소문자 차이 |
| 수신자 (To) | `triggerBody()?['toRecipients']` | `triggerBody()?['To']` | Gmail은 문자열 반환 |
| 참조 (Cc) | `triggerBody()?['ccRecipients']` | `triggerBody()?['Cc']` | Gmail은 문자열 반환 |

## 📧 Gmail 트리거 설정

### 트리거 유형
```json
{
  "When_a_new_email_arrives_Gmail": {
    "type": "ApiConnection",
    "recurrence": {
      "frequency": "Minute",
      "interval": 1
    },
    "inputs": {
      "host": {
        "connection": {
          "referenceName": "gmail"
        }
      },
      "method": "get",
      "path": "/Mail/OnNewEmail",
      "queries": {
        "label": "INBOX",
        "importance": "All",
        "starred": "All",
        "fetchOnlyWithAttachments": false,
        "includeAttachments": false
      }
    },
    "splitOn": "@triggerBody()?['value']"
  }
}
```

### 사용 가능한 쿼리 파라미터
| 파라미터 | 설명 | 가능한 값 |
|----------|------|-----------|
| `label` | 모니터링할 Gmail 라벨 | `INBOX`, `SPAM`, `TRASH`, 사용자 정의 라벨 |
| `importance` | 중요도 필터 | `All`, `High`, `Low` |
| `starred` | 별표 표시 필터 | `All`, `Starred`, `Not Starred` |
| `fetchOnlyWithAttachments` | 첨부파일 있는 메일만 | `true`, `false` |
| `includeAttachments` | 첨부파일 포함 여부 | `true`, `false` |

## ⚠️ Gmail 커넥터 제약사항

### 1. 계정 유형별 제한
| 계정 유형 | 제한 사항 |
|-----------|-----------|
| Google Workspace (G-Suite) | 제한 없음 |
| 소비자 계정 (@gmail.com) | Google 승인 앱만 사용 가능 |

### 2. BYOA (Bring Your Own Application)
소비자 Gmail 계정 사용 시 BYOA 옵션으로 제한 우회 가능:
1. Google Cloud Console에서 OAuth 2.0 클라이언트 생성
2. Azure Portal의 API Connection에서 "Bring Your Own Application" 선택
3. Client ID와 Client Secret 입력

### 3. API 제한 (Rate Limits)
| 제한 유형 | 값 |
|-----------|-----|
| 호출/분 | 60회 |
| 일일 작업 단위 | 90,000 |

## 📚 참조 문서
- [Gmail 커넥터 공식 문서](https://learn.microsoft.com/en-us/connectors/gmail/)
- [Logic Apps Gmail 트리거](https://learn.microsoft.com/en-us/azure/connectors/connectors-create-api-gmail)
