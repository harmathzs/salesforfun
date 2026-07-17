public with sharing class ContractPDFcontroller {
  public Id recordId {get; set;}
  public Contract contract {get; set;}

  public ContractPDFcontroller(ApexPages.StandardController controller) {
    if (controller!=null) {
      recordId = controller.getId();
      contract = (Contract) controller.getRecord();
    }
  }

  public ContractPDFcontroller(Id recordId) {
    this.recordId = recordId;
    contract = queryContract(recordId);
  }

  public ContractPDFcontroller(Contract contract) {
    recordId = contract.Id;
    this.contract = contract;
  }

  public ContractPDFcontroller() {
    if (ApexPages.currentPage().getParameters().containsKey('id')) {
      recordId = ApexPages.currentPage().getParameters().get('id');
      contract = queryContract(recordId);
    }
  }

  @AuraEnabled(cacheable=true)
  public static Contract queryContract(Id contractId) {
    if (String.isBlank(contractId)) return null;

    return [
      SELECT Id
        ,ContractNumber
        ,AccountId
        ,Account.Name
        ,CompanySignedId
        ,CompanySigned.Name
        ,CompanySignedDate
        ,CustomerSignedId
        ,CustomerSigned.Name
        ,CustomerSignedDate
        ,StartDate
        ,EndDate
        ,ContractTerm
        ,Description
        ,Opportunity__c
        ,Opportunity__r.Name
        ,Pricebook2Id
        ,SpecialTerms
        ,Status
        ,Total_Price__c
        ,(SELECT Id
          ,Name
          ,Description__c
          ,Opportunity__c
          ,Product__c
          ,Product__r.Name
          ,Quantity__c
          ,Unit_Price__c
          ,Subtotal_Price__c
        FROM Contract_Line_Items__r)
      FROM Contract
      WHERE Id = :contractId
      LIMIT 1
    ];
  }

  @AuraEnabled
  public static String getVFUrl(Id contractId){
    // build absolute Visualforce page URL
    String url = URL.getOrgDomainUrl().toExternalForm() + '/apex/ContractPDF?id=' + String.valueOf(contractId);
    return url;
  }

  @AuraEnabled
  public static void savePdfToContract(Id contractId){
    if (contractId==null) return;
    // generate PDF content from VF page
    PageReference pr = Page.ContractPDF;
    pr.getParameters().put('id', String.valueOf(contractId));
    Blob pdfBlob = pr.getContentAsPDF();

    // create ContentVersion and link to Contract
    // build file name: Contract-<ContractNumber>-YYYYMMDD-HHMMSS.pdf
    Contract c = [SELECT ContractNumber FROM Contract WHERE Id = :contractId LIMIT 1];
    String dt = Datetime.now().format('yyyyMMdd-HHmmss');
    String title = 'Contract-' + (c.ContractNumber == null ? String.valueOf(contractId) : c.ContractNumber) + '-' + dt + '.pdf';

    ContentVersion cv = new ContentVersion();
    cv.Title = title;
    cv.PathOnClient = title;
    cv.VersionData = pdfBlob;
    insert cv;

    // link the ContentDocument to the Contract
    ContentDocumentLink link = new ContentDocumentLink();
    link.ContentDocumentId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
    link.LinkedEntityId = contractId;
    link.ShareType = 'V';
    link.Visibility = 'AllUsers';
    insert link;
  }

  @AuraEnabled
  public static void sendEmailWithPdf(Id contractId, String toAddress, String subject, String body){
    if (contractId==null || String.isBlank(toAddress)) return;
    PageReference pr = Page.ContractPDF;
    pr.getParameters().put('id', String.valueOf(contractId));
    Blob pdfBlob = pr.getContentAsPDF();

    Messaging.EmailFileAttachment efa = new Messaging.EmailFileAttachment();
    efa.setFileName('Contract.pdf');
    efa.setBody(pdfBlob);

    Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
    mail.setToAddresses(new String[]{ toAddress });
    mail.setSubject(subject == null ? 'Contract PDF' : subject);
    mail.setPlainTextBody(body == null ? '' : body);
    mail.setFileAttachments(new Messaging.EmailFileAttachment[]{ efa });

    // try to set org-wide email if available
    List<OrgWideEmailAddress> ow = [SELECT Id FROM OrgWideEmailAddress WHERE Address = 'harmathzs@gmail.com' LIMIT 1];
    if (!ow.isEmpty()){
      mail.setOrgWideEmailAddressId(ow[0].Id);
    }

    Messaging.sendEmail(new Messaging.SingleEmailMessage[]{ mail });
  }
}
