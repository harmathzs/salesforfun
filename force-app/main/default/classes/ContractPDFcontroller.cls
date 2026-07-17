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
}
