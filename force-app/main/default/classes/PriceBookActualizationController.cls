/**
 * PriceBook Actualization Controller
 *
 * @author Zsolt Harmath
 * @description Provides functionality to clone pricebooks with percentage adjustments on all entries.
 *              Supports year-end pricebook rollover with configurable price adjustments.
 */
public with sharing class PriceBookActualizationController {

  // Instance variables for Visualforce page
  public String selectedSourceId { get; set; }
  public Decimal percentageAdjustment { get; set; }
  public String newPricebookName { get; set; }
  public List<SelectOption> pricebooks { get; private set; }
  public Boolean showResults { get; private set; }
  public Boolean resultSuccess { get; private set; }
  public String resultMessage { get; private set; }
  public List<String> resultErrors { get; private set; }
  public Integer previewEntryCount { get; private set; }

  // Constructor - load pricebooks on page load
  public PriceBookActualizationController() {
    System.debug('PriceBookActualizationController constructor called');
    loadPricebooks();
    applyOpportunityDefaults();
    showResults = false;
    resultErrors = new List<String>();

    percentageAdjustment = 0;
  }

  /**
   * Prefill the source pricebook from the current Opportunity record context, if available.
   */
  private void applyOpportunityDefaults() {
    String opportunityId = getCurrentRecordId();
    if (String.isBlank(opportunityId)) {
      return;
    }

    List<Opportunity> opportunities = [
      SELECT Id, Name, Pricebook2Id, Pricebook2.Name
      FROM Opportunity
      WHERE Id = :opportunityId
      LIMIT 1
    ];

    if (!opportunities.isEmpty() && opportunities[0].Pricebook2Id != null) {
      selectedSourceId = opportunities[0].Pricebook2Id;
      System.debug('PriceBookActualizationController.applyOpportunityDefaults; preselected source pricebook from Opportunity ' + opportunities[0].Name);
    }
  }

  /**
   * Read the current record id from the page context.
   *
   * Supports both standard record page parameters: id and recordId.
   */
  private String getCurrentRecordId() {
    PageReference currentPage = ApexPages.currentPage();
    if (currentPage == null) {
      return null;
    }

    Map<String, String> params = currentPage.getParameters();
    if (params.containsKey('recordId') && !String.isBlank(params.get('recordId'))) {
      return params.get('recordId');
    }

    if (params.containsKey('id') && !String.isBlank(params.get('id'))) {
      return params.get('id');
    }

    return null;
  }

  /**
   * Load all active pricebooks for dropdown selection
   */
  public void loadPricebooks() {
    System.debug('PriceBookActualizationController.loadPricebooks started');
    pricebooks = new List<SelectOption>();
    pricebooks.add(new SelectOption('', '-- Select a PriceBook --'));

    try {
      Pricebook2[] allPricebooks = [
        SELECT Id, Name
        FROM Pricebook2
        ORDER BY Name ASC
      ];

      System.debug('PriceBookActualizationController.loadPricebooks; found ' + allPricebooks.size() + ' pricebooks');

      for (Pricebook2 pb : allPricebooks) {
        pricebooks.add(new SelectOption(pb.Id, pb.Name));
      }
    } catch (Exception e) {
      System.debug('ERROR in PriceBookActualizationController.loadPricebooks: ' + e.getMessage());
      addErrorMessage('Failed to load pricebooks: ' + e.getMessage());
    }
  }

  /**
   * Action: Create the new pricebook from the Visualforce form
   */
  public void createPriceBook() {
    System.debug('PriceBookActualizationController.createPriceBook called');
    showResults = false;
    resultErrors = new List<String>();

    // Validate form inputs
    if (String.isBlank(selectedSourceId)) {
      addErrorMessage('Please select a source pricebook');
      return;
    }

    if (percentageAdjustment == null) {
      addErrorMessage('Please enter a percentage adjustment');
      return;
    }

    if (String.isBlank(newPricebookName)) {
      addErrorMessage('Please enter a name for the new pricebook');
      return;
    }

    // Call the actualization method
    Map<String, Object> result = createActualizedPriceBook(
      selectedSourceId,
      percentageAdjustment,
      newPricebookName
    );

    // Display results
    resultSuccess = (Boolean)result.get('success');
    resultMessage = (String)result.get('message');
    resultErrors = (List<String>)result.get('errors');
    showResults = true;

    // Clear form on success
    if (resultSuccess) {
      selectedSourceId = null;
      percentageAdjustment = 0;
      newPricebookName = null;
      previewEntryCount = null;
      loadPricebooks();
    }
  }

  /**
   * Action: Cancel and reset form
   */
  public void cancel() {
    System.debug('PriceBookActualizationController.cancel called');
    selectedSourceId = null;
    percentageAdjustment = 0;
    newPricebookName = null;
    previewEntryCount = null;
    showResults = false;
    resultErrors = new List<String>();
  }

  /**
   * Helper method to add error messages
   */
  private void addErrorMessage(String message) {
    resultSuccess = false;
    resultMessage = message;
    resultErrors.add(message);
    showResults = true;
  }

  /**
   * Validate that a new pricebook name is unique (not already in use)
   *
   * @param name The proposed pricebook name
   * @return Boolean true if name is available, false if duplicate exists
   */
  public static Boolean validateNewPricebookName(String name) {
    System.debug('PriceBookActualizationController.validateNewPricebookName: ' + name);

    if (String.isBlank(name)) {
      throw new AuraHandledException('Pricebook name cannot be blank');
    }

    try {
      Pricebook2[] existing = [
        SELECT Id
        FROM Pricebook2
        WHERE Name = :name
        LIMIT 1
      ];

      Boolean isUnique = existing.isEmpty();
      System.debug('PriceBookActualizationController.validateNewPricebookName; isUnique: ' + isUnique);
      return isUnique;
    } catch (Exception e) {
      System.debug('ERROR in PriceBookActualizationController.validateNewPricebookName: ' + e.getMessage());
      throw new AuraHandledException('Failed to validate pricebook name: ' + e.getMessage());
    }
  }

  /**
   * Create a new pricebook by cloning entries from an existing pricebook with percentage adjustment
   *
   * @param sourcePricebookId The Id of the source pricebook to clone
   * @param percentageAdjustment The percentage to adjust prices (e.g., 5 for +5%, -10 for -10%)
   * @param newPricebookName The name for the new pricebook
   * @return Map<String, Object> with success status, created pricebook Id, entry count, and any errors
   */
  public static Map<String, Object> createActualizedPriceBook(
    String sourcePricebookId,
    Decimal percentageAdjustment,
    String newPricebookName
  ) {
    System.debug('PriceBookActualizationController.createActualizedPriceBook started');
    System.debug('sourcePricebookId: ' + sourcePricebookId);
    System.debug('percentageAdjustment: ' + percentageAdjustment);
    System.debug('newPricebookName: ' + newPricebookName);

    Map<String, Object> result = new Map<String, Object>{
      'success' => false,
      'pricebookId' => null,
      'pricebookName' => null,
      'entriesCreated' => 0,
      'message' => '',
      'errors' => new List<String>()
    };

    try {
      // Validate inputs
      if (String.isBlank(sourcePricebookId)) {
        throw new AuraHandledException('Source pricebook ID cannot be blank');
      }

      if (percentageAdjustment == null) {
        throw new AuraHandledException('Percentage adjustment cannot be null');
      }

      if (String.isBlank(newPricebookName)) {
        throw new AuraHandledException('New pricebook name cannot be blank');
      }

      // Validate source pricebook exists
      Pricebook2[] sourcePricebooks = [
        SELECT Id, Name
        FROM Pricebook2
        WHERE Id = :sourcePricebookId
        LIMIT 1
      ];

      if (sourcePricebooks.isEmpty()) {
        throw new AuraHandledException('Source pricebook not found');
      }

      Pricebook2 sourcePricebook = sourcePricebooks[0];
      System.debug('Source pricebook found: ' + sourcePricebook.Name);

      // Validate new pricebook name is unique
      if (!validateNewPricebookName(newPricebookName)) {
        throw new AuraHandledException('A pricebook with name "' + newPricebookName + '" already exists');
      }

      // Query all pricebook entries for the source pricebook
      PricebookEntry[] sourceEntries = [
        SELECT Id, Pricebook2Id, Product2Id, UnitPrice, UseStandardPrice
        FROM PricebookEntry
        WHERE Pricebook2Id = :sourcePricebookId
        ORDER BY Product2Id ASC
      ];

      System.debug('Found ' + sourceEntries.size() + ' entries in source pricebook');

      if (sourceEntries.isEmpty()) {
        throw new AuraHandledException('Source pricebook has no entries to clone');
      }

      // Create new pricebook
      Pricebook2 newPricebook = new Pricebook2(
        Name = newPricebookName,
        IsActive = true
      );
      insert newPricebook;
      System.debug('New pricebook created with Id: ' + newPricebook.Id);

      // Clone all pricebook entries with adjusted prices
      PricebookEntry[] newEntries = new List<PricebookEntry>();

      for (PricebookEntry sourceEntry : sourceEntries) {
        // Calculate adjusted price with percentage
        Decimal adjustmentFactor = 1 + (percentageAdjustment / 100);
        Decimal newPrice = (sourceEntry.UnitPrice * adjustmentFactor).setScale(2, RoundingMode.HALF_UP);

        System.debug('Entry - Product: ' + sourceEntry.Product2Id +
          ', Original Price: ' + sourceEntry.UnitPrice +
          ', Adjustment Factor: ' + adjustmentFactor +
          ', New Price: ' + newPrice);

        PricebookEntry newEntry = new PricebookEntry(
          Pricebook2Id = newPricebook.Id,
          Product2Id = sourceEntry.Product2Id,
          UnitPrice = newPrice,
          UseStandardPrice = false

        );
        newEntries.add(newEntry);
      }

      // Insert all new entries
      insert newEntries;
      System.debug('Inserted ' + newEntries.size() + ' new pricebook entries');

      result.put('success', true);
      result.put('pricebookId', newPricebook.Id);
      result.put('pricebookName', newPricebook.Name);
      result.put('entriesCreated', newEntries.size());
      result.put('message', 'Successfully created pricebook "' + newPricebookName +
        '" with ' + newEntries.size() + ' entries at ' + percentageAdjustment + '% adjustment');

      System.debug('PriceBookActualizationController.createActualizedPriceBook completed successfully');
      System.debug('Result: ' + JSON.serialize(result));

    } catch (DmlException e) {
      String errorMsg = 'DML Error: ';
      List<String> errors = (List<String>)result.get('errors');
      for (Integer i = 0; i < e.getNumDml(); i++) {
        String err = 'Record ' + i + ': ' + e.getDmlMessage(i);
        System.debug('DML Error ' + i + ': ' + err);
        errors.add(err);
        errorMsg += err + '; ';
      }
      result.put('errors', errors);
      result.put('message', errorMsg);
      System.debug('ERROR - DML Exception: ' + e.getMessage());
    } catch (AuraHandledException e) {
      result.put('message', e.getMessage());
      ((List<String>)result.get('errors')).add(e.getMessage());
      System.debug('ERROR - AuraHandledException: ' + e.getMessage());
    } catch (Exception e) {
      String errorMsg = 'Unexpected error: ' + e.getMessage();
      result.put('message', errorMsg);
      ((List<String>)result.get('errors')).add(errorMsg);
      System.debug('ERROR - Exception: ' + e.getMessage() + '\n' + e.getStackTraceString());
    }

    return result;
  }
}
