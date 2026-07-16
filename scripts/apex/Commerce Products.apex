/* Commerce Products */
// Test the original query
List<Product2> productsOriginal = [
        SELECT Id, Name, StockKeepingUnit,
        (SELECT Id, Name, Catalog.Name, IsPrimaryCategory, ProductCategory.Name
        FROM ProductCategoryProducts
        LIMIT 3)
        FROM Product2 LIMIT 20
];

System.debug('Original Query Results: ' + productsOriginal);
System.debug('Original Query Size: ' + productsOriginal.size());

// Test the improved query
List<Product2> productsImproved = [
        SELECT Id, Name, StockKeepingUnit,
        (SELECT Id, Name, IsPrimaryCategory,
                ProductCategory.Name,
                ProductCategory.Catalog.Name
        FROM ProductCategoryProducts
        ORDER BY IsPrimaryCategory DESC
        LIMIT 3)
        FROM Product2
        WHERE IsActive = TRUE
        LIMIT 20
];

System.debug('Improved Query Results: ' + productsImproved);
System.debug('Improved Query Size: ' + productsImproved.size());
