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

      FROM Contract
      WHERE Id = :contractId
      LIMIT 1
    ];
  }
}
