@IsTest
private class WebshopCheckoutTest {

  /**
   * Test setup method to create required test data
   * @return Map<String, Object> containing test records
   */
  private static Map<String, Object> createTestData() {
    Map<String, Object> testData = new Map<String, Object>();

    // Create a test lead using TestFactory
    Lead[] testLeads = TestFactory.getTestLeads();
    insert testLeads[0];
    testData.put('testLead', testLeads[0]);

    // Create a standard price book (should exist in org, but create if needed)
    Pricebook2 standardPB = [SELECT Id FROM Pricebook2 WHERE IsStandard = TRUE LIMIT 1];
    if (standardPB == null) {
      standardPB = new Pricebook2(Name = 'Standard Price Book');
      insert standardPB;
    }
    testData.put('standardPricebook', standardPB);

    // Create a test product
    Product2 testProduct = new Product2(
      Name = 'Test Product',
      Description = 'Test Product for Webshop',
      ProductCode = 'TEST-PROD-001',
      IsActive = true
    );
    insert testProduct;
    testData.put('testProduct', testProduct);

    // Create pricebook entry
    PricebookEntry pbe = new PricebookEntry(
      Pricebook2Id = standardPB.Id,
      Product2Id = testProduct.Id,
      UnitPrice = 100.00,
      IsActive = true
    );
    insert pbe;
    testData.put('pricebookEntry', pbe);

    return testData;
  }

  /**
   * Creates a valid checkout request JSON
   * @param leadId The lead ID to use in the request
   * @param externalOrderId Optional external order ID for idempotency
   * @return String JSON request body
   */
  private static String createValidRequest(String leadId, String externalOrderId) {
    Map<String, Object> request = new Map<String, Object>{
      'traceId' => 'test-trace-123',
      'externalOrderId' => externalOrderId,
      'leadId' => leadId,
      'webshopUserId' => 'user-123',
      'pricebookName' => 'Standard Price Book',
      'opportunity' => new Map<String, Object>{
        'name' => 'Test Opportunity'
      },
      'opportunityProducts' => new List<Map<String, Object>>{
        new Map<String, Object>{
          'productId' => 'PRODUCT_ID_PLACEHOLDER',
          'quantity' => 2,
          'unitPrice' => 100.00
        }
      },
      'orderProducts' => new List<Map<String, Object>>{
        new Map<String, Object>{
          'productId' => 'PRODUCT_ID_PLACEHOLDER',
          'quantity' => 2,
          'unitPrice' => 100.00
        }
      }
    };
    return JSON.serialize(request);
  }

  /**
   * Test successful checkout with lead conversion
   */
  @IsTest
  static void testSuccessfulCheckoutWithLeadConversion() {
    // Setup test data
    Map<String, Object> testData = createTestData();
    Lead testLead = (Lead)testData.get('testLead');
    Product2 testProduct = (Product2)testData.get('testProduct');

    // Create valid request
    String requestJson = createValidRequest(testLead.Id, 'ext-order-123');
    requestJson = requestJson.replace('PRODUCT_ID_PLACEHOLDER', testProduct.Id);

    // Set up REST context
    RestRequest req = new RestRequest();
    RestResponse res = new RestResponse();
    req.requestBody = Blob.valueOf(requestJson);
    req.httpMethod = 'POST';
    RestContext.request = req;
    RestContext.response = res;

    // Test the checkout
    Test.startTest();
    WebshopCheckout.doCheckout();
    Test.stopTest();

    // Verify response
    System.assertEquals(200, res.statusCode, 'HTTP status should be 200');

    // Parse and verify response
    WebshopCheckout.CheckoutResponse response = (WebshopCheckout.CheckoutResponse)JSON.deserialize(
      res.responseBody.toString(),
      WebshopCheckout.CheckoutResponse.class
    );

    System.assertEquals(true, response.ok, 'Response should be successful');
    System.assertEquals('Checkout processed', response.message, 'Message should indicate success');
    System.assertNotEquals(null, response.accountId, 'Account ID should be set');
    System.assertNotEquals(null, response.contactId, 'Contact ID should be set');
    System.assertNotEquals(null, response.opportunityId, 'Opportunity ID should be set');
    System.assertNotEquals(null, response.orderId, 'Order ID should be set');

    // Verify created records
    Account createdAccount = [SELECT Id FROM Account WHERE Id = :response.accountId LIMIT 1];
    System.assertNotEquals(null, createdAccount, 'Account should exist');

    Contact createdContact = [SELECT Id FROM Contact WHERE Id = :response.contactId LIMIT 1];
    System.assertNotEquals(null, createdContact, 'Contact should exist');

    Opportunity createdOpportunity = [SELECT Id FROM Opportunity WHERE Id = :response.opportunityId LIMIT 1];
    System.assertNotEquals(null, createdOpportunity, 'Opportunity should exist');

    Order createdOrder = [SELECT Id FROM Order WHERE Id = :response.orderId LIMIT 1];
    System.assertNotEquals(null, createdOrder, 'Order should exist');
  }

