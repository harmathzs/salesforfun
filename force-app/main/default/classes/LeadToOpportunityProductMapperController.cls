public with sharing class LeadToOpportunityProductMapperController {
  @AuraEnabled
  public static Opportunity getOpportunity(String opportunityId) {
    return [
      SELECT Id
        ,Name
        ,Converted_Lead__c
        ,Converted_Lead__r.ProductInterest__c
        ,Pricebook2Id
        ,Pricebook2.Name
        ,(SELECT Id
          ,Name
          ,Product2Id
          ,Product2.Name
          ,Quantity
          ,UnitPrice
          ,ListPrice
          ,TotalPrice
        FROM OpportunityLineItems)
      FROM Opportunity
      WHERE Id = :opportunityId
      LIMIT 1
    ];
  }

  @AuraEnabled
  public static Pricebook2 getPricebook(String pricebookId) {
    return [
      SELECT Id
        ,Name
        ,(SELECT Id
          ,Name
          ,Product2Id
          ,Product2.Name
          ,UnitPrice
        FROM PricebookEntries)
      FROM Pricebook2
      WHERE Id = :pricebookId
      LIMIT 1
    ];
  }
}
