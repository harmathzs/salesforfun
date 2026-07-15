@IsTest
public class QuoteToOrderControllerTest {
  private static Pricebook2 standardPb;
  private static Account testAccount;
  private static Opportunity testOpp;
  private static Quote testQuote;

  @TestSetup
  static void setup() {
    standardPb = new Pricebook2(Id = Test.getStandardPricebookId());

    testAccount = new Account(Name = 'Test Account');
    insert testAccount;

    testOpp = new Opportunity(
      Name = 'Test Opportunity',
      AccountId = testAccount.Id,
      CloseDate = Date.today().addDays(30),
      StageName = 'Proposal',
      Pricebook2Id = Test.getStandardPricebookId()
    );
    insert testOpp;

    testQuote = new Quote(
      Name = 'Test Quote',
      OpportunityId = testOpp.Id,
      Pricebook2Id = Test.getStandardPricebookId(),
      ExpirationDate = Date.today().addDays(30)
    );
    insert testQuote;

    Product2 product = new Product2(Name = 'Test Product', IsActive = true);
    insert product;

    PricebookEntry pbe = new PricebookEntry(
      Pricebook2Id = Test.getStandardPricebookId(),
      Product2Id = product.Id,
      UnitPrice = 100,
      IsActive = true
    );
    insert pbe;

    QuoteLineItem qli = new QuoteLineItem(
      QuoteId = testQuote.Id,
      Product2Id = product.Id,
      Quantity = 1,
      UnitPrice = 100
    );
    insert qli;
  }

  @IsTest
  static void testGetQuoteFromContextQuoteType() {
    Quote quote = QuoteToOrderController.getQuoteFromContext(testQuote.Id);

    System.assertEquals(testQuote.Id, quote.Id);
  }

  @IsTest
  static void testGetQuoteFromContextOpportunityTypeFails() {
    try {
      QuoteToOrderController.getQuoteFromContext(testOpp.Id);
      System.assert(false, 'Should throw exception for non-synced quote');
    } catch (QuoteToOrderController.QuoteToOrderException e) {
      System.assert(e.getMessage().contains('No synced quote'), e.getMessage());
    }
  }

  @IsTest
  static void testGetQuoteFromContextOpportunityTypeSuccess() {
    Quote quote = [SELECT Id FROM Quote WHERE OpportunityId = :testOpp.Id LIMIT 1];
    Test.startTest();
    quote.Status = 'Approved';

    update quote;

    Quote result = QuoteToOrderController.getQuoteFromContext(testOpp.Id);
    Test.stopTest();


    System.assertEquals(quote.Id, result.Id);
  }

  @IsTest
  static void testGetQuoteFromContextNotApprovedFails() {
    Quote quote = [SELECT Id FROM Quote WHERE Id = :testQuote.Id LIMIT 1];
    quote.Status = 'Approved';

    update quote;

    try {
      QuoteToOrderController.getQuoteFromContext(testQuote.Id);
      System.assert(false, 'Should throw exception for non-approved quote');
    } catch (QuoteToOrderController.QuoteToOrderException e) {
      System.assert(e.getMessage().contains('must be approved'), e.getMessage());
    }
  }

  @IsTest
  static void testGetQuoteFromContextNotSyncingFails() {
    Quote quote = [SELECT Id FROM Quote WHERE Id = :testQuote.Id LIMIT 1];
    quote.Status = 'Approved';

    update quote;

    try {
      QuoteToOrderController.getQuoteFromContext(testQuote.Id);
      System.assert(false, 'Should throw exception for non-syncing quote');
    } catch (QuoteToOrderController.QuoteToOrderException e) {
      System.assert(e.getMessage().contains('must be syncing'), e.getMessage());
    }
  }

  @IsTest
  static void testGetQuoteFromContextExpiredFails() {
    Quote quote = [SELECT Id FROM Quote WHERE Id = :testQuote.Id LIMIT 1];
    quote.Status = 'Approved';

    quote.ExpirationDate = Date.today().addDays(-1);
    update quote;

    try {
      QuoteToOrderController.getQuoteFromContext(testQuote.Id);
      System.assert(false, 'Should throw exception for expired quote');
    } catch (QuoteToOrderController.QuoteToOrderException e) {
      System.assert(e.getMessage().contains('expired'), e.getMessage());
    }
  }

  @IsTest
  static void testGetQuoteLineItems() {
    List<QuoteLineItem> items = QuoteToOrderController.getQuoteLineItems(testQuote.Id);
    System.assertEquals(1, items.size());
    System.assertEquals(1, items.get(0).Quantity);
    System.assertEquals(100, items.get(0).UnitPrice);
  }

