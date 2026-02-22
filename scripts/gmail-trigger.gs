/**
 * ============================================================================
 * Gmail → Email2ADO-HTTP 자동 연동 스크립트
 * ============================================================================
 * 
 * 목적: Gmail에서 새 이메일 수신 시 Email2ADO-HTTP Logic App 워크플로우 호출
 * 버전: 1.5.0
 * 수정일: 2026-02-22
 * 변경: PIM digest/CONGRATULATIONS 제목 필터 + 발신자 2건 추가 + 중복 생성 방지 로직
 * 작성일: 2026-01-31
 * 
 * 📚 초기 설정 방법:
 * 1. Google Apps Script (https://script.google.com) 접속
 * 2. 새 프로젝트 생성
 * 3. 이 코드 붙여넣기
 * 4. 🔐 setWebhookUrl() 함수 실행하여 URL 설정 (최초 1회)
 * 5. processNewEmails 함수에 트리거 설정 (5분 간격 권장)
 * 
 * 🔐 보안:
 * - Webhook URL은 Script Properties에 암호화되어 저장됨
 * - 코드에 민감 정보 하드코딩 금지
 * 
 * 📌 주의사항:
 * - Gmail 레이블 "Email2ADO" 생성 필요
 * - 처리된 이메일은 "Email2ADO/Processed" 레이블로 이동
 * ============================================================================
 */

// ============================================================================
// 🔧 설정
// ============================================================================

/**
 * 처리할 Gmail 레이블
 * 이 레이블이 있는 이메일만 처리됨
 */
const SOURCE_LABEL = "Email2ADO";

/**
 * 처리 완료 후 이동할 레이블
 */
const PROCESSED_LABEL = "Email2ADO/Processed";

/**
 * 제외할 발신자 도메인 목록
 * 이 도메인에서 발송된 이메일은 처리하지 않고 건너뜀
 */
const EXCLUDED_DOMAINS = [
  "linkedin.com",
  "e.linkedin.com",
  "linkedin.mktgcenter.com"
];

/**
 * 제외할 특정 발신자 이메일 주소 목록
 * 이 주소에서 발송된 이메일은 처리하지 않고 건너뜀
 */
const EXCLUDED_SENDERS = [
  "no-reply@appmail.pluralsight.com",
  "mssecurity-noreply@microsoft.com",
  "pgievent@microsoft.com",
  "no-reply@cncf.io",
  "replyto@email.microsoft.com",
  "email@email.microsoft.com",
  "no-reply@linuxfoundation.org",
  "noreply@microsoft.com",
  "m365dev@microsoft.com"
];

/**
 * 제외할 이메일 제목 키워드 목록
 * 제목에 이 키워드가 포함된 이메일은 처리하지 않고 건너뜀
 */
const EXCLUDED_SUBJECT_KEYWORDS = [
  "[광고]",
  "Your weekly PIM digest",
  "CONGRATULATIONS"
];

/**
 * 중복 처리 방지를 위한 Script Properties 키
 */
const PROCESSED_IDS_KEY = 'PROCESSED_MESSAGE_IDS';

/**
 * 중복 처리 방지를 위한 최대 보관 기간 (밀리초, 7일)
 */
const DEDUP_RETENTION_MS = 7 * 24 * 60 * 60 * 1000;

/**
 * Webhook URL을 Script Properties에서 가져옴
 * @returns {string} Webhook URL
 */
function getWebhookUrl() {
  const url = PropertiesService.getScriptProperties().getProperty('WEBHOOK_URL');
  if (!url) {
    throw new Error('❌ WEBHOOK_URL이 설정되지 않았습니다. setWebhookUrl() 함수를 먼저 실행하세요.');
  }
  return url;
}

/**
 * 🔐 Webhook URL 설정 (최초 1회 실행 필요)
 * 
 * 사용법:
 * 1. Apps Script 에디터에서 이 함수 선택
 * 2. 실행 버튼 클릭
 * 3. 프롬프트에 Logic App Workflow URL 입력
 */
