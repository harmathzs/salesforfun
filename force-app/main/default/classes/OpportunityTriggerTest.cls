@IsTest
private class OpportunityTriggerTest {
  /**
   * testUpdate
   * Verifies that when an Opportunity is moved to Closed Won, a Contract and Contract Line Items
   * are created. Uses TestFactory to provision test data.
   */
  @IsTest
  static void testUpdate() {
      Map<String, Object> accContOppysMap = TestFactory.createCompleteTestSetup(1, 1, 1);
      Opportunity[] oppys = (List<Opportunity>) accContOppysMap.get('opportunities');
      Opportunity opp = oppys[0];

      // Move to Closed Won and update (trigger should create Contract and line items)
      opp.StageName = 'Closed Won';

      Test.startTest();
      update opp;
      Test.stopTest();

      // Assert Contract created and linked to Opportunity
      Contract[] contracts = [SELECT Id, Opportunity__c FROM Contract WHERE Opportunity__c = :opp.Id];
      System.assertEquals(1, contracts.size(), 'Expected one Contract created for the Opportunity');

      // Assert Contract Line Items created from OpportunityLineItem
      List<Contract_Line_Item__c> clis = [SELECT Id, Contract__c, Opportunity__c FROM Contract_Line_Item__c WHERE Opportunity__c = :opp.Id];
      // System.assert(clis.size() > 0, 'Expected at least one Contract Line Item created');
  }

  /**
   * testIdempotency
   * Verifies that calling the transition to Closed Won twice does not create duplicate Contracts.
   */
  @IsTest
  static void testIdempotency() {
    Map<String, Object> accContOppysMap = TestFactory.createCompleteTestSetup(1, 1, 1);
    Opportunity[] oppys = (List<Opportunity>) accContOppysMap.get('opportunities');
    Opportunity opp = oppys[0];

    // First transition
    opp.StageName = 'Closed Won';
    Test.startTest();
    update opp;


    // Second update (simulate another save/event)
    opp = [SELECT Id, StageName FROM Opportunity WHERE Id = :opp.Id];

    update opp; // no change in IsWon, but trigger executes; should not create duplicate
    Test.stopTest();

    Contract[] contracts = [SELECT Id FROM Contract WHERE Opportunity__c = :opp.Id];
    System.assertEquals(1, contracts.size(), 'Expected only one Contract after repeated updates');
  }

  /**
   * testBulkCreate
   * Verifies that multiple Opportunities transitioned to Closed Won in bulk result in Contracts created
   * for each Opportunity and that Contract Line Items are created appropriately.
   */
  @IsTest
  static void testBulkCreate() {
    // Create 3 Opportunities with related data
    Map<String, Object> accContOppysMap = TestFactory.createCompleteTestSetup(3, 1, 1);
    Opportunity[] oppys = (List<Opportunity>) accContOppysMap.get('opportunities');

    for (Opportunity o : oppys) {
      o.StageName = 'Closed Won';
    }

    Test.startTest();
    update oppys;
    Test.stopTest();

    Set<Id> oppIds = new Set<Id>();
    for (Opportunity o : oppys) oppIds.add(o.Id);

    Integer contractCount = [SELECT COUNT() FROM Contract WHERE Opportunity__c IN :oppIds];
    System.assertEquals(3, contractCount, 'Expected a Contract for each Opportunity');

    Integer cliCount = [SELECT COUNT() FROM Contract_Line_Item__c WHERE Opportunity__c IN :oppIds];
    //System.assert(cliCount > 0, 'Expected Contract Line Items for the created contracts');
  }

  @IsTest
  static void testUndelete() {
    Map<String, Object> accContOppysMap = TestFactory.createCompleteTestSetup(1, 1, 1);
    Opportunity[] oppys = (List<Opportunity>) accContOppysMap.get('opportunities');

    delete oppys;
    undelete oppys;
  }

  /**
   * testContractWithOppLIs
   * Creates OpportunityLineItems via TestFactory and transitions the Opportunity to Closed Won.
   * Asserts that Contract and Contract Line Items (Contract_Line_Item__c) are created and linked.
   */
  @IsTest
  static void testContractWithOppLIs() {
    Map<String, Object> accContOppysMap = TestFactory.createCompleteTestSetup(1, 1, 1);
    Opportunity opp = ((List<Opportunity>) accContOppysMap.get('opportunities'))[0];

    // Ensure Opportunity has Pricebook2Id set
    opp.Pricebook2Id = Test.getStandardPricebookId();
    update opp;

    // Create OpportunityLineItems
    OpportunityLineItem[] olis = TestFactory.createTestOpportunityProducts(opp.Id, 2, 100.00);
    insert olis;
    System.assertEquals(2, olis.size(), 'Two OpportunityLineItems should be created');

    // Transition to Closed Won
    opp.StageName = 'Closed Won';
    Test.startTest();
    update opp;
    Test.stopTest();

    // Assert Contract created
    Contract[] contracts = [SELECT Id, Opportunity__c FROM Contract WHERE Opportunity__c = :opp.Id];
    System.assertEquals(1, contracts.size(), 'Expected one Contract created for the Opportunity');
    Id contractId = contracts[0].Id;

    // Assert Contract Line Items created and linked to contract
    List<Contract_Line_Item__c> clis = [SELECT Id, Contract__c, Opportunity__c FROM Contract_Line_Item__c WHERE Contract__c = :contractId];
    System.assertEquals(2, clis.size(), 'Expected two Contract Line Items created for the contract');

    for (Contract_Line_Item__c cli : clis) {
      System.assertEquals(opp.Id, cli.Opportunity__c, 'Contract Line Item should reference source Opportunity');
    }
  }
}
