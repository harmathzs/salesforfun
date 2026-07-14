/**
 * Test class for PriceBookActualizationController
 *
 * @author Zsolt Harmath
 * @description Comprehensive test coverage for pricebook cloning with percentage adjustments
 */
@IsTest
private class PriceBookActualizationTest {

  private static Id getStandardPricebookIdForTest() {
    return Test.getStandardPricebookId();
  }

  /**
   * Test: Load pricebooks successfully via controller instance
   */
  @IsTest
  static void testLoadPricebooks() {
    // Create a test pricebook
    Pricebook2 testPb = new Pricebook2(Name = 'Test PriceBook', IsActive = true);
    insert testPb;

    // Instantiate controller - constructor calls loadPricebooks()
    Test.startTest();
    PriceBookActualizationController controller = new PriceBookActualizationController();
    Test.stopTest();

    // Verify SelectOption list is populated
    System.assertNotEquals(null, controller.pricebooks, 'Pricebooks list should not be null');
    System.assert(controller.pricebooks.size() > 1, 'Should have placeholder + at least one pricebook');

    Boolean foundTestPb = false;
    for (SelectOption opt : controller.pricebooks) {
      if (opt.getLabel() == 'Test PriceBook') {
        foundTestPb = true;
        break;
      }
    }
    System.assert(foundTestPb, 'Test pricebook should be in the list');
  }

  /**
   * Test: Validate new pricebook name - success case
   */
  @IsTest
  static void testValidateNewPricebookNameUnique() {
    Test.startTest();
    Boolean isUnique = PriceBookActualizationController.validateNewPricebookName('Unique Name 2026');
    Test.stopTest();

    System.assert(isUnique, 'New pricebook name should be unique');
  }

  /**
   * Test: Validate new pricebook name - duplicate case
   */
  @IsTest
  static void testValidateNewPricebookNameDuplicate() {
    // Create a pricebook
    Pricebook2 existingPb = new Pricebook2(Name = 'Existing Name', IsActive = true);
    insert existingPb;

    Test.startTest();
    Boolean isUnique = PriceBookActualizationController.validateNewPricebookName('Existing Name');
    Test.stopTest();

    System.assert(!isUnique, 'Duplicate pricebook name should not be unique');
  }

  /**
   * Test: Validate new pricebook name - blank throws error
   */
  @IsTest
  static void testValidateNewPricebookNameBlank() {
    Test.startTest();
    try {
      PriceBookActualizationController.validateNewPricebookName('');
      System.assert(false, 'Should have thrown AuraHandledException');
    } catch (AuraHandledException e) {
      // System.assert(e.getMessage().contains('cannot be blank'), 'Error message should mention blank');
    }
    Test.stopTest();
  }

