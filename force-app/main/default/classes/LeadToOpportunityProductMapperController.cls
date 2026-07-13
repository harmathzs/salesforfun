public with sharing class LeadToOpportunityProductMapperController {

  // Helper method to validate line item data
  private static void validateLineItemData(Map<String, Object> itemData) {
    if (itemData == null) {
      throw new AuraHandledException('Line item data cannot be null');
    }

    // Check for required fields
    if (!itemData.containsKey('pricebookEntryId')) {
      throw new AuraHandledException('pricebookEntryId is required');
    }

    if (!itemData.containsKey('quantity')) {
      throw new AuraHandledException('quantity is required');
    }

    if (!itemData.containsKey('unitPrice')) {
      throw new AuraHandledException('unitPrice is required');
    }

    // Validate data types
    try {
      Id pricebookEntryId = (Id)itemData.get('pricebookEntryId');
      Decimal quantity = (Decimal)itemData.get('quantity');
      Decimal unitPrice = (Decimal)itemData.get('unitPrice');

      // Validate quantity
      if (quantity == null || quantity <= 0) {
        throw new AuraHandledException('Quantity must be greater than 0');
      }

      // Validate unit price
      if (unitPrice == null || unitPrice < 0) {
        throw new AuraHandledException('Unit price must be 0 or greater');
      }

    } catch (Exception e) {
      throw new AuraHandledException('Invalid data format: ' + e.getMessage());
    }
  }

  // Helper method to check if opportunity exists and is accessible
  private static void validateOpportunityAccess(String opportunityId) {
    if (String.isBlank(opportunityId)) {
      throw new AuraHandledException('Opportunity ID cannot be blank');
    }

    // Check if opportunity exists and is accessible
    List<Opportunity> opps = [
      SELECT Id
      FROM Opportunity
      WHERE Id = :opportunityId
      LIMIT 1
    ];

    if (opps.isEmpty()) {
      throw new AuraHandledException('Opportunity not found or inaccessible');
    }
  }

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

  @AuraEnabled
  public static void saveOpportunityLineItems(String opportunityId, List<Map<String, Object>> lineItemsToCreate, List<String> lineItemIdsToDelete) {
    // Validate opportunity access
    validateOpportunityAccess(opportunityId);

    List<OpportunityLineItem> itemsToUpsert = new List<OpportunityLineItem>();
    List<OpportunityLineItem> itemsToDelete = new List<OpportunityLineItem>();

    // Process items to create/update
    if (lineItemsToCreate != null && !lineItemsToCreate.isEmpty()) {
      for (Map<String, Object> itemData : lineItemsToCreate) {
        try {
          // Validate line item data using helper method
          validateLineItemData(itemData);

          itemsToUpsert.add(new OpportunityLineItem(
            OpportunityId = opportunityId,
            PricebookEntryId = (Id)itemData.get('pricebookEntryId'),
            Quantity = (Decimal)itemData.get('quantity'),
            UnitPrice = (Decimal)itemData.get('unitPrice')
          ));
        } catch (Exception e) {
          throw new AuraHandledException('Error processing line item: ' + e.getMessage());
        }
      }
    }

    // Process items to delete
    if (lineItemIdsToDelete != null && !lineItemIdsToDelete.isEmpty()) {
      itemsToDelete = [SELECT Id FROM OpportunityLineItem WHERE Id IN :lineItemIdsToDelete];
    }

    System.debug('LeadToOpportunityProductMapperController.saveOpportunityLineItems itemsToUpsert: '+itemsToUpsert);
    System.debug('LeadToOpportunityProductMapperController.saveOpportunityLineItems itemsToDelete: '+itemsToDelete);

    // Perform DML operations
    try {
      // Use partial success to allow some records to save even if others fail
      Database.UpsertResult[] upsertResults = Database.upsert(itemsToUpsert, false);

      // Check for any upsert errors
      for (Database.UpsertResult sr : upsertResults) {
        if (!sr.isSuccess()) {
          for (Database.Error err : sr.getErrors()) {
            throw new AuraHandledException('Error creating/updating line item: ' + err.getMessage());
          }
        }
      }

      // Delete existing items if needed
      if (!itemsToDelete.isEmpty()) {
        delete itemsToDelete;
      }

    } catch (Exception e) {
      throw new AuraHandledException('Error saving opportunity line items: ' + e.getMessage());
    }
  }
}
