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
  public static Lead[] createTestLeads() {
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
  public static Lead[] createQualifiedTestLeads(Integer count) {
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
  public static Lead[] createUnqualifiedTestLeads(Integer count) {
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
/*
  public static Lead[] getMixedTestLeads(Integer qualifiedCount, Integer unqualifiedCount) {
    Lead[] mixedLeads = new List<Lead>();

    // Add qualified leads
    mixedLeads.addAll(getQualifiedTestLeads(qualifiedCount));

    // Add unqualified leads
    mixedLeads.addAll(getUnqualifiedTestLeads(unqualifiedCount));

    return mixedLeads;
  }

 */

  /**
   * Creates a test product for e-commerce testing.
   *
   * @param productName Name of the product to create
   * @param productCode Product code for the product
   * @param isActive Whether the product should be active
   * @return Product2 The created test product
   *
   * @description Creates a standard test product with consistent field values
   *              for webshop and checkout testing scenarios.
   */
  public static Product2 createTestProduct(String productName, String productCode, Boolean isActive) {
    Product2 testProduct = new Product2(
      Name = productName,
      ProductCode = productCode,
      Description = 'Test product for webshop checkout testing',
      IsActive = isActive,
      Family = 'Webshop'
    );
    insert testProduct;
    return testProduct;
  }

  /**
   * Creates multiple test products for bulk testing.
   *
   * @param count Number of test products to create
   * @return List<Product2> Array of created test products
   *
   * @description Creates multiple test products with sequential naming
   *              for comprehensive webshop testing scenarios.
   */
  public static Product2[] createTestProducts(Integer count) {
    Product2[] testProducts = new List<Product2>();

    for (Integer i = 0; i < count; i++) {
      // Manual string padding since String.leftPad() doesn't exist in Apex
      String paddedIndex = String.valueOf(i);
      while (paddedIndex.length() < 3) {
        paddedIndex = '0' + paddedIndex;
      }
      testProducts.add(createTestProduct(
        'Test Product ' + i,
        'TEST-PROD-' + paddedIndex,
        true
      ));
    }

    return testProducts;
  }

  /**
   * Creates a pricebook entry for a product in the standard pricebook.
   *
   * @param productId ID of the product to create pricebook entry for
   * @param unitPrice Unit price for the pricebook entry
   * @param isActive Whether the pricebook entry should be active
   * @return PricebookEntry The created pricebook entry
   *
   * @description Creates a pricebook entry in the standard pricebook
   *              for webshop checkout testing.
   */
/*
  public static PricebookEntry createPricebookEntry(Id productId, Decimal unitPrice, Boolean isActive) {
    Id standardPricebookId = Test.getStandardPricebookId();

    PricebookEntry pbe = new PricebookEntry(
      Pricebook2Id = standardPricebookId,
      Product2Id = productId,
      UnitPrice = unitPrice,
      IsActive = isActive
    );
    insert pbe;
    return pbe;
  }

 */

  /**
   * Creates pricebook entries for multiple products.
   *
   * @param productIds List of product IDs to create pricebook entries for
   * @param basePrice Base unit price for the pricebook entries
   * @return List<PricebookEntry> Array of created pricebook entries
   *
   * @description Creates pricebook entries in the standard pricebook
   *              for multiple products with sequential pricing.
   */
  public static PricebookEntry[] createTestPricebookEntries(List<Id> productIds, Decimal basePrice) {
    PricebookEntry[] entries = new List<PricebookEntry>();
    Id standardPricebookId = Test.getStandardPricebookId();

    for (Integer i = 0; i < productIds.size(); i++) {
      entries.add(new PricebookEntry(
        Pricebook2Id = standardPricebookId,
        Product2Id = productIds[i],
        UnitPrice = basePrice + (i * 10),
        IsActive = true
      ));
    }

    insert entries;
    return entries;
  }

  /**
   * Creates a complete webshop test setup with leads, products, and pricebook entries.
   *
   * @param leadCount Number of test leads to create
   * @param productCount Number of test products to create
   * @return Map<String, Object> Map containing all created test records
   *
   * @description Comprehensive setup method that creates all necessary test data
   *              for webshop checkout testing in a single call.
   */
  public static Map<String, Object> createWebshopTestSetup(Integer leadCount, Integer productCount) {
    Map<String, Object> testData = new Map<String, Object>();

    // Create test leads
    Lead[] testLeads = createQualifiedTestLeads(leadCount);
    insert testLeads;
    testData.put('leads', testLeads);

    // Create test products
    Product2[] testProducts = createTestProducts(productCount);
    testData.put('products', testProducts);

    // Create pricebook entries
    List<Id> productIds = new List<Id>();
    for (Product2 prod : testProducts) {
      productIds.add(prod.Id);
    }
    PricebookEntry[] entries = createTestPricebookEntries(productIds, 100.00);
    testData.put('pricebookEntries', entries);

    // Add standard pricebook ID
    testData.put('standardPricebookId', Test.getStandardPricebookId());

    return testData;
  }

  /**
   * Creates a complete checkout request structure for testing.
   *
   * @param leadId ID of the lead to use in the request
   * @param productId ID of the product to use in product lines
   * @param externalOrderId External order ID for idempotency testing
   * @param opportunityName Custom opportunity name (optional)
   * @return WebshopCheckout.CheckoutRequest Fully populated checkout request
   *
   * @description Helper method to create properly structured checkout requests
   *              for webshop testing scenarios.
   */
/*
  public static WebshopCheckout.CheckoutRequest createTestCheckoutRequest(
    Id leadId, Id productId, String externalOrderId, String opportunityName
  ) {
    WebshopCheckout.CheckoutRequest request = new WebshopCheckout.CheckoutRequest();

    request.traceId = 'test-trace-' + String.valueOf(System.now().getTime());
    request.externalOrderId = externalOrderId;
    request.leadId = leadId;
    request.webshopUserId = 'test-user-' + String.valueOf(System.now().getTime());
    request.pricebookName = 'Standard Price Book';

    // Add opportunity metadata if provided
    if (String.isNotBlank(opportunityName)) {
      request.opportunity = new Map<String, Object>{
        'name' => opportunityName
      };
    }

    // Add product lines
    request.opportunityProducts = new List<WebshopCheckout.ProductLine>{
      createTestProductLine(productId, 1, 100.00)
    };

    request.orderProducts = new List<WebshopCheckout.ProductLine>{
      createTestProductLine(productId, 1, 100.00)
    };

    return request;
  }

 */

  /**
   * Helper method to create ProductLine instances for checkout requests.
   *
   * @param productId ID of the product
   * @param quantity Quantity for the product line
   * @param unitPrice Unit price for the product line
   * @return WebshopCheckout.ProductLine Product line instance
   *
   * @description Convenience method for creating product line items
   *              in webshop checkout test scenarios.
   */
/*
  public static WebshopCheckout.ProductLine createTestProductLine(Id productId, Decimal quantity, Decimal unitPrice) {
    WebshopCheckout.ProductLine pl = new WebshopCheckout.ProductLine();
    pl.productId = productId;
    pl.quantity = quantity;
    pl.unitPrice = unitPrice;
    return pl;
  }

 */
  /**
   * Creates a list of standard test accounts.
   *
   * @param count Number of test accounts to create
   * @return List<Account> Array of created test Account records
   *
   * @description Generates test accounts with consistent naming pattern
   *              and standard field values for general testing purposes.
   */
  public static Account[] createTestAccounts(Integer count) {
    Account[] testAccounts = new List<Account>();

    for (Integer i = 0; i < count; i++) {
      testAccounts.add(new Account(
        Name = 'Test Account ' + i,
        Industry = 'Technology',
        BillingStreet = '123 Test Street',
        BillingCity = 'London',
        BillingPostalCode = 'SW1A 1AA',
        BillingCountry = 'United Kingdom',
        Phone = '(415) 555-01' + String.valueOf(i).right(2),
        Website = 'www.testaccount' + i + '.com',
        Description = 'Test account for unit testing purposes'
      ));
    }

    return testAccounts;
  }

  /**
   * Creates a list of standard test contacts.
   *
   * @param count Number of test contacts to create
   * @param accountId Optional account ID to associate contacts with
   * @return List<Contact> Array of created test Contact records
   *
   * @description Generates test contacts with consistent naming pattern
   *              and standard field values. Can optionally associate with an account.
   */
  public static Contact[] createTestContacts(Integer count, Id accountId) {
    Contact[] testContacts = new List<Contact>();

    for (Integer i = 0; i < count; i++) {
      Contact contact = new Contact(
        FirstName = 'Test',
        LastName = 'Contact ' + i,
        Email = 'testcontact' + i + '@example.com',
        Phone = '(415) 555-01' + String.valueOf(i).right(2),
        Title = 'Test User',
        Department = 'Quality Assurance',
        Description = 'Test contact for unit testing purposes'
      );

      if (accountId != null) {
        contact.AccountId = accountId;
      }

      testContacts.add(contact);
    }

    return testContacts;
  }

  /**
   * Creates a list of standard test opportunities.
   *
   * @param count Number of test opportunities to create
   * @param accountId Optional account ID to associate opportunities with
   * @param stageName Optional stage name for the opportunities, like 'Prospecting'
   * @param closeDate Optional close date for the opportunities
   * @return List<Opportunity> Array of created test Opportunity records
   *
   * @description Generates test opportunities with consistent naming pattern
   *              and standard field values. Can optionally associate with an account
   *              and set specific stage and close date.
   */
  public static Opportunity[] createTestOpportunities(Integer count, Id accountId, String stageName, Date closeDate) {
    Opportunity[] testOpportunities = new List<Opportunity>();

    if (closeDate == null) {
      closeDate = System.today().addDays(30);
    }

    for (Integer i = 0; i < count; i++) {
      Opportunity opp = new Opportunity(
        Name = 'Test Opportunity ' + i,
        StageName = stageName,
        CloseDate = closeDate,
        Description = 'Test opportunity for unit testing purposes',
        Amount = 10000 + (i * 1000)
      );

      if (accountId != null) {
        opp.AccountId = accountId;
      }

      testOpportunities.add(opp);
    }

    return testOpportunities;
  }

  /**
   * Creates a complete set of related test data (Accounts, Contacts, Opportunities).
   *
   * @param accountCount Number of test accounts to create
   * @param contactsPerAccount Number of contacts to create per account
   * @param opportunitiesPerAccount Number of opportunities to create per account
   * @return Map<String, Object> Map containing all created test records organized by type
   *
   * @description Comprehensive setup method that creates a complete hierarchy of
   *              related test data for complex testing scenarios involving accounts,
   *              contacts, and opportunities.
   *              WARNING: This method actually Inserts records with Ids !!!
   */
  public static Map<String, Object> createCompleteTestSetup(Integer accountCount, Integer contactsPerAccount, Integer opportunitiesPerAccount) {
    Map<String, Object> testData = new Map<String, Object>();

    // Create test accounts
    Account[] testAccounts = createTestAccounts(accountCount);
    insert testAccounts;
    testData.put('accounts', testAccounts);

    // Create contacts for each account
    List<Contact> allContacts = new List<Contact>();
    for (Account acc : testAccounts) {
      Contact[] accountContacts = createTestContacts(contactsPerAccount, acc.Id);
      allContacts.addAll(accountContacts);
    }
    insert allContacts;
    testData.put('contacts', allContacts);

    // Create opportunities for each account
    List<Opportunity> allOpportunities = new List<Opportunity>();
    for (Account acc : testAccounts) {
      Opportunity[] accountOpportunities = createTestOpportunities(opportunitiesPerAccount, acc.Id, 'Prospecting', Date.today());
      allOpportunities.addAll(accountOpportunities);
    }
    insert allOpportunities;
    testData.put('opportunities', allOpportunities);

    return testData;
  }

  /**
   * createTestOpportunityProducts
   * Creates products, pricebook entries and OpportunityLineItem records for a given Opportunity.
   *
   * @param oppId Id of the Opportunity to attach line items to
   * @param productCount Number of product lines to create
   * @param baseUnitPrice Base unit price for the first product (subsequent products increment)
   * @return List<OpportunityLineItem> Created OpportunityLineItem records
   *
   * @description Convenience method used by tests that need Opportunities pre-populated with
   *              OpportunityLineItems. Ensures PricebookEntry records exist in the standard pricebook.
   */
  public static OpportunityLineItem[] createTestOpportunityProducts(Id oppId, Integer productCount, Decimal baseUnitPrice) {
    if (oppId == null) return new OpportunityLineItem[0];
    if (productCount == null || productCount <= 0) productCount = 1;
    if (baseUnitPrice == null) baseUnitPrice = 100.00;

    // Create products
    Product2[] products = createTestProducts(productCount);

    // Create pricebook entries in the standard pricebook
    List<Id> productIds = new List<Id>();
    for (Product2 p : products) productIds.add(p.Id);
    PricebookEntry[] pbes = createTestPricebookEntries(productIds, baseUnitPrice);

    // Create OpportunityLineItems
    OpportunityLineItem[] olis = new List<OpportunityLineItem>();
    for (Integer i = 0; i < products.size(); i++) {
      OpportunityLineItem oli = new OpportunityLineItem(
        OpportunityId = oppId,
        PricebookEntryId = pbes[i].Id,
        Quantity = 1 + i,
        UnitPrice = pbes[i].UnitPrice
      );
      olis.add(oli);
    }


    return olis;
  }

  public static Contract[] createTestContracts(Integer count) {
    Account[] accounts = createTestAccounts(1);
    insert accounts;
    Account acc = accounts.get(0);

    Contract[] contracts = new List<Contract>();
    for (Integer i=0; i<count; i++) {
      Contract contract = new Contract(
        AccountId = acc.Id,
        Status = 'Draft',
        StartDate = Date.today(),
        ContractTerm = 12
      );
      contracts.add(contract);
    }

    return contracts;
  }

  public static Contract_Line_Item__c[] createTestContractLineItems(Contract[] contracts, PricebookEntry pbe) {
    Contract_Line_Item__c[] crlis = new List<Contract_Line_Item__c>();
    for (Contract contract: contracts) {
      if (String.isNotBlank(contract.Id)) {
        Contract_Line_Item__c crli = new Contract_Line_Item__c(
          Contract__c = contract.Id,
          Description__c = pbe.Product2.Description,
          Opportunity__c = contract.Opportunity__c,
          Product__c = pbe.Product2Id,
          Quantity__c = 1,
          Unit_Price__c = pbe.UnitPrice
        );
        crlis.add(crli);
      }
    }
    return crlis;
  }

}
