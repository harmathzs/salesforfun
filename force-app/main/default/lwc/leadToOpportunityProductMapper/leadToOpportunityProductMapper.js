import { LightningElement, api } from 'lwc';

import getOpportunity from '@salesforce/apex/LeadToOpportunityProductMapperController.getOpportunity';
import getPricebook from '@salesforce/apex/LeadToOpportunityProductMapperController.getPricebook';

export default class LeadToOpportunityProductMapper extends LightningElement {
  opportunityId;
  opportunity;

  pricebookId;
  pricebook;

  @api get recordId() {
    return this.opportunityId
  }

  set recordId(value) {
    this.opportunityId = value

    getOpportunity({opportunityId: this.opportunityId})
      .then(async (gotOpportunity)=>{
        this.opportunity = gotOpportunity
        console.log('opportunity', this.opportunity)
        console.log('opportunity json: ', JSON.stringify(this.opportunity))

        this.pricebookId = this.opportunity.Pricebook2Id
        this.pricebook = await getPricebook({pricebookId: this.pricebookId})
        console.log('pricebook', this.pricebook)
        console.log('pricebook json: ', JSON.stringify(this.pricebook))
      })
      .catch(console.warn)
  }

  get productInterest() {
    return this.opportunity?.Converted_Lead__r?.ProductInterest__c
  }
}
