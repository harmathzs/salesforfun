import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class MassLeadConverter extends LightningElement {
    @api recordIds;
    
    connectedCallback() {
        console.log('Mass Lead Converter initialized with records:', this.recordIds);
        this.showToast('Info', 'Mass Convert Leads action ready', 'info');
    }
    
    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        }));
    }
}