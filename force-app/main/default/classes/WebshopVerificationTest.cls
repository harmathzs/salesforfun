@IsTest
private class WebshopVerificationTest {

  /**
   * Test setup method to create test data
   * @return Lead test record
   */
  private static Lead createTestLead() {
    Lead testLead = new Lead(
      FirstName = 'Test',
      LastName = 'User',
      Email = 'test@example.com',
      Company = 'Test Company',
      Status = 'Open - Not Contacted',
      Email_Verified__c = false
    );
    insert testLead;
    return testLead;
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
    // Create verified lead
    Lead testLead = new Lead(
      FirstName = 'Verified',
      LastName = 'User',
      Email = 'verified@example.com',
      Company = 'Test Company',
      Status = 'Open - Not Contacted',
      Email_Verified__c = true  // Already verified
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
