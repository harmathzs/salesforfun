@IsTest
private class LeadToOpportunityProductMapperTest {
  @TestSetup static void testFactory() {
    Map<String, Object> data = TestFactory.createCompleteTestSetup(1, 1, 1);
    Product2[] products = TestFactory.createTestProducts(4);
    Id productId = products[0].Id;
    Id[] productIds = new List<Id>{productId};
    PricebookEntry[] pbes = TestFactory.createTestPricebookEntries(productIds, 100);
  }

  @IsTest
  static void testBehavior() {
    Opportunity oppy = [
      SELECT Id
      ,Name
      ,Converted_Lead__c
      ,Converted_Lead__r.ProductInterest__c
      ,Pricebook2Id
      ,Pricebook2.Name
        ,(SELECT Id
        ,Name
        ,PricebookEntryId
        ,Product2Id
        ,Product2.Name
        ,Quantity
        ,UnitPrice
        ,ListPrice
        ,TotalPrice
      FROM OpportunityLineItems)
    FROM Opportunity

    LIMIT 1];

    oppy = LeadToOpportunityProductMapperController.getOpportunity(oppy.Id);

    List<Map<String, Object>> lineItemsToCreate = new List<Map<String, Object>>();
    PricebookEntry pbe = [SELECT Id, Product2Id, UnitPrice FROM PricebookEntry LIMIT 1];
      Map<String, Object> lineItemToCreate = new Map<String, Object>{
        'pricebookEntryId' => pbe.Id,
        'quantity' => 1,
        'unitPrice' => 100
      };
    lineItemsToCreate.add(lineItemToCreate);

    String[] lineItemIdsToDelete = new List<String>();



    LeadToOpportunityProductMapperController.saveOpportunityLineItems(oppy.Id, lineItemsToCreate, lineItemIdsToDelete);

  }

  @IsTest static void testGetPricebook() {
    LeadToOpportunityProductMapperController.getPricebook(Test.getStandardPricebookId());
  }
}
