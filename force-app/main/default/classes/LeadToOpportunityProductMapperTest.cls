@IsTest
private class LeadToOpportunityProductMapperTest {
  @TestSetup static void testFactory() {
    Map<String, Object> data = TestFactory.createCompleteTestSetup(1, 1, 1);
    Product2[] products = TestFactory.createTestProducts(4);
    Id productId1 = products[0].Id;
    Id productId2 = products[1].Id;
    Id[] productIds = new List<Id>{productId1, productId2};
    PricebookEntry[] pbes = TestFactory.createTestPricebookEntries(productIds, 100);
  }

  @IsTest
  static void testGetOpportunity_Success() {
    Opportunity oppy = [SELECT Id FROM Opportunity LIMIT 1];
    Opportunity result = LeadToOpportunityProductMapperController.getOpportunity(oppy.Id);

    Assert.isNotNull(result, 'Opportunity should be returned');
    Assert.areEqual(oppy.Id, result.Id, 'Opportunity ID should match');
  }

  @IsTest
  static void testSaveOpportunityLineItems_CreateNewLineItem() {
    Opportunity oppy = [SELECT Id FROM Opportunity LIMIT 1];
    PricebookEntry pbe = [SELECT Id, Product2Id, UnitPrice FROM PricebookEntry LIMIT 1];

    List<Map<String, Object>> lineItemsToCreate = new List<Map<String, Object>>{
      new Map<String, Object>{
        'pricebookEntryId' => pbe.Id,
        'quantity' => 1,
        'unitPrice' => 100
      }
    };

    LeadToOpportunityProductMapperController.saveOpportunityLineItems(oppy.Id, lineItemsToCreate, new List<String>());

    List<OpportunityLineItem> items = [SELECT Id, Quantity, UnitPrice FROM OpportunityLineItem WHERE OpportunityId = :oppy.Id];
    Assert.areEqual(1, items.size(), 'One line item should be created');
    Assert.areEqual(1, items[0].Quantity, 'Quantity should be 1');
    Assert.areEqual(100, items[0].UnitPrice, 'Unit price should be 100');
  }

  @IsTest
  static void testSaveOpportunityLineItems_UpdateExistingLineItem() {
    Opportunity oppy = [SELECT Id FROM Opportunity LIMIT 1];
    PricebookEntry pbe = [SELECT Id, Product2Id, UnitPrice FROM PricebookEntry LIMIT 1];

    // Create initial line item
    OpportunityLineItem oli = new OpportunityLineItem(
      OpportunityId = oppy.Id,
      PricebookEntryId = pbe.Id,
      Quantity = 1,
      UnitPrice = 100
    );
    insert oli;

    // Update existing line item
    List<Map<String, Object>> lineItemsToCreate = new List<Map<String, Object>>{
      new Map<String, Object>{
        'id' => oli.Id,
        'pricebookEntryId' => pbe.Id,
        'quantity' => 5,
        'unitPrice' => 100
      }
    };

    LeadToOpportunityProductMapperController.saveOpportunityLineItems(oppy.Id, lineItemsToCreate, new List<String>());

    OpportunityLineItem updated = [SELECT Quantity FROM OpportunityLineItem WHERE Id = :oli.Id];
    Assert.areEqual(5, updated.Quantity, 'Quantity should be updated to 5');
  }

  @IsTest
  static void testSaveOpportunityLineItems_DeleteLineItem() {
    Opportunity oppy = [SELECT Id FROM Opportunity LIMIT 1];
    PricebookEntry pbe = [SELECT Id FROM PricebookEntry LIMIT 1];

    // Create line item to delete
    OpportunityLineItem oli = new OpportunityLineItem(
      OpportunityId = oppy.Id,
      PricebookEntryId = pbe.Id,
      Quantity = 2,
      UnitPrice = 100
    );
    insert oli;

    LeadToOpportunityProductMapperController.saveOpportunityLineItems(oppy.Id, new List<Map<String, Object>>(), new List<String>{oli.Id});

    List<OpportunityLineItem> items = [SELECT Id FROM OpportunityLineItem WHERE Id = :oli.Id];
    Assert.areEqual(0, items.size(), 'Line item should be deleted');
  }

  @IsTest
  static void testSaveOpportunityLineItems_MultipleOperations() {
    Opportunity oppy = [SELECT Id FROM Opportunity LIMIT 1];
    List<PricebookEntry> pbes = [SELECT Id, UnitPrice FROM PricebookEntry LIMIT 2];

    // Create initial line item for deletion
    OpportunityLineItem oliToDelete = new OpportunityLineItem(
      OpportunityId = oppy.Id,
      PricebookEntryId = pbes[0].Id,
      Quantity = 1,
      UnitPrice = 100
    );
    insert oliToDelete;

    // Create new items and delete existing
    List<Map<String, Object>> lineItemsToCreate = new List<Map<String, Object>>{
      new Map<String, Object>{
        'pricebookEntryId' => pbes[1].Id,
        'quantity' => 3,
        'unitPrice' => 150
      }
    };

    LeadToOpportunityProductMapperController.saveOpportunityLineItems(oppy.Id, lineItemsToCreate, new List<String>{oliToDelete.Id});

    List<OpportunityLineItem> items = [SELECT Id FROM OpportunityLineItem WHERE OpportunityId = :oppy.Id];
    Assert.areEqual(1, items.size(), 'Should have one line item after delete and create');
  }

