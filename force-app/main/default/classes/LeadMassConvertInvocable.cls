/**
 * Mass Lead Conversion Service
 *
 * @author Zsolt Harmath
 * @description Provides bulk lead conversion functionality for converting multiple leads to Accounts, Contacts, and Opportunities.
 *              Implements efficient bulk processing patterns and comprehensive error handling.
 */
public with sharing class LeadMassConvertInvocable {
  /**
   * Converts multiple leads to Accounts, Contacts, and Opportunities in a single transaction.
   *
   * @param leads List of List of Lead records to convert. The outer list contains one inner list of leads.
   * @return List<String> JSON string containing conversion results with OpportunityId, AccountId, ContactId, and Error for each lead.
   *
   * @example
   * // Basic usage
   * List<Lead> leadsToConvert = [SELECT Id FROM Lead WHERE Status = 'Qualified'];
   * List<String> results = LeadMassConvertInvocable.massConvert(new List<List<Lead>>{leadsToConvert});
   *
   * @note Only leads with 'Qualified' status will be converted. Unqualified leads will receive error messages.
   * @note This method follows bulk processing best practices - no DML in loops, proper error handling.
   */
  @InvocableMethod(label='Mass Convert Leads' description='Converts multiple leads to Accounts, Contacts, and Opportunities')
  public static List<String> massConvert(List<List<Lead>> leads) {
    System.debug('LeadMassConvertInvocable.massConvert; leads: '+leads);

    Map<String, List<Map<String, String>>> results = new Map<String, List<Map<String, String>>>{
      'error' => new List<Map<String, String>>(),
      'results' => new List<Map<String, String>>()
    };

    // Input validation
    if (leads == null || leads.isEmpty() || leads[0].isEmpty()) {
      results.get('error').add(new Map<String, String>{
        'OpportunityId' => null,
        'AccountId' => null,
        'ContactId' => null,
        'Error' => 'Leads list is empty!'
      });

      String resultsJson = JSON.serializePretty(results);
      System.debug('LeadMassConvertInvocable.massConvert; resultsJson: '+resultsJson);
      return new List<String>{ resultsJson };
    }

    Lead[] convertibleLeads = leads[0];

    // Prepare lead conversions - no DML in loop, just preparation
    List<Database.LeadConvert> leadConversions = new List<Database.LeadConvert>();
    Map<Id, Integer> leadIndexMap = new Map<Id, Integer>(); // Map lead Id to index for result mapping

    for (Integer i = 0; i < convertibleLeads.size(); i++) {
      Lead lead = convertibleLeads[i];

      // Validate lead status
      if (lead.Status != 'Qualified') {
        Map<String, String> errorResult = new Map<String, String>{
          'OpportunityId' => null,
          'AccountId' => null,
          'ContactId' => null,
          'Error' => 'Lead must be Qualified to convert: ' + lead.Status
        };
        results.get('results').add(errorResult);
        continue;
      }

      // Create lead conversion
      Database.LeadConvert leadConvert = new Database.LeadConvert();
      leadConvert.setLeadId(lead.Id);
      leadConvert.setDoNotCreateOpportunity(false); // Create opportunity by default
      leadConvert.setConvertedStatus('Closed - Converted');

      leadConversions.add(leadConvert);
      leadIndexMap.put(lead.Id, i);
    }

    // Bulk convert leads - DML outside the loop
    if (!leadConversions.isEmpty()) {
      List<Database.LeadConvertResult> convertResults = Database.convertLead(leadConversions);

      // Process results
      for (Integer i = 0; i < convertResults.size(); i++) {
        Database.LeadConvertResult convertResult = convertResults[i];

        if (convertResult.isSuccess()) {
          Map<String, String> result = new Map<String, String>{
            'OpportunityId' => convertResult.getOpportunityId(),
            'AccountId' => convertResult.getAccountId(),
            'ContactId' => convertResult.getContactId(),
            'Error' => null
          };
          results.get('results').add(result);
        } else {
          Map<String, String> errorResult = new Map<String, String>{
            'OpportunityId' => null,
            'AccountId' => null,
            'ContactId' => null,
            'Error' => 'Conversion failed: ' + convertResult.getErrors()[0].getMessage()
          };
          results.get('results').add(errorResult);
        }
      }
    }

    String resultsJson = JSON.serializePretty(results);
    System.debug('LeadMassConvertInvocable.massConvert; resultsJson: '+resultsJson);
    return new List<String>{ resultsJson };
  }
}
