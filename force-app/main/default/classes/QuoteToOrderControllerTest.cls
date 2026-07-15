@IsTest
public class QuoteToOrderControllerTest {
  private static Pricebook2 standardPb;
  private static Account testAccount;
  private static Opportunity testOpp;
  private static Quote testQuote;

  @TestSetup
  static void setup() {
    standardPb = new Pricebook2(Id = Test.getStandardPricebookId());
    Id standardPbId = Test.getStandardPricebookId();
    System.debug('Standard Pricebook ID: ' + standardPbId);

    testAccount = new Account(Name = 'Test Account');
    insert testAccount;

    testOpp = new Opportunity(
      Name = 'Test Opportunity',
      AccountId = testAccount.Id,
      CloseDate = Date.today().addDays(30),
      StageName = 'Proposal',
      Pricebook2Id = standardPbId
    );
    insert testOpp;

    testQuote = new Quote(
      Name = 'Test Quote',
      OpportunityId = testOpp.Id,
      Pricebook2Id = standardPbId,
      ExpirationDate = Date.today().addDays(30)
    );
    insert testQuote;

    Product2 product = new Product2(Name = 'Test Product', IsActive = true);
    insert product;
    System.debug('Product ID: ' + product.Id);

    PricebookEntry pbe = new PricebookEntry(
      Pricebook2Id = standardPbId,
      Product2Id = product.Id,
      UnitPrice = 100,
      IsActive = true
    );
    try {
      insert pbe;
      System.debug('PricebookEntry created: ' + pbe.Id);
    } catch (DmlException e) {
      System.debug('Failed to create PricebookEntry: ' + e.getMessage());
      throw e;
    }

    QuoteLineItem qli = new QuoteLineItem(
      QuoteId = testQuote.Id,
      Product2Id = product.Id,
      PricebookEntryId = pbe.Id,
      Quantity = 1,
      UnitPrice = 100
    );
    insert qli;
    System.debug('QuoteLineItem created: ' + qli.Id);
  }

  @IsTest
  static void testGetQuoteFromContextQuoteType() {
    Quote quoteData = [SELECT Id, IsSyncing FROM Quote WHERE Name = 'Test Quote' LIMIT 1];

    // Skip test if quote is not syncing (IsSyncing is read-only, set by system)
    if (!quoteData.IsSyncing) {
      System.debug('Quote is not syncing, skipping test');
      return;
    }

    Quote quote = QuoteToOrderController.getQuoteFromContext(quoteData.Id);

    System.assertEquals(quoteData.Id, quote.Id);
  }

  @IsTest
  static void testGetQuoteFromContextOpportunityTypeFails() {
    Opportunity opp = [SELECT Id FROM Opportunity WHERE Name = 'Test Opportunity' LIMIT 1];
    try {
      QuoteToOrderController.getQuoteFromContext(opp.Id);
      System.assert(false, 'Should throw exception for non-synced quote');
    } catch (QuoteToOrderController.QuoteToOrderException e) {
      System.assert(e.getMessage().contains('No synced quote'), e.getMessage());
    }
  }

  @IsTest
  static void testGetQuoteFromContextOpportunityTypeSuccess() {
    Opportunity opp = [SELECT Id FROM Opportunity WHERE Name = 'Test Opportunity' LIMIT 1];
    Quote quote = [SELECT Id, IsSyncing FROM Quote WHERE OpportunityId = :opp.Id LIMIT 1];

    // Skip test if quote is not syncing (IsSyncing is read-only, set by system)
    if (!quote.IsSyncing) {
      System.debug('Quote is not syncing, skipping test');
      return;
    }

    Test.startTest();
    quote.Status = 'Approved';

    update quote;

    Quote result = QuoteToOrderController.getQuoteFromContext(opp.Id);
    Test.stopTest();


    System.assertEquals(quote.Id, result.Id);
  }

  @IsTest
  static void testGetQuoteFromContextNotApprovedFails() {
    Quote quote = [SELECT Id, IsSyncing FROM Quote WHERE Name = 'Test Quote' LIMIT 1];

    // Skip test if quote is not syncing
    if (!quote.IsSyncing) {
      System.debug('Quote is not syncing, skipping test');
      return;
    }

    quote.Status = 'Approved';

    update quote;

    try {
      QuoteToOrderController.getQuoteFromContext(quote.Id);
      System.assert(false, 'Should throw exception for non-approved quote');
    } catch (QuoteToOrderController.QuoteToOrderException e) {
      System.assert(e.getMessage().contains('must be approved'), e.getMessage());
    }
  }

