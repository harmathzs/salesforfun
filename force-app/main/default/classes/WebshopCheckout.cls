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
      if (String.isBlank(body)) {
        out.message = 'Empty request body';
        res.statusCode = 400;
        res.responseBody = Blob.valueOf(JSON.serialize(out));
        return;
      }

      System.debug('Body to parse: <'+body+'>');

      // Parse the request using untyped deserialization first for validation
      Object parsedObj = JSON.deserializeUntyped(body);

      // Check if we got null (completely invalid JSON)
      if (parsedObj == null) {
        out.message = 'Invalid JSON payload';
        res.statusCode = 400;
        res.responseBody = Blob.valueOf(JSON.serialize(out));
        return;
      }

      // Try to deserialize as CheckoutRequest
      CheckoutRequest r;
      try {
        r = (CheckoutRequest) JSON.deserialize(body, CheckoutRequest.class);
      } catch (Exception e) {
        out.message = 'Invalid request structure: ' + e.getMessage();
        res.statusCode = 400;
        res.responseBody = Blob.valueOf(JSON.serialize(out));
        return;
      }

      // basic validation - check if deserialization resulted in null
      if (r == null) {
        out.message = 'Invalid JSON payload';
        res.statusCode = 400;
        res.responseBody = Blob.valueOf(JSON.serialize(out));
        return;
      }

      System.debug('r: '+r);


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
      Id accountId;
      Id contactId;
      Id opportunityId;

      if (!String.isBlank(r.leadId)) {
        // Fetch lead to set opportunity name (use Lead.Name if available)
        Lead L = [SELECT Id, FirstName, LastName, Name FROM Lead WHERE Id = :r.leadId LIMIT 1];

        Database.LeadConvert lc = new Database.LeadConvert();
        lc.setLeadId(r.leadId);
        lc.setDoNotCreateOpportunity(false); // create opportunity by default
        lc.setConvertedStatus('Closed - Converted'); // ensure this status exists in your org
        // set opportunity name to lead name (if present)
        if (!String.isBlank(L.Name)) {
          lc.setOpportunityName(L.Name);
        }
        System.debug('lc: '+lc);
/*
        // perform conversion
        Database.LeadConvertResult lcr = Database.convertLead(lc);
        if (!lcr.isSuccess()) {
          // return convert errors
          out.message = 'Lead conversion failed: ' + (lcr.getErrors() != null && lcr.getErrors().size() > 0 ? lcr.getErrors()[0].getMessage() : 'unknown');
          res.statusCode = 400;
          res.responseBody = Blob.valueOf(JSON.serialize(out));
          return;
        }

        accountId = lcr.getAccountId();
        contactId = lcr.getContactId();
        opportunityId = lcr.getOpportunityId(); // may be null if conversion did not create opportunity
        out.createdIds.put('convertedAccountId', accountId);
        out.createdIds.put('convertedContactId', contactId);
        if (opportunityId != null) out.createdIds.put('convertedOpportunityId', opportunityId);


 */
      } else {
        // If no leadId: try to resolve account/contact by webshopUserId or other info (left as minimal)
        // For now, require leadId for conversion. You can extend to lookup Contact by email.
      }
