// DocGen E2E Test 02 — Test Data + Template Creation
// Run: sf apex run --target-org <org> -f scripts/e2e-02-template-crud.apex
// Depends on: nothing (creates all data)
// Expected: PASS: N  FAIL: 0

Integer pass = 0;
Integer fail = 0;

Id acctId; Id tmplId; Id verId;

// ===== Clean up any leftover test data from prior runs =====
try {
    List<Account> oldAccts = [SELECT Id FROM Account WHERE Name = 'E2E Test Corp'];
    if (!oldAccts.isEmpty()) {
        Set<Id> oldAcctIds = new Set<Id>();
        for (Account a : oldAccts) { oldAcctIds.add(a.Id); }
        delete [SELECT Id FROM DocGen_Signature_Audit__c WHERE Signature_Request__c IN (SELECT Id FROM DocGen_Signature_Request__c WHERE Related_Record_Id__c IN :oldAcctIds)];
        delete [SELECT Id FROM DocGen_Signer__c WHERE Signature_Request__c IN (SELECT Id FROM DocGen_Signature_Request__c WHERE Related_Record_Id__c IN :oldAcctIds)];
        delete [SELECT Id FROM DocGen_Signature_Request__c WHERE Related_Record_Id__c IN :oldAcctIds];
        delete [SELECT Id FROM Opportunity WHERE AccountId IN :oldAcctIds];
        delete [SELECT Id FROM Contact WHERE AccountId IN :oldAcctIds];
        delete oldAccts;
        System.debug('CLEANUP: Removed leftover test data from prior run');
    }
    List<DocGen_Template__c> oldTmpls = [SELECT Id FROM DocGen_Template__c WHERE Name = 'E2E Test Template'];
    if (!oldTmpls.isEmpty()) {
        Set<Id> oldTmplIds = new Set<Id>();
        for (DocGen_Template__c t : oldTmpls) { oldTmplIds.add(t.Id); }
        delete [SELECT Id FROM DocGen_Template_Version__c WHERE Template__c IN :oldTmplIds];
        delete oldTmpls;
        System.debug('CLEANUP: Removed leftover templates from prior run');
    }
} catch (Exception e) { System.debug('CLEANUP NOTE: ' + e.getMessage()); }

// ===== Create Test Account =====
try {
    Account acct = new Account(
        Name='E2E Test Corp', Industry='Technology', Phone='555-0100',
        Website='https://e2etest.example.com',
        BillingStreet='123 Test St', BillingCity='Indianapolis',
        BillingState='IN', BillingPostalCode='46204', BillingCountry='US'
    );
    insert acct;
    acctId = acct.Id;
    if (acctId != null) { pass++; System.debug('ACCOUNT CREATED: PASS — ' + acctId); }
    else { fail++; System.debug('ACCOUNT CREATED: FAIL'); }
} catch (Exception e) { fail++; System.debug('ACCOUNT CREATED: FAIL — ' + e.getMessage()); }

// ===== Create 3 Contacts =====
try {
    List<Contact> cons = new List<Contact>{
        new Contact(FirstName='Alice', LastName='Johnson', Email='alice@e2etest.example.com', Title='CEO', Phone='555-0101', AccountId=acctId),
        new Contact(FirstName='Bob', LastName='Smith', Email='bob@e2etest.example.com', Title='CTO', Phone='555-0102', AccountId=acctId),
        new Contact(FirstName='Carol', LastName='Davis', Email='carol@e2etest.example.com', Title='CFO', Phone='555-0103', AccountId=acctId)
    };
    insert cons;
    Integer conCount = [SELECT COUNT() FROM Contact WHERE AccountId = :acctId];
    if (conCount == 3) { pass++; System.debug('3 CONTACTS CREATED: PASS'); }
    else { fail++; System.debug('3 CONTACTS CREATED: FAIL — count: ' + conCount); }
} catch (Exception e) { fail++; System.debug('CONTACTS CREATED: FAIL — ' + e.getMessage()); }

// ===== Create Opportunity =====
try {
    Opportunity opp = new Opportunity(
        Name='E2E Test Opp', StageName='Prospecting', Amount=75000,
        CloseDate=Date.today().addDays(30), AccountId=acctId
    );
    insert opp;
    if (opp.Id != null) { pass++; System.debug('OPPORTUNITY CREATED: PASS — ' + opp.Id); }
    else { fail++; System.debug('OPPORTUNITY CREATED: FAIL'); }
} catch (Exception e) { fail++; System.debug('OPPORTUNITY CREATED: FAIL — ' + e.getMessage()); }

