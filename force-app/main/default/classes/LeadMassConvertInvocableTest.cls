@IsTest
private class LeadMassConvertInvocableTest {

  @TestSetup
  static void setupTestData() {
    // Create test leads with different statuses
    List<Lead> testLeads = new List<Lead>();

    // Create 3 qualified leads
    for (Integer i = 0; i < 3; i++) {
      testLeads.add(new Lead(
        FirstName = 'Test' + i,
        LastName = 'Lead' + i,
        Company = 'Test Company ' + i,
        Status = 'Qualified',
        Email = 'test' + i + '@example.com'
      ));
    }

    // Create 2 unqualified leads
    for (Integer i = 3; i < 5; i++) {
      testLeads.add(new Lead(
        FirstName = 'Test' + i,
        LastName = 'Lead' + i,
        Company = 'Test Company ' + i,
        Status = 'Open - Not Contacted',
        Email = 'test' + i + '@example.com'
      ));
    }

    insert testLeads;
  }

  @IsTest
  static void testMassConvertWithQualifiedLeads() {
    // Get qualified leads
    List<Lead> qualifiedLeads = [SELECT Id, Status FROM Lead WHERE Status = 'Qualified'];

    Test.startTest();
    List<String> results = LeadMassConvertInvocable.massConvert(new List<List<Lead>>{qualifiedLeads});
    Test.stopTest();

    // Verify results
    System.assertEquals(1, results.size(), 'Should return one JSON result');

    // Parse JSON results
    Map<String, Object> resultsMap = (Map<String, Object>)JSON.deserializeUntyped(results[0]);
    List<Object> conversionResults = (List<Object>)resultsMap.get('results');
    List<Object> errors = (List<Object>)resultsMap.get('error');

    // Should have 3 successful conversions
    System.assertEquals(3, conversionResults.size(), 'Should have 3 conversion results');
    System.assertEquals(0, errors.size(), 'Should have no errors');

    // Verify each result has the expected fields
    for (Object resultObj : conversionResults) {
      Map<String, Object> result = (Map<String, Object>)resultObj;
      System.assert(result.get('OpportunityId') != null, 'Should have OpportunityId');
      System.assert(result.get('AccountId') != null, 'Should have AccountId');
      System.assert(result.get('ContactId') != null, 'Should have ContactId');
      System.assertEquals(null, result.get('Error'), 'Should have no error');
    }

    // Verify leads were converted
    List<Lead> convertedLeads = [SELECT IsConverted FROM Lead WHERE Id IN :qualifiedLeads];
    for (Lead convertedLead : convertedLeads) {
      System.assertEquals(true, convertedLead.IsConverted, 'Lead should be converted');
    }
  }

  @IsTest
  static void testMassConvertWithUnqualifiedLeads() {
    // Get unqualified leads
    List<Lead> unqualifiedLeads = [SELECT Id, Status FROM Lead WHERE Status != 'Qualified'];

    Test.startTest();
    List<String> results = LeadMassConvertInvocable.massConvert(new List<List<Lead>>{unqualifiedLeads});
    Test.stopTest();

    // Verify results
    System.assertEquals(1, results.size(), 'Should return one JSON result');

    // Parse JSON results
    Map<String, Object> resultsMap = (Map<String, Object>)JSON.deserializeUntyped(results[0]);
    List<Object> conversionResults = (List<Object>)resultsMap.get('results');
    List<Object> errors = (List<Object>)resultsMap.get('error');

    // Should have 2 failed conversions due to status
    System.assertEquals(2, conversionResults.size(), 'Should have 2 conversion results');
    System.assertEquals(0, errors.size(), 'Should have no top-level errors');

    // Verify each result has error about status
    for (Object resultObj : conversionResults) {
      Map<String, Object> result = (Map<String, Object>)resultObj;
      System.assertEquals(null, result.get('OpportunityId'), 'Should have no OpportunityId');
      System.assertEquals(null, result.get('AccountId'), 'Should have no AccountId');
      System.assertEquals(null, result.get('ContactId'), 'Should have no ContactId');
      System.assert(result.get('Error') != null, 'Should have error');
      System.assert(((String)result.get('Error')).contains('Qualified'), 'Error should mention Qualified status');
    }
  }

  @IsTest
  static void testMassConvertWithEmptyList() {
    Test.startTest();
    List<String> results = LeadMassConvertInvocable.massConvert(new List<List<Lead>>{new List<Lead>()});
    Test.stopTest();

    // Verify results
    System.assertEquals(1, results.size(), 'Should return one JSON result');

    // Parse JSON results
    Map<String, Object> resultsMap = (Map<String, Object>)JSON.deserializeUntyped(results[0]);
    List<Object> conversionResults = (List<Object>)resultsMap.get('results');
    List<Object> errors = (List<Object>)resultsMap.get('error');

    // Should have error about empty list
    System.assertEquals(0, conversionResults.size(), 'Should have no conversion results');
    System.assertEquals(1, errors.size(), 'Should have one error');

    Map<String, Object> error = (Map<String, Object>)errors[0];
    System.assertEquals('Leads list is empty!', error.get('Error'), 'Error should indicate empty list');
  }

  @IsTest
  static void testMassConvertWithMixedLeads() {
    // Get all leads (both qualified and unqualified)
    List<Lead> allLeads = [SELECT Id, Status FROM Lead];

    Test.startTest();
    List<String> results = LeadMassConvertInvocable.massConvert(new List<List<Lead>>{allLeads});
    Test.stopTest();

    // Verify results
    System.assertEquals(1, results.size(), 'Should return one JSON result');

    // Parse JSON results
    Map<String, Object> resultsMap = (Map<String, Object>)JSON.deserializeUntyped(results[0]);
    List<Object> conversionResults = (List<Object>)resultsMap.get('results');
    List<Object> errors = (List<Object>)resultsMap.get('error');

    // Should have 5 total results (3 qualified + 2 unqualified)
    System.assertEquals(5, conversionResults.size(), 'Should have 5 conversion results');
    System.assertEquals(0, errors.size(), 'Should have no top-level errors');

    // Count successful vs failed conversions
    Integer successfulCount = 0;
    Integer failedCount = 0;

    for (Object resultObj : conversionResults) {
      Map<String, Object> result = (Map<String, Object>)resultObj;
      if (result.get('Error') == null) {
        successfulCount++;
        System.assert(result.get('OpportunityId') != null, 'Successful result should have OpportunityId');
      } else {
        failedCount++;
        System.assert(((String)result.get('Error')).contains('Qualified'), 'Failed result should mention Qualified status');
      }
    }

    System.assertEquals(3, successfulCount, 'Should have 3 successful conversions');
    System.assertEquals(2, failedCount, 'Should have 2 failed conversions');
  }

  @IsTest
  static void testMassConvertWithNullInput() {
    Test.startTest();
    List<String> results = LeadMassConvertInvocable.massConvert(null);
    Test.stopTest();

    // Verify results
    System.assertEquals(1, results.size(), 'Should return one JSON result');

    // Parse JSON results
    Map<String, Object> resultsMap = (Map<String, Object>)JSON.deserializeUntyped(results[0]);
    List<Object> conversionResults = (List<Object>)resultsMap.get('results');
    List<Object> errors = (List<Object>)resultsMap.get('error');

    // Should have error about null input
    System.assertEquals(0, conversionResults.size(), 'Should have no conversion results');
    System.assertEquals(1, errors.size(), 'Should have one error');

    Map<String, Object> error = (Map<String, Object>)errors[0];
    System.assertEquals('Leads list is empty!', error.get('Error'), 'Error should indicate empty list');
  }
}
