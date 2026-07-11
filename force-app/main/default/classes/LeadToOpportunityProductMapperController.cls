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
      FROM Opportunity
      WHERE Id = :opportunityId
      LIMIT 1
    ];
  }
}
