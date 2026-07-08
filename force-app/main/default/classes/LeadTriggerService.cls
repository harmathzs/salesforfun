/**
 * Lead Trigger Service Layer
 *
 * @author Zsolt Harmath
 * @description Service class containing business logic for Lead trigger operations.
 *              Separates trigger logic from trigger handlers following separation of concerns principle.
 *
 * @see https://github.com/lfreeland/Saleforce-Trigger-Framework
 */
public with sharing class LeadTriggerService {
  /**
   * Copies Web-to-Lead Description to Product Interest field for Web leads.
   *
   * @param newLeads List of Lead records being inserted.
   *
   * @description For leads with LeadSource = 'Web' and non-blank Description,
   *              copies the Description field value to the ProductInterest__c custom field.
   *              This ensures Web-to-Lead form descriptions are properly captured for sales follow-up.
   *
   * @example
   * // Before insert trigger context
   * LeadTriggerService.copyDescriptionToProductInterestBI(Trigger.new);
   *
   * @note Only processes leads where LeadSource = 'Web' and Description is not blank.
   * @note This method is called from the beforeInsert trigger context.
   */
  public static void copyDescriptionToProductInterestBI(List<Lead> newLeads) {
    for (Lead newLead: newLeads) {
      if (newLead.LeadSource == 'Web' && String.isNotBlank(newLead.Description)) {
        newLead.ProductInterest__c = newLead.Description;
      }
    }
  }

  /**
   * Updates opportunities with converted lead information when a lead is converted.
   *
   * @param oldLeadsMap Map of old Lead records keyed by Id.
   * @param newLeadsMap Map of updated Lead records keyed by Id.
   *
   * @description When a lead is converted, this method updates the corresponding opportunity
   *              with the converted lead's ID in the Converted_Lead__c field.
   *              This approach is more reliable than querying from the opportunity side
   *              as it triggers when the lead conversion is complete and the relationship is established.
   *
   * @example
   * // After update trigger context
   * LeadTriggerService.updateConvertedOpportunity(Trigger.oldMap, Trigger.newMap);
   *
   * @note Only processes leads that have been converted (ConvertedOpportunityId is populated).
   * @note Creates a new list for DML operations to avoid modifying trigger context variables.
   */
  public static void updateConvertedOpportunity(Map<Id, SObject> oldLeadsMap, Map<Id, SObject> newLeadsMap) {
    List<Opportunity> opportunitiesToUpdate = new List<Opportunity>();

    // Find leads that were just converted (ConvertedOpportunityId changed from null to a value)
    for (Id leadId : newLeadsMap.keySet()) {
      Lead oldLead = (Lead) oldLeadsMap.get(leadId);
      Lead newLead = (Lead) newLeadsMap.get(leadId);

      // Check if this lead was just converted
      if (oldLead.ConvertedOpportunityId == null && newLead.ConvertedOpportunityId != null) {
        // Create opportunity update record
        Opportunity oppToUpdate = new Opportunity(
          Id = newLead.ConvertedOpportunityId,
          Converted_Lead__c = newLead.Id
        );
        opportunitiesToUpdate.add(oppToUpdate);
      }
    }

    // Update the opportunities if any were found
    if (!opportunitiesToUpdate.isEmpty()) {
      update opportunitiesToUpdate;
    }
  }
}
