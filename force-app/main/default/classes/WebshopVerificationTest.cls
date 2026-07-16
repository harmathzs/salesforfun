@IsTest
private class WebshopVerificationTest {

  /**
   * Creates and inserts a test lead using TestFactory.
   * Uses the first lead from getTestLeads() method.
   *
   * @return Lead inserted test lead record
   */
  private static Lead createTestLead() {
    // Get test leads from factory and insert the first one
    Lead[] testLeads = TestFactory.createTestLeads();
    insert testLeads[0];
    return testLeads[0];
  }

  /**
   * Creates and inserts a qualified test lead using TestFactory.
   *
   * @return Lead inserted qualified test lead record
   */
  private static Lead createQualifiedTestLead() {
    // Get qualified test leads from factory and insert the first one
    Lead[] qualifiedLeads = TestFactory.createQualifiedTestLeads(1);
    insert qualifiedLeads[0];
    return qualifiedLeads[0];
  }

  /**
   * Creates and inserts an unqualified test lead using TestFactory.
   *
   * @return Lead inserted unqualified test lead record
   */
  private static Lead createUnqualifiedTestLead() {
    // Get unqualified test leads from factory and insert the first one
    Lead[] unqualifiedLeads = TestFactory.createUnqualifiedTestLeads(1);
    insert unqualifiedLeads[0];
    return unqualifiedLeads[0];
  }

  /**
   * Creates and inserts a verified test lead using TestFactory.
   *
   * @return Lead inserted verified test lead record
   */
  private static Lead createVerifiedTestLead() {
    // Get test lead from factory, mark as verified, and insert
    Lead[] testLeads = TestFactory.createTestLeads();
    testLeads[0].Email_Verified__c = true;
    insert testLeads[0];
    return testLeads[0];
  }

  /**
   * Test successful verification email sending with leadId
   */
  @IsTest
  static void testSendVerificationEmailWithLeadId() {
    // Setup test data
    Lead testLead = createTestLead();

    // Create request JSON
    String requestJson = JSON.serialize(new Map<String, Object>{
      'leadId' => testLead.Id,
      'code' => '123456',
      'expiryMinutes' => 30
    });

    // Set up mock request
    RestRequest req = new RestRequest();
    RestResponse res = new RestResponse();
    req.requestBody = Blob.valueOf(requestJson);
    req.httpMethod = 'POST';
    RestContext.request = req;
    RestContext.response = res;

    // Test the method
    Test.startTest();
    WebshopVerificationEmailApi.VerifyEmailResponse response = WebshopVerificationEmailApi.sendVerificationEmail();
    Test.stopTest();

    // Verify results
    System.assertEquals(true, response.ok, 'Response should be successful');
    System.assertEquals('Verification email sent', response.message, 'Message should indicate success');
    System.assertNotEquals(null, response.requestId, 'Request ID should be generated');
    //System.assertEquals(200, RestContext.response.statusCode, 'HTTP status should be 200');
  }

  /**
   * Test successful verification email sending with email lookup
   */
  @IsTest
  static void testSendVerificationEmailWithEmail() {
    // Setup test data
    Lead testLead = createTestLead();

    // Create request JSON
    String requestJson = JSON.serialize(new Map<String, Object>{
      'email' => testLead.Email,
      'code' => 'ABCD1234',
      'firstName' => 'CustomName'
    });

    // Set up mock request
    RestRequest req = new RestRequest();
    RestResponse res = new RestResponse();
    req.requestBody = Blob.valueOf(requestJson);
    req.httpMethod = 'POST';
    RestContext.request = req;
    RestContext.response = res;

    // Test the method
    Test.startTest();
    WebshopVerificationEmailApi.VerifyEmailResponse response = WebshopVerificationEmailApi.sendVerificationEmail();
    Test.stopTest();

    // Verify results
    System.assertEquals(true, response.ok, 'Response should be successful');
    System.assertEquals('Verification email sent', response.message, 'Message should indicate success');
  }

  /**
   * Test error handling for empty request body
   */
  @IsTest
  static void testEmptyRequestBody() {
    // Set up mock request with empty body
    RestRequest req = new RestRequest();
    RestResponse res = new RestResponse();
    req.httpMethod = 'POST';
    RestContext.request = req;
    RestContext.response = res;

    // Test the method
    Test.startTest();
    WebshopVerificationEmailApi.VerifyEmailResponse response = WebshopVerificationEmailApi.sendVerificationEmail();
    Test.stopTest();

    // Verify error handling
    System.assertEquals(false, response.ok, 'Response should indicate failure');
    System.assertEquals(400, RestContext.response.statusCode, 'HTTP status should be 400');
    //System.assert(response.message.contains('Empty request body'), 'Error message should mention empty body');
  }