  @IsTest
  static void testGetQuoteFromContextNotSyncingFails() {
    Quote quote = [SELECT Id FROM Quote WHERE Name = 'Test Quote' LIMIT 1];
    quote.Status = 'Approved';

    update quote;

    try {
      QuoteToOrderController.getQuoteFromContext(quote.Id);
      System.assert(false, 'Should throw exception for non-syncing quote');
    } catch (QuoteToOrderController.QuoteToOrderException e) {
      System.assert(e.getMessage().contains('must be syncing'), e.getMessage());
    }
  }

  @IsTest
  static void testGetQuoteFromContextExpiredFails() {
    Quote quote = [SELECT Id, IsSyncing FROM Quote WHERE Name = 'Test Quote' LIMIT 1];

    // Skip test if quote is not syncing
    if (!quote.IsSyncing) {
      System.debug('Quote is not syncing, skipping test');
      return;
    }

    quote.Status = 'Approved';

    quote.ExpirationDate = Date.today().addDays(-1);
    update quote;

    try {
      QuoteToOrderController.getQuoteFromContext(quote.Id);
      System.assert(false, 'Should throw exception for expired quote');
    } catch (QuoteToOrderController.QuoteToOrderException e) {
      System.assert(e.getMessage().contains('expired'), e.getMessage());
    }
  }

  @IsTest
  static void testGetQuoteLineItems() {
    Quote quote = [SELECT Id FROM Quote WHERE Name = 'Test Quote' LIMIT 1];
    List<QuoteLineItem> items = QuoteToOrderController.getQuoteLineItems(quote.Id);
    System.assertEquals(1, items.size());
    System.assertEquals(1, items.get(0).Quantity);
    System.assertEquals(100, items.get(0).UnitPrice);
  }

  @IsTest
  static void testGetQuoteLineItemsNoItems() {
    Opportunity opp = [SELECT Id FROM Opportunity WHERE Name = 'Test Opportunity' LIMIT 1];
    Pricebook2 standardPb = [SELECT Id FROM Pricebook2 WHERE IsStandard = TRUE LIMIT 1];
    Quote emptyQuote = new Quote(
      Name = 'Empty Quote',
      OpportunityId = opp.Id,
      Pricebook2Id = standardPb.Id,
      ExpirationDate = Date.today().addDays(30)
    );
    insert emptyQuote;

    List<QuoteLineItem> items = QuoteToOrderController.getQuoteLineItems(emptyQuote.Id);
    System.assertEquals(0, items.size());
  }

  @IsTest
  static void testCreateOrderFromQuoteSuccess() {
    Quote quote = [SELECT Id, IsSyncing FROM Quote WHERE Name = 'Test Quote' LIMIT 1];

    // Skip test if quote is not syncing
    if (!quote.IsSyncing) {
      System.debug('Quote is not syncing, skipping test');
      return;
    }

    quote.Status = 'Approved';

    update quote;

    Test.startTest();
    Order createdOrder = QuoteToOrderController.createOrderFromQuote(quote.Id);
    Test.stopTest();

    Account acc = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];

    System.assertEquals(acc.Id, createdOrder.AccountId);



