/**
 * Test Data Factory
 *
 * @author Zsolt Harmath
 * @description Utility class for creating test data records with consistent patterns.
 *              Provides methods for generating various types of test leads for unit testing.
 */
public with sharing class TestFactory {
  /**
   * Creates a list of standard test leads.
   *
   * @return List<Lead> Array of 10 test Lead records with Web lead source.
   *
   * @description Generates test leads with consistent naming pattern (Jane Doe 0-9)
   *              and standard field values for general testing purposes.
   */
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

  /**
   * Creates test leads with Qualified status for conversion testing.
   *
   * @param count Number of qualified test leads to create.
   * @return List<Lead> Array of Lead records with Status = 'Qualified'.
   *
   * @description Generates leads ready for conversion with consistent naming pattern.
   *              Useful for testing lead conversion functionality.
   */
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

  /**
   * Creates test leads with unqualified status for negative testing.
   *
   * @param count Number of unqualified test leads to create.
   * @return List<Lead> Array of Lead records with Status = 'Open - Not Contacted'.
   *
   * @description Generates leads that should not be converted due to their status.
   *              Useful for testing validation and error handling in conversion processes.
   */
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

  /**
   * Creates a mixed set of qualified and unqualified test leads.
   *
   * @param qualifiedCount Number of qualified leads to include.
   * @param unqualifiedCount Number of unqualified leads to include.
   * @return List<Lead> Combined array of qualified and unqualified Lead records.
   *
   * @description Convenience method for creating test datasets with both convertible
   *              and non-convertible leads. Useful for comprehensive conversion testing.
   */
  public static Lead[] getMixedTestLeads(Integer qualifiedCount, Integer unqualifiedCount) {
    Lead[] mixedLeads = new List<Lead>();

    // Add qualified leads
    mixedLeads.addAll(getQualifiedTestLeads(qualifiedCount));

    // Add unqualified leads
    mixedLeads.addAll(getUnqualifiedTestLeads(unqualifiedCount));

    return mixedLeads;
  }
}
