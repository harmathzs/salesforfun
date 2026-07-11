import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import getOpportunity from '@salesforce/apex/LeadToOpportunityProductMapperController.getOpportunity';
import getPricebook from '@salesforce/apex/LeadToOpportunityProductMapperController.getPricebook';
import saveOpportunityLineItems from '@salesforce/apex/LeadToOpportunityProductMapperController.saveOpportunityLineItems';

export default class LeadToOpportunityProductMapper extends LightningElement {
  opportunityId;
  @track opportunity;
  @track pricebook;
  @track selectedProducts = [];
  @track isSaving = false;
  @track isLoading = false;
  @track errorMessage = '';
  @track showSuccess = false;

  @api get recordId() {
    return this.opportunityId;
  }

  set recordId(value) {
    this.opportunityId = value;

    if (this.opportunityId) {
      this.loadData();
    }
  }

  get productInterest() {
    return this.opportunity?.Converted_Lead__r?.ProductInterest__c;
  }

  get calculatedTotal() {
    return this.selectedProducts.reduce((total, product) => {
      return total + (product.total || 0);
    }, 0);
  }

  get hasSelectedProducts() {
    return this.selectedProducts.length > 0;
  }

  get existingLineItems() {
    return this.opportunity?.OpportunityLineItems || [];
  }

  async loadData() {
    this.isLoading = true;
    this.errorMessage = '';

    try {
      this.opportunity = await getOpportunity({ opportunityId: this.opportunityId });
      console.log('opportunity', this.opportunity);
      console.log('opportunity json: ', JSON.stringify(this.opportunity));

      if (this.opportunity?.Pricebook2Id) {
        this.pricebook = await getPricebook({ pricebookId: this.opportunity.Pricebook2Id });
        console.log('pricebook', this.pricebook);
        console.log('pricebook json: ', JSON.stringify(this.pricebook));

        // Initialize selected products from existing line items
        this.initializeSelectedProducts();
      }
    } catch (error) {
      console.error('Error loading data:', error);
      this.errorMessage = 'Error loading opportunity data: ' + (error.body?.message || error.message);
    } finally {
      this.isLoading = false;
    }
  }

  initializeSelectedProducts() {
    const existingItems = this.existingLineItems;
    if (!existingItems || existingItems.length === 0) {
      this.selectedProducts = [];
      return;
    }

    // Map existing line items to our selected products format
    this.selectedProducts = existingItems.map(item => ({
      Id: item.Id,
      Name: item.Name,
      Product2: { Name: item.Product2?.Name, Id: item.Product2Id },
      Product2Id: item.Product2Id,
      UnitPrice: item.UnitPrice,
      quantity: item.Quantity,
      total: item.TotalPrice,
      isExisting: true
    }));
  }

  handleProductSelect(event) {
    const productId = event.target.dataset.id;
    const isSelected = event.target.checked;

    // Defensive checks
    if (!productId || !this.pricebook?.PricebookEntries) {
      console.warn('Product selection aborted: missing productId or pricebook data');
      return;
    }

    const productEntry = this.pricebook.PricebookEntries.find(entry => entry.Id === productId);

    if (!productEntry) {
      console.warn(`Product entry not found for ID: ${productId}`);
      return;
    }

    if (isSelected && productEntry) {
      // Check if already selected (to prevent duplicates)
      const alreadySelected = this.selectedProducts.some(p => p.Id === productId);
      if (alreadySelected) {
        console.warn(`Product ${productId} already selected`);
        return;
      }

      // Add to selected products
      this.selectedProducts = [...this.selectedProducts, {
        Id: productEntry.Id,
        Name: productEntry.Name,
        Product2: productEntry.Product2,
        Product2Id: productEntry.Product2Id,
        UnitPrice: productEntry.UnitPrice,
        quantity: 1,
        total: productEntry.UnitPrice,
        isExisting: false
      }];
    } else {
      // Remove from selected products (only non-existing items)
      this.selectedProducts = this.selectedProducts.filter(product =>
        !(product.Id === productId && !product.isExisting)
      );
    }
  }

  handleQuantityChange(event) {
    const productId = event.target.dataset.id;
    const quantity = +event.target.value || 1;

    this.selectedProducts = this.selectedProducts.map(product => {
      if (product.Id === productId) {
        const newTotal = product.UnitPrice * quantity;
        return {
          ...product,
          quantity: quantity,
          total: newTotal
        };
      }
      return product;
    });
  }

  handleRemoveProduct(event) {
    const productId = event.target.dataset.id;
    this.selectedProducts = this.selectedProducts.filter(product => product.Id !== productId);
  }

  handleRemoveAll() {
    // Only remove non-existing items to preserve existing line items
    this.selectedProducts = this.selectedProducts.filter(product => product.isExisting);
  }

  async handleSave() {
    if (!this.hasSelectedProducts) {
      this.errorMessage = 'Please select at least one product.';
      return;
    }

    this.isSaving = true;
    this.errorMessage = '';
    this.showSuccess = false;

    try {
      // Prepare data for Apex controller
      const lineItemsToCreate = this.selectedProducts
        .filter(product => !product.isExisting)
        .map(product => ({
          pricebookEntryId: product.Id,
          quantity: product.quantity,
          unitPrice: product.UnitPrice
        }));

      const lineItemIdsToDelete = this.existingLineItems
        .filter(existingItem => !this.selectedProducts.some(selected => selected.Id === existingItem.Id))
        .map(item => item.Id);

      // Call Apex method
      await saveOpportunityLineItems({
        opportunityId: this.opportunityId,
        lineItemsToCreate: lineItemsToCreate,
        lineItemIdsToDelete: lineItemIdsToDelete
      });

      // Show success message
      this.showSuccessMessage('Success', 'Opportunity line items saved successfully!', 'success');
      this.showSuccess = true;

      // Refresh data
      await this.loadData();

    } catch (error) {
      console.error('Error saving line items:', error);
      const errorMessage = error.body?.message || error.message || 'Unknown error';
      this.errorMessage = 'Error saving line items: ' + errorMessage;
      this.showSuccessMessage('Error', errorMessage, 'error');
    } finally {
      this.isSaving = false;
    }
  }

  handleCancel() {
    // Reset to initial state
    this.initializeSelectedProducts();
    this.errorMessage = '';
    this.showSuccess = false;
  }

  showSuccessMessage(title, message, variant) {
    this.dispatchEvent(
      new ShowToastEvent({
        title: title,
        message: message,
        variant: variant
      })
    );
  }

  getProductCheckboxId(productId) {
    return `product-checkbox-${productId}`;
  }

  getQuantityInputId(productId) {
    return `quantity-input-${productId}`;
  }

  // Currency formatting helper
  formatCurrency(value) {
    if (value == null || value === undefined) return '';
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD',
      minimumFractionDigits: 2,
      maximumFractionDigits: 2
    }).format(value);
  }
}