function setWebhookUrl() {
  const ui = SpreadsheetApp.getUi ? SpreadsheetApp.getUi() : null;
  
  // 프롬프트가 없는 환경(standalone script)에서는 Logger로 안내
  if (!ui) {
    Logger.log('========================================');
    Logger.log('🔐 Webhook URL 설정 방법:');
    Logger.log('1. File > Project properties > Script properties');
    Logger.log('2. Add property: WEBHOOK_URL');
    Logger.log('3. Value: Azure Logic App Workflow URL (트리거 URL)');
    Logger.log('========================================');
    Logger.log('');
    Logger.log('또는 아래 코드를 직접 실행:');
    Logger.log('PropertiesService.getScriptProperties().setProperty("WEBHOOK_URL", "YOUR_URL_HERE");');
    return;
  }
  
  const result = ui.prompt(
    'Webhook URL 설정',
    'Email2ADO-HTTP Logic App Workflow URL을 입력하세요:',
    ui.ButtonSet.OK_CANCEL
  );
  
  if (result.getSelectedButton() === ui.Button.OK) {
    const url = result.getResponseText().trim();
    if (url) {
      PropertiesService.getScriptProperties().setProperty('WEBHOOK_URL', url);
      ui.alert('✅ Webhook URL이 안전하게 저장되었습니다.');
    }
  }
}

/**
 * 현재 설정된 URL 확인 (마스킹 처리)
 */
function checkWebhookUrl() {
  try {
    const url = getWebhookUrl();
    const masked = url.substring(0, 50) + '...[MASKED]';
    Logger.log(`✅ Webhook URL 설정됨: ${masked}`);
  } catch (e) {
    Logger.log(e.message);
  }
}

// ============================================================================
// 📧 메인 함수
// ============================================================================

/**
 * 새 이메일 처리 (트리거로 실행)
 * 설정: Edit > Current project's triggers > Add Trigger
 *       - Function: processNewEmails
 *       - Event source: Time-driven
 *       - Type: Minutes timer
 *       - Interval: Every 5 minutes
 */
function processNewEmails() {
  try {
    // 소스 레이블 확인/생성
    let sourceLabel = GmailApp.getUserLabelByName(SOURCE_LABEL);
    if (!sourceLabel) {
      sourceLabel = GmailApp.createLabel(SOURCE_LABEL);
      Logger.log(`레이블 생성됨: ${SOURCE_LABEL}`);
    }
    
    // 처리 완료 레이블 확인/생성
    let processedLabel = GmailApp.getUserLabelByName(PROCESSED_LABEL);
    if (!processedLabel) {
      processedLabel = GmailApp.createLabel(PROCESSED_LABEL);
      Logger.log(`레이블 생성됨: ${PROCESSED_LABEL}`);
    }
    
    // 소스 레이블의 스레드 가져오기
    const threads = sourceLabel.getThreads(0, 10); // 최대 10개씩 처리
    
    if (threads.length === 0) {
      Logger.log("처리할 새 이메일 없음");
      return;
    }
    
    Logger.log(`처리할 이메일 스레드: ${threads.length}개`);
    
    for (const thread of threads) {
      const messages = thread.getMessages();
      
      for (const message of messages) {
        // 이미 읽은 메시지는 건너뛰기 (선택적)
        // if (message.isRead()) continue;
        
        // 중복 처리 방지 체크
        const msgId = message.getId();
        if (isAlreadyProcessed(msgId)) {
          Logger.log('⏭️ 중복 메시지 건너뛰기: ' + message.getSubject() + ' (id: ' + msgId + ')');
          continue;
        }
        
        // 제외 발신자 필터링 (도메인 + 주소)
        const sender = message.getFrom();
        if (isExcludedSender(sender)) {
          Logger.log('⏭️ 제외 발신자 건너뛰기: ' + message.getSubject() + ' (from: ' + sender + ')');
          continue;
        }
        
        // 제외 제목 키워드 필터링
        const subject = message.getSubject();
        if (isExcludedSubject(subject)) {
          Logger.log('⏭️ 제외 제목 건너뛰기: ' + subject + ' (from: ' + sender + ')');
          continue;
        }
        try {
          const result = sendToLogicApp(message);
          
          if (result.success) {
            Logger.log(`✅ 처리 성공: ${message.getSubject()}`);
            message.markRead();
            markAsProcessed(message.getId());
          } else {
            Logger.log(`❌ 처리 실패: ${message.getSubject()} - ${result.error}`);
          }
        } catch (e) {
          Logger.log(`❌ 예외 발생: ${message.getSubject()} - ${e.message}`);
        }
      }
      
      // 처리 완료 레이블로 이동
      thread.removeLabel(sourceLabel);
      thread.addLabel(processedLabel);
    }
    
    Logger.log("이메일 처리 완료");
    
  } catch (e) {
    Logger.log(`❌ 오류 발생: ${e.message}`);
    throw e;
  }
}

