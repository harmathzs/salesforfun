/** Metillium Trigger Framework from https://github.com/lfreeland/Saleforce-Trigger-Framework */
global with sharing class LeadTriggerAction extends mtf.TriggerAction {
  public override void beforeInsert(List<SObject> newRecords) {
    // copy Web-to-Lead Description to Product Interest
    LeadTriggerService.copyDescriptionToProductInterestBI(newRecords);
  }

  public override void beforeUpdate(Map<Id, SObject> oldRecordsMap, Map<Id, SObject> newRecordsMap) {}

  public override void beforeDelete(Map<Id, SObject> deletedRecordsMap) {}

  public override void afterInsert(List<SObject> newRecords) {
    Lead[] newLeads = newRecords;

    for (Lead newLead : newLeads) {

    }
  }

  public override void afterUpdate(Map<Id, SObject> oldRecordsMap, Map<Id, SObject> newRecordsMap) { }

  public override void afterDelete(Map<Id, SObject> deletedRecordsMap) {
    Lead[] deletedLeads = deletedRecordsMap.values();

    for (Lead deletedLead : deletedLeads) {

    }
  }

  public override void afterUndelete(List<SObject> undeletedRecords) {
    Lead[] undeletedLeads = undeletedRecords;

    for (Lead undeletedLead : undeletedLeads) {

    }
  }

}
