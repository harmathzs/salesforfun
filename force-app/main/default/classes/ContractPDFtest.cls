@IsTest
private class ContractPDFtest {

  @TestSetup static void testFactory() {
    Contract[] contracts = TestFactory.createTestContracts(1);
    insert contracts;
  }

  @IsTest
  static void testEmptyConstructor() {
    ContractPDFcontroller controller = new ContractPDFcontroller();
  }

  @IsTest static void testParameter() {
    Contract contract = [SELECT Id FROM Contract LIMIT 1];
    ApexPages.currentPage().getParameters().put('id', contract.Id);
    ContractPDFcontroller controller = new ContractPDFcontroller();
  }

  @IsTest static void testId() {
    Contract contract = [SELECT Id FROM Contract LIMIT 1];
    ContractPDFcontroller controller = new ContractPDFcontroller(contract.Id);
  }

  @IsTest static void testRecord() {
    Contract contract = [SELECT Id FROM Contract LIMIT 1];
    ContractPDFcontroller controller = new ContractPDFcontroller(contract);
  }

  @IsTest static void testStandard() {
    Contract contract = [SELECT Id FROM Contract LIMIT 1];
    ApexPages.StandardController stdController = new ApexPages.StandardController(contract);
    ContractPDFcontroller controller = new ContractPDFcontroller(stdController);
  }
}