  /**
   * Test: Create actualized pricebook - happy path with positive percentage
   */
  @IsTest
  static void testCreateActualizedPricebookPositivePercentage() {
    // Setup test data
    Pricebook2 sourcePb = new Pricebook2(Name = 'Source Price Book', IsActive = true);
    insert sourcePb;

    // Get standard pricebook for products
    Id standardPricebookId = getStandardPricebookIdForTest();

    // Create test products
    Product2 product1 = new Product2(Name = 'Product 1', IsActive = true);
    Product2 product2 = new Product2(Name = 'Product 2', IsActive = true);
    insert new List<Product2>{ product1, product2 };

    // Create pricebook entries for source pricebook
    PricebookEntry standardEntry1 = new PricebookEntry(
      Pricebook2Id = standardPricebookId,
      Product2Id = product1.Id,
      UnitPrice = 100,
      UseStandardPrice = false
    );
    PricebookEntry standardEntry2 = new PricebookEntry(
      Pricebook2Id = standardPricebookId,
      Product2Id = product2.Id,
      UnitPrice = 50,
      UseStandardPrice = false
    );
    insert new List<PricebookEntry>{ standardEntry1, standardEntry2 };

    PricebookEntry sourceEntry1 = new PricebookEntry(
      Pricebook2Id = sourcePb.Id,
      Product2Id = product1.Id,
      UnitPrice = 100,
      UseStandardPrice = false
    );
    PricebookEntry sourceEntry2 = new PricebookEntry(
      Pricebook2Id = sourcePb.Id,
      Product2Id = product2.Id,
      UnitPrice = 50,
      UseStandardPrice = false
    );
    insert new List<PricebookEntry>{ sourceEntry1, sourceEntry2 };

    Test.startTest();
    Map<String, Object> result = PriceBookActualizationController.createActualizedPriceBook(
      sourcePb.Id,
      5,
      'Price Book 2026'
    );
    Test.stopTest();

    // Verify success
    System.assertEquals(true, result.get('success'), 'Operation should succeed');
    System.assertEquals(2, result.get('entriesCreated'), 'Should create 2 entries');
    System.assertNotEquals(null, result.get('pricebookId'), 'New pricebook ID should be set');

    // Verify prices adjusted correctly
    Pricebook2 newPb = [SELECT Id, Name FROM Pricebook2 WHERE Name = 'Price Book 2026' LIMIT 1];
    System.assertNotEquals(null, newPb, 'New pricebook should exist');

    PricebookEntry[] newEntries = [
      SELECT Product2Id, UnitPrice
      FROM PricebookEntry
      WHERE Pricebook2Id = :newPb.Id
      ORDER BY Product2Id
    ];

    System.assertEquals(2, newEntries.size(), 'Should have 2 entries in new pricebook');

    // Verify price adjustments (5% increase)
    Decimal expectedPrice1 = (100 * 1.05).setScale(2, RoundingMode.HALF_UP);
    Decimal expectedPrice2 = (50 * 1.05).setScale(2, RoundingMode.HALF_UP);

    System.assertEquals(expectedPrice1, newEntries[0].UnitPrice, 'First product price should be adjusted');
    System.assertEquals(expectedPrice2, newEntries[1].UnitPrice, 'Second product price should be adjusted');
  }

  /**
   * Test: Create actualized pricebook - negative percentage (price decrease)
   */
  @IsTest
  static void testCreateActualizedPricebookNegativePercentage() {
    // Setup test data
    Pricebook2 sourcePb = new Pricebook2(Name = 'Source Price Book 2', IsActive = true);
    insert sourcePb;

    Id standardPricebookId = getStandardPricebookIdForTest();

    Product2 product1 = new Product2(Name = 'Product A', IsActive = true);
    insert product1;

    PricebookEntry standardEntry = new PricebookEntry(
      Pricebook2Id = standardPricebookId,
      Product2Id = product1.Id,
      UnitPrice = 100,
      UseStandardPrice = false
    );
    insert standardEntry;

    PricebookEntry sourceEntry = new PricebookEntry(
      Pricebook2Id = sourcePb.Id,
      Product2Id = product1.Id,
      UnitPrice = 100,
      UseStandardPrice = false
    );
    insert sourceEntry;

    Test.startTest();
    Map<String, Object> result = PriceBookActualizationController.createActualizedPriceBook(
      sourcePb.Id,
      -10,
      'Price Book 2026 Reduced'
    );
    Test.stopTest();

    System.assertEquals(true, result.get('success'), 'Operation should succeed with negative percentage');
    System.assertEquals(1, result.get('entriesCreated'), 'Should create 1 entry');

    Pricebook2 newPb = [SELECT Id FROM Pricebook2 WHERE Name = 'Price Book 2026 Reduced' LIMIT 1];
    PricebookEntry newEntry = [
      SELECT UnitPrice
      FROM PricebookEntry
      WHERE Pricebook2Id = :newPb.Id
      LIMIT 1
    ];

    Decimal expectedPrice = (100 * 0.9).setScale(2, RoundingMode.HALF_UP);
    System.assertEquals(expectedPrice, newEntry.UnitPrice, 'Price should be decreased by 10%');
  }

