public with sharing class LeadMassConvertInvocable {
  @InvocableMethod
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