  @IsTest
  static void testValidateLineItemData_MissingPricebookEntryId() {
    Opportunity oppy = [SELECT Id FROM Opportunity LIMIT 1];

    List<Map<String, Object>> invalidItems = new List<Map<String, Object>>{
      new Map<String, Object>{
        'quantity' => 1,
        'unitPrice' => 100
      }
    };

    try {
      LeadToOpportunityProductMapperController.saveOpportunityLineItems(oppy.Id, invalidItems, new List<String>());
      Assert.fail('Should have thrown exception for missing pricebookEntryId');
    } catch (AuraHandledException e) {
      // Assert.isTrue(e.getMessage().contains('pricebookEntryId is required'), 'Error message should mention pricebookEntryId');
    }
  }

  @IsTest
  static void testValidateLineItemData_MissingQuantity() {
    Opportunity oppy = [SELECT Id FROM Opportunity LIMIT 1];
    PricebookEntry pbe = [SELECT Id FROM PricebookEntry LIMIT 1];

    List<Map<String, Object>> invalidItems = new List<Map<String, Object>>{
      new Map<String, Object>{
        'pricebookEntryId' => pbe.Id,
        'unitPrice' => 100
      }
    };

    try {
      LeadToOpportunityProductMapperController.saveOpportunityLineItems(oppy.Id, invalidItems, new List<String>());
      Assert.fail('Should have thrown exception for missing quantity');
    } catch (AuraHandledException e) {
      // Assert.isTrue(e.getMessage().contains('quantity is required'), 'Error message should mention quantity');
    }
  }

  @IsTest
  static void testValidateLineItemData_MissingUnitPrice() {
    Opportunity oppy = [SELECT Id FROM Opportunity LIMIT 1];
    PricebookEntry pbe = [SELECT Id FROM PricebookEntry LIMIT 1];

    List<Map<String, Object>> invalidItems = new List<Map<String, Object>>{
      new Map<String, Object>{
        'pricebookEntryId' => pbe.Id,
        'quantity' => 1
      }
    };

    try {
      LeadToOpportunityProductMapperController.saveOpportunityLineItems(oppy.Id, invalidItems, new List<String>());
      Assert.fail('Should have thrown exception for missing unitPrice');
    } catch (AuraHandledException e) {
      // Assert.isTrue(e.getMessage().contains('unitPrice is required'), 'Error message should mention unitPrice');
    }
  }

  @IsTest
  static void testValidateLineItemData_InvalidQuantity() {
    Opportunity oppy = [SELECT Id FROM Opportunity LIMIT 1];
    PricebookEntry pbe = [SELECT Id FROM PricebookEntry LIMIT 1];

    List<Map<String, Object>> invalidItems = new List<Map<String, Object>>{
      new Map<String, Object>{
        'pricebookEntryId' => pbe.Id,
        'quantity' => 0,
        'unitPrice' => 100
      }
    };

    try {
      LeadToOpportunityProductMapperController.saveOpportunityLineItems(oppy.Id, invalidItems, new List<String>());
      Assert.fail('Should have thrown exception for zero quantity');
    } catch (AuraHandledException e) {
      // Assert.isTrue(e.getMessage().contains('Quantity must be greater than 0'), 'Error message should validate quantity > 0');
    }
  }

  @IsTest
  static void testValidateLineItemData_NegativeQuantity() {
    Opportunity oppy = [SELECT Id FROM Opportunity LIMIT 1];
    PricebookEntry pbe = [SELECT Id FROM PricebookEntry LIMIT 1];

    List<Map<String, Object>> invalidItems = new List<Map<String, Object>>{
      new Map<String, Object>{
        'pricebookEntryId' => pbe.Id,
        'quantity' => -5,
        'unitPrice' => 100
      }
    };

    try {
      LeadToOpportunityProductMapperController.saveOpportunityLineItems(oppy.Id, invalidItems, new List<String>());
      Assert.fail('Should have thrown exception for negative quantity');
    } catch (AuraHandledException e) {
      // Assert.isTrue(e.getMessage().contains('Quantity must be greater than 0'), 'Error message should validate quantity > 0');
    }
  }

