/**
 * WebshopConvert
 *
 * REST web service for converting leads in Salesforce.
 * This class provides an endpoint to convert a lead into an account, contact, and optionally an opportunity.
 *
 * @author Salesforce Developer
 * @version 1.0
 * @since API 29.0
 */
@RestResource(UrlMapping='/webshop/convertLead')
global with sharing class WebshopConvert {

    /**
     * Converts a lead into an account, contact, and optionally an opportunity.
     * When createOpportunity is true, Salesforce will create the opportunity during lead conversion.
     * When createOpportunity is false, no opportunity will be created.
     *
     * @param None This method processes the request body which should contain:
     *             - leadId: The ID of the lead to convert (required)
     *             - createOpportunity: Boolean flag to create an opportunity (default: true)
     *             - opportunityName: Custom name for the opportunity (optional, used only if createOpportunity=true)
     *
     * @return Map<String, Object> A response map containing:
     *         - success: Boolean indicating if the operation was successful
     *         - error: Error details if the operation failed (null if successful)
     *         - result: Map containing accountId, contactId, and opportunityId if successful
     *
     * @throws Exception If there's an error during lead conversion or opportunity creation
     *
     * @example
     * Request Body:
     * {
     *   "leadId": "00Q1t00000ABC123",
     *   "createOpportunity": true,
     *   "opportunityName": "New Business Opportunity"
     * }
     *
     * Success Response:
     * {
     *   "success": true,
     *   "error": null,
     *   "result": {
     *     "accountId": "0011t00000ABC456",
     *     "contactId": "0031t00000ABC789",
     *     "opportunityId": "0061t00000ABC012"
     *   }
     * }
     */
    @HttpPost
    global static Map<String, Object> post() {
        Map<String, Object> response = new Map<String, Object>{
            'success' => false,
            'error' => null,
            'result' => null
        };

        try {
            RestRequest req = RestContext.request;

            if (req == null || String.isBlank(req.requestBody.toString())) {
                response.put('error', 'missing request body');
                return response;
            }

            Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(req.requestBody.toString());
            Id leadId = payload.containsKey('leadId') ? (Id) payload.get('leadId') : null;
            Boolean createOpportunity = payload.containsKey('createOpportunity') ? (Boolean) payload.get('createOpportunity') : true;
            String oppName = payload.containsKey('opportunityName') ? (String) payload.get('opportunityName') : null;

            if (leadId == null) {
                response.put('error', 'leadId is required');
                return response;
            }

            Lead leadRecord = [
                SELECT Id, IsConverted, ConvertedAccountId, ConvertedContactId, ConvertedOpportunityId, Company
                FROM Lead
                WHERE Id = :leadId
                LIMIT 1
            ];

            if (leadRecord.IsConverted) {
                Map<String, Object> result = new Map<String, Object>{
                    'accountId' => leadRecord.ConvertedAccountId,
                    'contactId' => leadRecord.ConvertedContactId,
                    'opportunityId' => leadRecord.ConvertedOpportunityId
                };
                response.put('result', result);
                response.put('success', true);
                return response;
            }

            Database.LeadConvert leadConvert = new Database.LeadConvert();
            leadConvert.setLeadId(leadRecord.Id);
            String convertedStatus = 'Closed - Converted';
            leadConvert.setConvertedStatus(convertedStatus);

            // Let Salesforce create the opportunity if createOpportunity is true
            leadConvert.setDoNotCreateOpportunity(!createOpportunity);

            // Set opportunity name if provided and creating opportunity
            if (createOpportunity) {
                String nameToUse = (oppName != null && oppName.trim().length() > 0) ? oppName :
                    (leadRecord.Company != null ? (leadRecord.Company + ' Webshop Opportunity') : 'Webshop Opportunity');
                leadConvert.setOpportunityName(nameToUse);
            }

            Database.LeadConvertResult convertResult = Database.convertLead(leadConvert, true);

            Id accountId = convertResult.getAccountId();
            Id contactId = convertResult.getContactId();
            Id oppId = convertResult.getOpportunityId();

            Map<String, Object> result = new Map<String, Object>{
                'accountId' => accountId,
                'contactId' => contactId,
                'opportunityId' => oppId
            };

            response.put('result', result);
            response.put('success', true);
            return response;

        } catch (Exception ex) {
            Map<String, Object> error = new Map<String, Object>{
                'message' => ex.getMessage(),
                'type' => ex.getTypeName()
            };
            response.put('error', error);
            response.put('success', false);
            return response;
        }
    }
}
