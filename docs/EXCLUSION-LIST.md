# 📧 이메일 제외 목록 관리 가이드

> **상태**: ✅ 운영 중 | **최종 업데이트**: 2026-02-16 | **스크립트 버전**: v1.4.0

---

## 📋 개요

Email2ADO 시스템은 Gmail에서 수신한 이메일을 자동으로 Azure DevOps Work Item으로 생성합니다.  
그러나 모든 이메일이 Work Item으로 생성될 필요는 없으므로, **도메인 기반**, **발신자 주소 기반**, **제목 키워드 기반** 제외 필터를 통해 불필요한 자동 메일을 걸러냅니다.

### 필터링 순서

```
이메일 수신 → Gmail 필터 (Email2ADO 레이블) → Apps Script 처리
                                                    │
                                              ┌─────▼─────┐
                                              │ 제외 체크   │
                                              ├────────────┤
                                              │ 1. 도메인   │ → EXCLUDED_DOMAINS
                                              │ 2. 발신자   │ → EXCLUDED_SENDERS
                                              │ 3. 제목     │ → EXCLUDED_SUBJECT_KEYWORDS
                                              └─────┬──────┘
                                                    │
                                         ┌──────────▼──────────┐
                                         │ 제외 대상?           │
                                         ├──────────┬──────────┤
                                         │ YES      │ NO       │
                                         │ SKIP     │ 처리     │
                                         │ (로그)   │ → Logic  │
                                         │          │   App    │
                                         └──────────┴──────────┘
```

---

## 📑 현재 제외 목록

### 1. 도메인 기반 제외 (`EXCLUDED_DOMAINS`)

해당 도메인에서 발송된 **모든** 이메일을 제외합니다.

| # | 도메인 | 발송 유형 | 추가일 | 추가 사유 |
|---|--------|----------|--------|----------|
| 1 | `linkedin.com` | 일반 알림 (초대, 메시지 등) | 2026-02-07 | LinkedIn 알림이 Work Item으로 생성됨 |
| 2 | `e.linkedin.com` | 이메일 마케팅/뉴스레터 | 2026-02-07 | LinkedIn 뉴스레터가 Work Item으로 생성됨 |
| 3 | `linkedin.mktgcenter.com` | 마케팅 센터 | 2026-02-07 | LinkedIn 마케팅 메일이 Work Item으로 생성됨 |

**스크립트 위치**: `scripts/gmail-trigger.gs` → `EXCLUDED_DOMAINS` 상수

```javascript
const EXCLUDED_DOMAINS = [
  "linkedin.com",
  "e.linkedin.com",
  "linkedin.mktgcenter.com"
];
```

### 2. 발신자 주소 기반 제외 (`EXCLUDED_SENDERS`)

해당 이메일 주소에서 발송된 이메일만 **정확히 일치**하는 경우 제외합니다.

| # | 발신자 주소 | 발송 유형 | 추가일 | 추가 사유 |
|---|------------|----------|--------|----------|
| 1 | `no-reply@appmail.pluralsight.com` | Pluralsight 학습 플랫폼 알림 | 2026-02-16 | 학습 플랫폼 자동 알림이 Work Item으로 생성됨 |
| 2 | `MSSecurity-noreply@microsoft.com` | Microsoft Security 자동 알림 | 2026-02-16 | 보안 알림이 Work Item으로 생성됨 |
| 3 | `pgievent@microsoft.com` | Microsoft PGI 이벤트 알림 | 2026-02-16 | 이벤트 초대/알림이 Work Item으로 생성됨 |
| 4 | `no-reply@cncf.io` | CNCF 뉴스레터/알림 | 2026-02-16 | CNCF 자동 알림이 Work Item으로 생성됨 |
| 5 | `replyto@email.microsoft.com` | Microsoft 마케팅/이벤트 메일 | 2026-02-16 | Microsoft 마케팅 메일이 Work Item으로 생성됨 |
| 6 | `email@email.microsoft.com` | Microsoft 자동 발송 메일 | 2026-02-16 | Microsoft 자동 메일이 Work Item으로 생성됨 |
| 7 | `no-reply@linuxfoundation.org` | Linux Foundation 알림 | 2026-02-16 | Linux Foundation 알림이 Work Item으로 생성됨 |

**스크립트 위치**: `scripts/gmail-trigger.gs` → `EXCLUDED_SENDERS` 상수

```javascript
const EXCLUDED_SENDERS = [
  "no-reply@appmail.pluralsight.com",
  "mssecurity-noreply@microsoft.com",
  "pgievent@microsoft.com",
  "no-reply@cncf.io",
  "replyto@email.microsoft.com",
  "email@email.microsoft.com",
  "no-reply@linuxfoundation.org"
];
```

> 💡 **비교 방식**: 대소문자 무시 (lowercase 비교). `MSSecurity-noreply@microsoft.com`도 정상 매칭됩니다.

### 3. 제목 키워드 기반 제외 (`EXCLUDED_SUBJECT_KEYWORDS`)

이메일 제목에 해당 키워드가 **포함**된 경우 제외합니다.

| # | 키워드 | 제외 사유 | 추가일 |
|---|--------|----------|--------|
| 1 | `[광고]` | 광고성 메일이 Work Item으로 생성됨 | 2026-02-16 |

**스크립트 위치**: `scripts/gmail-trigger.gs` → `EXCLUDED_SUBJECT_KEYWORDS` 상수

