import { LightningElement, api } from 'lwc';

import queryContract from '@salesforce/apex/ContractPDFcontroller.queryContract'

export default class ContractPdfCreator extends LightningElement {
  contractId;
  @api get recordId() {
    return this.contractId
  }
  set recordId(value) {
    this.contractId = value

    this.loadData().catch(console.warn)
  }

  contract;
  async loadData() {
    this.contract = await queryContract({contractId: this.contractId})
    console.log('contract', this.contract)
  }
}