  @IsTest
  static void testValidateLineItemData_NegativeUnitPrice() {
    Opportunity oppy = [SELECT Id FROM Opportunity LIMIT 1];
    PricebookEntry pbe = [SELECT Id FROM PricebookEntry LIMIT 1];

    List<Map<String, Object>> invalidItems = new List<Map<String, Object>>{
      new Map<String, Object>{
        'pricebookEntryId' => pbe.Id,
        'quantity' => 1,
        'unitPrice' => -50
      }
    };

    try {
      LeadToOpportunityProductMapperController.saveOpportunityLineItems(oppy.Id, invalidItems, new List<String>());
      Assert.fail('Should have thrown exception for negative unit price');
    } catch (AuraHandledException e) {
      // Assert.isTrue(e.getMessage().contains('Unit price must be 0 or greater'), 'Error message should validate unitPrice >= 0');
    }
  }

  @IsTest
  static void testValidateOpportunityAccess_BlankOpportunityId() {
    List<Map<String, Object>> lineItemsToCreate = new List<Map<String, Object>>();

    try {
      LeadToOpportunityProductMapperController.saveOpportunityLineItems('', lineItemsToCreate, new List<String>());
      Assert.fail('Should have thrown exception for blank opportunity ID');
    } catch (AuraHandledException e) {
      // Assert.isTrue(e.getMessage().contains('Opportunity ID cannot be blank'), 'Error message should mention blank ID');
    }
  }

  @IsTest
  static void testValidateOpportunityAccess_InvalidOpportunityId() {
    List<Map<String, Object>> lineItemsToCreate = new List<Map<String, Object>>();

    try {
      LeadToOpportunityProductMapperController.saveOpportunityLineItems('001XXXXXXXXXXXXXXX', lineItemsToCreate, new List<String>());
      Assert.fail('Should have thrown exception for non-existent opportunity');
    } catch (AuraHandledException e) {
      // Assert.isTrue(e.getMessage().contains('Opportunity not found or inaccessible'), 'Error message should mention opportunity not found');
    }
  }

  @IsTest
  static void testSaveOpportunityLineItems_NullLineItemsToCreate() {
    Opportunity oppy = [SELECT Id FROM Opportunity LIMIT 1];

    LeadToOpportunityProductMapperController.saveOpportunityLineItems(oppy.Id, null, new List<String>());

    List<OpportunityLineItem> items = [SELECT Id FROM OpportunityLineItem WHERE OpportunityId = :oppy.Id];
    Assert.areEqual(0, items.size(), 'No line items should be created when null list provided');
  }

  @IsTest
  static void testSaveOpportunityLineItems_EmptyLineItemsToDelete() {
    Opportunity oppy = [SELECT Id FROM Opportunity LIMIT 1];
    PricebookEntry pbe = [SELECT Id FROM PricebookEntry LIMIT 1];

    List<Map<String, Object>> lineItemsToCreate = new List<Map<String, Object>>{
      new Map<String, Object>{
        'pricebookEntryId' => pbe.Id,
        'quantity' => 2,
        'unitPrice' => 100
      }
    };

    LeadToOpportunityProductMapperController.saveOpportunityLineItems(oppy.Id, lineItemsToCreate, new List<String>());

    List<OpportunityLineItem> items = [SELECT Id FROM OpportunityLineItem WHERE OpportunityId = :oppy.Id];
    Assert.areEqual(1, items.size(), 'One line item should exist');
  }

  @IsTest
  static void testGetPricebook() {
    Pricebook2 result = LeadToOpportunityProductMapperController.getPricebook(Test.getStandardPricebookId());
    Assert.isNull(result, 'getPricebook should return null in test context');
  }

  @IsTest
  static void testSaveOpportunityLineItems_UpdateWithCapitalIdKey() {
    Opportunity oppy = [SELECT Id FROM Opportunity LIMIT 1];
    PricebookEntry pbe = [SELECT Id FROM PricebookEntry LIMIT 1];

    // Create initial line item
    OpportunityLineItem oli = new OpportunityLineItem(
      OpportunityId = oppy.Id,
      PricebookEntryId = pbe.Id,
      Quantity = 1,
      UnitPrice = 100
    );
    insert oli;

    // Update with capital 'Id' key
    List<Map<String, Object>> lineItemsToCreate = new List<Map<String, Object>>{
      new Map<String, Object>{
        'Id' => oli.Id,
        'pricebookEntryId' => pbe.Id,
        'quantity' => 3,
        'unitPrice' => 100
      }
    };

    LeadToOpportunityProductMapperController.saveOpportunityLineItems(oppy.Id, lineItemsToCreate, new List<String>());

    OpportunityLineItem updated = [SELECT Quantity FROM OpportunityLineItem WHERE Id = :oli.Id];
    Assert.areEqual(3, updated.Quantity, 'Quantity should be updated to 3 with capital Id key');
  }
}
