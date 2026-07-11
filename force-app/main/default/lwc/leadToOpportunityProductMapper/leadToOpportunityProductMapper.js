import { LightningElement, api, wire } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';

export default class LeadToOpportunityProductMapper extends LightningElement {
  @api recordId;

  @wire(getRecord, { recordId: '$recordId',
    fields: ['Opportunity.Id', 'Opportunity.Name', 'Opportunity.Converted_Lead__c', 'Opportunity.Converted_Lead__r.ProductInterest__c'] })
  opportunity;

  get opportunityName() {
    console.log('opportunity.data.fields', this.opportunity.data ? this.opportunity.data.fields : "no oppy data yet")
    return this.opportunity.data ? this.opportunity.data.fields.Name.value : 'Loading...';
  }

  get productInterest() {
    return this.opportunity.data ? this.opportunity.data.fields.Converted_Lead__r.value.fields.ProductInterest__c.value : 'Loading...'
  }
}
