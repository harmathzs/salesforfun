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

  public static Lead[] getQualifiedTestLeads(Integer count) {
    Lead[] qualifiedLeads = new List<Lead>();
    for (Integer i=0; i<count; i++) {
      qualifiedLeads.add(new Lead(
        FirstName='Qualified',
        LastName='Lead '+i,
        Company='Qualified Company ' + i,
        Status='Qualified',
        LeadSource='Web',
        Email='qualified'+i+'@test.com',
        Description='Interested in conversion testing'
      ));
    }
    return qualifiedLeads;
  }

  public static Lead[] getUnqualifiedTestLeads(Integer count) {
    Lead[] unqualifiedLeads = new List<Lead>();
    for (Integer i=0; i<count; i++) {
      unqualifiedLeads.add(new Lead(
        FirstName='Unqualified',
        LastName='Lead '+i,
        Company='Unqualified Company ' + i,
        Status='Open - Not Contacted',
        LeadSource='Web',
        Email='unqualified'+i+'@test.com',
        Description='Not ready for conversion'
      ));
    }
    return unqualifiedLeads;
  }

  public static Lead[] getMixedTestLeads(Integer qualifiedCount, Integer unqualifiedCount) {
    Lead[] mixedLeads = new List<Lead>();

    // Add qualified leads
    mixedLeads.addAll(getQualifiedTestLeads(qualifiedCount));

    // Add unqualified leads
    mixedLeads.addAll(getUnqualifiedTestLeads(unqualifiedCount));

    return mixedLeads;
  }
}
