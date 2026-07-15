import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getQuoteFromContext from '@salesforce/apex/QuoteToOrderController.getQuoteFromContext';
import getQuoteLineItems from '@salesforce/apex/QuoteToOrderController.getQuoteLineItems';
import createOrderFromQuote from '@salesforce/apex/QuoteToOrderController.createOrderFromQuote';

export default class QuoteToOrder extends LightningElement {
  _recordId;
  @api get recordId() {
    return this._recordId
  }
  set recordId(value) {
    this._recordId = value

    this.init().catch(console.warn)
  }

  quote = null;
  lineItems = [];
  isLoading = true;
  error = null;
  orderCreated = false;
  createdOrderId = null;
  isCreatingOrder = false;

  /*
  connectedCallback() {
    this.init().catch(console.warn)
  }

   */

  async init() {
    try {
      this.isLoading = true;
      this.error = null;

      // Load quote from context (Quote or Opportunity)
      this.quote = await getQuoteFromContext({ recordId: this.recordId });
      this.quote.IsApproved = this.quote.Status === "Approved" || this.quote.Status === "Accepted"
      console.log('Quote loaded:', this.quote);

      // Load quote line items for display
      this.lineItems = await getQuoteLineItems({ quoteId: this.quote.Id });
      console.log('Line items loaded:', this.lineItems);

    } catch (err) {
      console.error('Error loading quote:', err);
      this.error = err.body?.message || err.message || 'Failed to load quote';
      this.showToast('Error', this.error, 'error');
    } finally {
      this.isLoading = false;
    }
  }

  async handleCreateOrder() {
    if (!this.quote) {
      this.showToast('Error', 'No quote loaded', 'error');
      return;
    }

    try {
      this.isCreatingOrder = true;

      const createdOrder = await createOrderFromQuote({ quoteId: this.quote.Id });
      console.log('Order created:', createdOrder);

      this.createdOrderId = createdOrder.Id;
      this.orderCreated = true;
      this.showToast('Success', `Order ${createdOrder.Id} created successfully`, 'success');

    } catch (err) {
      console.error('Error creating order:', err);
      const errorMsg = err.body?.message || err.message || 'Failed to create order';
      this.showToast('Error', errorMsg, 'error');
    } finally {
      this.isCreatingOrder = false;
    }
  }

  handleReset() {
    this.orderCreated = false;
    this.createdOrderId = null;
    this.init().catch(console.warn)
  }

  showToast(title, message, variant) {
    this.dispatchEvent(
      new ShowToastEvent({
        title,
        message,
        variant
      })
    );
  }

  get isQuoteValid() {
    return this.quote && this.quote.IsApproved && this.quote.IsSyncing;
  }

  get accountName() {
    return this.quote && this.quote.Account ? this.quote.Account.Name : this.quote?.AccountId || 'N/A';
  }

  get isCreateButtonDisabled() {
    return this.isLoading || this.isCreatingOrder || this.orderCreated || !this.isQuoteValid || this.lineItems.length === 0;
  }

  get loadingSpinnerVisible() {
    return this.isLoading || this.isCreatingOrder;
  }
}
