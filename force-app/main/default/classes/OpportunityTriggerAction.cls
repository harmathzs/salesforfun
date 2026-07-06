/**
 * Opportunity Trigger Action Handler
 *
 * @author Zsolt Harmath
 * @description Trigger action handler for Opportunity object that extends the Metillium Trigger Framework.
 *              Implements trigger event handlers for before/after insert, update, delete, and undelete operations.
 *
 * @see https://github.com/lfreeland/Saleforce-Trigger-Framework
 */
global with sharing class OpportunityTriggerAction extends mtf.TriggerAction {
  /**
   * Handles before insert trigger events for Opportunity records.
   *
   * @param newRecords List of new Opportunity records being inserted.
   *
   * @description Placeholder for before insert logic. Currently empty but available for future enhancements.
   */
  public override void beforeInsert(List<SObject> newRecords) {}

  /**
   * Handles before update trigger events for Opportunity records.
   *
   * @param oldRecordsMap Map of old Opportunity records keyed by Id.
   * @param newRecordsMap Map of new Opportunity records keyed by Id.
   *
   * @description Placeholder for before update logic. Currently empty but available for future enhancements.
   */
  public override void beforeUpdate(Map<Id, SObject> oldRecordsMap, Map<Id, SObject> newRecordsMap) {}

  /**
   * Handles before delete trigger events for Opportunity records.
   *
   * @param deletedRecordsMap Map of Opportunity records being deleted keyed by Id.
   *
   * @description Placeholder for before delete logic. Currently empty but available for future enhancements.
   */
  public override void beforeDelete(Map<Id, SObject> deletedRecordsMap) {}

  /**
   * Handles after insert trigger events for Opportunity records.
   *
   * @param newRecords List of new Opportunity records that have been inserted.
   *
   * @description Updates the Converted_Lead__c field on Opportunity records with the ID of the Lead that was converted to create the Opportunity.
   *              This method queries the Lead records that were converted to the new Opportunities and updates the Opportunities with the converted Lead information.
   *              The method performs a single update operation to minimize governor limits.
   */
  public override void afterInsert(List<SObject> newRecords) {
    Opportunity[] newOpportunities = newRecords;

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

  /**
   * Handles after update trigger events for Opportunity records.
   *
   * @param oldRecordsMap Map of old Opportunity records keyed by Id.
   * @param newRecordsMap Map of updated Opportunity records keyed by Id.
   *
   * @description Placeholder for after update logic. Currently empty but available for future enhancements.
   */
  public override void afterUpdate(Map<Id, SObject> oldRecordsMap, Map<Id, SObject> newRecordsMap) { }

  /**
   * Handles after delete trigger events for Opportunity records.
   *
   * @param deletedRecordsMap Map of Opportunity records that have been deleted keyed by Id.
   *
   * @description Placeholder for after delete logic. Currently empty but available for future enhancements.
   */
  public override void afterDelete(Map<Id, SObject> deletedRecordsMap) {
    Opportunity[] deletedOpportunities = deletedRecordsMap.values();

    for (Opportunity deletedOpportunity : deletedOpportunities) {

    }
  }

  /**
   * Handles after undelete trigger events for Opportunity records.
   *
   * @param undeletedRecords List of Opportunity records that have been undeleted.
   *
   * @description Placeholder for after undelete logic. Currently empty but available for future enhancements.
   */
  public override void afterUndelete(List<SObject> undeletedRecords) {
    Opportunity[] undeletedOpportunities = undeletedRecords;

    for (Opportunity undeletedOpportunity : undeletedOpportunities) {

    }
  }
}
