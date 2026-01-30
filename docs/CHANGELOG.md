# 📋 변경 이력 (CHANGELOG)

모든 주요 변경 사항을 이 파일에 기록합니다.  
형식은 [Keep a Changelog](https://keepachangelog.com/ko/1.0.0/)를 따릅니다.

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
