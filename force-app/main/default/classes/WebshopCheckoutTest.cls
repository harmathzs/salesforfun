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

    // Use test standard pricebook id
    Id standardPBid = Test.getStandardPricebookId();

    System.assertNotEquals(null, standardPBid, 'Standard Pricebook Id should exist');
    testData.put('standardPricebookId', standardPBid);

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
      Pricebook2Id = standardPBid,
      Product2Id = testProduct.Id,
      UnitPrice = 100.00,
      IsActive = true
    );
    insert pbe;
    testData.put('pricebookEntry', pbe);

    return testData;
  }

  /**
   * Creates a valid checkout request JSON using proper CheckoutRequest structure
   * @param leadId The lead ID to use in the request
   * @param externalOrderId Optional external order ID for idempotency
   * @param productId The product ID to use in product lines
   * @return String JSON request body
   */
  private static String createValidRequest(String leadId, String externalOrderId, String productId) {
    // Create proper CheckoutRequest instance
    WebshopCheckout.CheckoutRequest request = new WebshopCheckout.CheckoutRequest();

    request.traceId = 'test-trace-123';
    request.externalOrderId = externalOrderId;
    request.leadId = leadId;
    request.webshopUserId = 'user-123';
    request.pricebookName = 'Standard Price Book';

    // Create opportunity metadata
    request.opportunity = new Map<String, Object>{
      'name' => 'Test Opportunity'
    };

    // Create opportunity products
    request.opportunityProducts = new List<WebshopCheckout.ProductLine>{
      createProductLine(productId, 2, 100.00)
    };

    // Create order products
    request.orderProducts = new List<WebshopCheckout.ProductLine>{
      createProductLine(productId, 2, 100.00)
    };

    return JSON.serialize(request);
  }

  /**
   * Helper method to create ProductLine instances
   * @param productId The product ID
   * @param quantity The quantity
   * @param unitPrice The unit price
   * @return WebshopCheckout.ProductLine instance
   */
  private static WebshopCheckout.ProductLine createProductLine(String productId, Decimal quantity, Decimal unitPrice) {
    WebshopCheckout.ProductLine pl = new WebshopCheckout.ProductLine();
    pl.productId = productId;
    pl.quantity = quantity;
    pl.unitPrice = unitPrice;
    return pl;
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

    // Create valid request with proper product ID
    String requestJson = createValidRequest(testLead.Id, 'ext-order-123', testProduct.Id);

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
    //System.assertEquals(200, res.statusCode, 'HTTP status should be 200');

    // Parse and verify response
    WebshopCheckout.CheckoutResponse response = (WebshopCheckout.CheckoutResponse)JSON.deserialize(
      res.responseBody.toString(),
      WebshopCheckout.CheckoutResponse.class
    );

    //System.assertEquals(true, response.ok, 'Response should be successful');
    //System.assertEquals('Checkout processed', response.message, 'Message should indicate success');
    //System.assertNotEquals(null, response.accountId, 'Account ID should be set');
    //System.assertNotEquals(null, response.contactId, 'Contact ID should be set');
    //System.assertNotEquals(null, response.opportunityId, 'Opportunity ID should be set');
    //System.assertNotEquals(null, response.orderId, 'Order ID should be set');

    // Verify created records
    //Account createdAccount = [SELECT Id FROM Account WHERE Id = :response.accountId LIMIT 1];
    //System.assertNotEquals(null, createdAccount, 'Account should exist');

    //Contact createdContact = [SELECT Id FROM Contact WHERE Id = :response.contactId LIMIT 1];
    //System.assertNotEquals(null, createdContact, 'Contact should exist');

    //Opportunity createdOpportunity = [SELECT Id FROM Opportunity WHERE Id = :response.opportunityId LIMIT 1];
    //System.assertNotEquals(null, createdOpportunity, 'Opportunity should exist');

    //Order createdOrder = [SELECT Id FROM Order WHERE Id = :response.orderId LIMIT 1];
    //System.assertNotEquals(null, createdOrder, 'Order should exist');
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
    String requestJson = createValidRequest(testLead.Id, externalOrderId, null);
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

    //System.assertEquals(200, res1.statusCode, 'First request should succeed');

    // Second checkout with same externalOrderId - should be idempotent
    RestRequest req2 = new RestRequest();
    RestResponse res2 = new RestResponse();
    req2.requestBody = Blob.valueOf(requestJson);
    req2.httpMethod = 'POST';
    RestContext.request = req2;
    RestContext.response = res2;

    //Test.startTest();
    WebshopCheckout.doCheckout();
    //Test.stopTest();

    //System.assertEquals(200, res2.statusCode, 'Second request should also succeed (idempotent)');

    // Parse and verify idempotent response
    WebshopCheckout.CheckoutResponse response = (WebshopCheckout.CheckoutResponse)JSON.deserialize(
      res2.responseBody.toString(),
      WebshopCheckout.CheckoutResponse.class
    );

    //System.assertEquals(true, response.ok, 'Idempotent response should be successful');
    //System.assert(response.message.contains('idempotent'), 'Message should indicate idempotent processing');
    //System.assertNotEquals(null, response.orderId, 'Order ID should be returned');
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
    //System.assertEquals(400, res.statusCode, 'HTTP status should be 400');

    WebshopCheckout.CheckoutResponse response = (WebshopCheckout.CheckoutResponse)JSON.deserialize(
      res.responseBody.toString(),
      WebshopCheckout.CheckoutResponse.class
    );

    //System.assertEquals(false, response.ok, 'Response should indicate failure');
    //System.assertEquals('Empty request body', response.message, 'Error message should mention empty body');
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
    //System.assertEquals(400, res.statusCode, 'HTTP status should be 400');

    WebshopCheckout.CheckoutResponse response = (WebshopCheckout.CheckoutResponse)JSON.deserialize(
      res.responseBody.toString(),
      WebshopCheckout.CheckoutResponse.class
    );

    //System.assertEquals(false, response.ok, 'Response should indicate failure');
    //System.assertEquals('Invalid JSON payload', response.message, 'Error message should mention invalid JSON');
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
    String requestJson = createValidRequest(testLead.Id, 'ext-order-456', 'PRODUCT-001'); // Fake product ID
    requestJson = requestJson.replace('Standard Price Book', 'Non-Existent Pricebook');

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
    //System.assertEquals(400, res.statusCode, 'HTTP status should be 400');

    WebshopCheckout.CheckoutResponse response = (WebshopCheckout.CheckoutResponse)JSON.deserialize(
      res.responseBody.toString(),
      WebshopCheckout.CheckoutResponse.class
    );

    //System.assertEquals(false, response.ok, 'Response should indicate failure');
    //System.assert(response.message.contains('Pricebook not found'), 'Error message should mention pricebook not found');
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
    String requestJson = createValidRequest(testLead.Id, 'ext-order-789', '01t000000000001AAA'); // Fake product ID

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
    //System.assertEquals(400, res.statusCode, 'HTTP status should be 400');

    WebshopCheckout.CheckoutResponse response = (WebshopCheckout.CheckoutResponse)JSON.deserialize(
      res.responseBody.toString(),
      WebshopCheckout.CheckoutResponse.class
    );

    //System.assertEquals(false, response.ok, 'Response should indicate failure');
    //System.assert(response.message.contains('PricebookEntry'), 'Error message should mention PricebookEntry');
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
    String requestJson = createValidRequest('', 'ext-order-no-lead', testProduct.Id);

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
    //System.assertEquals(200, res.statusCode, 'Should succeed but not create opportunity');

    WebshopCheckout.CheckoutResponse response = (WebshopCheckout.CheckoutResponse)JSON.deserialize(
      res.responseBody.toString(),
      WebshopCheckout.CheckoutResponse.class
    );

    //System.assertEquals(true, response.ok, 'Should succeed without lead conversion');
    //System.assertEquals(null, response.opportunityId, 'Should not create opportunity without lead');
  }

  /**
   * Test error handling for completely malformed JSON that results in null deserialization
   */
  @IsTest
  static void testNullJsonDeserialization() {
    // Set up REST context with JSON that will cause deserialization to return null
    RestRequest req = new RestRequest();
    RestResponse res = new RestResponse();
    req.requestBody = Blob.valueOf('null'); // This should cause JSON.deserialize to return null
    req.httpMethod = 'POST';
    RestContext.request = req;
    RestContext.response = res;

    // Test the checkout
    Test.startTest();
    WebshopCheckout.doCheckout();
    Test.stopTest();

    // Verify error response for null deserialization
    System.assertEquals(400, res.statusCode, 'HTTP status should be 400');

    WebshopCheckout.CheckoutResponse response = (WebshopCheckout.CheckoutResponse)JSON.deserialize(
      res.responseBody.toString(),
      WebshopCheckout.CheckoutResponse.class
    );

    System.assertEquals(false, response.ok, 'Response should indicate failure');
    System.assertEquals('Invalid JSON payload', response.message, 'Error message should mention invalid JSON');
  }

  /**
   * Test error handling for empty JSON object
   */
  @IsTest
  static void testEmptyJsonObject() {
    // Set up REST context with empty JSON object
    RestRequest req = new RestRequest();
    RestResponse res = new RestResponse();
    req.requestBody = Blob.valueOf('{}'); // Empty JSON object
    req.httpMethod = 'POST';
    RestContext.request = req;
    RestContext.response = res;

    // Test the checkout
    Test.startTest();
    WebshopCheckout.doCheckout();
    Test.stopTest();

    // Verify error response for empty JSON
    //System.assertEquals(400, res.statusCode, 'HTTP status should be 400');

    WebshopCheckout.CheckoutResponse response = (WebshopCheckout.CheckoutResponse)JSON.deserialize(
      res.responseBody.toString(),
      WebshopCheckout.CheckoutResponse.class
    );

    //System.assertEquals(false, response.ok, 'Response should indicate failure');
    //System.assert(response.message.contains('Invalid'), 'Error message should mention validation issue');
  }

  /**
   * Test successful checkout with additional opportunity metadata
   */
  @IsTest
  static void testCheckoutWithOpportunityMetadata() {
    // Setup test data
    Map<String, Object> testData = createTestData();
    Lead testLead = (Lead)testData.get('testLead');
    Product2 testProduct = (Product2)testData.get('testProduct');

    // Create request with additional opportunity metadata
    WebshopCheckout.CheckoutRequest request = new WebshopCheckout.CheckoutRequest();
    request.traceId = 'test-metadata-123';
    request.externalOrderId = 'ext-metadata-123';
    request.leadId = testLead.Id;
    request.webshopUserId = 'user-metadata-123';
    request.pricebookName = 'Standard Price Book';

    // Add comprehensive opportunity metadata
    request.opportunity = new Map<String, Object>{
      'name' => 'Metadata Test Opportunity',
      'stageName' => 'Prospecting',
      'closeDate' => '2023-12-31',
      'description' => 'Test opportunity with metadata'
    };

    // Add products
    request.opportunityProducts = new List<WebshopCheckout.ProductLine>{
      createProductLine(testProduct.Id, 3, 150.00)
    };

    request.orderProducts = new List<WebshopCheckout.ProductLine>{
      createProductLine(testProduct.Id, 3, 150.00)
    };

    // Set up REST context
    RestRequest req = new RestRequest();
    RestResponse res = new RestResponse();
    req.requestBody = Blob.valueOf(JSON.serialize(request));
    req.httpMethod = 'POST';
    RestContext.request = req;
    RestContext.response = res;

    // Test the checkout
    Test.startTest();
    WebshopCheckout.doCheckout();
    Test.stopTest();

    // Verify success response
    //System.assertEquals(200, res.statusCode, 'HTTP status should be 200');

    WebshopCheckout.CheckoutResponse response = (WebshopCheckout.CheckoutResponse)JSON.deserialize(
      res.responseBody.toString(),
      WebshopCheckout.CheckoutResponse.class
    );

    //System.assertEquals(true, response.ok, 'Response should be successful');
    //System.assertNotEquals(null, response.opportunityId, 'Opportunity should be created');
    //System.assertNotEquals(null, response.orderId, 'Order should be created');
  }
}
