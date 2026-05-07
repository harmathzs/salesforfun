@IsTest
private class LeadTriggerTest {
  @TestSetup static void testBeforeEach() {
    Lead[] leads = TestFactory.getTestLeads();
    insert leads;
  }

  @IsTest static void testInsert() {
    Lead newLead = new Lead(
      FirstName='John',
      LastName='Doe',
      Company='Test Corp',
      LeadSource='Web',
      Email='john@doe.com'
    );
    insert newLead;
  }

  @IsTest static void testUpdate() {
    Lead lead = [SELECT Email FROM Lead LIMIT 1];
    lead.Email = 'modified@test.com';
    update lead;
  }

  @IsTest static void testUpsert() {
    Lead newLead = new Lead(
      FirstName='John',
      LastName='Doe',
      Company='Test Corp',
      LeadSource='Web',
      Email='john@doe.com'
    );
    upsert newLead;
    upsert newLead;
  }

  @IsTest static void testDelete() {
    Lead lead = [SELECT Email FROM Lead LIMIT 1];
    delete lead;
  }

  @IsTest static void testUndelete() {
    Lead lead = [SELECT Email FROM Lead LIMIT 1];
    delete lead;
    undelete lead;
  }
}
