/**
 * Lead Trigger Test Class
 *
 * @author Zsolt Harmath
 * @description Test coverage for Lead trigger functionality including insert, update,
 *              upsert, delete, and undelete operations. Tests the Metillium Trigger Framework integration.
 *
 * @group TestClasses
 * @see LeadTriggerAction
 * @see LeadTriggerService
 */
@IsTest
private class LeadTriggerTest {
    /**
     * Sets up test data that runs before each test method.
     *
     * @description Creates 10 standard test leads using TestFactory and inserts them.
     *              These records are available for all test methods in this class.
     *
     * @see TestFactory.createTestLeads()
     */
  @TestSetup static void testBeforeEach() {
    Lead[] leads = TestFactory.createTestLeads();
    insert leads;
  }

  /**
   * Tests Lead insert trigger functionality.
   *
   * @description Verifies that the beforeInsert trigger properly handles new lead creation,
   *              including Web-to-Lead Description to Product Interest copying.
   *
   * @testSetup testBeforeEach()
   * @isTest true
   */
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

  /**
   * Tests Lead update trigger functionality.
   *
   * @description Verifies that the beforeUpdate and afterUpdate triggers properly handle
   *              lead record updates without errors.
   *
   * @testSetup testBeforeEach()
   * @isTest true
   */
  @IsTest static void testUpdate() {
    Lead lead = [SELECT Email FROM Lead LIMIT 1];
    lead.Email = 'modified@test.com';
    update lead;
  }

  /**
   * Tests Lead upsert trigger functionality.
   *
   * @description Verifies that the upsert operation properly handles both insert and update
   *              scenarios for lead records without errors.
   *
   * @testSetup testBeforeEach()
   * @isTest true
   */
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

  /**
   * Tests Lead delete trigger functionality.
   *
   * @description Verifies that the beforeDelete and afterDelete triggers properly handle
   *              lead record deletion without errors.
   *
   * @testSetup testBeforeEach()
   * @isTest true
   */
  @IsTest static void testDelete() {
    Lead lead = [SELECT Email FROM Lead LIMIT 1];
    delete lead;
  }

  /**
   * Tests Lead undelete trigger functionality.
   *
   * @description Verifies that the afterUndelete trigger properly handles
   *              lead record restoration from the recycle bin without errors.
   *
   * @testSetup testBeforeEach()
   * @isTest true
   */
  @IsTest static void testUndelete() {
    Lead lead = [SELECT Email FROM Lead LIMIT 1];
    delete lead;
    undelete lead;
  }
}