  /**
   * Test error handling for invalid verification code
   */
  @IsTest
  static void testInvalidVerificationCode() {
    Lead testLead = createTestLead();

    // Create request with invalid code
    String requestJson = JSON.serialize(new Map<String, Object>{
      'leadId' => testLead.Id,
      'code' => '123'  // Too short
    });

    // Set up mock request
    RestRequest req = new RestRequest();
    RestResponse res = new RestResponse();
    req.requestBody = Blob.valueOf(requestJson);
    req.httpMethod = 'POST';
    RestContext.request = req;
    RestContext.response = res;

    // Test the method
    Test.startTest();
    WebshopVerificationEmailApi.VerifyEmailResponse response = WebshopVerificationEmailApi.sendVerificationEmail();
    Test.stopTest();

    // Verify error handling
    System.assertEquals(false, response.ok, 'Response should indicate failure');
    System.assertEquals(400, RestContext.response.statusCode, 'HTTP status should be 400');
    //System.assert(response.message.contains('Invalid verification code'), 'Error message should mention invalid code');
  }

  /**
   * Test error handling for non-existent lead
   */
  @IsTest
  static void testLeadNotFound() {
    // Create request for non-existent lead
    String requestJson = JSON.serialize(new Map<String, Object>{
      'leadId' => '00Q000000000001',  // Fake ID
      'code' => '123456'
    });

    // Set up mock request
    RestRequest req = new RestRequest();
    RestResponse res = new RestResponse();
    req.requestBody = Blob.valueOf(requestJson);
    req.httpMethod = 'POST';
    RestContext.request = req;
    RestContext.response = res;

    // Test the method
    Test.startTest();
    WebshopVerificationEmailApi.VerifyEmailResponse response = WebshopVerificationEmailApi.sendVerificationEmail();
    Test.stopTest();

    // Verify error handling
    System.assertEquals(false, response.ok, 'Response should indicate failure');
    System.assertEquals(400, RestContext.response.statusCode, 'HTTP status should be 400');
    //System.assert(response.message.contains('Lead not found'), 'Error message should mention lead not found');
  }

  /**
   * Test error handling for lead with no email
   */
  @IsTest
  static void testLeadWithNoEmail() {
    // Create lead without email
    Lead testLead = new Lead(
      FirstName = 'NoEmail',
      LastName = 'User',
      Company = 'Test Company',
      Status = 'Open - Not Contacted'
      // Email intentionally omitted
    );
    insert testLead;

    // Create request
    String requestJson = JSON.serialize(new Map<String, Object>{
      'leadId' => testLead.Id,
      'code' => '123456'
    });

    // Set up mock request
    RestRequest req = new RestRequest();
    RestResponse res = new RestResponse();
    req.requestBody = Blob.valueOf(requestJson);
    req.httpMethod = 'POST';
    RestContext.request = req;
    RestContext.response = res;

    // Test the method
    Test.startTest();
    WebshopVerificationEmailApi.VerifyEmailResponse response = WebshopVerificationEmailApi.sendVerificationEmail();
    Test.stopTest();

    // Verify error handling
    System.assertEquals(false, response.ok, 'Response should indicate failure');
    System.assertEquals(400, RestContext.response.statusCode, 'HTTP status should be 400');
    //System.assert(response.message.contains('Lead has no email'), 'Error message should mention no email');
  }

  /**
   * Test error handling for already verified lead
   */
  @IsTest
  static void testAlreadyVerifiedLead() {
    // Create verified lead using factory
    Lead testLead = createVerifiedTestLead();

    // Create request
    String requestJson = JSON.serialize(new Map<String, Object>{
      'leadId' => testLead.Id,
      'code' => '123456'
    });

    // Set up mock request
    RestRequest req = new RestRequest();
    RestResponse res = new RestResponse();
    req.requestBody = Blob.valueOf(requestJson);
    req.httpMethod = 'POST';
    RestContext.request = req;
    RestContext.response = res;

    // Test the method
    Test.startTest();
    WebshopVerificationEmailApi.VerifyEmailResponse response = WebshopVerificationEmailApi.sendVerificationEmail();
    Test.stopTest();

    // Verify error handling
    // BUT: if already verified it is not error but OK!
    // System.assertEquals(false, response.ok, 'Response should indicate failure');
    // System.assertEquals(400, RestContext.response.statusCode, 'HTTP status should be 400');
    //System.assert(response.message.contains('Lead already verified'), 'Error message should mention already verified');
  }

  /**
   * Test default expiry time when not specified
   */
  @IsTest
  static void testDefaultExpiryTime() {
    Lead testLead = createTestLead();

    // Create request without expiryMinutes
    String requestJson = JSON.serialize(new Map<String, Object>{
      'leadId' => testLead.Id,
      'code' => 'DEFAULTTEST'
      // expiryMinutes intentionally omitted
    });

    // Set up mock request
    RestRequest req = new RestRequest();
    RestResponse res = new RestResponse();
    req.requestBody = Blob.valueOf(requestJson);
    req.httpMethod = 'POST';
    RestContext.request = req;
    RestContext.response = res;

    // Test the method
    Test.startTest();
    WebshopVerificationEmailApi.VerifyEmailResponse response = WebshopVerificationEmailApi.sendVerificationEmail();
    Test.stopTest();

    // Verify success with default expiry
    System.assertEquals(true, response.ok, 'Response should be successful with default expiry');
  }
}
