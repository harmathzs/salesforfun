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

  @IsTest static void testLineItems() {
    Contract[] contracts = [SELECT Id, Opportunity__c FROM Contract LIMIT 1];
    Contract contract = contracts.get(0);

    Product2[] products = TestFactory.createTestProducts(1);
    Product2 product = products.get(0);
    PricebookEntry pbe = new PricebookEntry(
      Pricebook2Id = Test.getStandardPricebookId(),
      Product2Id = product.Id,
      UnitPrice = 1
    );
    insert pbe;

    Contract_Line_Item__c[] crlis = TestFactory.createTestContractLineItems(contracts, pbe);
    insert crlis;

    ContractPDFcontroller controller = new ContractPDFcontroller(contract);
  }
}
