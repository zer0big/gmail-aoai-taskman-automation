# Bicep 배포 가이드

## 사전 요구사항
- Azure CLI 설치
- Bicep CLI 설치
- Azure 구독

## 배포 단계

### 1. 리소스 그룹 생성
```powershell
az group create --name rg-email2ado --location koreacentral
```

### 2. Bicep 배포
```powershell
az deployment group create `
  --resource-group rg-email2ado `
  --template-file infra/main.bicep `
  --parameters `
    namePrefix='email2ado' `
    adoOrganization='tdg-zerobig' `
    adoProject='CM-Worker-Demo' `
    teamsWebhookUrl='<your-teams-webhook-url>'
```

### 3. Managed Identity 권한 부여

#### Storage Account (Table Storage)
```powershell
$logicAppPrincipalId = az deployment group show `
  --resource-group rg-email2ado `
  --name main `
  --query properties.outputs.logicAppPrincipalId.value -o tsv

$storageAccountName = az deployment group show `
  --resource-group rg-email2ado `
  --name main `
  --query properties.outputs.storageAccountName.value -o tsv

az role assignment create `
  --assignee $logicAppPrincipalId `
  --role "Storage Table Data Contributor" `
  --scope "/subscriptions/<subscription-id>/resourceGroups/rg-email2ado/providers/Microsoft.Storage/storageAccounts/$storageAccountName"
```

#### Azure DevOps
```powershell
# Azure DevOps 조직에 Managed Identity 추가
# Portal에서 수동 작업 필요: Organization Settings > Service Connections
```

### 4. Office 365 API Connection 생성
```powershell
# Azure Portal에서 수동 생성
# Resource Groups > rg-email2ado > Create > API Connection > Office 365 Outlook
# Authentication: Managed Identity 권장
```

### 5. 워크플로 배포
```powershell
cd Email2ADO-Workflow
func azure functionapp publish <logic-app-name>
```

## 배포 후 확인
```powershell
# Logic App 상태 확인
az logicapp show --resource-group rg-email2ado --name <logic-app-name>

# Application Insights 로그 확인
az monitor app-insights query `
  --app <app-insights-name> `
  --resource-group rg-email2ado `
  --analytics-query "traces | where timestamp > ago(1h) | top 10 by timestamp desc"
```

## 정리
```powershell
az group delete --name rg-email2ado --yes
```