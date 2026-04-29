@IsTest
private class DocGenControllerCoverageTest {
    @IsTest
    static void getOrgIdReturnsCurrentOrgId() {
        String orgId = DocGenController.getOrgId();
        System.assertEquals(UserInfo.getOrganizationId(), orgId);
    }

    @IsTest
    static void scoutAttachedImageSizeWithNullReturnsZero() {
        System.assertEquals(0L, DocGenController.scoutAttachedImageSize(null));
    }

    @IsTest
    static void scoutAttachedImageSizeWithNoImagesReturnsZero() {
        Account acct = new Account(Name = 'Scout Test');
        insert acct;
        Long size = DocGenController.scoutAttachedImageSize(acct.Id);
        System.assertEquals(0L, size, 'No attached images → 0');
    }

    @IsTest
    static void scoutAttachedImageSizeSumsAttachedImages() {
        Account acct = new Account(Name = 'Scout With Images');
        insert acct;
        Blob fakePng = Blob.valueOf('fake-png-bytes-of-known-length');
        ContentVersion cv = new ContentVersion(
            Title = 'attached-image',
            PathOnClient = 'pic.png',
            VersionData = fakePng,
            FirstPublishLocationId = acct.Id
        );
        insert cv;

        Long size = DocGenController.scoutAttachedImageSize(acct.Id);
        System.assert(size > 0L, 'Attached PNG should be counted, got ' + size);
    }

    @IsTest
    static void saveAndClearWatermarkImageRoundtrip() {
        DocGen_Template__c tmpl = new DocGen_Template__c(
            Name = 'Watermark Test Tmpl',
            Type__c = 'Word',
            Output_Format__c = 'PDF',
            Base_Object_API__c = 'Account'
        );
        insert tmpl;
        DocGen_Template_Version__c version = new DocGen_Template_Version__c(Template__c = tmpl.Id, Is_Active__c = true);
        insert version;

        // Tiny 1x1 PNG (base64 of a real 1x1 transparent PNG)
        String pngB64 = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkAAIAAAoAAv/lxKUAAAAASUVORK5CYII=';

        Test.startTest();
        Id cvId = DocGenController.saveWatermarkImage(version.Id, 'wm.png', pngB64);
        System.assertNotEquals(null, cvId, 'saveWatermarkImage should return new CV Id');

        DocGen_Template_Version__c reloaded = [
            SELECT Watermark_Image_CV_Id__c
            FROM DocGen_Template_Version__c
            WHERE Id = :version.Id
        ];
        System.assertEquals(cvId, reloaded.Watermark_Image_CV_Id__c, 'Version should now reference the watermark CV');

        DocGenController.clearWatermarkImage(version.Id);
        DocGen_Template_Version__c cleared = [
            SELECT Watermark_Image_CV_Id__c
            FROM DocGen_Template_Version__c
            WHERE Id = :version.Id
        ];
        System.assertEquals(null, cleared.Watermark_Image_CV_Id__c, 'Watermark CV reference should be cleared');
        Test.stopTest();
    }

    @IsTest
    static void saveWatermarkImageRejectsBlankInputs() {
        DocGen_Template__c tmpl = new DocGen_Template__c(
            Name = 'Watermark Reject',
            Type__c = 'Word',
            Output_Format__c = 'PDF',
            Base_Object_API__c = 'Account'
        );
        insert tmpl;
        DocGen_Template_Version__c version = new DocGen_Template_Version__c(Template__c = tmpl.Id, Is_Active__c = true);
        insert version;

        Boolean threwOnNullVersionId = false;
        try {
            DocGenController.saveWatermarkImage(null, 'a.png', 'AAAA');
        } catch (DocGenException e) {
            threwOnNullVersionId = true;
        }
        System.assert(threwOnNullVersionId, 'saveWatermarkImage(null,…) should throw');

        Boolean threwOnBlankBase64 = false;
        try {
            DocGenController.saveWatermarkImage(version.Id, 'a.png', '');
        } catch (DocGenException e) {
            threwOnBlankBase64 = true;
        }
        System.assert(threwOnBlankBase64, 'saveWatermarkImage(…, blank) should throw');
    }

    @IsTest
    static void clearWatermarkImageWithNullIsNoop() {
        // No exception, no DML, just returns
        DocGenController.clearWatermarkImage(null);
    }

    @IsTest
    static void generatePdfAsyncEnqueuesQueueable() {
        Account acct = new Account(Name = 'Async PDF Test');
        insert acct;
        DocGen_Template__c tmpl = new DocGen_Template__c(
            Name = 'Async Test Tmpl',
            Type__c = 'HTML',
            Output_Format__c = 'PDF',
            Base_Object_API__c = 'Account',
            Query_Config__c = '{"v":3,"root":"Account","nodes":[{"id":"n0","object":"Account","fields":["Name"],"parentNode":null,"lookupField":null,"relationshipName":null}]}'
        );
        insert tmpl;
        ContentVersion cv = new ContentVersion(
            Title = 'Async Test Body',
            PathOnClient = 'b.html',
            VersionData = Blob.valueOf('<html><body><h1>{Name}</h1></body></html>'),
            FirstPublishLocationId = tmpl.Id
        );
        insert cv;
        cv = [SELECT Id FROM ContentVersion WHERE Id = :cv.Id];
        insert new DocGen_Template_Version__c(
            Template__c = tmpl.Id,
            Content_Version_Id__c = cv.Id,
            Is_Active__c = true
        );

        Test.startTest();
        Id jobId = DocGenController.generatePdfAsync(tmpl.Id, acct.Id);
        Test.stopTest();
        System.assertNotEquals(null, jobId, 'generatePdfAsync should return AsyncApexJob Id');
    }

    @IsTest
    static void renderImageAsPdfBase64ShortcircuitsInTestMode() {
        // The method has Test.isRunningTest() bypass that returns base64('test-pdf')
        String result = DocGenController.renderImageAsPdfBase64(
            '/sfc/servlet.shepherd/version/download/068000000000000'
        );
        System.assertNotEquals(null, result, 'Should return non-null in test mode');
        System.assertEquals(EncodingUtil.base64Encode(Blob.valueOf('test-pdf')), result);
    }

    @IsTest
    static void renderImageAsPdfBase64RejectsExternalUrls() {
        // Security guard: only Salesforce-hosted URLs allowed
        String resultExt = DocGenController.renderImageAsPdfBase64('https://evil.com/img.png');
        System.assertEquals(null, resultExt, 'Non-Salesforce URL should return null');
        String resultBlank = DocGenController.renderImageAsPdfBase64('');
        System.assertEquals(null, resultBlank, 'Blank URL should return null');
    }
}