// ============================================================================
// � 제외 필터 + �🔗 Logic App 호출
// ============================================================================

/**
 * 제외 대상 발신자인지 확인 (도메인 또는 특정 주소)
 * @param {string} from - 발신자 정보
 * @returns {boolean} 제외 대상이면 true
 */
function isExcludedSender(from) {
  const emailMatch = from.match(/<(.+)>/);
  const senderEmail = (emailMatch ? emailMatch[1] : from).toLowerCase();
  
  // 도메인 기반 제외 체크
  const domainExcluded = EXCLUDED_DOMAINS.some(domain => senderEmail.endsWith('@' + domain) || senderEmail.endsWith('.' + domain));
  if (domainExcluded) return true;
  
  // 특정 발신자 주소 제외 체크
  return EXCLUDED_SENDERS.some(addr => senderEmail === addr.toLowerCase());
}

/**
 * 제외 대상 제목인지 확인 (키워드 포함 여부)
 * @param {string} subject - 이메일 제목
 * @returns {boolean} 제외 대상이면 true
 */
function isExcludedSubject(subject) {
  if (!subject) return false;
  const subjectLower = subject.toLowerCase();
  return EXCLUDED_SUBJECT_KEYWORDS.some(keyword => subjectLower.includes(keyword.toLowerCase()));
}

// ============================================================================
// 🔄 중복 방지
// ============================================================================

/**
 * 이미 처리된 메시지인지 확인
 * @param {string} messageId - Gmail 메시지 ID
 * @returns {boolean} 이미 처리된 경우 true
 */
function isAlreadyProcessed(messageId) {
  const processed = getProcessedIds();
  return processed.some(entry => entry.id === messageId);
}

/**
 * 처리된 메시지 ID 기록
 * @param {string} messageId - Gmail 메시지 ID
 */
function markAsProcessed(messageId) {
  const processed = getProcessedIds();
  processed.push({ id: messageId, ts: Date.now() });
  saveProcessedIds(processed);
}

/**
 * 처리된 메시지 ID 목록 가져오기 (만료된 항목 자동 정리)
 * @returns {Array<{id: string, ts: number}>}
 */
function getProcessedIds() {
  const props = PropertiesService.getScriptProperties();
  const raw = props.getProperty(PROCESSED_IDS_KEY);
  if (!raw) return [];
  
  try {
    const entries = JSON.parse(raw);
    const cutoff = Date.now() - DEDUP_RETENTION_MS;
    return entries.filter(e => e.ts > cutoff);
  } catch (e) {
    Logger.log('⚠️ 처리 ID 파싱 오류, 초기화: ' + e.message);
    return [];
  }
}

