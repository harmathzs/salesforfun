import { LightningElement, api, wire } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';

export default class LeadToOpportunityProductMapper extends LightningElement {
  @api recordId;

  @wire(getRecord, { recordId: '$recordId', fields: ['Lead.Id', 'Lead.Name'] })
  lead;

  get leadName() {
    return this.lead.data ? this.lead.data.fields.Name.value : 'Loading...';
  }
}
