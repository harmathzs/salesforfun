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
  showCheckIcons = false;

  @api get recordId() {
    return this.opportunityId;
  }

  set recordId(value) {
    this.opportunityId = value;

    if (this.opportunityId) {
      this.loadData().catch(console.warn);
    }
  }

  get productInterest() {
    return this.opportunity?.Converted_Lead__r?.ProductInterest__c;
  }

  get calculatedTotal() {
    const totalAmount = this.selectedProducts.reduce((total, product) => {
      return total + (product.total || 0);
    }, 0);
    return this.formatCurrency(totalAmount);
  }

  get hasSelectedProducts() {
    return this.selectedProducts.length > 0;
  }

  get existingLineItems() {
    return this.opportunity?.OpportunityLineItems || [];
  }

  // Getter functions for template compatibility
  getProductSelected = (productId) => {
    return this.selectedProducts.some(p => p.Id === productId);
  };

  getExistingProduct = (product2Id) => {
    return this.existingLineItems.some(item => item.Product2Id === product2Id);
  };

  getHasRemovableProducts = () => {
    return this.selectedProducts.some(p => !p.isExisting);
  };

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

        // Format pricebook entry prices
        this.formatPricebookEntries();

        // Initialize selected products from existing line items
        this.initializeSelectedProducts();
      }
    } catch (error) {
      console.warn('Error loading data:', error);
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
      originalQuantity: item.Quantity, // Store original quantity for comparison
      total: item.TotalPrice,
      formattedTotal: this.formatCurrency(item.TotalPrice),
      formattedUnitPrice: this.formatCurrency(item.UnitPrice),
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

      // Check if this is an existing product (shouldn't be selectable due to disabled checkbox)
      const isExistingProduct = this.existingLineItems.some(item => item.Product2Id === productEntry.Product2Id);
      if (isExistingProduct) {
        console.warn(`Product ${productId} is an existing product and cannot be re-selected`);
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
        originalQuantity: 1, // Initial quantity for new products
        total: productEntry.UnitPrice,
        formattedTotal: this.formatCurrency(productEntry.UnitPrice),
        formattedUnitPrice: this.formatCurrency(productEntry.UnitPrice),
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
    const quantityInput = event.target.value;

    // If input is empty or invalid, set to minimum quantity (1)
    const quantity = quantityInput === '' || isNaN(+quantityInput) || +quantityInput < 1
      ? 1
      : +quantityInput;

    this.selectedProducts = this.selectedProducts.map(product => {
      if (product.Id === productId) {
        const newTotal = product.UnitPrice * quantity;
        return {
          ...product,
          quantity: quantity,
          total: newTotal,
          formattedTotal: this.formatCurrency(newTotal),
          formattedUnitPrice: this.formatCurrency(product.UnitPrice)
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
      console.log('handleSave selectedProducts', JSON.stringify(this.selectedProducts) )
      // Prepare data for Apex controller
      const lineItemsToCreate = this.selectedProducts
        .filter(product => !product.isExisting || product.quantity !== product.originalQuantity)
        .map(product => ({
          pricebookEntryId: product.Id,
          quantity: product.quantity,
          unitPrice: product.UnitPrice,
          // Include ID for existing products to enable update operation
          ...(product.isExisting && { id: product.Id })
        }));
      console.log('lineItemsToCreate', JSON.stringify(lineItemsToCreate) )

      const lineItemIdsToDelete = this.existingLineItems
        .filter(existingItem => !this.selectedProducts.some(selected => selected.Id === existingItem.Id))
        .map(item => item.Id);
      console.log('lineItemIdsToDelete', JSON.stringify(lineItemIdsToDelete) )

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
      console.warn('Error saving line items:', error);
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

  formatPricebookEntries() {
    if (this.pricebook?.PricebookEntries) {
      this.pricebook.PricebookEntries = this.pricebook.PricebookEntries.map(entry => ({
        ...entry,
        formattedUnitPrice: this.formatCurrency(entry.UnitPrice)
      }));
    }
  }

  // Currency formatting helper
  formatCurrency(value) {
    if (value == null) return '';
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD',
      minimumFractionDigits: 2,
      maximumFractionDigits: 2
    }).format(value);
  }
}