```javascript
const EXCLUDED_SUBJECT_KEYWORDS = [
  "[광고]"
];
```

> 💡 **비교 방식**: `String.includes()` — 제목 문자열에 키워드가 포함되면 제외됩니다. 대소문자를 구분합니다.

---

## 🔧 제외 목록 변경 방법

### 도메인 추가

특정 도메인의 **모든** 이메일을 제외하려면 `EXCLUDED_DOMAINS`에 추가합니다.

```javascript
const EXCLUDED_DOMAINS = [
  "linkedin.com",
  "e.linkedin.com",
  "linkedin.mktgcenter.com",
  "newsletter.example.com"    // ← 새 도메인 추가
];
```

### 발신자 주소 추가

특정 발신자 **1명**의 이메일만 제외하려면 `EXCLUDED_SENDERS`에 추가합니다.

```javascript
const EXCLUDED_SENDERS = [
  "no-reply@appmail.pluralsight.com",
  "mssecurity-noreply@microsoft.com",
  "pgievent@microsoft.com",
  "no-reply@cncf.io",
  "replyto@email.microsoft.com",
  "email@email.microsoft.com",
  "no-reply@linuxfoundation.org",
  "noreply@example.com"       // ← 새 발신자 추가
];
```

### 제목 키워드 추가

제목에 특정 키워드가 포함된 이메일을 제외하려면 `EXCLUDED_SUBJECT_KEYWORDS`에 추가합니다.

```javascript
const EXCLUDED_SUBJECT_KEYWORDS = [
  "[광고]",
  "[AD]"                      // ← 새 키워드 추가
];
```

### 도메인 vs 발신자 주소 vs 제목 키워드 — 어떤 것을 써야 할까?

| 상황 | 권장 방식 | 예시 |
|------|----------|------|
| 해당 도메인의 **모든** 메일을 제외하려 할 때 | `EXCLUDED_DOMAINS` | `linkedin.com` → 해당 도메인 모든 발신자 제외 |
| 한 도메인에서 **특정 발신자만** 제외하려 할 때 | `EXCLUDED_SENDERS` | `pgievent@microsoft.com` → microsoft.com의 다른 메일은 유지 |
| 같은 도메인의 여러 발신자를 제외해야 할 때 | 상황에 따라 판단 | 제외할 주소가 많으면 도메인 제외 검토 |
| **제목 기반**으로 광고/스팸 메일을 제외하려 할 때 | `EXCLUDED_SUBJECT_KEYWORDS` | `[광고]` → 제목에 포함된 메일 제외 |

---

## 🚀 배포 절차

제외 목록 변경 후 **3단계** 배포가 필요합니다:

### Step 1: Git 커밋 & 푸시

```bash
cd gmail-aoai-taskman-automation
git add scripts/gmail-trigger.gs docs/EXCLUSION-LIST.md
git commit -m "feat: add excluded sender/domain - <사유>"
git push origin main
```

### Step 2: Google Apps Script 배포

#### 방법 A: clasp CLI (권장)

```bash
cd clasp-temp
# Code.js를 최신 gmail-trigger.gs로 교체
cp ../gmail-aoai-taskman-automation/scripts/gmail-trigger.gs Code.js
clasp push
```

#### 방법 B: 수동 교체

1. [script.google.com](https://script.google.com) → **Email2ADO-Trigger** 열기
2. GitHub에서 최신 `scripts/gmail-trigger.gs` 복사
3. 편집기에 붙여넣기 → 저장

### Step 3: 동작 확인

1. Apps Script 편집기에서 `processNewEmails` 실행
2. **View > Logs** 확인:
   ```
   ⏭️ 제외 발신자 건너뛰기: Security alert (from: "Microsoft" <MSSecurity-noreply@microsoft.com>)
   ⏭️ 제외 제목 건너뛰기: [광고] 특별 할인 이벤트 (from: "Sender" <sender@example.com>)
   ```

---

## 📊 로그 형식

제외된 이메일은 Apps Script 로그에 아래 형식으로 기록됩니다:

```
⏭️ 제외 발신자 건너뛰기: <이메일 제목> (from: <발신자 정보>)
⏭️ 제외 제목 건너뛰기: <이메일 제목> (from: <발신자 정보>)
```

### 로그 확인 방법

1. [script.google.com](https://script.google.com) → **Email2ADO-Trigger** 열기
2. 좌측 메뉴 **실행** 클릭
3. 최근 실행 기록에서 **상세 보기** 클릭

---

## 📝 변경 이력

| 날짜 | 버전 | 변경 내용 |
|------|------|----------|
| 2026-02-16 | v1.4.0 | EXCLUDED_SENDERS 4개 주소 추가 (cncf, microsoft email, linuxfoundation), EXCLUDED_SUBJECT_KEYWORDS 추가 ([광고]) |
| 2026-02-16 | v1.3.0 | EXCLUSION-LIST.md 신규 생성, EXCLUDED_SENDERS 3개 주소 추가 |
| 2026-02-07 | v1.2.0 | EXCLUDED_DOMAINS 3개 도메인 추가 (linkedin.com 외) |

---

## 📚 관련 문서

| 문서 | 내용 |
|------|------|
| [GMAIL-INTEGRATION.md](GMAIL-INTEGRATION.md) | Gmail 연동 전체 가이드 |
| [TROUBLESHOOTING.md](TROUBLESHOOTING.md) | 문제 해결 가이드 |
| [CHANGELOG.md](CHANGELOG.md) | 전체 변경 이력 |
