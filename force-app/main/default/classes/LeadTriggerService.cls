/** Metillium Trigger Framework from https://github.com/lfreeland/Saleforce-Trigger-Framework */
public with sharing class LeadTriggerService {
  /**
   * @description Copy Web-to-Lead Description to Product Interest.
   *
   * @param newLeads Leads before insert.
   *
   *
   * */
  public static void copyDescriptionToProductInterestBI(List<Lead> newLeads) {
    for (Lead newLead: newLeads) {
      if (newLead.LeadSource == 'Web' && String.isNotBlank(newLead.Description)) {
        newLead.ProductInterest__c = newLead.Description;
      }
    }
  }
}