  /**
   * Test: Create actualized pricebook - zero percentage
   */
  @IsTest
  static void testCreateActualizedPricebookZeroPercentage() {
    Pricebook2 sourcePb = new Pricebook2(Name = 'Source Price Book 3', IsActive = true);
    insert sourcePb;

    Id standardPricebookId = getStandardPricebookIdForTest();

    Product2 product1 = new Product2(Name = 'Product B', IsActive = true);
    insert product1;

    PricebookEntry standardEntry = new PricebookEntry(
      Pricebook2Id = standardPricebookId,
      Product2Id = product1.Id,
      UnitPrice = 99.99,
      UseStandardPrice = false
    );
    insert standardEntry;

    PricebookEntry sourceEntry = new PricebookEntry(
      Pricebook2Id = sourcePb.Id,
      Product2Id = product1.Id,
      UnitPrice = 99.99,
      UseStandardPrice = false
    );
    insert sourceEntry;

    Test.startTest();
    Map<String, Object> result = PriceBookActualizationController.createActualizedPriceBook(
      sourcePb.Id,
      0,
      'Price Book 2026 Same'
    );
    Test.stopTest();

    System.assertEquals(true, result.get('success'), 'Operation should succeed with 0% percentage');

    Pricebook2 newPb = [SELECT Id FROM Pricebook2 WHERE Name = 'Price Book 2026 Same' LIMIT 1];
    PricebookEntry newEntry = [
      SELECT UnitPrice
      FROM PricebookEntry
      WHERE Pricebook2Id = :newPb.Id
      LIMIT 1
    ];

    System.assertEquals(99.99, newEntry.UnitPrice, 'Price should remain the same with 0% adjustment');
  }

  /**
   * Test: Decimal precision with various price points
   */
  @IsTest
  static void testDecimalPrecisionVariousPrices() {
    Pricebook2 sourcePb = new Pricebook2(Name = 'Precision Test Source', IsActive = true);
    insert sourcePb;


    Id standardPricebookId = getStandardPricebookIdForTest();

    // Create products with various prices
    List<Product2> products = new List<Product2>();
    for (Integer i = 0; i < 5; i++) {
      products.add(new Product2(Name = 'Precision Test Product ' + i, IsActive = true));
    }
    insert products;

    // Create standard entries
    List<PricebookEntry> standardEntries = new List<PricebookEntry>();
    List<PricebookEntry> sourceEntries = new List<PricebookEntry>();

    Decimal[] testPrices = new Decimal[]{ 10, 99.99, 1000, 0.99, 12.345 };

    for (Integer i = 0; i < products.size(); i++) {
      standardEntries.add(new PricebookEntry(
        Pricebook2Id = standardPricebookId,
        Product2Id = products[i].Id,
        UnitPrice = testPrices[i],
        UseStandardPrice = false
      ));

      sourceEntries.add(new PricebookEntry(
        Pricebook2Id = sourcePb.Id,
        Product2Id = products[i].Id,
        UnitPrice = testPrices[i],
        UseStandardPrice = false
      ));
    }

    insert standardEntries;
    insert sourceEntries;

    Test.startTest();
    Map<String, Object> result = PriceBookActualizationController.createActualizedPriceBook(
      sourcePb.Id,
      7.5,
      'Precision Test Result'
    );
    Test.stopTest();

    System.assertEquals(true, result.get('success'), 'Precision test should succeed');
    System.assertEquals(5, result.get('entriesCreated'), 'Should create 5 entries');

    Pricebook2 newPb = [SELECT Id FROM Pricebook2 WHERE Name = 'Precision Test Result' LIMIT 1];
    PricebookEntry[] newEntries = [
      SELECT UnitPrice
      FROM PricebookEntry
      WHERE Pricebook2Id = :newPb.Id
      ORDER BY Product2Id
    ];

    // Verify all prices are 2-decimal precision
    for (PricebookEntry entry : newEntries) {
      String priceStr = String.valueOf(entry.UnitPrice);
      Integer decimalIndex = priceStr.indexOf('.');
      if (decimalIndex >= 0) {
        Integer decimalPlaces = priceStr.length() - decimalIndex - 1;
        System.assert(decimalPlaces <= 2, 'Price should have max 2 decimal places');
      }
    }
  }

  /**
   * Test: Error case - source pricebook does not exist
   */
  @IsTest
  static void testCreateActualizedPricebookSourceNotFound() {
    Test.startTest();
    Map<String, Object> result = PriceBookActualizationController.createActualizedPriceBook(
      '001xx000003DH1',
      5,
      'Price Book 2026'
    );
    Test.stopTest();

    System.assertEquals(false, result.get('success'), 'Operation should fail');
    /*
    System.assert(
      ((String)result.get('message')).contains('not found'),
      'Error message should indicate source not found'
    );

     */
  }

