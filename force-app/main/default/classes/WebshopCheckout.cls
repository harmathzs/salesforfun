@RestResource(UrlMapping='/webshop/checkout/*')
global with sharing class WebshopCheckout {

  // Simple request wrapper matching the JSON we expect
  public class CheckoutRequest {
    public String traceId;
    public String externalOrderId;
    public String leadId;
    public String webshopUserId;
    public String pricebookName;
    public Map<String,Object> opportunity; // optional metadata
    public List<ProductLine> opportunityProducts;
    public List<ProductLine> orderProducts;
  }

  public class ProductLine {
    public String productId; // Product2 Id
    public String pricebookEntryId; // optional: PricebookEntry Id
    public Decimal unitPrice;
    public Decimal quantity;
  }

  public class CheckoutResponse {
    public Boolean ok;
    public String message;
    public Id accountId;
    public Id contactId;
    public Id opportunityId;
    public Id orderId;
    public Map<String,Id> createdIds = new Map<String,Id>();
    public List<String> warnings = new List<String>();
  }

  @HttpPost
  global static void doCheckout() {
    RestRequest req = RestContext.request;
    RestResponse res = RestContext.response;
    res.addHeader('Content-Type', 'application/json');

    CheckoutResponse out = new CheckoutResponse();
    out.ok = false;

    try {
      String body = req.requestBody.toString();
      System.debug('=== WebshopCheckout Started ===');
      System.debug('Request body length: ' + (String.isBlank(body) ? '0' : String.valueOf(body.length())));

      if (String.isBlank(body)) {
        System.debug('Error: Empty request body received');
        out.message = 'Empty request body';
        res.statusCode = 400;
        res.responseBody = Blob.valueOf(JSON.serialize(out));
        return;
      }

      System.debug('Body to parse: ' + body.substring(0, Math.min(1000, body.length())) + (body.length() > 1000 ? '...' : ''));

      // Parse the request using untyped deserialization first for validation
      Object parsedObj = JSON.deserializeUntyped(body);
      System.debug('JSON parsing result: ' + (parsedObj == null ? 'NULL (invalid JSON)' : 'Success'));

      // Check if we got null (completely invalid JSON)
      if (parsedObj == null) {
        System.debug('Error: Invalid JSON payload - could not parse');
        out.message = 'Invalid JSON payload';
        res.statusCode = 400;
        res.responseBody = Blob.valueOf(JSON.serialize(out));
        return;
      }

      // Try to deserialize as CheckoutRequest
      CheckoutRequest r;
      try {
        System.debug('Attempting to deserialize as CheckoutRequest...');
        r = (CheckoutRequest) JSON.deserialize(body, CheckoutRequest.class);
        System.debug('Successfully deserialized CheckoutRequest');
      } catch (Exception e) {
        System.debug('Error: Invalid request structure - ' + e.getMessage());
        out.message = 'Invalid request structure: ' + e.getMessage();
        res.statusCode = 400;
        res.responseBody = Blob.valueOf(JSON.serialize(out));
        return;
      }

      // basic validation - check if deserialization resulted in null
      if (r == null) {
        System.debug('Error: Deserialization resulted in null CheckoutRequest');
        out.message = 'Invalid JSON payload';
        res.statusCode = 400;
        res.responseBody = Blob.valueOf(JSON.serialize(out));
        return;
      }

      System.debug('CheckoutRequest details:');
      System.debug('  traceId: ' + r.traceId);
      System.debug('  externalOrderId: ' + r.externalOrderId);
      System.debug('  leadId: ' + r.leadId);
      System.debug('  webshopUserId: ' + r.webshopUserId);
      System.debug('  pricebookName: ' + r.pricebookName);
      System.debug('  opportunity: ' + (r.opportunity == null ? 'null' : JSON.serialize(r.opportunity)));
      System.debug('  opportunityProducts: ' + (r.opportunityProducts == null ? 'null' : r.opportunityProducts.size() + ' items'));
      System.debug('  orderProducts: ' + (r.orderProducts == null ? 'null' : r.orderProducts.size() + ' items'));


      // default pricebook name
      String pbName = String.isBlank(r.pricebookName) ? 'Standard Price Book' : r.pricebookName;

      // Idempotency check: find existing Order by External_Id__c (custom field) if externalOrderId provided
      if (!String.isBlank(r.externalOrderId)) {
        List<Order> existing = [SELECT Id, AccountId FROM Order WHERE External_Id__c = :r.externalOrderId LIMIT 1];
        if (!existing.isEmpty()) {
          out.ok = true;
          out.message = 'Order already processed (idempotent)';
          out.orderId = existing[0].Id;
          out.accountId = existing[0].AccountId;

          // Ensure createdIds is properly initialized for idempotent response
          out.createdIds = new Map<String, String>{
            'orderId' => String.valueOf(existing[0].Id),
            'accountId' => String.valueOf(existing[0].AccountId)
          };

          res.statusCode = 200;
          res.responseBody = Blob.valueOf(JSON.serialize(out));
          return;
        }
      }

      // 1) If leadId provided -> convert Lead using standard conversion
      System.debug('=== Starting Lead Conversion Process ===');
      Id accountId;
      Id contactId;
      Id opportunityId;

      if (!String.isBlank(r.leadId)) {
        System.debug('Lead ID provided: ' + r.leadId);

        // First, check if this lead is already converted
        Lead L = [SELECT Id, FirstName, LastName, Name, Company, IsConverted, ConvertedAccountId, ConvertedContactId
                  FROM Lead WHERE Id = :r.leadId LIMIT 1];
        System.debug('Fetched lead: ' + L.FirstName + ' ' + L.LastName + ' (Company: ' + (String.isBlank(L.Company) ? 'N/A' : L.Company) + ')');
        System.debug('Lead conversion status: IsConverted=' + L.IsConverted);

        if (L.IsConverted) {
          // Lead is already converted - use existing Account and Contact
          System.debug('Lead is already converted - using existing Account and Contact');
          accountId = L.ConvertedAccountId;
          contactId = L.ConvertedContactId;

          // Look up the converted contact to get opportunity information
          Contact convertedContact = [SELECT Id, AccountId FROM Contact WHERE Id = :contactId LIMIT 1];

          System.debug('Using existing converted records:');
          System.debug('  AccountId: ' + accountId);
          System.debug('  ContactId: ' + contactId);

          out.createdIds.put('convertedAccountId', accountId);
          out.createdIds.put('convertedContactId', contactId);

          // For repeat orders, we'll create a new opportunity later in the process
          opportunityId = null;
          System.debug('=== Lead Conversion Process Completed (using existing converted records) ===');
        } else {
          // Lead is not converted - perform standard conversion
          System.debug('Lead is not converted - performing standard conversion');

          Database.LeadConvert lc = new Database.LeadConvert();
          lc.setLeadId(r.leadId);
          lc.setDoNotCreateOpportunity(false); // create opportunity by default
          lc.setConvertedStatus('Closed - Converted'); // ensure this status exists in your org

          // set opportunity name to lead name (if present)
          if (!String.isBlank(L.Name)) {
            lc.setOpportunityName(L.Name);
            System.debug('Setting opportunity name to lead name: ' + L.Name);
          } else if (!String.isBlank(L.Company)) {
            lc.setOpportunityName(L.Company + ' Webshop Opportunity');
            System.debug('Setting opportunity name to company name: ' + L.Company + ' Webshop Opportunity');
          } else {
            System.debug('No lead name or company available, opportunity will use default naming');
          }

          System.debug('LeadConvert configuration:');
          System.debug('  LeadId: ' + lc.getLeadId());
          System.debug('  ConvertedStatus: ' + lc.getConvertedStatus());
          System.debug('  OpportunityName: ' + lc.getOpportunityName());

          // perform conversion
          System.debug('Performing lead conversion...');
          Database.LeadConvertResult lcr = Database.convertLead(lc);

          if (!lcr.isSuccess()) {
            // return convert errors
            String errorMsg = (lcr.getErrors() != null && lcr.getErrors().size() > 0) ? lcr.getErrors()[0].getMessage() : 'unknown';
            System.debug('Error: Lead conversion failed - ' + errorMsg);
            out.message = 'Lead conversion failed: ' + errorMsg;
            res.statusCode = 400;
            res.responseBody = Blob.valueOf(JSON.serialize(out));
            return;
          }

          System.debug('Lead conversion successful');
          accountId = lcr.getAccountId();
          contactId = lcr.getContactId();
          opportunityId = lcr.getOpportunityId(); // may be null if conversion did not create opportunity

          System.debug('Conversion results:');
          System.debug('  AccountId: ' + accountId);
          System.debug('  ContactId: ' + contactId);
          System.debug('  OpportunityId: ' + opportunityId);

          out.createdIds.put('convertedAccountId', accountId);
          out.createdIds.put('convertedContactId', contactId);
          if (opportunityId != null) out.createdIds.put('convertedOpportunityId', opportunityId);

          System.debug('=== Lead Conversion Process Completed ===');
        }

      } else {
        // If no leadId: try to resolve account/contact by webshopUserId or other info (left as minimal)
        // For now, require leadId for conversion. You can extend to lookup Contact by email.
        out.message = 'leadId is required for checkout';
        res.statusCode = 400;
        res.responseBody = Blob.valueOf(JSON.serialize(out));
        return;
      }

      // 2) Determine Pricebook2Id from name
      System.debug('=== Pricebook Resolution ===');
      System.debug('Looking for pricebook: ' + pbName);
      Pricebook2 pb = [SELECT Id, Name FROM Pricebook2 WHERE Name = :pbName LIMIT 1];
      if (pb == null) {
        System.debug('Error: Pricebook not found - ' + pbName);
        out.message = 'Pricebook not found: ' + pbName;
        res.statusCode = 400;
        res.responseBody = Blob.valueOf(JSON.serialize(out));
        return;
      }
      Id pricebookId = pb.Id;
      System.debug('Found pricebook: ' + pb.Name + ' (ID: ' + pricebookId + ')');

      // 3) If opportunityId not created by convert, create Opportunity now (use lead name or provided metadata)
      System.debug('=== Opportunity Creation ===');
      if (opportunityId == null) {
        System.debug('No opportunity created by lead conversion, creating new opportunity');
        String oppName = (r.opportunity != null && r.opportunity.get('name') != null) ? String.valueOf(r.opportunity.get('name')) : null;
        if (String.isBlank(oppName) && !String.isBlank(r.leadId)) {
          Lead l = [SELECT Name FROM Lead WHERE Id = :r.leadId LIMIT 1];
          oppName = l.Name;
          System.debug('Using lead name for opportunity: ' + oppName);
        }

        if (String.isBlank(oppName)) {
          System.debug('Using default opportunity name');
          oppName = 'Webshop Order';
        } else {
          System.debug('Using provided opportunity name: ' + oppName);
        }

        Opportunity opp = new Opportunity();
        opp.Name = oppName;
        opp.AccountId = accountId;
        opp.CloseDate = Date.today();
        opp.StageName = 'Prospecting';
        opp.Pricebook2Id = pricebookId;

        System.debug('Creating opportunity: ' + oppName);
        insert opp;
        opportunityId = opp.Id;
        System.debug('Created opportunity with ID: ' + opportunityId);
        out.createdIds.put('opportunityId', opportunityId);
      } else {
        System.debug('Opportunity already exists from lead conversion: ' + opportunityId);
        // ensure opportunity has Pricebook2Id set
        Opportunity existingOpp = [SELECT Id, Pricebook2Id FROM Opportunity WHERE Id = :opportunityId LIMIT 1];
        if (existingOpp.Pricebook2Id == null) {
          System.debug('Adding pricebook to existing opportunity');
          existingOpp.Pricebook2Id = pricebookId;
          update existingOpp;
        }
      }
      System.debug('Final opportunity ID: ' + opportunityId);

      // 4) Create OpportunityLineItems for opportunityProducts
      System.debug('=== Opportunity Line Items Creation ===');
      if (r.opportunityProducts != null && !r.opportunityProducts.isEmpty()) {
        System.debug('Creating ' + r.opportunityProducts.size() + ' opportunity line items');
        List<OpportunityLineItem> oliToInsert = new List<OpportunityLineItem>();
        for (ProductLine pl : r.opportunityProducts) {
          System.debug('Processing opportunity product: productId=' + pl.productId + ', quantity=' + pl.quantity + ', unitPrice=' + pl.unitPrice);

          // Resolve PricebookEntry
          Id pbeId = pl.pricebookEntryId;
          if (String.isBlank(pbeId)) {
            System.debug('  No pricebookEntryId provided, looking up by product ID');
            // find pricebookentry by product and pricebook
            List<PricebookEntry> pbes = [SELECT Id, UnitPrice FROM PricebookEntry WHERE Pricebook2Id = :pricebookId AND Product2Id = :pl.productId AND IsActive = TRUE LIMIT 1];
            if (pbes.isEmpty()) {
              System.debug('Error: Missing PricebookEntry for product ' + pl.productId);
              throw new WebshopException('Missing PricebookEntry for product ' + pl.productId);
            }
            pbeId = pbes[0].Id;
            if (pl.unitPrice == null) {
              pl.unitPrice = pbes[0].UnitPrice;
              System.debug('  Using pricebook entry unit price: ' + pl.unitPrice);
            }
          }

          OpportunityLineItem oli = new OpportunityLineItem();
          oli.OpportunityId = opportunityId;
          oli.PricebookEntryId = pbeId;
          oli.Quantity = (pl.quantity == null) ? 1 : pl.quantity;
          oli.UnitPrice = (pl.unitPrice == null) ? 0 : pl.unitPrice;
          oliToInsert.add(oli);

          System.debug('  Created line item: quantity=' + oli.Quantity + ', unitPrice=' + oli.UnitPrice);
        }

        if (!oliToInsert.isEmpty()) {
          System.debug('Inserting ' + oliToInsert.size() + ' opportunity line items');
          insert oliToInsert;
          System.debug('Successfully created opportunity line items');
        }
      } else {
        System.debug('No opportunity products to create');
      }

      // 5) Create Order for Account
      System.debug('=== Order Creation ===');
      System.debug('Creating order for account: ' + accountId);
      Order ord = new Order();
      ord.AccountId = accountId;
      ord.Pricebook2Id = pricebookId;
      ord.EffectiveDate = Date.today();
      ord.Status = 'Draft';
      if (!String.isBlank(r.externalOrderId)) {
        ord.External_Id__c = r.externalOrderId;
        System.debug('Setting external order ID: ' + r.externalOrderId);
      } else {
        System.debug('No external order ID provided');
      }

      System.debug('Inserting order...');
      insert ord;
      System.debug('Created order with ID: ' + ord.Id);
      out.orderId = ord.Id;
      out.createdIds.put('orderId', ord.Id);

      // 6) Create OrderItems (OrderItem) from orderProducts
      System.debug('=== Order Line Items Creation ===');
      if (r.orderProducts != null && !r.orderProducts.isEmpty()) {
        System.debug('Creating ' + r.orderProducts.size() + ' order line items');
        List<OrderItem> ois = new List<OrderItem>();
        for (ProductLine pl : r.orderProducts) {
          System.debug('Processing order product: productId=' + pl.productId + ', quantity=' + pl.quantity + ', unitPrice=' + pl.unitPrice);

          // Resolve PricebookEntry
          Id pbeId = pl.pricebookEntryId;
          if (String.isBlank(pbeId)) {
            System.debug('  No pricebookEntryId provided, looking up by product ID');
            List<PricebookEntry> pbes = [SELECT Id, UnitPrice FROM PricebookEntry WHERE Pricebook2Id = :pricebookId AND Product2Id = :pl.productId AND IsActive = TRUE LIMIT 1];
            if (pbes.isEmpty()) {
              System.debug('Error: Missing PricebookEntry for product ' + pl.productId);
              throw new WebshopException('Missing PricebookEntry for product ' + pl.productId);
            }
            pbeId = pbes[0].Id;
            if (pl.unitPrice == null) {
              pl.unitPrice = pbes[0].UnitPrice;
              System.debug('  Using pricebook entry unit price: ' + pl.unitPrice);
            }
          }

          OrderItem oi = new OrderItem();
          oi.OrderId = ord.Id;
          oi.PricebookEntryId = pbeId;
          oi.Quantity = (pl.quantity == null) ? 1 : pl.quantity;
          oi.UnitPrice = (pl.unitPrice == null) ? 0 : pl.unitPrice;
          ois.add(oi);

          System.debug('  Created order line item: quantity=' + oi.Quantity + ', unitPrice=' + oi.UnitPrice);
        }

        if (!ois.isEmpty()) {
          System.debug('Inserting ' + ois.size() + ' order line items');
          insert ois;
          System.debug('Successfully created order line items');
        }
      } else {
        System.debug('No order products to create');
      }

      // 7) Optionally activate the Order (depends on your business process/permissions)
      // ord.Status = 'Activated'; update ord;

      System.debug('=== Finalizing Checkout Response ===');
      out.ok = true;
      out.message = 'Checkout processed';
      out.accountId = accountId;
      out.contactId = contactId;
      out.opportunityId = opportunityId;
      out.orderId = ord.Id;

      System.debug('Checkout results:');
      System.debug('  AccountId: ' + accountId);
      System.debug('  ContactId: ' + contactId);
      System.debug('  OpportunityId: ' + opportunityId);
      System.debug('  OrderId: ' + ord.Id);
      System.debug('  CreatedIds: ' + JSON.serialize(out.createdIds));

      // Ensure createdIds contains only serializable types (convert Ids to Strings)
      Map<String, String> safeCreatedIds = new Map<String, String>();
      for (String key : out.createdIds.keySet()) {
        Object value = out.createdIds.get(key);
        if (value instanceof Id) {
          safeCreatedIds.put(key, String.valueOf(value));
        } else if (value != null) {
          safeCreatedIds.put(key, String.valueOf(value));
        }
      }
      out.createdIds = safeCreatedIds;

      System.debug('=== WebshopCheckout Completed Successfully ===');
      res.statusCode = 200;
      res.responseBody = Blob.valueOf(JSON.serialize(out));
      return;

    } catch (WebshopException we) {
      System.debug('=== Business Error Caught ===');
      System.debug('Error: ' + we.getMessage());
      CheckoutResponse outErr = new CheckoutResponse();
      outErr.ok = false;
      outErr.message = 'Business error: ' + we.getMessage();
      outErr.createdIds = new Map<String, String>(); // Ensure empty but properly typed map
      RestContext.response.statusCode = 400;
      RestContext.response.responseBody = Blob.valueOf(JSON.serialize(outErr));
      System.debug('Returning business error response');
      return;


    } catch (Exception ex) {
      // unexpected error
      System.debug('=== Unexpected Error Caught ===');
      System.debug('Error type: ' + ex.getTypeName());
      System.debug('Error message: ' + ex.getMessage());
      System.debug('Stack trace: ' + ex.getStackTraceString());

      CheckoutResponse outErr = new CheckoutResponse();
      outErr.ok = false;
      outErr.message = 'Unexpected error: ' + String.valueOf(ex.getMessage()); // Ensure string conversion
      outErr.createdIds = new Map<String, String>(); // Ensure empty but properly typed map
      RestContext.response.statusCode = 500;
      RestContext.response.responseBody = Blob.valueOf(JSON.serialize(outErr));
      System.debug('Returning unexpected error response');
      return;
    }
  }

  // simple custom exception for business errors
  public class WebshopException extends Exception {}

}
