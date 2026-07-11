import { LightningElement, api } from 'lwc';

import getOpportunity from '@salesforce/apex/LeadToOpportunityProductMapperController.getOpportunity';

export default class LeadToOpportunityProductMapper extends LightningElement {
  _opportunityId;
  opportunity;
  @api get recordId() {
    return this._opportunityId
  }
  set recordId(value) {
    this._opportunityId = value

    getOpportunity({opportunityId: this._opportunityId})
      .then(gotOpportunity=>{
        this.opportunity = gotOpportunity
        console.log('opportunity', this.opportunity)
      })
      .catch(console.warn)
  }

}
