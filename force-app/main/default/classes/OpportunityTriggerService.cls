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
   */
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

    // Create a map of opportunity ID to lead for easy lookup
    Map<Id, Lead> opportunityToLeadMap = new Map<Id, Lead>();
    for (Lead lead : convertedLeads) {
      opportunityToLeadMap.put(lead.ConvertedOpportunityId, lead);
    }

    // Update the opportunities with the converted lead information
    for (Opportunity opp : newOpportunities) {
      if (opportunityToLeadMap.containsKey(opp.Id)) {
        Lead convertedLead = opportunityToLeadMap.get(opp.Id);
        // Later we might want to update other fields as well
        opp.Converted_Lead__c = convertedLead.Id;
      }
    }

    // Update the opportunities if any were modified
    if (!newOpportunities.isEmpty()) {
      update newOpportunities;
    }
  }
}
