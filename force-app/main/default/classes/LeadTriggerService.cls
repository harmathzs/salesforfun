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
}