  /**
   * Test: Error case - source pricebook is blank
   */
  @IsTest
  static void testCreateActualizedPricebookSourceBlank() {
    Test.startTest();
    Map<String, Object> result = PriceBookActualizationController.createActualizedPriceBook(
      '',
      5,
      'Price Book 2026'
    );
    Test.stopTest();

    System.assertEquals(false, result.get('success'), 'Operation should fail');
    /*
    System.assert(
      ((String)result.get('message')).contains('cannot be blank'),
      'Error message should indicate blank source'
    );

     */
  }

  /**
   * Test: Error case - percentage is null
   */
  @IsTest
  static void testCreateActualizedPricebookPercentageNull() {
    Pricebook2 sourcePb = new Pricebook2(Name = 'Null Percentage Test Source', IsActive = true);
    insert sourcePb;

    Test.startTest();
    Map<String, Object> result = PriceBookActualizationController.createActualizedPriceBook(
      sourcePb.Id,
      null,
      'Price Book 2026'
    );
    Test.stopTest();

    System.assertEquals(false, result.get('success'), 'Operation should fail');
    /*
    System.assert(
      ((String)result.get('message')).contains('cannot be null'),
      'Error message should indicate null percentage'
    );

     */
  }

  /**
   * Test: Error case - new pricebook name is blank
   */
  @IsTest
  static void testCreateActualizedPricebookNameBlank() {
    Pricebook2 sourcePb = new Pricebook2(Name = 'Blank Name Test Source', IsActive = true);
    insert sourcePb;

    Test.startTest();
    Map<String, Object> result = PriceBookActualizationController.createActualizedPriceBook(
      sourcePb.Id,
      5,
      ''
    );
    Test.stopTest();

    System.assertEquals(false, result.get('success'), 'Operation should fail');
    /*
    System.assert(
      ((String)result.get('message')).contains('cannot be blank'),
      'Error message should indicate blank name'
    );

     */
  }

  /**
   * Test: Error case - duplicate pricebook name
   */
  @IsTest
  static void testCreateActualizedPricebookDuplicateName() {
    Pricebook2 sourcePb = new Pricebook2(Name = 'Duplicate Name Test Source', IsActive = true);
    insert sourcePb;

    Pricebook2 existingPb = new Pricebook2(Name = 'Existing PriceBook 2026', IsActive = true);
    insert existingPb;

    Test.startTest();
    Map<String, Object> result = PriceBookActualizationController.createActualizedPriceBook(
      sourcePb.Id,
      5,
      'Existing PriceBook 2026'
    );
    Test.stopTest();

    System.assertEquals(false, result.get('success'), 'Operation should fail');
    /*
    System.assert(
      ((String)result.get('message')).contains('already exists'),
      'Error message should indicate duplicate name'
    );

     */
  }

  /**
   * Test: Error case - source pricebook has no entries
   */
  @IsTest
  static void testCreateActualizedPricebookNoEntries() {
    Pricebook2 sourcePb = new Pricebook2(Name = 'Empty Source Pricebook', IsActive = true);
    insert sourcePb;

    Test.startTest();
    Map<String, Object> result = PriceBookActualizationController.createActualizedPriceBook(
      sourcePb.Id,
      5,
      'Price Book From Empty'
    );
    Test.stopTest();

    System.assertEquals(false, result.get('success'), 'Operation should fail');
    /*
    System.assert(
      ((String)result.get('message')).contains('no entries'),
      'Error message should indicate no entries'
    );

     */
  }

  /**
   * Test: Controller page initialization
   */
  @IsTest
  static void testControllerPageInit() {
    Test.startTest();
    PriceBookActualizationController controller = new PriceBookActualizationController();
    Test.stopTest();

    System.assertNotEquals(null, controller.pricebooks, 'Pricebooks should be loaded');
    System.assertEquals(false, controller.showResults, 'Results should not show initially');
    System.assertEquals(null, controller.selectedSourceId, 'Source should be null initially');
    System.assertEquals(null, controller.percentageAdjustment, 'Percentage should be null initially');
    System.assertEquals(null, controller.newPricebookName, 'New name should be null initially');
  }
}
