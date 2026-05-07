public with sharing class TestFactory {
  public static Lead[] getTestLeads() {
    Lead[] testLeads = new List<Lead>();
    for (Integer i=0; i<10; i++) {
      testLeads.add(new Lead(
        FirstName='Jane',
        LastName='Doe '+i,
        Company='Test Corp',
        LeadSource='Web',
        Email='test'+i+'@lead.com',
        Description='I am interested in the Perfect Product PP-2000 series.'
      ));
    }
    return testLeads;
  }
}
