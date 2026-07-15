import { LightningElement, api } from 'lwc';
import isValidId from '@salesforce/apex/QuoteToOrderController.isValidId'
import parseId from '@salesforce/apex/QuoteToOrderController.parseId'
import whichSobject from '@salesforce/apex/QuoteToOrderController.whichSobject'
import getRecordById from '@salesforce/apex/QuoteToOrderController.getRecordById'

export default class QuoteToOrder extends LightningElement {
  _recordId;
  @api get recordId() {
    return this._recordId
  }
  set recordId(value) {
    this._recordId = value

    this.init().catch(console.warn)
  }

  validId;
  parsedId;
  sObjectName;
  _record;
  async init() {
    this.validId = await isValidId({rawId: this.recordId})
    if (this.validId) {
      this.parsedId = await parseId({rawId: this.recordId})
      this.sObjectName = await whichSobject({recordId: this.recordId})
      this._record = await getRecordById({recordId: this.recordId, sObjectName: this.sObjectName})
      console.log('record', this._record)
    }
  }
}
