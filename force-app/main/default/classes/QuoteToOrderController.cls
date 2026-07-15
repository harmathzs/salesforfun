public with sharing class QuoteToOrderController {
  public class QuoteToOrderException extends Exception {}

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

  @AuraEnabled
  public static Quote getQuoteFromContext(Id recordId) {
    if (recordId == null) {
      throw new QuoteToOrderException('Record ID cannot be null');
    }

    String sObjectName = recordId.getSobjectType().getDescribe().getName();
    Quote quote = null;

    if (sObjectName == 'Quote') {
      // Direct quote context
      quote = queryQuoteById(recordId);
    } else if (sObjectName == 'Opportunity') {
      // Opportunity context: find synced quote
      List<Quote> quotes = [
        SELECT Id, Name, AccountId, QuoteNumber, Status, IsSyncing,
               ExpirationDate, Subtotal, TotalPrice, Tax, GrandTotal, OpportunityId
        FROM Quote
        WHERE OpportunityId = :recordId AND IsSyncing = TRUE AND Status IN ('Approved', 'Accepted')
        LIMIT 1
      ];
      if (quotes.isEmpty()) {
        throw new QuoteToOrderException('No synced quote found for this Opportunity');
      }
      quote = quotes.get(0);
    } else {
      throw new QuoteToOrderException('Invalid record type. Expected Quote or Opportunity.');
    }

    if (quote == null) {
      throw new QuoteToOrderException('Quote not found');
    }

    validateQuote(quote);
    return quote;
  }

  @AuraEnabled
  public static List<QuoteLineItem> getQuoteLineItems(Id quoteId) {
    if (quoteId == null) {
      throw new QuoteToOrderException('Quote ID cannot be null');
    }

    return [
      SELECT Id, QuoteId, Product2Id, Product2.Name, Quantity, UnitPrice, Subtotal, Description
      FROM QuoteLineItem
      WHERE QuoteId = :quoteId
      ORDER BY CreatedDate ASC
    ];
  }

  @AuraEnabled
  public static Order createOrderFromQuote(Id quoteId) {
    if (quoteId == null) {
      throw new QuoteToOrderException('Quote ID cannot be null');
    }

    // Fetch quote with validation
    Quote quote = queryQuoteById(quoteId);
    validateQuote(quote);

    // Check for duplicate order (idempotency)
    List<Order> existingOrders = [
      SELECT Id, OrderNumber FROM Order WHERE OrderNumber = :quoteId LIMIT 1
    ];
    if (!existingOrders.isEmpty()) {
      throw new QuoteToOrderException('Order already created from this quote: ' + existingOrders.get(0).Id);
    }

    // Fetch quote line items
    List<QuoteLineItem> quoteLineItems = getQuoteLineItems(quoteId);
    if (quoteLineItems.isEmpty()) {
      throw new QuoteToOrderException('Quote has no line items. Cannot create order.');
    }

    // Resolve pricebook
    Id pricebookId = resolvePricebook(quote.OpportunityId);
    if (pricebookId == null) {
      throw new QuoteToOrderException('No pricebook available. Please add a pricebook to the opportunity.');
    }

    // Create order header
    Order order = new Order(
      AccountId = quote.AccountId,

      Pricebook2Id = pricebookId,
      EffectiveDate = Date.today(),
      Status = 'Draft',

      Description = 'Created from Quote: ' + quote.QuoteNumber
    );

    insert order;
    System.debug('Order created: ' + order.Id);

    // Create order line items from quote line items
    List<OrderItem> orderItems = new List<OrderItem>();
    for (QuoteLineItem qli : quoteLineItems) {
      OrderItem oi = new OrderItem(
        OrderId = order.Id,
        Product2Id = qli.Product2Id,
        Quantity = qli.Quantity,
        UnitPrice = qli.UnitPrice
      );
      orderItems.add(oi);
    }

    if (!orderItems.isEmpty()) {
      insert orderItems;
      System.debug('Created ' + orderItems.size() + ' order items');
    }

    return order;
  }

  private static Quote queryQuoteById(Id quoteId) {
    List<Quote> quotes = [
      SELECT Id, Name, AccountId, QuoteNumber, Status, IsSyncing,
             ExpirationDate, Subtotal, TotalPrice, Tax, GrandTotal, OpportunityId
      FROM Quote
      WHERE Id = :quoteId
      LIMIT 1
    ];

    if (quotes.isEmpty()) {
      throw new QuoteToOrderException('Quote not found: ' + quoteId);
    }

    return quotes.get(0);
  }

  private static void validateQuote(Quote quote) {
    if (!(quote.Status == 'Approved' || quote.Status == 'Accepted')) {
      throw new QuoteToOrderException('Quote must be approved to create an order');
    }

    if (!quote.IsSyncing) {
      throw new QuoteToOrderException('Quote must be syncing with opportunity to create an order');
    }

    if (quote.ExpirationDate < Date.today()) {
      throw new QuoteToOrderException('Quote has expired. Please renew the quote.');
    }
  }

  private static Id resolvePricebook(Id opportunityId) {
    if (opportunityId == null) {
      return null;
    }

    // Try to get pricebook from opportunity
    Opportunity opp = [
      SELECT Pricebook2Id FROM Opportunity WHERE Id = :opportunityId LIMIT 1
    ];

    if (opp.Pricebook2Id != null) {
      return opp.Pricebook2Id;
    }

    // Fallback to standard pricebook
    List<Pricebook2> standardPbs = [
      SELECT Id FROM Pricebook2 WHERE IsStandard = TRUE LIMIT 1
    ];

    return standardPbs.isEmpty() ? null : standardPbs.get(0).Id;
  }
}