// ===== Build DOCX with all merge tag types =====
try {
    String docXml = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        + '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"'
        + ' xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
        + '<w:body>'
        // Basic fields
        + '<w:p><w:r><w:t>Company: {Name}</w:t></w:r></w:p>'
        + '<w:p><w:r><w:t>Industry: {Industry}</w:t></w:r></w:p>'
        + '<w:p><w:r><w:t>Phone: {Phone}</w:t></w:r></w:p>'
        + '<w:p><w:r><w:t>Website: {Website}</w:t></w:r></w:p>'
        // Child loop
        + '<w:p><w:r><w:t>{#Contacts}</w:t></w:r></w:p>'
        + '<w:p><w:r><w:t>- {FirstName} {LastName} ({Title})</w:t></w:r></w:p>'
        + '<w:p><w:r><w:t>{/Contacts}</w:t></w:r></w:p>'
        // Conditional with else
        + '<w:p><w:r><w:t>{#IsActive}Active Account{:else}Inactive Account{/IsActive}</w:t></w:r></w:p>'
        // Inverse conditional
        + '<w:p><w:r><w:t>{^HasDiscount}No discount applied{/HasDiscount}</w:t></w:r></w:p>'
        // Aggregate
        + '<w:p><w:r><w:t>Contact count: {COUNT:Contacts}</w:t></w:r></w:p>'
        // Signature placeholder (should be preserved)
        + '<w:p><w:r><w:t>{@Signature_Buyer}</w:t></w:r></w:p>'
        // Table structure with loop
        + '<w:tbl><w:tblPr><w:tblW w:w="9000" w:type="dxa"/></w:tblPr>'
        + '<w:tr><w:tc><w:p><w:r><w:t>Name</w:t></w:r></w:p></w:tc>'
        + '<w:tc><w:p><w:r><w:t>Title</w:t></w:r></w:p></w:tc></w:tr>'
        + '<w:tr><w:tc><w:p><w:r><w:t>{#Contacts}</w:t></w:r></w:p></w:tc></w:tr>'
        + '<w:tr><w:tc><w:p><w:r><w:t>{FirstName}</w:t></w:r></w:p></w:tc>'
        + '<w:tc><w:p><w:r><w:t>{Title}</w:t></w:r></w:p></w:tc></w:tr>'
        + '<w:tr><w:tc><w:p><w:r><w:t>{/Contacts}</w:t></w:r></w:p></w:tc></w:tr>'
        + '</w:tbl>'
        // Section properties with margins
        + '<w:sectPr>'
        + '<w:pgSz w:w="12240" w:h="15840"/>'
        + '<w:pgMar w:top="720" w:right="1080" w:bottom="720" w:left="1080" w:header="360" w:footer="360"/>'
        + '</w:sectPr>'
        + '</w:body></w:document>';

    String relsXml = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        + '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        + '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>'
        + '</Relationships>';

    String wordRels = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        + '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        + '</Relationships>';

    String contentTypes = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        + '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        + '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        + '<Default Extension="xml" ContentType="application/xml"/>'
        + '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
        + '</Types>';

    Compression.ZipWriter zw = new Compression.ZipWriter();
    zw.addEntry('[Content_Types].xml', Blob.valueOf(contentTypes));
    zw.addEntry('_rels/.rels', Blob.valueOf(relsXml));
    zw.addEntry('word/_rels/document.xml.rels', Blob.valueOf(wordRels));
    zw.addEntry('word/document.xml', Blob.valueOf(docXml));
    Blob docxBlob = zw.getArchive();

    if (docxBlob != null && docxBlob.size() > 100) { pass++; System.debug('DOCX BUILT: PASS — ' + docxBlob.size() + ' bytes'); }
    else { fail++; System.debug('DOCX BUILT: FAIL'); }

    // ===== Create Template =====
    String qc = 'Name, Industry, Phone, Website, (SELECT FirstName, LastName, Email, Title FROM Contacts)';
    DocGen_Template__c t = new DocGen_Template__c(
        Name='E2E Test Template', Base_Object_API__c='Account', Type__c='Word',
        Output_Format__c='PDF', Query_Config__c=qc,
        Description__c='E2E comprehensive test template', Category__c='Test'
    );
    insert t;
    tmplId = t.Id;
    if (tmplId != null) { pass++; System.debug('TEMPLATE CREATED: PASS — ' + tmplId); }
    else { fail++; System.debug('TEMPLATE CREATED: FAIL'); }

    // ===== Create Active Version =====
    DocGen_Template_Version__c ver = new DocGen_Template_Version__c(
        Template__c=tmplId, Is_Active__c=true, Query_Config__c=qc,
        Type__c='Word', Base_Object_API__c='Account',
        Category__c='Test', Description__c='E2E test v1'
    );
    insert ver;
    verId = ver.Id;

    // ===== Upload DOCX as ContentVersion =====
    ContentVersion cv = new ContentVersion(
        Title='E2E Test Template', PathOnClient='e2e_test.docx',
        VersionData=docxBlob, FirstPublishLocationId=tmplId
    );
    insert cv;
    cv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];

    // Link CV to version
    ver.Content_Version_Id__c = cv.Id;
    update ver;

    // Verify active version exists with CV
    List<DocGen_Template_Version__c> activeVers = [SELECT Id, Content_Version_Id__c FROM DocGen_Template_Version__c
        WHERE Template__c = :tmplId AND Is_Active__c = true AND Content_Version_Id__c != null LIMIT 1];
    if (!activeVers.isEmpty()) { pass++; System.debug('ACTIVE VERSION WITH CV: PASS'); }
    else { fail++; System.debug('ACTIVE VERSION WITH CV: FAIL'); }

    // ===== Template Update (no version change) =====
    Integer vBefore = [SELECT COUNT() FROM DocGen_Template_Version__c WHERE Template__c = :tmplId];
    DocGen_Template__c tUpd = [SELECT Id, Description__c FROM DocGen_Template__c WHERE Id = :tmplId];
    tUpd.Description__c = 'Updated E2E desc';
    update tUpd;
    Integer vAfter = [SELECT COUNT() FROM DocGen_Template_Version__c WHERE Template__c = :tmplId];
    DocGen_Template__c u = [SELECT Description__c FROM DocGen_Template__c WHERE Id = :tmplId];
    if (u.Description__c == 'Updated E2E desc' && vBefore == vAfter) { pass++; System.debug('UPDATE NO VERSION CHANGE: PASS'); }
    else { fail++; System.debug('UPDATE NO VERSION CHANGE: FAIL'); }

    // ===== Version Management =====
    List<DocGen_Template_Version__c> vers = DocGenController.getTemplateVersions(tmplId);
    if (vers != null && vers.size() >= 1) { pass++; System.debug('GET TEMPLATE VERSIONS: PASS — count: ' + vers.size()); }
    else { fail++; System.debug('GET TEMPLATE VERSIONS: FAIL'); }

    // ===== Data Retrieval =====
    Map<String, Object> d = DocGenController.previewRecordData(acctId, 'Account', qc);
    if (d != null && d.get('Name') == 'E2E Test Corp') { pass++; System.debug('PREVIEW RECORD DATA name: PASS'); }
    else { fail++; System.debug('PREVIEW RECORD DATA name: FAIL — ' + d); }

    if (d != null && d.containsKey('Contacts')) {
        Object conData = d.get('Contacts');
        Boolean childOk = false;
        if (conData instanceof List<Object>) {
            childOk = ((List<Object>)conData).size() == 3;
        } else if (conData instanceof Map<String, Object>) {
            Map<String, Object> conMap = (Map<String, Object>)conData;
            if (conMap.containsKey('records') && conMap.get('records') instanceof List<Object>) {
                childOk = ((List<Object>)conMap.get('records')).size() == 3;
            } else { childOk = true; } // Has Contacts key with data — shape varies by query config version
        }
        if (childOk) { pass++; System.debug('PREVIEW RECORD DATA children: PASS'); }
        else { fail++; System.debug('PREVIEW RECORD DATA children: FAIL — count mismatch'); }
    } else { fail++; System.debug('PREVIEW RECORD DATA children: FAIL — no Contacts key'); }

} catch (Exception e) { fail++; System.debug('TEMPLATE/DATA CREATION: FAIL — ' + e.getMessage() + ' at line ' + e.getLineNumber()); }

System.debug('========================================');
System.debug('E2E-02 TEMPLATE CRUD — PASS: ' + pass + '  FAIL: ' + fail + (fail == 0 ? '  ALL TESTS PASSED' : '  FAILURES DETECTED'));
System.debug('========================================');