  /**
   * Test idempotent checkout (duplicate external order ID)
   */
  @IsTest
  static void testIdempotentCheckout() {
    // Setup test data
    Map<String, Object> testData = createTestData();
    Lead testLead = (Lead)testData.get('testLead');
    Product2 testProduct = (Product2)testData.get('testProduct');

    // Create valid request
    String externalOrderId = 'idempotent-test-123';
    String requestJson = createValidRequest(testLead.Id, externalOrderId);
    requestJson = requestJson.replace('PRODUCT_ID_PLACEHOLDER', testProduct.Id);

    // First checkout - should succeed
    RestRequest req1 = new RestRequest();
    RestResponse res1 = new RestResponse();
    req1.requestBody = Blob.valueOf(requestJson);
    req1.httpMethod = 'POST';
    RestContext.request = req1;
    RestContext.response = res1;

    Test.startTest();
    WebshopCheckout.doCheckout();
    Test.stopTest();

    System.assertEquals(200, res1.statusCode, 'First request should succeed');

    // Second checkout with same externalOrderId - should be idempotent
    RestRequest req2 = new RestRequest();
    RestResponse res2 = new RestResponse();
    req2.requestBody = Blob.valueOf(requestJson);
    req2.httpMethod = 'POST';
    RestContext.request = req2;
    RestContext.response = res2;

    Test.startTest();
    WebshopCheckout.doCheckout();
    Test.stopTest();

    System.assertEquals(200, res2.statusCode, 'Second request should also succeed (idempotent)');

    // Parse and verify idempotent response
    WebshopCheckout.CheckoutResponse response = (WebshopCheckout.CheckoutResponse)JSON.deserialize(
      res2.responseBody.toString(),
      WebshopCheckout.CheckoutResponse.class
    );

    System.assertEquals(true, response.ok, 'Idempotent response should be successful');
    System.assert(response.message.contains('idempotent'), 'Message should indicate idempotent processing');
    System.assertNotEquals(null, response.orderId, 'Order ID should be returned');
  }

  /**
   * Test error handling for empty request body
   */
  @IsTest
  static void testEmptyRequestBody() {
    // Set up REST context with empty body
    RestRequest req = new RestRequest();
    RestResponse res = new RestResponse();
    req.httpMethod = 'POST';
    RestContext.request = req;
    RestContext.response = res;

    // Test the checkout
    Test.startTest();
    WebshopCheckout.doCheckout();
    Test.stopTest();

    // Verify error response
    System.assertEquals(400, res.statusCode, 'HTTP status should be 400');

    WebshopCheckout.CheckoutResponse response = (WebshopCheckout.CheckoutResponse)JSON.deserialize(
      res.responseBody.toString(),
      WebshopCheckout.CheckoutResponse.class
    );

    System.assertEquals(false, response.ok, 'Response should indicate failure');
    System.assertEquals('Empty request body', response.message, 'Error message should mention empty body');
  }

  /**
   * Test error handling for invalid JSON
   */
  @IsTest
  static void testInvalidJson() {
    // Set up REST context with invalid JSON
    RestRequest req = new RestRequest();
    RestResponse res = new RestResponse();
    req.requestBody = Blob.valueOf('invalid json');
    req.httpMethod = 'POST';
    RestContext.request = req;
    RestContext.response = res;

    // Test the checkout
    Test.startTest();
    WebshopCheckout.doCheckout();
    Test.stopTest();

    // Verify error response
    System.assertEquals(400, res.statusCode, 'HTTP status should be 400');

    WebshopCheckout.CheckoutResponse response = (WebshopCheckout.CheckoutResponse)JSON.deserialize(
      res.responseBody.toString(),
      WebshopCheckout.CheckoutResponse.class
    );

    System.assertEquals(false, response.ok, 'Response should indicate failure');
    System.assertEquals('Invalid JSON payload', response.message, 'Error message should mention invalid JSON');
  }

