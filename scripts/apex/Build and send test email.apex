// Build and send test email
Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
mail.setToAddresses(new List<String>{'kolomparozseb537@gmail.com'});
mail.setSubject('Test email from Salesforce — deliverability check');
mail.setPlainTextBody('This is a one-line deliverability test from Salesforce. If you receive it, reply to confirm.');
// Optionally set a verified org-wide address as sender:
// mail.setOrgWideEmailAddressId('<ORG_WIDE_ADDRESS_ID>');
Messaging.SendEmailResult[] results = Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{mail}, false);
System.debug('sendEmail results: ' + results);
