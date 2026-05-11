public with sharing class LeadMassConvertInvocable {
  @InvocableMethod
  public static List<String> massConvert(List<List<Lead>> leads) {
    System.debug('LeadMassConvertInvocable.massConvert; leads: '+leads);

    Map<String, List<Map<String, String>>> results = new Map<String, List<Map<String, String>>>{
      'error' => null,
      'results' => new List<Map<String, String>>()
    };

    if (!leads.isEmpty()) {
      Lead[] convertibleLeads = leads[0];

      for (Lead lead: convertibleLeads) {
        // TODO convert lead
        String opportunityId = 'XXX';
        String accountId = 'XXX';
        String contactId = 'XXX';
        Map<String, String> result = new Map<String, String>{
          'OpportunityId' => opportunityId,
          'AccountId' => accountId,
          'ContactId' => contactId,
          'Error' => null
        };
        results.get('results').add(result);
      }
    } else {
      results.get('error').add(new Map<String, String>{
        'OpportunityId' => null,
        'AccountId' => null,
        'ContactId' => null,
        'Error' => 'Leads list is empty!'
      });
    }

    String resultsJson = JSON.serializePretty(results);
    System.debug('LeadMassConvertInvocable.massConvert; resultsJson: '+resultsJson);
    return new List<String>{ resultsJson };
  }
}
