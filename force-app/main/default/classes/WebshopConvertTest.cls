@IsTest
private class WebshopConvertTest {

    // Helper method to create RestRequest for testing
    private static RestRequest createRestRequest(String requestBody) {
        RestRequest req = new RestRequest();
        req.requestBody = Blob.valueOf(requestBody);
        req.httpMethod = 'POST';
        return req;
    }

    // Helper method to create a single test lead
    private static Lead createTestLead() {
        return new Lead(
            FirstName = 'Test',
            LastName = 'Lead',
            Company = 'Test Company',
            Status = 'Open - Not Contacted',
            Email = 'test@example.com'
        );
    }

    // Helper method to create a converted lead with related records
    private static Lead createConvertedLead() {
        // Create related records first
        Account testAccount = new Account(
            Name = 'Test Account',
            Industry = 'Technology'
        );
        insert testAccount;

        Contact testContact = new Contact(
            FirstName = 'Test',
            LastName = 'Contact',
            AccountId = testAccount.Id,
            Email = 'test.contact@example.com'
        );
        insert testContact;

        Opportunity testOpportunity = new Opportunity(
            Name = 'Test Opportunity',
            AccountId = testAccount.Id,
            CloseDate = Date.today().addDays(30),
            StageName = 'Prospecting'
        );
        insert testOpportunity;

        // Create and return converted lead
        Lead lead = createTestLead();
        lead.IsConverted = true;
        //lead.ConvertedAccountId = testAccount.Id;
        //lead.ConvertedContactId = testContact.Id;
        //lead.ConvertedOpportunityId = testOpportunity.Id;
        return lead;
    }

    // Test setup method
    @TestSetup
    static void setupTestData() {
        // Create test data that will be available to all test methods
        createTestLead();
    }

    // Test method for successful lead conversion with opportunity creation
    @IsTest
    static void testConvertLeadWithOpportunity() {
        // Create test lead
        Lead testLead = createTestLead();
        insert testLead;

        // Set up test context
        Test.startTest();
        RestContext.request = createRestRequest(JSON.serialize(new Map<String, Object>{
            'leadId' => testLead.Id,
            'createOpportunity' => true,
            'opportunityName' => 'Test Webshop Opportunity'
        }));

        // Call the method
        Map<String, Object> result = WebshopConvert.post();

        Test.stopTest();

        // Verify results
        System.assertEquals(true, result.get('success'), 'Conversion should be successful');
        System.assertEquals(null, result.get('error'), 'There should be no errors');

        Map<String, Object> conversionResult = (Map<String, Object>) result.get('result');
        System.assertNotEquals(null, conversionResult.get('accountId'), 'Account ID should be returned');
        System.assertNotEquals(null, conversionResult.get('contactId'), 'Contact ID should be returned');
        System.assertNotEquals(null, conversionResult.get('opportunityId'), 'Opportunity ID should be returned');

        // Verify lead is converted
        Lead convertedLead = [SELECT IsConverted FROM Lead WHERE Id = :testLead.Id];
        System.assertEquals(true, convertedLead.IsConverted, 'Lead should be converted');
    }

    // Test method for successful lead conversion without opportunity creation
    @IsTest
    static void testConvertLeadWithoutOpportunity() {
        // Create test lead
        Lead testLead = createTestLead();
        insert testLead;

        // Set up test context
        Test.startTest();
        RestContext.request = createRestRequest(JSON.serialize(new Map<String, Object>{
            'leadId' => testLead.Id,
            'createOpportunity' => false
        }));

        // Call the method
        Map<String, Object> result = WebshopConvert.post();

        Test.stopTest();

        // Verify results
        System.assertEquals(true, result.get('success'), 'Conversion should be successful');
        System.assertEquals(null, result.get('error'), 'There should be no errors');

        Map<String, Object> conversionResult = (Map<String, Object>) result.get('result');
        System.assertNotEquals(null, conversionResult.get('accountId'), 'Account ID should be returned');
        System.assertNotEquals(null, conversionResult.get('contactId'), 'Contact ID should be returned');
        System.assertEquals(null, conversionResult.get('opportunityId'), 'Opportunity ID should be null');

        // Verify lead is converted
        Lead convertedLead = [SELECT IsConverted FROM Lead WHERE Id = :testLead.Id];
        System.assertEquals(true, convertedLead.IsConverted, 'Lead should be converted');
    }

    // Test method for already converted lead (idempotent behavior)
    @IsTest
    static void testAlreadyConvertedLead() {
        // Create and convert a lead first
        Lead testLead = createTestLead();
        insert testLead;

        // Convert the lead using standard Salesforce conversion
        Database.LeadConvert lc = new Database.LeadConvert();
        lc.setLeadId(testLead.Id);
        lc.setConvertedStatus('Closed - Converted');
        Database.LeadConvertResult lcr = Database.convertLead(lc);

        // Set up test context to convert again
        Test.startTest();
        RestContext.request = createRestRequest(JSON.serialize(new Map<String, Object>{
            'leadId' => testLead.Id,
            'createOpportunity' => true
        }));

        // Call the method
        Map<String, Object> result = WebshopConvert.post();

        Test.stopTest();

        // Verify results - should return existing converted records
        System.assertEquals(true, result.get('success'), 'Conversion should be successful');
        System.assertEquals(null, result.get('error'), 'There should be no errors');

        Map<String, Object> conversionResult = (Map<String, Object>) result.get('result');
        System.assertEquals(lcr.getAccountId(), conversionResult.get('accountId'), 'Should return existing account ID');
        System.assertEquals(lcr.getContactId(), conversionResult.get('contactId'), 'Should return existing contact ID');
        System.assertEquals(lcr.getOpportunityId(), conversionResult.get('opportunityId'), 'Should return existing opportunity ID');
    }

