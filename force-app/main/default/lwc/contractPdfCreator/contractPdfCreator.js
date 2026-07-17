import { LightningElement, api, track } from 'lwc';

import { CloseActionScreenEvent } from 'lightning/actions';

import queryContract from '@salesforce/apex/ContractPDFcontroller.queryContract';
import getVFUrl from '@salesforce/apex/ContractPDFcontroller.getVFUrl';
import savePdfToContract from '@salesforce/apex/ContractPDFcontroller.savePdfToContract';
import sendEmailWithPdf from '@salesforce/apex/ContractPDFcontroller.sendEmailWithPdf';

export default class ContractPdfCreator extends LightningElement {
  contractId;
  @api get recordId() { return this.contractId; }
  set recordId(value) {
    this.contractId = value;
    this.loadData().catch(console.warn);
  }

  @track contract;
  vfUrl = '';
  showEmailModal = false;
  emailTo = '';
  emailSubject = '';
  emailBody = '';

  async loadData() {
    this.contract = await queryContract({contractId: this.contractId});
    console.log('contract', this.contract);
    try{
      this.vfUrl = await getVFUrl({contractId: this.contractId});
    } catch(e){ console.warn('getVFUrl failed', e); }
  }

  handleDownload() {
    if (!this.vfUrl) return;
    window.open(this.vfUrl + '&download=true','_blank');
  }

  async handleSave() {
    try {
      await savePdfToContract({contractId: this.contractId});
      // TODO: show toast on success
      console.log('Saved PDF to Contract');
    } catch (e) { console.warn(e); }
  }

  openEmailModal() { this.showEmailModal = true; this.emailSubject = 'Contract ' + (this.contract? this.contract.ContractNumber : ''); }
  closeEmailModal(){ this.showEmailModal = false; }
  onEmailToChange(e){ this.emailTo = e.target.value; }
  onEmailSubjectChange(e){ this.emailSubject = e.target.value; }
  onEmailBodyChange(e){ this.emailBody = e.target.value; }

  async handleSendEmail(){
    try{
      await sendEmailWithPdf({contractId: this.contractId, toAddress: this.emailTo, subject: this.emailSubject, body: this.emailBody});
      this.closeEmailModal();
      console.log('Email sent');
    } catch(e){ console.warn(e); }
  }

  handleCancel(){
    // this.dispatchEvent(new CustomEvent('cancel'));
    this.dispatchEvent(new CloseActionScreenEvent());
  }
}
