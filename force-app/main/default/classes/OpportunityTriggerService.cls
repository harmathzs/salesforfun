/**
 * Opportunity Trigger Service Layer
 *
 * @author Zsolt Harmath
 * @description Service class containing business logic for Opportunity trigger operations.
 *              Separates trigger logic from trigger handlers following separation of concerns principle.
 *
 * @see https://github.com/lfreeland/Saleforce-Trigger-Framework
 */
public with sharing class OpportunityTriggerService {

  /**
   * Updates opportunities with converted lead information.
   *
   * @param newOpportunities List of Opportunity records that have been inserted.
   *
   * @description Queries the Lead records that were converted to create the Opportunities
   *              and updates the Opportunities with the converted Lead information.
   *              Specifically sets the Converted_Lead__c field on each Opportunity to the ID
   *              of the Lead that was converted to create it.
   *
   * @example
   * // After insert trigger context
   * OpportunityTriggerService.updateConvertedLead(Trigger.new);
   *
   * @note This method performs a single update operation to minimize governor limits.
   * @note Only processes opportunities that have a corresponding converted lead.
   * @note Creates a new list for DML operations to avoid modifying trigger context variables directly.
   */
/*
  public static void updateConvertedLead(List<Opportunity> newOpportunities) {
    // Get the IDs of the new opportunities
    Set<Id> opportunityIds = new Set<Id>();
    for (Opportunity opp : newOpportunities) {
      opportunityIds.add(opp.Id);
    }

    // Query the leads that were converted to these opportunities
    List<Lead> convertedLeads = [
      SELECT Id, FirstName, LastName, Email, Company
      FROM Lead
      WHERE ConvertedOpportunityId IN :opportunityIds
    ];
    System.debug('convertedLeads: '+convertedLeads);

    // Create a map of opportunity ID to lead for easy lookup
    Map<Id, Lead> opportunityToLeadMap = new Map<Id, Lead>();
    for (Lead lead : convertedLeads) {
      opportunityToLeadMap.put(lead.ConvertedOpportunityId, lead);
    }
    System.debug('opportunityToLeadMap: '+opportunityToLeadMap);

    // Create a new list for opportunities that need to be updated
    List<Opportunity> opportunitiesToUpdate = new List<Opportunity>();

    // Update the opportunities with the converted lead information
    for (Opportunity opp : newOpportunities) {
      if (opportunityToLeadMap.containsKey(opp.Id)) {
        Lead convertedLead = opportunityToLeadMap.get(opp.Id);
        // Create a new opportunity record for update to avoid DML on trigger context variables
        Opportunity oppToUpdate = new Opportunity(
          Id = opp.Id,
          Converted_Lead__c = convertedLead.Id
        );
        opportunitiesToUpdate.add(oppToUpdate);
      }
    }
    System.debug('opportunitiesToUpdate: '+opportunitiesToUpdate);

    // Update the opportunities if any were modified
    if (!opportunitiesToUpdate.isEmpty()) {
      update opportunitiesToUpdate;
      System.debug('Updated opportunitiesToUpdate: '+opportunitiesToUpdate);
    }
  }

 */
  public static void setPricebook(List<Opportunity> newOpportunities) {
    Integer thisYear = Date.today().year();
    String pricebookName = 'Price Book ' + thisYear;

    // Query for the specific pricebook name
    Pricebook2[] pricebooks = [SELECT Id, Name FROM Pricebook2 WHERE Name = :pricebookName];
    Pricebook2 pricebook = null;
    if (pricebooks.isEmpty()) {
      pricebooks = [SELECT Id, Name FROM Pricebook2 WHERE Name = 'Standard Price Book'];
    }
    Id pricebookId = null;
    if (!pricebooks.isEmpty()) {
      pricebook = pricebooks.get(0);
      pricebookId = pricebook.Id;
    }
    if (Test.isRunningTest()) {
      pricebookId = Test.getStandardPricebookId();
    }

    for (Opportunity oppy: newOpportunities) {
      if (String.isBlank(oppy.Pricebook2Id)) {
          oppy.Pricebook2Id = pricebookId;
      }
    }
  }

  public static Contract[] createContracts(Map<Id, SObject> oldOpportunitiesMap, Map<Id, SObject> newOpportunitiesMap) {
    if (newOpportunitiesMap==null) return null;
    if (newOpportunitiesMap.isEmpty()) return null;

    Contract[] contractsToInsert = new List<Contract>();

    for (Id opportunityId: newOpportunitiesMap.keySet()) {
      Opportunity oldOpportunity = (Opportunity) oldOpportunitiesMap.get(opportunityId);
      Opportunity newOpportunity = (Opportunity) newOpportunitiesMap.get(opportunityId);
      if (!oldOpportunity.IsWon && newOpportunity.IsWon) {
        Contract contract = new Contract(
          AccountId = newOpportunity.AccountId,
          Pricebook2Id = newOpportunity.Pricebook2Id
        );
        contractsToInsert.add(contract);
      }
    }

    if (!contractsToInsert.isEmpty()) {
      insert contractsToInsert;
    }
    // TODO: insert contract line items from opportunity products

    return contractsToInsert;
  }
}
