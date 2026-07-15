public with sharing class QuoteToOrderController {
  @AuraEnabled
  public static Boolean isValidId(String rawId) {
    return rawId.length() == 15 || rawId.length() == 18;
  }

  @AuraEnabled
  public static Id parseId(String rawId) {
    return Id.valueOf(rawId);
  }

  @AuraEnabled
  public static String whichSobject(Id recordId) {
    SObjectType sObjectType = recordId.getSobjectType();
    return sObjectType.getDescribe().getName();
  }

  @AuraEnabled
  public static SObject getRecordById(Id recordId, String sObjectName) {
    String soql = 'SELECT Id, Name, AccountId, CreatedDate, Description FROM '+sObjectName+' WHERE Id = :recordId LIMIT 1';
    SObject[] objects = Database.query(soql);
    if (objects.isEmpty()) {
      return null;
    } else {
      return objects.get(0);
    }
  }
}
