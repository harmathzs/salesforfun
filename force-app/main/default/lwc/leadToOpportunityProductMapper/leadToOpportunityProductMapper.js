import { LightningElement, api, wire } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';

export default class LeadToOpportunityProductMapper extends LightningElement {
  @api recordId;

  @wire(getRecord, { recordId: '$recordId', fields: ['Opportunity.Id', 'Opportunity.Name'] })
  opportunity;

  get opportunityName() {
    return this.opportunity.data ? this.opportunity.data.fields.Name.value : 'Loading...';
  }
}