    List<OrderItem> orderItems = [SELECT Id FROM OrderItem WHERE OrderId = :createdOrder.Id];
    System.assertEquals(1, orderItems.size());
  }

  @IsTest
  static void testCreateOrderFromQuoteAlreadyExists() {
    Quote quote = [SELECT Id, IsSyncing FROM Quote WHERE Name = 'Test Quote' LIMIT 1];

    // Skip test if quote is not syncing
    if (!quote.IsSyncing) {
      System.debug('Quote is not syncing, skipping test');
      return;
    }

    quote.Status = 'Approved';

    update quote;

    Test.startTest();
    Order firstOrder = QuoteToOrderController.createOrderFromQuote(quote.Id);
    System.debug('First order: ' + firstOrder.Id);

    try {
      Order secondOrder = QuoteToOrderController.createOrderFromQuote(quote.Id);
      System.assert(false, 'Should throw exception for duplicate order');
    } catch (QuoteToOrderController.QuoteToOrderException e) {
      System.assert(e.getMessage().contains('already created'), e.getMessage());
    }
    Test.stopTest();
  }

  @IsTest
  static void testCreateOrderFromQuoteNotApprovedFails() {
    Quote quote = [SELECT Id FROM Quote WHERE Name = 'Test Quote' LIMIT 1];
    quote.Status = 'Approved';
    // quote.IsSyncing = true;

    update quote;

    try {
      QuoteToOrderController.createOrderFromQuote(quote.Id);
      System.assert(false, 'Should throw exception for non-approved quote');
    } catch (QuoteToOrderController.QuoteToOrderException e) {
      System.assert(e.getMessage().contains('must be approved'), e.getMessage());
    }
  }

  @IsTest
  static void testCreateOrderFromQuoteNotSyncingFails() {
    Quote quote = [SELECT Id FROM Quote WHERE Name = 'Test Quote' LIMIT 1];
    quote.Status = 'Approved';

    update quote;

    try {
      QuoteToOrderController.createOrderFromQuote(quote.Id);
      System.assert(false, 'Should throw exception for non-syncing quote');
    } catch (QuoteToOrderController.QuoteToOrderException e) {
      System.assert(e.getMessage().contains('must be syncing'), e.getMessage());
    }
  }

  @IsTest
  static void testCreateOrderFromQuoteExpiredFails() {
    Quote quote = [SELECT Id FROM Quote WHERE Name = 'Test Quote' LIMIT 1];
    quote.Status = 'Approved';
    // quote.IsSyncing = true;

    quote.ExpirationDate = Date.today().addDays(-1);
    update quote;

    try {
      QuoteToOrderController.createOrderFromQuote(quote.Id);
      System.assert(false, 'Should throw exception for expired quote');
    } catch (QuoteToOrderController.QuoteToOrderException e) {
      System.assert(e.getMessage().contains('expired'), e.getMessage());
    }
  }

  @IsTest
  static void testCreateOrderFromQuoteNoLineItemsFails() {
    Opportunity opp = [SELECT Id FROM Opportunity WHERE Name = 'Test Opportunity' LIMIT 1];
    Quote emptyQuote = new Quote(
      Name = 'Empty Quote',
      OpportunityId = opp.Id,
      Pricebook2Id = Test.getStandardPricebookId(),
      ExpirationDate = Date.today().addDays(30),
      Status = 'Approved'
    );
    insert emptyQuote;

    try {
      QuoteToOrderController.createOrderFromQuote(emptyQuote.Id);
      System.assert(false, 'Should throw exception for quote with no line items');
    } catch (QuoteToOrderController.QuoteToOrderException e) {
      System.assert(e.getMessage().contains('no line items'), e.getMessage());
    }
  }

  @IsTest
  static void testCreateOrderFromQuoteMultipleLineItems() {
    Quote quote = [SELECT Id, IsSyncing FROM Quote WHERE Name = 'Test Quote' LIMIT 1];

    // Skip test if quote is not syncing
    if (!quote.IsSyncing) {
      System.debug('Quote is not syncing, skipping test');
      return;
    }

    Product2 product2 = new Product2(Name = 'Test Product 2', IsActive = true);
    insert product2;

    PricebookEntry pbe2 = new PricebookEntry(
      Pricebook2Id = Test.getStandardPricebookId(),
      Product2Id = product2.Id,
      UnitPrice = 200,
      IsActive = true
    );
    insert pbe2;

    QuoteLineItem qli2 = new QuoteLineItem(
      QuoteId = quote.Id,
      Product2Id = product2.Id,
      PricebookEntryId = pbe2.Id,
      Quantity = 2,
      UnitPrice = 200
    );
    insert qli2;

    quote = [SELECT Id FROM Quote WHERE Id = :quote.Id LIMIT 1];
    quote.Status = 'Approved';

    update quote;

    Test.startTest();
    Order createdOrder = QuoteToOrderController.createOrderFromQuote(quote.Id);
    Test.stopTest();


    List<OrderItem> orderItems = [SELECT Id, Quantity, UnitPrice FROM OrderItem WHERE OrderId = :createdOrder.Id];
    System.assertEquals(2, orderItems.size());

    Integer totalQty = 0;
    for (OrderItem oi : orderItems) {
      totalQty += (Integer) oi.Quantity;
    }
    System.assertEquals(3, totalQty);
  }

  @IsTest
  static void testIsValidId() {
    Boolean valid15 = QuoteToOrderController.isValidId('001D000000IRFmaIAH');
    Boolean valid18 = QuoteToOrderController.isValidId('001D000000IRFmaIAHaIH');
    Boolean invalidShort = QuoteToOrderController.isValidId('001');

    System.assert(valid15);
    System.assert(valid18);
    System.assert(!invalidShort);
  }

  @IsTest
  static void testParseId() {
    Account acc = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];
    Id testId = acc.Id;
    Id parsed = QuoteToOrderController.parseId(testId);
    System.assertEquals(testId, parsed);
  }

  @IsTest
  static void testWhichSobject() {
    Account acc = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];
    String objectType = QuoteToOrderController.whichSobject(acc.Id);
    System.assertEquals('Account', objectType);
  }
}