    // Test method for missing request body
    @IsTest
    static void testMissingRequestBody() {
        Test.startTest();
        RestContext.request = new RestRequest(); // No request body

        Map<String, Object> result = WebshopConvert.post();

        Test.stopTest();

        System.assertEquals(false, result.get('success'), 'Conversion should fail');
        System.assertNotEquals(null, result.get('error'), 'There should be an error');
        System.assertEquals('missing request body', result.get('error'), 'Error should indicate missing request body');
    }

    // Test method for missing leadId
    @IsTest
    static void testMissingLeadId() {
        Test.startTest();
        RestContext.request = createRestRequest(JSON.serialize(new Map<String, Object>{
            'createOpportunity' => true
        }));

        Map<String, Object> result = WebshopConvert.post();

        Test.stopTest();

        System.assertEquals(false, result.get('success'), 'Conversion should fail');
        System.assertNotEquals(null, result.get('error'), 'There should be an error');
        System.assertEquals('leadId is required', result.get('error'), 'Error should indicate missing leadId');
    }

    // Test method for invalid leadId
    @IsTest
    static void testInvalidLeadId() {
        Test.startTest();
        RestContext.request = createRestRequest(JSON.serialize(new Map<String, Object>{
            'leadId' => '00Q000000000001', // Invalid ID
            'createOpportunity' => true
        }));

        Map<String, Object> result = WebshopConvert.post();

        Test.stopTest();

        System.assertEquals(false, result.get('success'), 'Conversion should fail');
        System.assertNotEquals(null, result.get('error'), 'There should be an error');
    }

    // Test method for default opportunity name when not provided
    @IsTest
    static void testDefaultOpportunityName() {
        // Create test lead with company name
        Lead testLead = createTestLead();
        testLead.Company = 'Acme Corporation';
        insert testLead;

        Test.startTest();
        RestContext.request = createRestRequest(JSON.serialize(new Map<String, Object>{
            'leadId' => testLead.Id,
            'createOpportunity' => true
            // No opportunityName provided
        }));

        Map<String, Object> result = WebshopConvert.post();

        Test.stopTest();

        System.assertEquals(true, result.get('success'), 'Conversion should be successful');

        Map<String, Object> conversionResult = (Map<String, Object>) result.get('result');
        Id oppId = (Id) conversionResult.get('opportunityId');

        // Verify opportunity was created with default name
        Opportunity createdOpp = [SELECT Name FROM Opportunity WHERE Id = :oppId];
        System.assertEquals('Acme Corporation Webshop Opportunity', createdOpp.Name, 'Should use company name for opportunity');
    }

    // Test method for opportunity name when provided
    @IsTest
    static void testCustomOpportunityName() {
        Lead testLead = createTestLead();
        insert testLead;

        Test.startTest();
        RestContext.request = createRestRequest(JSON.serialize(new Map<String, Object>{
            'leadId' => testLead.Id,
            'createOpportunity' => true,
            'opportunityName' => 'Custom Opportunity Name'
        }));

        Map<String, Object> result = WebshopConvert.post();

        Test.stopTest();

        System.assertEquals(true, result.get('success'), 'Conversion should be successful');

        Map<String, Object> conversionResult = (Map<String, Object>) result.get('result');
        Id oppId = (Id) conversionResult.get('opportunityId');

        // Verify opportunity was created with custom name
        Opportunity createdOpp = [SELECT Name FROM Opportunity WHERE Id = :oppId];
        System.assertEquals('Custom Opportunity Name', createdOpp.Name, 'Should use provided opportunity name');
    }

    // Additional test using existing TestFactory for qualified leads
    @IsTest
    static void testConvertQualifiedLead() {
        // Use existing TestFactory to create qualified leads
        Lead[] qualifiedLeads = TestFactory.getQualifiedTestLeads(1);
        insert qualifiedLeads;

        Test.startTest();
        RestContext.request = createRestRequest(JSON.serialize(new Map<String, Object>{
            'leadId' => qualifiedLeads[0].Id,
            'createOpportunity' => true,
            'opportunityName' => 'Qualified Lead Opportunity'
        }));

        Map<String, Object> result = WebshopConvert.post();

        Test.stopTest();

        System.assertEquals(true, result.get('success'), 'Conversion should be successful');
        System.assertEquals(null, result.get('error'), 'There should be no errors');

        Map<String, Object> conversionResult = (Map<String, Object>) result.get('result');
        System.assertNotEquals(null, conversionResult.get('accountId'), 'Account ID should be returned');
        System.assertNotEquals(null, conversionResult.get('contactId'), 'Contact ID should be returned');
        System.assertNotEquals(null, conversionResult.get('opportunityId'), 'Opportunity ID should be returned');
    }
}
