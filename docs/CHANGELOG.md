# 📋 변경 이력 (CHANGELOG)

모든 주요 변경 사항을 이 파일에 기록합니다.  
형식은 [Keep a Changelog](https://keepachangelog.com/ko/1.0.0/)를 따릅니다.

---

## [2.3.0] - 2026-01-30 (Phase 9: Security Hardening)

### 🎯 목표 달성
- Azure Well-Architected Framework 보안 점검 및 개선
- 보안 점수 7/10 → 9/10 향상

### 추가됨 (Added)
- 2026-01-30: `Get_ADO_PAT_From_KeyVault` 액션 추가 (MSI + Key Vault 런타임 조회)
- 2026-01-30: Easy Auth 구성 (Microsoft Entra ID 인증)
- 2026-01-30: App Registration `Email2ADO-HTTP-Auth` 생성
- 2026-01-30: `secureData.properties` 민감 데이터 마스킹
- 2026-01-30: `docs/DEPLOY.md` 배포 가이드 신규 작성
- 2026-01-30: `docs/TROUBLESHOOTING.md` 문제 해결 가이드 신규 작성

### 변경됨 (Changed)
- 2026-01-30: `Create_ADO_WorkItem_HTTP`가 Key Vault에서 런타임에 PAT 조회
- 2026-01-30: `local.settings.template.json` OpenAI endpoint 수정 (cognitiveservices.azure.com)
- 2026-01-30: `workflow.json` contentVersion 2.3.0.0으로 업데이트
- 2026-01-30: `README.md` 전면 개정 (보안 아키텍처, Phase 추적 포함)

### 보안 개선 사항
- **SEC-01**: ADO PAT App Settings 노출 → Key Vault 런타임 조회로 해결
- **SEC-02**: HTTP Trigger 무인증 → Easy Auth (Entra ID) 적용
- **SEC-03**: OpenAI endpoint URL 오류 수정

### 배포 정보
- **Workflow Version**: 2.3.0.0
- **App Registration**: Email2ADO-HTTP-Auth (c454a3ed-f41d-4180-82d0-4ab0704fc65c)
- **ADO Work Item**: #218

---

## [2.2.1] - 2026-01-30 (Phase 8: V1 Connector Workaround)

### 🎯 목표 달성
- Logic App Standard에서 V1 커넥터 connectionRuntimeUrl 문제 우회
- Email2ADO-HTTP 워크플로우로 E2E 테스트 성공

### 추가됨 (Added)
- 2026-01-30: `Email2ADO-HTTP` 워크플로우 (HTTP Trigger 방식)
- 2026-01-30: Power Automate Workflow 연동 (Teams Incoming Webhook 대체)
- 2026-01-30: `TEAMS_WORKFLOW_URL` App Setting 추가

### 변경됨 (Changed)
- 2026-01-30: Teams 알림을 Incoming Webhook에서 Power Automate Workflow로 변경

### 알려진 이슈
- V1 커넥터(Gmail, Teams, VSTS)가 Logic App Standard에서 `connectionRuntimeUrl` 미지원
- **해결책**: Email2ADO-HTTP 워크플로우 + 외부 HTTP 호출 사용

### 배포 정보
- **Healthy Workflow**: Email2ADO-HTTP
- **Unhealthy Workflow**: Email2ADO-Gmail (V1 제약으로 비활성)
- **ADO Work Item**: #216

---

## [2.2.0] - 2026-01-30 (Phase 7: Key Vault Integration)

### 🎯 목표 달성
- Key Vault 통합으로 보안 강화
- ADO PAT를 Key Vault에 안전하게 저장

### 추가됨 (Added)
- 2026-01-30: Key Vault 리소스 생성 (kv-zbtask-prod)
- 2026-01-30: Key Vault Bicep 모듈 (infra/modules/key-vault.bicep)
- 2026-01-30: ADO PAT Secret 저장 (ado-pat)
- 2026-01-30: Logic App MSI에 Key Vault Secrets User 역할 부여

### 변경됨 (Changed)
- 2026-01-30: ADO_PAT App Setting을 Key Vault Reference로 변경
- 2026-01-30: logic-app.bicep에 keyVaultName 파라미터 추가
- 2026-01-30: main.bicep에 Key Vault 모듈 통합
- 2026-01-30: ARCHITECTURE.md 보안 섹션 Key Vault 반영
- 2026-01-30: README.md Azure 리소스 테이블에 Key Vault 추가

### 배포 정보
- **Key Vault**: kv-zbtask-prod
- **Secret**: ado-pat (Key Vault Reference로 참조)
- **RBAC**: Logic App MSI에 Key Vault Secrets User 역할

---

## [2.0.0] - 2026-01-30

### 🎯 목표 달성
- Office 365 Outlook 트리거 → Gmail 트리거 전환 완료
- rg-zb-taskman 리소스 그룹에 프로덕션 배포 완료

### 추가됨 (Added)
- 2026-01-30: V1 API Connection MSI 인증 구현
- 2026-01-30: STORAGE_ACCOUNT_NAME App Setting 추가
- 2026-01-29: zbtaskman.bicepparam 파라미터 파일 생성
- 2026-01-29: Gmail 트리거 workflow.json 구현
- 2026-01-29: connections.json MSI 인증 방식 적용

### 변경됨 (Changed)
- 2026-01-30: api-connections.bicep V1 연결 단순화 (Access Policy 제거)
- 2026-01-30: main.bicep 스토리지 이름 길이 제한 수정 (24자)
- 2026-01-30: Azure OpenAI 엔드포인트 도메인 수정 (openai.azure.com)
- 2026-01-30: FUNCTIONS_WORKER_RUNTIME dotnet으로 수정
- 2026-01-29: workflow.json 트리거 섹션 Gmail용으로 변경
- 2026-01-29: 변수 초기화 필드 매핑 Gmail 형식으로 변경

### 제거됨 (Removed)
- 2026-01-30: api-connections.bicep에서 미사용 logicAppPrincipalId 파라미터 제거
- 2026-01-30: connectionRuntimeUrl, CONNECTION_KEY 설정 제거 (V1 MSI 미지원)
- 2026-01-29: Office 365 Outlook 커넥터 제거

### 배포 정보
- **리소스 그룹**: rg-zb-taskman
- **Logic App**: email2ado-logic-prod
- **Storage Account**: stemail2adoprodxhum3jlfa
- **API Connections**: gmail-prod, teams-prod, visualstudioteamservices-prod
- **Azure OpenAI**: zb-taskman (gpt-4o)

---

## [Unreleased] - v2.0.0-dev

### 🎯 목표
- Office 365 Outlook 트리거 → Gmail 트리거 전환

### 추가됨 (Added)
- 2026-01-29: 프로젝트 구조 생성
- 2026-01-29: ADO Epic 및 Phase Issue 생성 (ID: 204-211)
- 2026-01-29: Gmail 전환 프로젝트 시작

### 변경됨 (Changed)
- (예정) workflow.json 트리거 섹션 Gmail용으로 변경
- (예정) 변수 초기화 필드 매핑 변경

### 제거됨 (Removed)
- (예정) Office 365 Outlook 커넥터 제거

---

## [1.0.0] - 2026-01-24

### 추가됨 (Added)
- Office 365 Outlook 메일 트리거
- Table Storage 기반 중복 방지 (Managed Identity)
- Azure OpenAI GPT-4o AI 분석
- Azure DevOps Work Item 자동 생성
- PAT 기반 담당자/태그 할당
- Microsoft Teams 알림

### 알려진 이슈
- VSTS 커넥터에서 AssignedTo, Tags 필드 직접 할당 불가 → HTTP + PAT로 해결
- MSI 직접 ADO 인증 불가 → API Connection V2 + OAuth로 해결

---

## 📝 작성 규칙

### 카테고리
- **추가됨 (Added)**: 새 기능
- **변경됨 (Changed)**: 기존 기능 변경
- **사용 중단 (Deprecated)**: 곧 제거될 기능
- **제거됨 (Removed)**: 제거된 기능
- **수정됨 (Fixed)**: 버그 수정
- **보안 (Security)**: 보안 취약점 수정

### 형식
```
## [버전] - YYYY-MM-DD

### 카테고리
- YYYY-MM-DD: 변경 내용 설명 (@담당자)
```
