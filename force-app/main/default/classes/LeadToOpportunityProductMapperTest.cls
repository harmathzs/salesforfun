@IsTest
private class LeadToOpportunityProductMapperTest {
  @TestSetup static void testFactory() {
    Map<String, Object> data = TestFactory.createCompleteTestSetup(1, 1, 1);
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


  }

  @IsTest static void testGetPricebook() {
    LeadToOpportunityProductMapperController.getPricebook(Test.getStandardPricebookId());
  }
}