/*
      // 2) Determine Pricebook2Id from name
      Pricebook2 pb = [SELECT Id, Name FROM Pricebook2 WHERE Name = :pbName LIMIT 1];
      if (pb == null) {
        out.message = 'Pricebook not found: ' + pbName;
        res.statusCode = 400;
        res.responseBody = Blob.valueOf(JSON.serialize(out));
        return;
      }
      Id pricebookId = pb.Id;

      // 3) If opportunityId not created by convert, create Opportunity now (use lead name or provided metadata)
      if (opportunityId == null) {
        String oppName = (r.opportunity != null && r.opportunity.get('name') != null) ? String.valueOf(r.opportunity.get('name')) : null;
        if (String.isBlank(oppName) && !String.isBlank(r.leadId)) {
          Lead l = [SELECT Name FROM Lead WHERE Id = :r.leadId LIMIT 1];
          oppName = l.Name;
        }
        Opportunity opp = new Opportunity();
        opp.Name = String.isBlank(oppName) ? 'Webshop Order' : oppName;
        opp.AccountId = accountId;
        opp.CloseDate = Date.today();
        opp.StageName = 'Prospecting';
        opp.Pricebook2Id = pricebookId;
        insert opp;
        opportunityId = opp.Id;
        out.createdIds.put('opportunityId', opportunityId);
      } else {
        // ensure opportunity has Pricebook2Id set
        Opportunity existingOpp = [SELECT Id, Pricebook2Id FROM Opportunity WHERE Id = :opportunityId LIMIT 1];
        if (existingOpp.Pricebook2Id == null) {
          existingOpp.Pricebook2Id = pricebookId;
          update existingOpp;
        }
      }

      // 4) Create OpportunityLineItems for opportunityProducts
      if (r.opportunityProducts != null && !r.opportunityProducts.isEmpty()) {
        List<OpportunityLineItem> oliToInsert = new List<OpportunityLineItem>();
        for (ProductLine pl : r.opportunityProducts) {
          // Resolve PricebookEntry
          Id pbeId = pl.pricebookEntryId;
          if (String.isBlank(pbeId)) {
            // find pricebookentry by product and pricebook
            List<PricebookEntry> pbes = [SELECT Id, UnitPrice FROM PricebookEntry WHERE Pricebook2Id = :pricebookId AND Product2Id = :pl.productId AND IsActive = TRUE LIMIT 1];
            if (pbes.isEmpty()) {
              throw new WebshopException('Missing PricebookEntry for product ' + pl.productId);
            }
            pbeId = pbes[0].Id;
            if (pl.unitPrice == null) pl.unitPrice = pbes[0].UnitPrice;
          }
          OpportunityLineItem oli = new OpportunityLineItem();
          oli.OpportunityId = opportunityId;
          oli.PricebookEntryId = pbeId;
          oli.Quantity = (pl.quantity == null) ? 1 : pl.quantity;
          oli.UnitPrice = (pl.unitPrice == null) ? 0 : pl.unitPrice;
          oliToInsert.add(oli);
        }
        if (!oliToInsert.isEmpty()) insert oliToInsert;
      }

      // 5) Create Order for Account
      Order ord = new Order();
      ord.AccountId = accountId;
      ord.Pricebook2Id = pricebookId;
      ord.EffectiveDate = Date.today();
      ord.Status = 'Draft';
      if (!String.isBlank(r.externalOrderId)) ord.External_Id__c = r.externalOrderId; // requires custom field
      insert ord;
      out.orderId = ord.Id;
      out.createdIds.put('orderId', ord.Id);

      // 6) Create OrderItems (OrderItem) from orderProducts
      if (r.orderProducts != null && !r.orderProducts.isEmpty()) {
        List<OrderItem> ois = new List<OrderItem>();
        for (ProductLine pl : r.orderProducts) {
          // Resolve PricebookEntry
          Id pbeId = pl.pricebookEntryId;
          if (String.isBlank(pbeId)) {
            List<PricebookEntry> pbes = [SELECT Id, UnitPrice FROM PricebookEntry WHERE Pricebook2Id = :pricebookId AND Product2Id = :pl.productId AND IsActive = TRUE LIMIT 1];
            if (pbes.isEmpty()) {
              throw new WebshopException('Missing PricebookEntry for product ' + pl.productId);
            }
            pbeId = pbes[0].Id;
            if (pl.unitPrice == null) pl.unitPrice = pbes[0].UnitPrice;
          }
          OrderItem oi = new OrderItem();
          oi.OrderId = ord.Id;
          oi.PricebookEntryId = pbeId;
          oi.Quantity = (pl.quantity == null) ? 1 : pl.quantity;
          oi.UnitPrice = (pl.unitPrice == null) ? 0 : pl.unitPrice;
          ois.add(oi);
        }
        if (!ois.isEmpty()) insert ois;
      }

      // 7) Optionally activate the Order (depends on your business process/permissions)
      // ord.Status = 'Activated'; update ord;

      out.ok = true;
      out.message = 'Checkout processed';
      out.accountId = accountId;
      out.contactId = contactId;
      out.opportunityId = opportunityId;
      out.orderId = ord.Id;

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

      res.statusCode = 200;
      res.responseBody = Blob.valueOf(JSON.serialize(out));
      return;

*/

    } catch (WebshopException we) {
      CheckoutResponse outErr = new CheckoutResponse();
      outErr.ok = false;
      outErr.message = 'Business error: ' + we.getMessage();
      outErr.createdIds = new Map<String, String>(); // Ensure empty but properly typed map
      RestContext.response.statusCode = 400;
      RestContext.response.responseBody = Blob.valueOf(JSON.serialize(outErr));
      return;


    } catch (Exception ex) {
      // unexpected error
      CheckoutResponse outErr = new CheckoutResponse();
      outErr.ok = false;
      outErr.message = 'Unexpected error: ' + String.valueOf(ex.getMessage()); // Ensure string conversion
      outErr.createdIds = new Map<String, String>(); // Ensure empty but properly typed map
      RestContext.response.statusCode = 500;
      RestContext.response.responseBody = Blob.valueOf(JSON.serialize(outErr));
      return;
    }
  }

  // simple custom exception for business errors
  public class WebshopException extends Exception {}

}
