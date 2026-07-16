/**
 * Opportunity Trigger Service Layer
 *
 * @author Zsolt Harmath
 * @description Service class containing business logic for Opportunity trigger operations.
 *              Separates trigger logic from trigger handlers following separation of concerns principle.
 *
 * @see https://github.com/lfreeland/Saleforce-Trigger-Framework
 */
public with sharing class OpportunityTriggerService {

  /**
   * Updates opportunities with converted lead information.
   *
   * @param newOpportunities List of Opportunity records that have been inserted.
   *
   * @description Queries the Lead records that were converted to create the Opportunities
   *              and updates the Opportunities with the converted Lead information.
   *              Specifically sets the Converted_Lead__c field on each Opportunity to the ID
   *              of the Lead that was converted to create it.
   *
   * @example
   * // After insert trigger context
   * OpportunityTriggerService.updateConvertedLead(Trigger.new);
   *
   * @note This method performs a single update operation to minimize governor limits.
   * @note Only processes opportunities that have a corresponding converted lead.
   * @note Creates a new list for DML operations to avoid modifying trigger context variables directly.
   */
/*
  public static void updateConvertedLead(List<Opportunity> newOpportunities) {
    // Get the IDs of the new opportunities
    Set<Id> opportunityIds = new Set<Id>();
    for (Opportunity opp : newOpportunities) {
      opportunityIds.add(opp.Id);
    }

    // Query the leads that were converted to these opportunities
    List<Lead> convertedLeads = [
      SELECT Id, FirstName, LastName, Email, Company
      FROM Lead
      WHERE ConvertedOpportunityId IN :opportunityIds
    ];
    System.debug('convertedLeads: '+convertedLeads);

    // Create a map of opportunity ID to lead for easy lookup
    Map<Id, Lead> opportunityToLeadMap = new Map<Id, Lead>();
    for (Lead lead : convertedLeads) {
      opportunityToLeadMap.put(lead.ConvertedOpportunityId, lead);
    }
    System.debug('opportunityToLeadMap: '+opportunityToLeadMap);

    // Create a new list for opportunities that need to be updated
    List<Opportunity> opportunitiesToUpdate = new List<Opportunity>();

    // Update the opportunities with the converted lead information
    for (Opportunity opp : newOpportunities) {
      if (opportunityToLeadMap.containsKey(opp.Id)) {
        Lead convertedLead = opportunityToLeadMap.get(opp.Id);
        // Create a new opportunity record for update to avoid DML on trigger context variables
        Opportunity oppToUpdate = new Opportunity(
          Id = opp.Id,
          Converted_Lead__c = convertedLead.Id
        );
        opportunitiesToUpdate.add(oppToUpdate);
      }
    }
    System.debug('opportunitiesToUpdate: '+opportunitiesToUpdate);

    // Update the opportunities if any were modified
    if (!opportunitiesToUpdate.isEmpty()) {
      update opportunitiesToUpdate;
      System.debug('Updated opportunitiesToUpdate: '+opportunitiesToUpdate);
    }
  }

 */
  public static void setPricebook(List<Opportunity> newOpportunities) {
    Integer thisYear = Date.today().year();
    String pricebookName = 'Price Book ' + thisYear;

    // Query for the specific pricebook name
    Pricebook2[] pricebooks = [SELECT Id, Name FROM Pricebook2 WHERE Name = :pricebookName];
    Pricebook2 pricebook = null;
    if (pricebooks.isEmpty()) {
      pricebooks = [SELECT Id, Name FROM Pricebook2 WHERE Name = 'Standard Price Book'];
    }
    Id pricebookId = null;
    if (!pricebooks.isEmpty()) {
      pricebook = pricebooks.get(0);
      pricebookId = pricebook.Id;
    }
    if (Test.isRunningTest()) {
      pricebookId = Test.getStandardPricebookId();
    }

    for (Opportunity oppy: newOpportunities) {
      if (String.isBlank(oppy.Pricebook2Id)) {
          oppy.Pricebook2Id = pricebookId;
      }
    }
  }

  /**
   * createContracts
   * Handler invoked from Opportunity trigger after update. Scans opportunities that transitioned
   * to Closed Won (IsWon) and creates Contract records and Contract Line Items. Bulk-safe.
   *
   * @param oldOpportunitiesMap Map<Id, SObject> Map of old Opportunity values (Trigger.oldMap)
   * @param newOpportunitiesMap Map<Id, SObject> Map of new Opportunity values (Trigger.newMap)
   * @return Contract[] List of created Contract records (empty list if none created)
   * @throws IllegalArgumentException if inputs are invalid
   */
  public static Contract[] createContracts(Map<Id, SObject> oldOpportunitiesMap, Map<Id, SObject> newOpportunitiesMap) {
    if (newOpportunitiesMap==null) return new Contract[0];
    if (newOpportunitiesMap.isEmpty()) return new Contract[0];

    // Collect opportunities that moved to Won
    List<Opportunity> wonOpps = new List<Opportunity>();
    for (Id opportunityId: newOpportunitiesMap.keySet()) {
      Opportunity oldOpportunity = (Opportunity) oldOpportunitiesMap.get(opportunityId);
      Opportunity newOpportunity = (Opportunity) newOpportunitiesMap.get(opportunityId);
      if (oldOpportunity == null || newOpportunity == null) continue;
      if (!oldOpportunity.IsWon && newOpportunity.IsWon) {
        wonOpps.add(newOpportunity);
      }
    }

    if (wonOpps.isEmpty()) return new Contract[0];

    // Prevent duplicate contracts: query existing Contracts linked to these opportunities
    Set<Id> wonOppIds = new Set<Id>();
    for (Opportunity o : wonOpps) wonOppIds.add(o.Id);

    Map<Id, Contract> existingByOpp = new Map<Id, Contract>();
    for (Contract c : [SELECT Id, Opportunity__c FROM Contract WHERE Opportunity__c IN :wonOppIds]) {
      if (c.Opportunity__c != null) existingByOpp.put(c.Opportunity__c, c);
    }

    List<Contract> contractsToInsert = new List<Contract>();
    Map<Id, Id> oppToContractId = new Map<Id, Id>();

    for (Opportunity o : wonOpps) {
      if (existingByOpp.containsKey(o.Id)) continue; // already has contract

      Contract contract = new Contract(
        AccountId = o.AccountId,
        Pricebook2Id = o.Pricebook2Id,
        Opportunity__c = o.Id,
        Status = 'Draft',
        StartDate = Date.today(),
        ContractTerm = 24,
        Description = 'Contract created from Opportunity: ' + o.Name
      );
      contractsToInsert.add(contract);
    }

    if (!contractsToInsert.isEmpty()) {
      insert contractsToInsert;
      // map inserted contracts back to opportunity ids
      Integer idx=0;
      for (Contract c : contractsToInsert) {
        // Attempt to find matching opp by Opportunity__c on inserted record (may be null until populated)
      }
    }

    // Refresh contracts to get Opportunity__c populated
    Set<Id> createdContractIds = new Set<Id>();
    for (Contract c : contractsToInsert) createdContractIds.add(c.Id);

    Map<Id, Contract> createdContractsById = new Map<Id, Contract>();
    if (!createdContractIds.isEmpty()) {
      for (Contract c : [SELECT Id, Opportunity__c, AccountId FROM Contract WHERE Id IN :createdContractIds]) {
        createdContractsById.put(c.Id, c);
        if (c.Opportunity__c != null) oppToContractId.put(c.Opportunity__c, c.Id);
      }
    }

    // Create Contract Line Items from OpportunityLineItem
    List<Contract_Line_Item__c> contractLineItemsToInsert = new List<Contract_Line_Item__c>();

    // Query opportunity line items for the won opportunities without existing contracts
    List<OpportunityLineItem> olis = [SELECT Id, OpportunityId, Product2Id, Quantity, UnitPrice FROM OpportunityLineItem WHERE OpportunityId IN :wonOppIds];

    for (OpportunityLineItem oli : olis) {
      Id oppId = oli.OpportunityId;
      Id contractId = oppToContractId.get(oppId);
      if (contractId == null) continue; // skip if no contract created/found

      Contract_Line_Item__c cli = new Contract_Line_Item__c(
        Contract__c = contractId,
        Product__c = oli.Product2Id,
        Quantity__c = oli.Quantity,
        Unit_Price__c = oli.UnitPrice,

        Opportunity__c = oppId
      );
      contractLineItemsToInsert.add(cli);
    }

    if (!contractLineItemsToInsert.isEmpty()) {
      insert contractLineItemsToInsert;
    }

    return contractsToInsert;
  }
}
