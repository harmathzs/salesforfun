@RestResource(UrlMapping='/webshop/verification-email')
global with sharing class WebshopVerificationEmailApi {

  global class VerifyEmailRequest {
    public String leadId;
    public String email;
    public String firstName;
    public String code;
    public Integer expiryMinutes;
  }

  global class VerifyEmailResponse {
    public Boolean ok;
    public String message;
    public String requestId;
  }

  @HttpPost
  global static VerifyEmailResponse sendVerificationEmail() {
    VerifyEmailResponse out = new VerifyEmailResponse();
    out.requestId = 'vf_' + String.valueOf(Crypto.getRandomLong()).replace('-', '');

    try {
      String raw = RestContext.request.requestBody == null
        ? null
        : RestContext.request.requestBody.toString();

      if (String.isBlank(raw)) {
        throw new AuraHandledException('Empty request body');
      }

      VerifyEmailRequest req = (VerifyEmailRequest) JSON.deserialize(raw, VerifyEmailRequest.class);

      if (String.isBlank(req.code) || req.code.length() < 4) {
        throw new AuraHandledException('Invalid verification code');
      }
      if (req.expiryMinutes == null || req.expiryMinutes <= 0) {
        req.expiryMinutes = 15;
      }

      Lead leadRecord;
      if (!String.isBlank(req.leadId)) {
        leadRecord = [
          SELECT Id, FirstName, LastName, Name, Email, Email_Verified__c
          FROM Lead
          WHERE Id = :req.leadId
          LIMIT 1
        ];
      } else if (!String.isBlank(req.email)) {
        List<Lead> leads = [
          SELECT Id, FirstName, LastName, Name, Email, Email_Verified__c
          FROM Lead
          WHERE Email = :req.email
          ORDER BY CreatedDate DESC
          LIMIT 1
        ];
        if (!leads.isEmpty()) leadRecord = leads[0];
      }

      if (leadRecord == null) {
        throw new AuraHandledException('Lead not found');
      }
      if (String.isBlank(leadRecord.Email)) {
        throw new AuraHandledException('Lead has no email');
      }
      if (leadRecord.Email_Verified__c == true) {
        throw new AuraHandledException('Lead already verified');
      }

      String greetName = !String.isBlank(req.firstName)
        ? req.firstName
        : (!String.isBlank(leadRecord.FirstName) ? leadRecord.FirstName : 'there');

      String subject = 'Verify your React 4 fun account';

      String body =
        'Hi ' + greetName + ',\n\n' +
          'Thanks for registering with React 4 fun.\n\n' +
          'Your verification code is:\n\n' +
          req.code + '\n\n' +
          'This code expires in ' + String.valueOf(req.expiryMinutes) + ' minutes.\n\n' +
          'If you did not request this, you can ignore this email. No changes will be made unless the code is entered.\n\n' +
          'Best regards,\n' +
          'The React 4 fun team';

      Messaging.SingleEmailMessage msg = new Messaging.SingleEmailMessage();
      msg.setToAddresses(new String[] { leadRecord.Email });
      msg.setSubject(subject);
      msg.setPlainTextBody(body);
      msg.setSaveAsActivity(false);

      // Optional: enforce org-wide sender
      // msg.setOrgWideEmailAddressId('0D2xxxxxxxxxxxx');

      Messaging.SendEmailResult[] results = Messaging.sendEmail(new Messaging.SingleEmailMessage[] { msg });

      if (results == null || results.isEmpty() || !results[0].isSuccess()) {
        String err = 'Unknown send failure';
        if (results != null && !results.isEmpty() && results[0].getErrors() != null && !results[0].getErrors().isEmpty()) {
          err = results[0].getErrors()[0].getMessage();
        }
        throw new AuraHandledException('Email send failed: ' + err);
      }

      // Optional reporting only (you kept these fields)
      leadRecord.Verification_Channel__c = 'Email';
      update leadRecord;

      out.ok = true;
      out.message = 'Verification email sent';
      return out;

    } catch (Exception ex) {
      RestContext.response.statusCode = 400;
      out.ok = false;
      out.message = ex.getMessage();
      return out;
    }
  }
}