  @IsTest
  static void testGetQuoteLineItemsNoItems() {
    Quote emptyQuote = new Quote(
      Name = 'Empty Quote',
      OpportunityId = testOpp.Id,
      Pricebook2Id = standardPb.Id,
      ExpirationDate = Date.today().addDays(30)
    );
    insert emptyQuote;

    List<QuoteLineItem> items = QuoteToOrderController.getQuoteLineItems(emptyQuote.Id);
    System.assertEquals(0, items.size());
  }

  @IsTest
  static void testCreateOrderFromQuoteSuccess() {
    Quote quote = [SELECT Id FROM Quote WHERE Id = :testQuote.Id LIMIT 1];
    quote.Status = 'Approved';

    update quote;

    Test.startTest();
    Order createdOrder = QuoteToOrderController.createOrderFromQuote(testQuote.Id);
    Test.stopTest();


    System.assertEquals(testAccount.Id, createdOrder.AccountId);



    List<OrderItem> orderItems = [SELECT Id FROM OrderItem WHERE OrderId = :createdOrder.Id];
    System.assertEquals(1, orderItems.size());
  }

  @IsTest
  static void testCreateOrderFromQuoteAlreadyExists() {
    Quote quote = [SELECT Id FROM Quote WHERE Id = :testQuote.Id LIMIT 1];
    quote.Status = 'Approved';

    update quote;

    Test.startTest();
    Order firstOrder = QuoteToOrderController.createOrderFromQuote(testQuote.Id);
    System.debug('First order: ' + firstOrder.Id);

    try {
      Order secondOrder = QuoteToOrderController.createOrderFromQuote(testQuote.Id);
      System.assert(false, 'Should throw exception for duplicate order');
    } catch (QuoteToOrderController.QuoteToOrderException e) {
      System.assert(e.getMessage().contains('already created'), e.getMessage());
    }
    Test.stopTest();
  }

  @IsTest
  static void testCreateOrderFromQuoteNotApprovedFails() {
    Quote quote = [SELECT Id FROM Quote WHERE Id = :testQuote.Id LIMIT 1];
    quote.Status = 'Approved';

    update quote;

    try {
      QuoteToOrderController.createOrderFromQuote(testQuote.Id);
      System.assert(false, 'Should throw exception for non-approved quote');
    } catch (QuoteToOrderController.QuoteToOrderException e) {
      System.assert(e.getMessage().contains('must be approved'), e.getMessage());
    }
  }

  @IsTest
  static void testCreateOrderFromQuoteNotSyncingFails() {
    Quote quote = [SELECT Id FROM Quote WHERE Id = :testQuote.Id LIMIT 1];
    quote.Status = 'Approved';

    update quote;

    try {
      QuoteToOrderController.createOrderFromQuote(testQuote.Id);
      System.assert(false, 'Should throw exception for non-syncing quote');
    } catch (QuoteToOrderController.QuoteToOrderException e) {
      System.assert(e.getMessage().contains('must be syncing'), e.getMessage());
    }
  }

  @IsTest
  static void testCreateOrderFromQuoteExpiredFails() {
    Quote quote = [SELECT Id FROM Quote WHERE Id = :testQuote.Id LIMIT 1];
    quote.Status = 'Approved';

    quote.ExpirationDate = Date.today().addDays(-1);
    update quote;

    try {
      QuoteToOrderController.createOrderFromQuote(testQuote.Id);
      System.assert(false, 'Should throw exception for expired quote');
    } catch (QuoteToOrderController.QuoteToOrderException e) {
      System.assert(e.getMessage().contains('expired'), e.getMessage());
    }
  }

  @IsTest
  static void testCreateOrderFromQuoteNoLineItemsFails() {
    Quote emptyQuote = new Quote(
      Name = 'Empty Quote',
      OpportunityId = testOpp.Id,
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
      QuoteId = testQuote.Id,
      Product2Id = product2.Id,
      Quantity = 2,
      UnitPrice = 200
    );
    insert qli2;

    Quote quote = [SELECT Id FROM Quote WHERE Id = :testQuote.Id LIMIT 1];
    quote.Status = 'Approved';

    update quote;

    Test.startTest();
    Order createdOrder = QuoteToOrderController.createOrderFromQuote(testQuote.Id);
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
    Boolean valid18 = QuoteToOrderController.isValidId('001D000000IRFmaIAHaIAH');
    Boolean invalidShort = QuoteToOrderController.isValidId('001');

    System.assert(valid15);
    System.assert(valid18);
    System.assert(!invalidShort);
  }

  @IsTest
  static void testParseId() {
    Id testId = testAccount.Id;
    Id parsed = QuoteToOrderController.parseId(testId);
    System.assertEquals(testId, parsed);
  }

  @IsTest
  static void testWhichSobject() {
    String objectType = QuoteToOrderController.whichSobject(testAccount.Id);
    System.assertEquals('Account', objectType);
  }
}