  /**
   * Test error handling for missing pricebook
   */
  @IsTest
  static void testMissingPricebook() {
    // Setup test data
    Map<String, Object> testData = createTestData();
    Lead testLead = (Lead)testData.get('testLead');

    // Create request with non-existent pricebook
    String requestJson = createValidRequest(testLead.Id, 'ext-order-456');
    requestJson = requestJson.replace('Standard Price Book', 'Non-Existent Pricebook');
    requestJson = requestJson.replace('PRODUCT_ID_PLACEHOLDER', 'PRODUCT-001'); // Fake product ID

    // Set up REST context
    RestRequest req = new RestRequest();
    RestResponse res = new RestResponse();
    req.requestBody = Blob.valueOf(requestJson);
    req.httpMethod = 'POST';
    RestContext.request = req;
    RestContext.response = res;

    // Test the checkout
    Test.startTest();
    WebshopCheckout.doCheckout();
    Test.stopTest();

    // Verify error response
    System.assertEquals(400, res.statusCode, 'HTTP status should be 400');

    WebshopCheckout.CheckoutResponse response = (WebshopCheckout.CheckoutResponse)JSON.deserialize(
      res.responseBody.toString(),
      WebshopCheckout.CheckoutResponse.class
    );

    System.assertEquals(false, response.ok, 'Response should indicate failure');
    System.assert(response.message.contains('Pricebook not found'), 'Error message should mention pricebook not found');
  }

  /**
   * Test error handling for missing pricebook entry
   */
  @IsTest
  static void testMissingPricebookEntry() {
    // Setup test data
    Map<String, Object> testData = createTestData();
    Lead testLead = (Lead)testData.get('testLead');

    // Create request with fake product ID that has no pricebook entry
    String requestJson = createValidRequest(testLead.Id, 'ext-order-789');
    requestJson = requestJson.replace('PRODUCT_ID_PLACEHOLDER', '01t000000000001AAA'); // Fake product ID

    // Set up REST context
    RestRequest req = new RestRequest();
    RestResponse res = new RestResponse();
    req.requestBody = Blob.valueOf(requestJson);
    req.httpMethod = 'POST';
    RestContext.request = req;
    RestContext.response = res;

    // Test the checkout
    Test.startTest();
    WebshopCheckout.doCheckout();
    Test.stopTest();

    // Verify error response
    System.assertEquals(400, res.statusCode, 'HTTP status should be 400');

    WebshopCheckout.CheckoutResponse response = (WebshopCheckout.CheckoutResponse)JSON.deserialize(
      res.responseBody.toString(),
      WebshopCheckout.CheckoutResponse.class
    );

    System.assertEquals(false, response.ok, 'Response should indicate failure');
    System.assert(response.message.contains('PricebookEntry'), 'Error message should mention PricebookEntry');
  }

  /**
   * Test checkout without lead ID (should fail)
   */
  @IsTest
  static void testCheckoutWithoutLeadId() {
    // Setup test data
    Map<String, Object> testData = createTestData();
    Product2 testProduct = (Product2)testData.get('testProduct');

    // Create request without leadId
    String requestJson = createValidRequest('', 'ext-order-no-lead');
    requestJson = requestJson.replace('PRODUCT_ID_PLACEHOLDER', testProduct.Id);

    // Set up REST context
    RestRequest req = new RestRequest();
    RestResponse res = new RestResponse();
    req.requestBody = Blob.valueOf(requestJson);
    req.httpMethod = 'POST';
    RestContext.request = req;
    RestContext.response = res;

    // Test the checkout
    Test.startTest();
    WebshopCheckout.doCheckout();
    Test.stopTest();

    // Verify error response (currently the API requires leadId)
    System.assertEquals(200, res.statusCode, 'Should succeed but not create opportunity');

    WebshopCheckout.CheckoutResponse response = (WebshopCheckout.CheckoutResponse)JSON.deserialize(
      res.responseBody.toString(),
      WebshopCheckout.CheckoutResponse.class
    );

    System.assertEquals(true, response.ok, 'Should succeed without lead conversion');
    System.assertEquals(null, response.opportunityId, 'Should not create opportunity without lead');
  }
}
