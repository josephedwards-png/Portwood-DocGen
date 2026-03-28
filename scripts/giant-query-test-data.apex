// =====================================================================
// Giant Query Test Data — 3,000 Products in a Pricebook for large-dataset testing
// Generates a full product catalog / pricebook PDF
// Run: sf apex run --target-org <org> -f scripts/giant-query-test-data.apex
// =====================================================================

// 1. Get the Standard Pricebook
Id stdPricebookId = Test.isRunningTest() ? Test.getStandardPricebookId() : [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1].Id;

// 2. Create or get a custom Pricebook
List<Pricebook2> existingPb = [SELECT Id FROM Pricebook2 WHERE Name = 'Giant Query Test Pricebook' LIMIT 1];
Pricebook2 pb;
if (!existingPb.isEmpty()) {
    pb = existingPb[0];
} else {
    pb = new Pricebook2(Name = 'Giant Query Test Pricebook', IsActive = true);
    insert pb;
}
System.debug('Pricebook: ' + pb.Id);

// 3. Create 3,000 Products in batches of 200
Integer totalProducts = 3000;
Integer batchSize = 200;
Integer successCount = 0;
Integer failCount = 0;
List<Id> productIds = new List<Id>();

for (Integer batch = 0; batch < totalProducts; batch += batchSize) {
    List<Product2> products = new List<Product2>();
    Integer batchEnd = Math.min(batch + batchSize, totalProducts);
    for (Integer i = batch; i < batchEnd; i++) {
        String seq = String.valueOf(i + 1).leftPad(4, '0');
        products.add(new Product2(
            Name = 'Product GQ-' + seq,
            ProductCode = 'GQ-' + seq,
            Description = 'Giant Query test product #' + seq,
            IsActive = true
        ));
    }
    List<Database.SaveResult> results = Database.insert(products, false);
    for (Database.SaveResult sr : results) {
        if (sr.isSuccess()) {
            successCount++;
            productIds.add(sr.getId());
        } else {
            failCount++;
        }
    }
    System.debug('Products batch ' + (batch / batchSize + 1) + ' complete (' + batchEnd + '/' + totalProducts + ')');
}
System.debug('Products created: ' + successCount + ' (failed: ' + failCount + ')');

// 4. Create Standard PricebookEntries (required before custom)
List<PricebookEntry> stdEntries = new List<PricebookEntry>();
for (Id prodId : productIds) {
    stdEntries.add(new PricebookEntry(
        Pricebook2Id = stdPricebookId,
        Product2Id = prodId,
        UnitPrice = Math.round(Math.random() * 9990 + 10) / 100.0,
        IsActive = true
    ));
}

Integer stdSuccess = 0;
for (Integer batch = 0; batch < stdEntries.size(); batch += batchSize) {
    List<PricebookEntry> chunk = new List<PricebookEntry>();
    Integer batchEnd = Math.min(batch + batchSize, stdEntries.size());
    for (Integer i = batch; i < batchEnd; i++) {
        chunk.add(stdEntries[i]);
    }
    List<Database.SaveResult> results = Database.insert(chunk, false);
    for (Database.SaveResult sr : results) {
        if (sr.isSuccess()) stdSuccess++;
    }
    System.debug('Std PBE batch ' + (batch / batchSize + 1) + ' complete');
}
System.debug('Standard PricebookEntries: ' + stdSuccess);

// 5. Create Custom PricebookEntries
List<PricebookEntry> customEntries = new List<PricebookEntry>();
for (Id prodId : productIds) {
    customEntries.add(new PricebookEntry(
        Pricebook2Id = pb.Id,
        Product2Id = prodId,
        UnitPrice = Math.round(Math.random() * 49990 + 10) / 100.0,
        IsActive = true
    ));
}

Integer customSuccess = 0;
for (Integer batch = 0; batch < customEntries.size(); batch += batchSize) {
    List<PricebookEntry> chunk = new List<PricebookEntry>();
    Integer batchEnd = Math.min(batch + batchSize, customEntries.size());
    for (Integer i = batch; i < batchEnd; i++) {
        chunk.add(customEntries[i]);
    }
    List<Database.SaveResult> results = Database.insert(chunk, false);
    for (Database.SaveResult sr : results) {
        if (sr.isSuccess()) customSuccess++;
    }
    System.debug('Custom PBE batch ' + (batch / batchSize + 1) + ' complete');
}
System.debug('Custom PricebookEntries: ' + customSuccess);

// 6. Template with V3 query config — Pricebook with PricebookEntries and Product details
String queryConfig = '{"v":3,"root":"Pricebook2","nodes":['
    + '{"id":"n0","object":"Pricebook2","fields":["Name","Description","IsActive"],"parentFields":[],"parentNode":null,"lookupField":null,"relationshipName":null},'
    + '{"id":"n1","object":"PricebookEntry","fields":["UnitPrice","IsActive","ProductCode"],"parentFields":["Product2.Name","Product2.ProductCode","Product2.Description"],"parentNode":"n0","lookupField":"Pricebook2Id","relationshipName":"PricebookEntries"}'
    + ']}';

List<DocGen_Template__c> existing = [SELECT Id FROM DocGen_Template__c WHERE Name = 'Giant Query Pricebook Template' LIMIT 1];
DocGen_Template__c tmpl;
if (!existing.isEmpty()) {
    tmpl = existing[0];
    tmpl.Query_Config__c = queryConfig;
    tmpl.Base_Object_API__c = 'Pricebook2';
    tmpl.Output_Format__c = 'PDF';
    tmpl.Type__c = 'Word';
    update tmpl;
} else {
    tmpl = new DocGen_Template__c(
        Name = 'Giant Query Pricebook Template',
        Base_Object_API__c = 'Pricebook2',
        Query_Config__c = queryConfig,
        Output_Format__c = 'PDF',
        Type__c = 'Word'
    );
    insert tmpl;
}

// 7. Summary
Integer pbeCount = [SELECT COUNT() FROM PricebookEntry WHERE Pricebook2Id = :pb.Id];
System.debug('');
System.debug('=== GIANT QUERY PRICEBOOK TEST DATA READY ===');
System.debug('Pricebook:  ' + pb.Id + ' (Giant Query Test Pricebook)');
System.debug('Template:   ' + tmpl.Id + ' (Giant Query Pricebook Template)');
System.debug('Products:   ' + successCount);
System.debug('PBE Count:  ' + pbeCount);
System.debug('');
System.debug('NEXT: Upload a DOCX template with these tags:');
System.debug('  {Name} — Pricebook name');
System.debug('  {#PricebookEntries}');
System.debug('  {Product2.Name} | {Product2.ProductCode} | {UnitPrice:currency} | {Product2.Description}');
System.debug('  {/PricebookEntries}');
System.debug('');
System.debug('THEN: Navigate to Pricebook ' + pb.Id + ' and click Giant Query!');