/**
 * 처리된 메시지 ID 목록 저장
 * @param {Array<{id: string, ts: number}>} entries
 */
function saveProcessedIds(entries) {
  const props = PropertiesService.getScriptProperties();
  props.setProperty(PROCESSED_IDS_KEY, JSON.stringify(entries));
}

/**
 * Email2ADO-HTTP Logic App에 이메일 데이터 전송
 * @param {GmailMessage} message - Gmail 메시지 객체
 * @returns {Object} 처리 결과 {success: boolean, error?: string}
 */
function sendToLogicApp(message) {
  const messageId = message.getId();
  const subject = message.getSubject();
  const body = message.getPlainBody();
  const from = message.getFrom();
  const receivedTime = message.getDate();
  
  // 발신자 이메일 추출
  const emailMatch = from.match(/<(.+)>/);
  const senderEmail = emailMatch ? emailMatch[1] : from;
  
  // Logic App 요청 페이로드
  const payload = {
    messageId: `gmail-${messageId}`,
    subject: subject,
    body: body.substring(0, 5000), // 본문 길이 제한 (5000자)
    from: senderEmail,
    receivedDateTime: receivedTime.toISOString(),
    source: "Gmail-AppsScript"
  };
  
  const options = {
    method: "POST",
    contentType: "application/json",
    payload: JSON.stringify(payload),
    muteHttpExceptions: true,
    headers: {
      "User-Agent": "Gmail-AppsScript/1.0"
    }
  };
  
  try {
    const webhookUrl = getWebhookUrl();
    const response = UrlFetchApp.fetch(webhookUrl, options);
    const statusCode = response.getResponseCode();
    
    if (statusCode >= 200 && statusCode < 300) {
      return { success: true };
    } else {
      return { 
        success: false, 
        error: `HTTP ${statusCode}: ${response.getContentText().substring(0, 200)}` 
      };
    }
  } catch (e) {
    return { success: false, error: e.message };
  }
}

// ============================================================================
// 🧪 테스트 함수
// ============================================================================

/**
 * 수동 테스트용 함수
 * Apps Script 에디터에서 직접 실행하여 테스트
 */
function testWebhook() {
  const testPayload = {
    messageId: `test-${Date.now()}`,
    subject: "[Apps Script Test] Gmail 연동 테스트",
    body: "이 메시지는 Google Apps Script에서 전송된 테스트 메시지입니다.",
    from: "test@gmail.com",
    receivedDateTime: new Date().toISOString(),
    source: "Gmail-AppsScript-Test"
  };
  
  const options = {
    method: "POST",
    contentType: "application/json",
    payload: JSON.stringify(testPayload),
    muteHttpExceptions: true
  };
  
  try {
    const webhookUrl = getWebhookUrl();
    const response = UrlFetchApp.fetch(webhookUrl, options);
    Logger.log(`Status: ${response.getResponseCode()}`);
    Logger.log(`Response: ${response.getContentText()}`);
  } catch (e) {
    Logger.log(`Error: ${e.message}`);
  }
}

/**
 * 레이블 생성 테스트
 */
function createLabels() {
  let sourceLabel = GmailApp.getUserLabelByName(SOURCE_LABEL);
  if (!sourceLabel) {
    sourceLabel = GmailApp.createLabel(SOURCE_LABEL);
    Logger.log(`✅ 레이블 생성: ${SOURCE_LABEL}`);
  } else {
    Logger.log(`ℹ️ 레이블 이미 존재: ${SOURCE_LABEL}`);
  }
  
  let processedLabel = GmailApp.getUserLabelByName(PROCESSED_LABEL);
  if (!processedLabel) {
    processedLabel = GmailApp.createLabel(PROCESSED_LABEL);
    Logger.log(`✅ 레이블 생성: ${PROCESSED_LABEL}`);
  } else {
    Logger.log(`ℹ️ 레이블 이미 존재: ${PROCESSED_LABEL}`);
  }
}
