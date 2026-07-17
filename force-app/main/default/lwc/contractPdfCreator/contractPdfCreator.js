import { LightningElement, api } from 'lwc';

import queryContract from '@salesforce/apex/ContractPDFcontroller.queryContract'

export default class ContractPdfCreator extends LightningElement {
  @api recordId;
}
