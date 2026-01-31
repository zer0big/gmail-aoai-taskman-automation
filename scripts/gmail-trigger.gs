/**
 * ============================================================================
 * Gmail → Email2ADO-HTTP 자동 연동 스크립트
 * ============================================================================
 * 
 * 목적: Gmail에서 새 이메일 수신 시 Email2ADO-HTTP Logic App 워크플로우 호출
 * 버전: 1.0.0
 * 작성일: 2026-01-31
 * 
 * 📚 설정 방법:
 * 1. Google Apps Script (https://script.google.com) 접속
 * 2. 새 프로젝트 생성
 * 3. 이 코드 붙여넣기
 * 4. WEBHOOK_URL을 실제 Logic App 트리거 URL로 변경
 * 5. processNewEmails 함수에 트리거 설정 (5분 간격 권장)
 * 
 * 📌 주의사항:
 * - Gmail 레이블 "Email2ADO" 생성 필요
 * - 처리된 이메일은 "Email2ADO/Processed" 레이블로 이동
 * ============================================================================
 */

// ============================================================================
// 🔧 설정 (수정 필요)
// ============================================================================

/**
 * Email2ADO-HTTP Logic App 워크플로우 트리거 URL
 * Azure Portal > Logic App > Workflows > Email2ADO-HTTP > Overview > Workflow URL
 */
const WEBHOOK_URL = "https://email2ado-logic-prod.azurewebsites.net/api/Email2ADO-HTTP/triggers/When_a_HTTP_request_is_received/invoke?api-version=2022-05-01&sp=%2Ftriggers%2FWhen_a_HTTP_request_is_received%2Frun&sv=1.0&sig=YOUR_SIGNATURE_HERE";

/**
 * 처리할 Gmail 레이블
 * 이 레이블이 있는 이메일만 처리됨
 */
const SOURCE_LABEL = "Email2ADO";

/**
 * 처리 완료 후 이동할 레이블
 */
const PROCESSED_LABEL = "Email2ADO/Processed";

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
        
        try {
          const result = sendToLogicApp(message);
          
          if (result.success) {
            Logger.log(`✅ 처리 성공: ${message.getSubject()}`);
            message.markRead();
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
// 🔗 Logic App 호출
// ============================================================================

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
    const response = UrlFetchApp.fetch(WEBHOOK_URL, options);
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
    const response = UrlFetchApp.fetch(WEBHOOK_URL, options);
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
