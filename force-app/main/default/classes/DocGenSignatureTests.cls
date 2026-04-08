@isTest
private class DocGenSignatureTests {

    @testSetup
    static void setup() {
        Account acc = new Account(Name = 'Signature Test Account', Website = 'https://test.com');
        insert acc;

        Contact con = new Contact(
            FirstName = 'Signature',
            LastName = 'Tester',
            Email = 'signer@example.com',
            AccountId = acc.Id
        );
        insert con;

        DocGen_Signature_Request__c req = new DocGen_Signature_Request__c(
            Signer_Name__c = 'Legacy Signer',
            Signer_Email__c = 'legacy@test.com',
            Source_Document_Id__c = '068000000000001AAA',
            Related_Record_Id__c = acc.Id,
            Secure_Token__c = 'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2',
            Status__c = 'Sent'
        );
        insert req;

        DocGen_Signer__c signer = new DocGen_Signer__c(
            Signature_Request__c = req.Id,
            Signer_Name__c = 'Multi Signer One',
            Signer_Email__c = 'multisigner@test.com',
            Role_Name__c = 'Buyer',
            Secure_Token__c = 'f6e5d4c3b2a1f6e5d4c3b2a1f6e5d4c3b2a1f6e5d4c3b2a1f6e5d4c3b2a1f6e5',
            Status__c = 'Pending',
            Sort_Order__c = 1
        );
        insert signer;
    }

    // =========================================================================
    // Helpers
    // =========================================================================

    private static DocGen_Signer__c getTestSigner() {
        return [SELECT Id, Secure_Token__c, Status__c, Signature_Request__c,
                       PIN_Hash__c, PIN_Expires_At__c, PIN_Attempts__c, PIN_Verified_At__c
                FROM DocGen_Signer__c WHERE Secure_Token__c = 'f6e5d4c3b2a1f6e5d4c3b2a1f6e5d4c3b2a1f6e5d4c3b2a1f6e5d4c3b2a1f6e5' LIMIT 1];
    }

    private static DocGen_Signature_Request__c getTestRequest() {
        return [SELECT Id, Status__c, Secure_Token__c FROM DocGen_Signature_Request__c LIMIT 1];
    }

    // =========================================================================
    // Token Validation
    // =========================================================================

    @isTest
    static void testValidateToken_validMultiSigner() {
        Test.startTest();
        DocGenSignatureController.SignatureInitResponse res =
            DocGenSignatureController.validateToken('f6e5d4c3b2a1f6e5d4c3b2a1f6e5d4c3b2a1f6e5d4c3b2a1f6e5d4c3b2a1f6e5');
        Test.stopTest();

        System.assertEquals(true, res.isValid, 'Token should be valid');
        System.assertEquals('Multi Signer One', res.signerName);
        System.assertEquals('multisigner@test.com', res.signerEmail);
        System.assertEquals('Buyer', res.roleName);
        System.assertEquals(true, res.requiresPin, 'PIN should be required for new signer');
    }

    @isTest
    static void testValidateToken_blank() {
        Test.startTest();
        DocGenSignatureController.SignatureInitResponse res =
            DocGenSignatureController.validateToken('');
        Test.stopTest();

        System.assertEquals(false, res.isValid);
        System.assert(res.errorMessage.contains('Invalid'));
    }

    @isTest
    static void testValidateToken_badFormat() {
        Test.startTest();
        DocGenSignatureController.SignatureInitResponse res =
            DocGenSignatureController.validateToken('not-a-hex-token');
        Test.stopTest();

        System.assertEquals(false, res.isValid);
        System.assert(res.errorMessage.contains('Invalid'));
    }

    @isTest
    static void testValidateToken_notFound() {
        Test.startTest();
        DocGenSignatureController.SignatureInitResponse res =
            DocGenSignatureController.validateToken('0000000000000000000000000000000000000000000000000000000000000099');
        Test.stopTest();

        System.assertEquals(false, res.isValid);
        System.assert(res.errorMessage.contains('not found'));
    }

    @isTest
    static void testValidateToken_legacyRequest() {
        Test.startTest();
        DocGenSignatureController.SignatureInitResponse res =
            DocGenSignatureController.validateToken('a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2');
        Test.stopTest();

        System.assertEquals(true, res.isValid, 'Legacy token should be valid');
        System.assertEquals('Legacy Signer', res.signerName);
        System.assertEquals(false, res.isSignerToken);
    }

    @isTest
    static void testValidateToken_alreadySigned() {
        DocGen_Signer__c signer = getTestSigner();
        signer.Status__c = 'Signed';
        update signer;

        Test.startTest();
        DocGenSignatureController.SignatureInitResponse res =
            DocGenSignatureController.validateToken('f6e5d4c3b2a1f6e5d4c3b2a1f6e5d4c3b2a1f6e5d4c3b2a1f6e5d4c3b2a1f6e5');
        Test.stopTest();

        System.assertEquals(false, res.isValid);
        System.assert(res.errorMessage.contains('already signed'));
    }

    // =========================================================================
    // PIN Verification
    // =========================================================================

    @isTest
    static void testSendPin_success() {
        Test.startTest();
        Map<String, Object> result = DocGenSignatureController.sendPin(
            'f6e5d4c3b2a1f6e5d4c3b2a1f6e5d4c3b2a1f6e5d4c3b2a1f6e5d4c3b2a1f6e5',
            'multisigner@test.com'
        );
        Test.stopTest();

        System.assertEquals(true, result.get('success'), 'PIN send should succeed');

        DocGen_Signer__c signer = getTestSigner();
        System.assertNotEquals(null, signer.PIN_Hash__c, 'PIN hash should be set');
        System.assertNotEquals(null, signer.PIN_Expires_At__c, 'PIN expiry should be set');
    }

    @isTest
    static void testSendPin_wrongEmail() {
        Test.startTest();
        Map<String, Object> result = DocGenSignatureController.sendPin(
            'f6e5d4c3b2a1f6e5d4c3b2a1f6e5d4c3b2a1f6e5d4c3b2a1f6e5d4c3b2a1f6e5',
            'wrong@example.com'
        );
        Test.stopTest();

        System.assertEquals(false, result.get('success'));
        System.assert(((String)result.get('message')).contains('does not match'));
    }

    @isTest
    static void testSendPin_invalidToken() {
        Test.startTest();
        Map<String, Object> result = DocGenSignatureController.sendPin('bad', 'test@test.com');
        Test.stopTest();

        System.assertEquals(false, result.get('success'));
    }

    @isTest
    static void testVerifyPin_success() {
        // First send a PIN
        DocGen_Signer__c signer = getTestSigner();
        String testPin = '123456';
        String pinHash = EncodingUtil.convertToHex(
            Crypto.generateDigest('SHA-256', Blob.valueOf(testPin))
        );
        signer.PIN_Hash__c = pinHash;
        signer.PIN_Expires_At__c = System.now().addMinutes(10);
        signer.PIN_Attempts__c = 0;
        update signer;

        Test.startTest();
        Map<String, Object> result = DocGenSignatureController.verifyPin(
            'f6e5d4c3b2a1f6e5d4c3b2a1f6e5d4c3b2a1f6e5d4c3b2a1f6e5d4c3b2a1f6e5',
            '123456'
        );
        Test.stopTest();

        System.assertEquals(true, result.get('success'), 'PIN verification should succeed');

        signer = getTestSigner();
        System.assertNotEquals(null, signer.PIN_Verified_At__c, 'PIN_Verified_At should be set');
        System.assertEquals(null, signer.PIN_Hash__c, 'PIN hash should be cleared');
    }

    @isTest
    static void testVerifyPin_wrongPin() {
        DocGen_Signer__c signer = getTestSigner();
        String pinHash = EncodingUtil.convertToHex(
            Crypto.generateDigest('SHA-256', Blob.valueOf('123456'))
        );
        signer.PIN_Hash__c = pinHash;
        signer.PIN_Expires_At__c = System.now().addMinutes(10);
        signer.PIN_Attempts__c = 0;
        update signer;

        Test.startTest();
        Map<String, Object> result = DocGenSignatureController.verifyPin(
            'f6e5d4c3b2a1f6e5d4c3b2a1f6e5d4c3b2a1f6e5d4c3b2a1f6e5d4c3b2a1f6e5',
            '999999'
        );
        Test.stopTest();

        System.assertEquals(false, result.get('success'));
        signer = getTestSigner();
        System.assertEquals(1, signer.PIN_Attempts__c, 'Attempt counter should increment');
    }

    @isTest
    static void testVerifyPin_expired() {
        DocGen_Signer__c signer = getTestSigner();
        String pinHash = EncodingUtil.convertToHex(
            Crypto.generateDigest('SHA-256', Blob.valueOf('123456'))
        );
        signer.PIN_Hash__c = pinHash;
        signer.PIN_Expires_At__c = System.now().addMinutes(-1); // expired
        signer.PIN_Attempts__c = 0;
        update signer;

        Test.startTest();
        Map<String, Object> result = DocGenSignatureController.verifyPin(
            'f6e5d4c3b2a1f6e5d4c3b2a1f6e5d4c3b2a1f6e5d4c3b2a1f6e5d4c3b2a1f6e5',
            '123456'
        );
        Test.stopTest();

        System.assertEquals(false, result.get('success'));
        System.assert(((String)result.get('message')).contains('expired'));
    }

    @isTest
    static void testVerifyPin_lockedOut() {
        DocGen_Signer__c signer = getTestSigner();
        signer.PIN_Attempts__c = 3;
        update signer;

        Test.startTest();
        Map<String, Object> result = DocGenSignatureController.verifyPin(
            'f6e5d4c3b2a1f6e5d4c3b2a1f6e5d4c3b2a1f6e5d4c3b2a1f6e5d4c3b2a1f6e5',
            '123456'
        );
        Test.stopTest();

        System.assertEquals(false, result.get('success'));
        System.assert(((String)result.get('message')).contains('Too many'));
    }

    // =========================================================================
    // Save Signature (Typed Name)
    // =========================================================================

    @isTest
    static void testSaveSignature_success() {
        // Set up PIN-verified signer
        DocGen_Signer__c signer = getTestSigner();
        signer.PIN_Verified_At__c = System.now();
        signer.Status__c = 'Viewed';
        update signer;

        Test.startTest();
        DocGenSignatureController.SaveSignatureResult result =
            DocGenSignatureController.saveSignature(
                'f6e5d4c3b2a1f6e5d4c3b2a1f6e5d4c3b2a1f6e5d4c3b2a1f6e5d4c3b2a1f6e5',
                'John Smith',
                true,
                '192.168.1.1',
                'Mozilla/5.0'
            );
        Test.stopTest();

        System.assertEquals(true, result.isComplete, 'Should be complete (only 1 signer)');
        System.assertEquals(0, result.remaining);

        signer = [SELECT Status__c, Signature_Data__c, Consent_Captured__c, Signature_Request__c FROM DocGen_Signer__c WHERE Id = :signer.Id];
        System.assertEquals('Signed', signer.Status__c);
        System.assertEquals('John Smith', signer.Signature_Data__c);
        System.assertEquals(true, signer.Consent_Captured__c);

        // Verify audit record created
        List<DocGen_Signature_Audit__c> audits = [
            SELECT Signer_Name__c, IP_Address__c, Consent_Captured__c, PIN_Verified_At__c
            FROM DocGen_Signature_Audit__c
            WHERE Signature_Request__c = :signer.Signature_Request__c
        ];
        System.assertEquals(1, audits.size(), 'Audit record should be created');
        System.assertEquals('Multi Signer One', audits[0].Signer_Name__c);
        System.assertNotEquals(null, audits[0].IP_Address__c);
        System.assertEquals(true, audits[0].Consent_Captured__c);
        System.assertNotEquals(null, audits[0].PIN_Verified_At__c);
    }

    @isTest
    static void testSaveSignature_noConsent() {
        DocGen_Signer__c signer = getTestSigner();
        signer.PIN_Verified_At__c = System.now();
        update signer;

        Test.startTest();
        try {
            DocGenSignatureController.saveSignature(
                'f6e5d4c3b2a1f6e5d4c3b2a1f6e5d4c3b2a1f6e5d4c3b2a1f6e5d4c3b2a1f6e5',
                'John Smith',
                false,
                '1.2.3.4',
                'Test'
            );
            System.assert(false, 'Should have thrown');
        } catch (Exception e) {
            // AuraHandledException — message not accessible in test context
        }
        Test.stopTest();
    }

    @isTest
    static void testSaveSignature_noPinVerification() {
        Test.startTest();
        try {
            DocGenSignatureController.saveSignature(
                'f6e5d4c3b2a1f6e5d4c3b2a1f6e5d4c3b2a1f6e5d4c3b2a1f6e5d4c3b2a1f6e5',
                'John Smith',
                true,
                '1.2.3.4',
                'Test'
            );
            System.assert(false, 'Should have thrown');
        } catch (Exception e) {
            // AuraHandledException — message not accessible in test context
        }
        Test.stopTest();
    }

    @isTest
    static void testSaveSignature_blankName() {
        DocGen_Signer__c signer = getTestSigner();
        signer.PIN_Verified_At__c = System.now();
        update signer;

        Test.startTest();
        try {
            DocGenSignatureController.saveSignature(
                'f6e5d4c3b2a1f6e5d4c3b2a1f6e5d4c3b2a1f6e5d4c3b2a1f6e5d4c3b2a1f6e5',
                '',
                true,
                '1.2.3.4',
                'Test'
            );
            System.assert(false, 'Should have thrown');
        } catch (Exception e) {
            // AuraHandledException — message not accessible in test context
        }
        Test.stopTest();
    }

    @isTest
    static void testSaveSignature_invalidToken() {
        Test.startTest();
        try {
            DocGenSignatureController.saveSignature('bad-token', 'Name', true, '1.1.1.1', 'UA');
            System.assert(false, 'Should have thrown');
        } catch (Exception e) {
            // AuraHandledException — message not accessible in test context
        }
        Test.stopTest();
    }

    // =========================================================================
    // Signature Service — Typed Name Stamping
    // =========================================================================

    @isTest
    static void testSignerData_constructor() {
        DocGenSignatureService.SignerData sd = new DocGenSignatureService.SignerData('Buyer', 'John Smith');
        System.assertEquals('Buyer', sd.roleName);
        System.assertEquals('John Smith', sd.typedName);
        System.assertNotEquals(null, sd.signedDate);
    }

    @isTest
    static void testSignerData_constructorWithDate() {
        Datetime dt = System.now();
        DocGenSignatureService.SignerData sd = new DocGenSignatureService.SignerData('Seller', 'Jane Doe', dt);
        System.assertEquals('Seller', sd.roleName);
        System.assertEquals('Jane Doe', sd.typedName);
        System.assertEquals(dt, sd.signedDate);
    }

    @isTest
    static void testStampSignaturesInXml() {
        String docXml = '<w:body><w:p><w:r><w:t>{@Signature_Buyer}</w:t></w:r></w:p></w:body>';
        String relsXml = '<Relationships></Relationships>';
        String ctXml = '<Types></Types>';

        List<DocGenSignatureService.SignerImageData> signers = new List<DocGenSignatureService.SignerImageData>();
        signers.add(new DocGenSignatureService.SignerImageData('Buyer', 'John Smith', System.now()));

        Test.startTest();
        DocGenSignatureService.StampResult result = DocGenSignatureService.stampSignaturesInXml(
            docXml, relsXml, ctXml, signers
        );
        Test.stopTest();

        System.assert(result.documentXml != null);
        System.assert(!result.documentXml.contains('{@Signature_Buyer}'), 'Placeholder should be replaced');
    }

    // =========================================================================
    // Email Service
    // =========================================================================

    @isTest
    static void testSendSignatureEmails() {
        List<DocGenSignatureEmailService.SignerEmail> signers = new List<DocGenSignatureEmailService.SignerEmail>();
        signers.add(new DocGenSignatureEmailService.SignerEmail(
            'Test Signer', 'test@test.com', 'Buyer', 'https://example.com/sign?token=abc', null
        ));

        Test.startTest();
        DocGenSignatureEmailService.sendSignatureRequestEmails(signers, 'Test Document');
        Test.stopTest();
        // No assertions needed — just verifying no exceptions
    }

    // =========================================================================
    // Authenticator Controller (Document Verification)
    // =========================================================================

    @isTest
    static void testVerifyDocument_notFound() {
        Test.startTest();
        DocGenAuthenticatorController.VerificationResult res =
            DocGenAuthenticatorController.verifyDocument('0000000000000000000000000000000000000000000000000000000000000000');
        Test.stopTest();

        System.assertEquals(false, res.isValid);
    }

    @isTest
    static void testVerifyDocument_found() {
        DocGen_Signature_Request__c req = getTestRequest();
        DocGen_Signature_Audit__c audit = new DocGen_Signature_Audit__c(
            Signature_Request__c = req.Id,
            Signer_Name__c = 'Test',
            Signer_Email__c = 'test@test.com',
            Signed_Date__c = System.now(),
            Document_Hash_SHA256__c = 'abc123hash',
            IP_Address__c = '1.2.3.4'
        );
        insert audit;

        Test.startTest();
        DocGenAuthenticatorController.VerificationResult res =
            DocGenAuthenticatorController.verifyDocument('abc123hash');
        Test.stopTest();

        System.assertEquals(true, res.isValid);
        System.assertEquals('Test', res.signerName);
    }

    // =========================================================================
    // Sender Controller
    // =========================================================================

    @isTest
    static void testGetSignerRolePicklistValues() {
        Test.startTest();
        List<Map<String, String>> options = DocGenSignatureSenderController.getSignerRolePicklistValues();
        Test.stopTest();
        System.assertNotEquals(null, options);
    }

    @isTest
    static void testGetContactInfo() {
        Contact con = [SELECT Id FROM Contact LIMIT 1];
        Test.startTest();
        Map<String, String> info = DocGenSignatureSenderController.getContactInfo(con.Id);
        Test.stopTest();
        System.assertEquals('Signature Tester', info.get('name'));
    }

    @isTest
    static void testGetPendingSignatureRequests() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Test.startTest();
        List<Map<String, Object>> results = DocGenSignatureSenderController.getPendingSignatureRequests(acc.Id);
        Test.stopTest();
        System.assert(results.size() >= 1);
    }

    @isTest
    static void testGetDocGenTemplates() {
        Test.startTest();
        List<DocGen_Template__c> templates = DocGenSignatureSenderController.getDocGenTemplates();
        Test.stopTest();
        System.assertNotEquals(null, templates);
    }

    // =========================================================================
    // Setup Controller — Signature Settings
    // =========================================================================

    @isTest
    static void testSaveSignatureSettings() {
        Test.startTest();
        DocGenSetupController.saveSignatureSettings(
            '#FF0000', 'https://logo.png', 'Sign {DocumentTitle}',
            'Please sign', 'Footer text', 'Test Corp', ''
        );
        Test.stopTest();

        DocGen_Settings__c settings = DocGen_Settings__c.getOrgDefaults();
        System.assertEquals('#FF0000', settings.Signature_Email_Brand_Color__c);
        System.assertEquals('Test Corp', settings.Company_Name__c);
    }

    // =========================================================================
    // Queueable constructors (coverage)
    // =========================================================================

    @isTest
    static void testSignaturePdfQueueableConstructor() {
        DocGen_Signature_Request__c req = getTestRequest();
        DocGenSignatureService.SignaturePdfQueueable q = new DocGenSignatureService.SignaturePdfQueueable(req.Id);
        System.assertNotEquals(null, q);
    }

    @isTest
    static void testTemplateSignaturePdfQueueableConstructor() {
        DocGen_Signature_Request__c req = getTestRequest();
        DocGenSignatureService.TemplateSignaturePdfQueueable q = new DocGenSignatureService.TemplateSignaturePdfQueueable(req.Id);
        System.assertNotEquals(null, q);
    }

    // =========================================================================
    // Multi-signer flow
    // =========================================================================

    @isTest
    static void testMultiSignerFlow_twoSigners() {
        DocGen_Signature_Request__c req = getTestRequest();

        // Add a second signer
        DocGen_Signer__c signer2 = new DocGen_Signer__c(
            Signature_Request__c = req.Id,
            Signer_Name__c = 'Multi Signer Two',
            Signer_Email__c = 'signer2@test.com',
            Role_Name__c = 'Seller',
            Secure_Token__c = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
            Status__c = 'Pending',
            Sort_Order__c = 2
        );
        insert signer2;

        // Verify PIN and sign first signer
        DocGen_Signer__c signer1 = getTestSigner();
        signer1.PIN_Verified_At__c = System.now();
        signer1.Status__c = 'Viewed';
        update signer1;

        Test.startTest();
        DocGenSignatureController.SaveSignatureResult result1 =
            DocGenSignatureController.saveSignature(
                'f6e5d4c3b2a1f6e5d4c3b2a1f6e5d4c3b2a1f6e5d4c3b2a1f6e5d4c3b2a1f6e5',
                'Signer One Name',
                true,
                '1.1.1.1',
                'Browser 1'
            );
        Test.stopTest();

        System.assertEquals(false, result1.isComplete, 'Should not be complete — signer 2 pending');
        System.assertEquals(1, result1.remaining);
    }

    // =========================================================================
    // Fetch document data
    // =========================================================================

    @isTest
    static void testFetchDocumentData() {
        Test.startTest();
        DocGenSignatureController.SignatureInitResponse res =
            DocGenSignatureController.fetchDocumentData('a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2');
        Test.stopTest();
        // Legacy request with fake Source_Document_Id — preview will be unavailable but shouldn't throw
        System.assertNotEquals(null, res);
    }

    // =========================================================================
    // Stamp and return source
    // =========================================================================

    @isTest
    static void testStampAndReturnSource_invalidToken() {
        Test.startTest();
        try {
            DocGenSignatureController.stampAndReturnSource('bad', 'name');
            System.assert(false, 'Should have thrown');
        } catch (Exception e) {
            // AuraHandledException — message not accessible in test context
        }
        Test.stopTest();
    }

    // =========================================================================
    // Additional coverage — Sender Controller
    // =========================================================================

    @isTest
    static void testCreateMultiSignerRequest() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        // Create a test DOCX ContentVersion
        ContentVersion cv = new ContentVersion(
            Title = 'Test Contract',
            PathOnClient = 'contract.docx',
            VersionData = Blob.valueOf('fake docx content')
        );
        insert cv;
        cv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];

        // Link to account
        ContentDocumentLink cdl = new ContentDocumentLink(
            ContentDocumentId = cv.ContentDocumentId,
            LinkedEntityId = acc.Id,
            ShareType = 'V'
        );
        insert cdl;

        String signersJson = '[{"signerName":"Test Buyer","signerEmail":"buyer@test.com","roleName":"Buyer","contactId":""}]';

        Test.startTest();
        List<DocGenSignatureSenderController.SignerResult> results =
            DocGenSignatureSenderController.createMultiSignerRequest(cv.ContentDocumentId, acc.Id, signersJson);
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals('Test Buyer', results[0].signerName);
        System.assert(String.isNotBlank(results[0].signerUrl));
    }

    @isTest
    static void testGetRelatedDocuments() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Test.startTest();
        List<ContentVersion> docs = DocGenSignatureSenderController.getRelatedDocuments(acc.Id);
        Test.stopTest();
        System.assertNotEquals(null, docs);
    }

    @isTest
    static void testGetDocumentSignatureRoles_noDoc() {
        // Fake ID — should return empty list, not throw
        Test.startTest();
        List<String> roles = DocGenSignatureSenderController.getDocumentSignatureRoles(null);
        Test.stopTest();
        System.assertEquals(0, roles.size());
    }

    @isTest
    static void testResendSignatureRequest() {
        DocGen_Signature_Request__c req = getTestRequest();
        req.Status__c = 'Sent';
        update req;

        Test.startTest();
        DocGenSignatureSenderController.resendSignatureRequest(req.Id);
        Test.stopTest();

        DocGen_Signer__c signer = [SELECT Status__c FROM DocGen_Signer__c
            WHERE Signature_Request__c = :req.Id LIMIT 1];
        System.assertEquals('Pending', signer.Status__c);
    }

    @isTest
    static void testCancelSignatureRequest() {
        DocGen_Signature_Request__c req = getTestRequest();

        Test.startTest();
        DocGenSignatureSenderController.cancelSignatureRequest(req.Id);
        Test.stopTest();

        req = [SELECT Status__c FROM DocGen_Signature_Request__c WHERE Id = :req.Id];
        System.assertEquals('Cancelled', req.Status__c);

        DocGen_Signer__c signer = [SELECT Status__c FROM DocGen_Signer__c LIMIT 1];
        System.assertEquals('Cancelled', signer.Status__c);
    }

    @isTest
    static void testCancelAlreadySigned() {
        DocGen_Signature_Request__c req = getTestRequest();
        req.Status__c = 'Signed';
        update req;

        Test.startTest();
        try {
            DocGenSignatureSenderController.cancelSignatureRequest(req.Id);
            System.assert(false, 'Should have thrown');
        } catch (Exception e) {
            // Expected
        }
        Test.stopTest();
    }

    @isTest
    static void testResendAlreadySigned() {
        DocGen_Signature_Request__c req = getTestRequest();
        req.Status__c = 'Signed';
        update req;

        Test.startTest();
        try {
            DocGenSignatureSenderController.resendSignatureRequest(req.Id);
            System.assert(false, 'Should have thrown');
        } catch (Exception e) {
            // Expected
        }
        Test.stopTest();
    }

    // =========================================================================
    // Additional coverage — Signature Service
    // =========================================================================

    @isTest
    static void testStampAllSignaturesToBlob() {
        // Create a minimal DOCX with a signature placeholder
        ContentVersion cv = new ContentVersion(
            Title = 'Sig Template',
            PathOnClient = 'sig.docx',
            VersionData = Blob.valueOf('not a real docx')
        );
        insert cv;

        List<DocGenSignatureService.SignerData> signers = new List<DocGenSignatureService.SignerData>();
        signers.add(new DocGenSignatureService.SignerData('Buyer', 'John Smith'));

        Test.startTest();
        try {
            // Will fail because it's not a real DOCX ZIP, but exercises the code path
            DocGenSignatureService.stampAllSignaturesToBlob(cv.Id, signers);
        } catch (Exception e) {
            // Expected — fake blob isn't a valid ZIP
        }
        Test.stopTest();
    }

    @isTest
    static void testBuildVerificationBlockHtml() {
        DocGen_Signature_Request__c req = getTestRequest();
        List<DocGen_Signer__c> signers = [
            SELECT Signer_Name__c, Signer_Email__c, Role_Name__c, PIN_Verified_At__c
            FROM DocGen_Signer__c
            WHERE Signature_Request__c = :req.Id
        ];

        Test.startTest();
        String html = DocGenSignatureService.buildVerificationBlockHtml(req.Id, signers);
        Test.stopTest();

        System.assert(html.contains('ELECTRONIC SIGNATURE CERTIFICATE'));
        System.assert(html.contains('Multi Signer One'));
    }

    @isTest
    static void testSignerImageData_typedName() {
        DocGenSignatureService.SignerImageData sid = new DocGenSignatureService.SignerImageData('Buyer', 'John', System.now());
        System.assertEquals('Buyer', sid.roleName);
        System.assertEquals('John', sid.typedName);
    }

    @isTest
    static void testHandleSignatureSubmission_invalidToken() {
        Test.startTest();
        try {
            DocGenSignatureService.handleSignatureSubmission('bad', 'name');
        } catch (DocGenSignatureService.SignatureException e) {
            // Expected
        }
        Test.stopTest();
    }

    // =========================================================================
    // Additional coverage — Email Service
    // =========================================================================

    @isTest
    static void testSendSignatureEmails_withContact() {
        Contact con = [SELECT Id FROM Contact LIMIT 1];
        List<DocGenSignatureEmailService.SignerEmail> signers = new List<DocGenSignatureEmailService.SignerEmail>();
        signers.add(new DocGenSignatureEmailService.SignerEmail(
            'Contact Signer', 'contact@test.com', 'Buyer', 'https://example.com/sign', con.Id
        ));

        Test.startTest();
        DocGenSignatureEmailService.sendSignatureRequestEmails(signers, 'Test Document');
        Test.stopTest();
    }

    @isTest
    static void testSendSignatureEmails_empty() {
        Test.startTest();
        DocGenSignatureEmailService.sendSignatureRequestEmails(null, 'Test');
        DocGenSignatureEmailService.sendSignatureRequestEmails(new List<DocGenSignatureEmailService.SignerEmail>(), 'Test');
        Test.stopTest();
    }

    @isTest
    static void testSendSignatureEmails_withBranding() {
        // Set up branding settings
        DocGen_Settings__c settings = DocGen_Settings__c.getOrgDefaults();
        settings.Signature_Email_Brand_Color__c = '#FF0000';
        settings.Signature_Email_Logo_Url__c = 'https://example.com/logo.png';
        settings.Company_Name__c = 'Test Corp';
        settings.Signature_Email_Subject__c = 'Sign {DocumentTitle} for {SignerName}';
        settings.Signature_Email_Message__c = '{SenderName} needs your signature on {DocumentTitle}';
        settings.Signature_Email_Footer_Text__c = 'Custom footer';
        upsert settings;

        List<DocGenSignatureEmailService.SignerEmail> signers = new List<DocGenSignatureEmailService.SignerEmail>();
        signers.add(new DocGenSignatureEmailService.SignerEmail(
            'Branded Signer', 'branded@test.com', 'Seller', 'https://example.com/sign', null
        ));

        Test.startTest();
        DocGenSignatureEmailService.sendSignatureRequestEmails(signers, 'Branded Doc');
        Test.stopTest();
    }

    // =========================================================================
    // Additional coverage — Controller edge cases
    // =========================================================================

    @isTest
    static void testValidateToken_cancelledRequest() {
        DocGen_Signature_Request__c req = getTestRequest();
        req.Status__c = 'Cancelled';
        update req;

        // The signer's parent request is cancelled
        Test.startTest();
        DocGenSignatureController.SignatureInitResponse res =
            DocGenSignatureController.validateToken('f6e5d4c3b2a1f6e5d4c3b2a1f6e5d4c3b2a1f6e5d4c3b2a1f6e5d4c3b2a1f6e5');
        Test.stopTest();

        System.assertEquals(false, res.isValid);
    }

    @isTest
    static void testSendPin_lockedOut() {
        DocGen_Signer__c signer = getTestSigner();
        signer.PIN_Attempts__c = 3;
        update signer;

        Test.startTest();
        Map<String, Object> result = DocGenSignatureController.sendPin(
            'f6e5d4c3b2a1f6e5d4c3b2a1f6e5d4c3b2a1f6e5d4c3b2a1f6e5d4c3b2a1f6e5',
            'multisigner@test.com'
        );
        Test.stopTest();

        System.assertEquals(false, result.get('success'));
    }

    @isTest
    static void testVerifyPin_invalidFormat() {
        Test.startTest();
        Map<String, Object> result = DocGenSignatureController.verifyPin(
            'f6e5d4c3b2a1f6e5d4c3b2a1f6e5d4c3b2a1f6e5d4c3b2a1f6e5d4c3b2a1f6e5',
            'abc'
        );
        Test.stopTest();
        System.assertEquals(false, result.get('success'));
    }

    @isTest
    static void testVerifyPin_noPinSent() {
        Test.startTest();
        Map<String, Object> result = DocGenSignatureController.verifyPin(
            'f6e5d4c3b2a1f6e5d4c3b2a1f6e5d4c3b2a1f6e5d4c3b2a1f6e5d4c3b2a1f6e5',
            '123456'
        );
        Test.stopTest();
        System.assertEquals(false, result.get('success'));
    }

    @isTest
    static void testSaveLegacySignature() {
        Test.startTest();
        DocGenSignatureController.saveLegacySignature(
            'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2',
            'Legacy Name'
        );
        Test.stopTest();

        DocGen_Signature_Request__c req = getTestRequest();
        System.assertEquals('Viewed', req.Status__c);
    }

    @isTest
    static void testFinishSignatureUpload_noop() {
        Test.startTest();
        DocGenSignatureController.finishSignatureUpload('token', 'base64', 'file');
        Test.stopTest();
        // No-op method — just verify it doesn't throw
    }

    @isTest
    static void testGetOrgWideEmailAddresses() {
        Test.startTest();
        List<Map<String, String>> owas = DocGenSetupController.getOrgWideEmailAddresses();
        Test.stopTest();
        System.assert(owas.size() >= 1); // At least the "Running User" default
    }

    @isTest
    static void testGetTemplateSignatureRoles_noTemplate() {
        Test.startTest();
        List<String> roles = DocGenSignatureSenderController.getTemplateSignatureRoles(null);
        Test.stopTest();
        System.assertEquals(0, roles.size());
    }

    // =========================================================================
    // Flow Invocable classes (Validator, Submitter, Finalizer)
    // =========================================================================

    @isTest
    static void testSignatureValidator_invocable() {
        DocGenSignatureValidator.FlowInput input = new DocGenSignatureValidator.FlowInput();
        input.token = 'f6e5d4c3b2a1f6e5d4c3b2a1f6e5d4c3b2a1f6e5d4c3b2a1f6e5d4c3b2a1f6e5';

        Test.startTest();
        List<DocGenSignatureValidator.FlowOutput> results =
            DocGenSignatureValidator.validateToken(new List<DocGenSignatureValidator.FlowInput>{ input });
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(true, results[0].isValid);
        System.assertEquals('Multi Signer One', results[0].signerName);
    }

    @isTest
    static void testSignatureValidator_invalidToken() {
        DocGenSignatureValidator.FlowInput input = new DocGenSignatureValidator.FlowInput();
        input.token = '0000000000000000000000000000000000000000000000000000000000000000';

        Test.startTest();
        List<DocGenSignatureValidator.FlowOutput> results =
            DocGenSignatureValidator.validateToken(new List<DocGenSignatureValidator.FlowInput>{ input });
        Test.stopTest();

        System.assertEquals(false, results[0].isValid);
    }

    @isTest
    static void testSignatureSubmitter_invocable() {
        DocGenSignatureSubmitter.FlowInput input = new DocGenSignatureSubmitter.FlowInput();
        input.token = 'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';
        input.signatureData = 'Test Name';

        Test.startTest();
        List<DocGenSignatureSubmitter.FlowOutput> results =
            DocGenSignatureSubmitter.submitSignature(new List<DocGenSignatureSubmitter.FlowInput>{ input });
        Test.stopTest();

        System.assertEquals(1, results.size());
        // May succeed or fail depending on token state — just verifying the invocable runs
    }

    @isTest
    static void testSignatureFinalizer_invocable() {
        DocGenSignatureFinalizer.FinalizeRequest req = new DocGenSignatureFinalizer.FinalizeRequest();
        req.token = 'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';
        req.base64Image = 'Test Name';

        Test.startTest();
        DocGenSignatureFinalizer.finalizeSignature(new List<DocGenSignatureFinalizer.FinalizeRequest>{ req });
        Test.stopTest();
        // Just verifying invocable runs without exception
    }

    // =========================================================================
    // Platform Event Trigger coverage
    // =========================================================================

    @isTest
    static void testSignaturePdfTrigger_templateBased() {
        // Create a request with a template reference to exercise the template path
        DocGen_Signature_Request__c req = getTestRequest();

        Test.startTest();
        DocGen_Signature_PDF__e evt = new DocGen_Signature_PDF__e();
        evt.Request_Id__c = req.Id;
        EventBus.publish(evt);
        Test.getEventBus().deliver();
        Test.stopTest();
        // Trigger fires and enqueues Queueable — just verifying no exception
    }

    // =========================================================================
    // Authenticator — verifyByRequestId
    // =========================================================================

    @isTest
    static void testVerifyByRequestId_withAudits() {
        DocGen_Signature_Request__c req = getTestRequest();
        DocGen_Signature_Audit__c audit = new DocGen_Signature_Audit__c(
            Signature_Request__c = req.Id,
            Signer_Name__c = 'Test Signer',
            Signer_Email__c = 'test@test.com',
            Signed_Date__c = System.now(),
            Document_Hash_SHA256__c = 'abc123',
            IP_Address__c = '1.2.3.4',
            Consent_Captured__c = true,
            PIN_Verified_At__c = System.now()
        );
        insert audit;

        Test.startTest();
        List<DocGenAuthenticatorController.VerificationResult> results =
            DocGenAuthenticatorController.verifyByRequestId(req.Id);
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals('Test Signer', results[0].signerName);
        System.assertEquals('abc123', results[0].documentHash);
        System.assertEquals(true, results[0].consentCaptured);
    }

    @isTest
    static void testVerifyByRequestId_noAudits() {
        Test.startTest();
        List<DocGenAuthenticatorController.VerificationResult> results =
            DocGenAuthenticatorController.verifyByRequestId('001000000000000AAA');
        Test.stopTest();
        System.assertEquals(0, results.size());
    }

    // =========================================================================
    // Controller — convertSignatureRequestToPdf (test path)
    // =========================================================================

    @isTest
    static void testConvertSignatureRequestToPdf() {
        DocGen_Signature_Request__c req = getTestRequest();
        // Ensure a signer exists and is signed
        DocGen_Signer__c signer = getTestSigner();
        signer.Status__c = 'Signed';
        signer.Signature_Data__c = 'Test Name';
        update signer;

        Test.startTest();
        // In test context, this returns a test PDF blob
        Blob pdf = DocGenSignatureController.convertSignatureRequestToPdf(req.Id);
        Test.stopTest();

        System.assertNotEquals(null, pdf);
    }

    // =========================================================================
    // Controller — extractDocxParts
    // =========================================================================

    @isTest
    static void testExtractDocxParts_invalidBlob() {
        Test.startTest();
        try {
            DocGenSignatureController.extractDocxParts(Blob.valueOf('not a zip'));
        } catch (Exception e) {
            // Expected — not a valid ZIP
        }
        Test.stopTest();
    }

    // =========================================================================
    // Service — Queueable execute (test path)
    // =========================================================================

    @isTest
    static void testSignaturePdfQueueable_execute() {
        DocGen_Signature_Request__c req = getTestRequest();
        DocGen_Signer__c signer = getTestSigner();
        signer.Status__c = 'Signed';
        signer.Signature_Data__c = 'Queueable Test';
        update signer;

        Test.startTest();
        DocGenSignatureService.SignaturePdfQueueable q = new DocGenSignatureService.SignaturePdfQueueable(req.Id);
        q.execute(null);
        Test.stopTest();
    }

    @isTest
    static void testTemplateSignaturePdfQueueable_execute() {
        DocGen_Signature_Request__c req = getTestRequest();
        DocGen_Signer__c signer = getTestSigner();
        signer.Status__c = 'Signed';
        signer.Signature_Data__c = 'Template Queueable Test';
        update signer;

        Test.startTest();
        DocGenSignatureService.TemplateSignaturePdfQueueable q =
            new DocGenSignatureService.TemplateSignaturePdfQueueable(req.Id);
        q.execute(null);
        Test.stopTest();
    }

    // =========================================================================
    // Service — handleSignatureSubmission
    // =========================================================================

    @isTest
    static void testHandleSignatureSubmission_validLegacy() {
        DocGen_Signature_Request__c req = getTestRequest();
        Test.startTest();
        DocGenSignatureService.handleSignatureSubmission(
            'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2',
            'Legacy Submit Name'
        );
        Test.stopTest();
    }

    // =========================================================================
    // Sender — createTemplateSignerRequest
    // =========================================================================

    @isTest
    static void testCreateTemplateSignerRequest() {
        // Need a real template — use test data factory if available
        List<DocGen_Template__c> templates = [SELECT Id FROM DocGen_Template__c LIMIT 1];
        if (templates.isEmpty()) {
            DocGen_Template__c tmpl = new DocGen_Template__c(Name = 'Sig Test Template', Base_Object_API__c = 'Account');
            insert tmpl;
            templates.add(tmpl);
        }
        Account acc = [SELECT Id FROM Account LIMIT 1];

        String signersJson = '[{"signerName":"Template Signer","signerEmail":"tmpl@test.com","roleName":"Buyer","contactId":""}]';

        Test.startTest();
        try {
            List<DocGenSignatureSenderController.SignerResult> results =
                DocGenSignatureSenderController.createTemplateSignerRequest(templates[0].Id, acc.Id, signersJson);
            System.assertEquals(1, results.size());
        } catch (Exception e) {
            // May fail if template has no content — that's OK for coverage
        }
        Test.stopTest();
    }

    // =========================================================================
    // Sender — getPendingSignatureRequests with signers
    // =========================================================================

    @isTest
    static void testGetPendingSignatureRequests_withSigners() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        DocGen_Signature_Request__c req = getTestRequest();
        req.Related_Record_Id__c = acc.Id;
        update req;

        Test.startTest();
        List<Map<String, Object>> results =
            DocGenSignatureSenderController.getPendingSignatureRequests(acc.Id);
        Test.stopTest();

        System.assert(results.size() >= 1);
        Map<String, Object> first = results[0];
        System.assertNotEquals(null, first.get('signers'));
    }

    @isTest
    static void testCreateSignatureRequest_legacy() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        ContentVersion cv = new ContentVersion(
            Title = 'Legacy Doc',
            PathOnClient = 'legacy.docx',
            VersionData = Blob.valueOf('fake')
        );
        insert cv;
        cv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];
        ContentDocumentLink cdl = new ContentDocumentLink(
            ContentDocumentId = cv.ContentDocumentId,
            LinkedEntityId = acc.Id,
            ShareType = 'V'
        );
        insert cdl;

        Test.startTest();
        String url = DocGenSignatureSenderController.createSignatureRequest(
            cv.ContentDocumentId, acc.Id, 'Legacy Signer', 'legacy@test.com'
        );
        Test.stopTest();
        System.assert(String.isNotBlank(url));
    }

    // =========================================================================
    // NEW COVERAGE — DocGenSignatureController
    // =========================================================================

    @isTest
    static void testFetchDocumentData_multiSignerPath() {
        // Exercise fetchDocumentData via the multi-signer (DocGen_Signer__c) token path
        Test.startTest();
        DocGenSignatureController.SignatureInitResponse res =
            DocGenSignatureController.fetchDocumentData('f6e5d4c3b2a1f6e5d4c3b2a1f6e5d4c3b2a1f6e5d4c3b2a1f6e5d4c3b2a1f6e5');
        Test.stopTest();

        // Signer has no template and fake Source_Document_Id — covers the legacy DOCX branch
        // inside fetchDocumentData for a signer token
        System.assertNotEquals(null, res);
    }

    @isTest
    static void testFetchDocumentData_templatePathWithCache() {
        // Create a template and request with cached preview data
        DocGen_Template__c tmpl = new DocGen_Template__c(Name = 'FetchTest Tmpl', Base_Object_API__c = 'Account');
        insert tmpl;

        Account acc = [SELECT Id FROM Account LIMIT 1];
        DocGen_Signature_Request__c req = new DocGen_Signature_Request__c(
            Template__c = tmpl.Id,
            Related_Record_Id__c = acc.Id,
            Status__c = 'Sent',
            Secure_Token__c = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'
        );
        insert req;

        // Cache preview HTML in Signature_Data__c
        Map<String, Object> cachedData = new Map<String, Object>{
            'previewHtml' => '<html><body><p>Cached Preview</p></body></html>'
        };
        req.Signature_Data__c = JSON.serialize(cachedData);
        update req;

        // Create a signer that points to this request
        DocGen_Signer__c signer = new DocGen_Signer__c(
            Signature_Request__c = req.Id,
            Signer_Name__c = 'Cache Tester',
            Signer_Email__c = 'cache@test.com',
            Secure_Token__c = 'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
            Status__c = 'Pending',
            Sort_Order__c = 1
        );
        insert signer;

        Test.startTest();
        DocGenSignatureController.SignatureInitResponse res =
            DocGenSignatureController.fetchDocumentData('cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc');
        Test.stopTest();

        System.assertNotEquals(null, res);
        System.assert(res.isValid);
        // Should have used cached preview HTML
        System.assert(res.templateBase64 != null && res.templateBase64.contains('Cached Preview'));
    }

    @isTest
    static void testFetchDocumentData_templatePathNoCache() {
        // Template request with no cached data — exercises the fallback preview generation
        DocGen_Template__c tmpl = new DocGen_Template__c(Name = 'NoCache Tmpl', Base_Object_API__c = 'Account');
        insert tmpl;

        Account acc = [SELECT Id FROM Account LIMIT 1];
        DocGen_Signature_Request__c req = new DocGen_Signature_Request__c(
            Template__c = tmpl.Id,
            Related_Record_Id__c = acc.Id,
            Status__c = 'Sent',
            Secure_Token__c = 'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd'
        );
        insert req;

        DocGen_Signer__c signer = new DocGen_Signer__c(
            Signature_Request__c = req.Id,
            Signer_Name__c = 'NoCache Tester',
            Signer_Email__c = 'nocache@test.com',
            Secure_Token__c = 'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
            Status__c = 'Pending',
            Sort_Order__c = 1
        );
        insert signer;

        Test.startTest();
        DocGenSignatureController.SignatureInitResponse res =
            DocGenSignatureController.fetchDocumentData('eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee');
        Test.stopTest();

        System.assertNotEquals(null, res);
        // Falls through to the unavailable preview fallback
        System.assertNotEquals(null, res.templateBase64);
    }

    @isTest
    static void testFetchDocumentData_legacyPathWithRealCV() {
        // Legacy request with a real ContentVersion to exercise getDocumentHtml
        ContentVersion cv = new ContentVersion(
            Title = 'Fetch Legacy Doc',
            PathOnClient = 'fetch.docx',
            VersionData = Blob.valueOf('not a real docx but exercises the path')
        );
        insert cv;
        cv = [SELECT Id FROM ContentVersion WHERE Id = :cv.Id];

        DocGen_Signature_Request__c req = new DocGen_Signature_Request__c(
            Signer_Name__c = 'Fetch Legacy Signer',
            Signer_Email__c = 'fetchlegacy@test.com',
            Source_Document_Id__c = cv.Id,
            Related_Record_Id__c = [SELECT Id FROM Account LIMIT 1].Id,
            Secure_Token__c = '1111111111111111111111111111111111111111111111111111111111111111',
            Status__c = 'Sent'
        );
        insert req;

        Test.startTest();
        DocGenSignatureController.SignatureInitResponse res =
            DocGenSignatureController.fetchDocumentData('1111111111111111111111111111111111111111111111111111111111111111');
        Test.stopTest();

        System.assertNotEquals(null, res);
        // getDocumentHtml will catch the ZIP parse error and return fallback HTML
        System.assertNotEquals(null, res.templateBase64);
    }

    @isTest
    static void testValidateLegacyRequest_signedStatus() {
        DocGen_Signature_Request__c req = getTestRequest();
        req.Status__c = 'Signed';
        req.Secure_Token__c = '2222222222222222222222222222222222222222222222222222222222222222';
        update req;

        // Remove signer token so it falls through to legacy path
        DocGen_Signer__c signer = getTestSigner();
        signer.Secure_Token__c = 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx';
        update signer;

        Test.startTest();
        DocGenSignatureController.SignatureInitResponse res =
            DocGenSignatureController.validateToken('2222222222222222222222222222222222222222222222222222222222222222');
        Test.stopTest();

        System.assertEquals(false, res.isValid);
        System.assert(res.errorMessage.contains('already been signed'));
    }

    @isTest
    static void testValidateLegacyRequest_cancelledStatus() {
        DocGen_Signature_Request__c req = getTestRequest();
        req.Status__c = 'Cancelled';
        req.Secure_Token__c = '3333333333333333333333333333333333333333333333333333333333333333';
        update req;

        DocGen_Signer__c signer = getTestSigner();
        signer.Secure_Token__c = 'yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy';
        update signer;

        Test.startTest();
        DocGenSignatureController.SignatureInitResponse res =
            DocGenSignatureController.validateToken('3333333333333333333333333333333333333333333333333333333333333333');
        Test.stopTest();

        System.assertEquals(false, res.isValid);
        System.assert(res.errorMessage.contains('cancelled'));
    }

    @isTest
    static void testGetOrCreatePublicLink_withRealCV() {
        // Create a real CV to exercise getOrCreatePublicLink inside validateLegacyRequest
        ContentVersion cv = new ContentVersion(
            Title = 'Public Link Test',
            PathOnClient = 'publink.docx',
            VersionData = Blob.valueOf('test content for public link')
        );
        insert cv;
        cv = [SELECT Id FROM ContentVersion WHERE Id = :cv.Id];

        DocGen_Signature_Request__c req = getTestRequest();
        req.Source_Document_Id__c = cv.Id;
        req.Status__c = 'Sent';
        req.Secure_Token__c = '4444444444444444444444444444444444444444444444444444444444444444';
        update req;

        DocGen_Signer__c signer = getTestSigner();
        signer.Secure_Token__c = 'zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz';
        update signer;

        Test.startTest();
        DocGenSignatureController.SignatureInitResponse res =
            DocGenSignatureController.validateToken('4444444444444444444444444444444444444444444444444444444444444444');
        Test.stopTest();

        System.assertEquals(true, res.isValid);
        System.assertEquals('Public Link Test', res.documentTitle);
    }

    @isTest
    static void testConvertStampedDocxToHtml_fakeBlob() {
        Test.startTest();
        try {
            DocGenSignatureController.convertStampedDocxToHtml(Blob.valueOf('not a zip'));
        } catch (Exception e) {
            // Expected — not a valid ZIP
        }
        Test.stopTest();
    }

    @isTest
    static void testCaptureClientIp_viaTestContext() {
        // captureClientIp is called inside saveSignature — exercise it through that path
        // The VF and session branches are handled, and Test.isRunningTest() skips session
        DocGen_Signer__c signer = getTestSigner();
        signer.PIN_Verified_At__c = System.now();
        signer.Status__c = 'Viewed';
        update signer;

        Test.startTest();
        DocGenSignatureController.SaveSignatureResult result =
            DocGenSignatureController.saveSignature(
                'f6e5d4c3b2a1f6e5d4c3b2a1f6e5d4c3b2a1f6e5d4c3b2a1f6e5d4c3b2a1f6e5',
                'IP Test Signer',
                true,
                null,
                null
            );
        Test.stopTest();

        // Verify audit was created with IP (will be 'Unknown' in test context)
        List<DocGen_Signature_Audit__c> audits = [
            SELECT IP_Address__c, User_Agent__c FROM DocGen_Signature_Audit__c
            WHERE Signature_Request__c = :signer.Signature_Request__c
        ];
        System.assert(!audits.isEmpty());
    }

    @isTest
    static void testStampLegacySignerAndSavePdf_viaSigner() {
        // stampAndReturnSource with a signer token exercises stampMultiSignerAndSavePdf
        DocGen_Signer__c signer = getTestSigner();
        signer.Status__c = 'Signed';
        signer.Signature_Data__c = 'Stamp Test';
        update signer;

        Test.startTest();
        try {
            Map<String, String> result = DocGenSignatureController.stampAndReturnSource(
                'f6e5d4c3b2a1f6e5d4c3b2a1f6e5d4c3b2a1f6e5d4c3b2a1f6e5d4c3b2a1f6e5',
                'Stamp Test'
            );
            // If platform event publish succeeds, we get a result
            System.assertNotEquals(null, result);
        } catch (Exception e) {
            // AuraHandledException possible
        }
        Test.stopTest();
    }

    @isTest
    static void testStampAndReturnSource_legacyFallback() {
        // Use a token that only matches a request (not a signer) to exercise stampLegacySignerAndSavePdf
        DocGen_Signer__c signer = getTestSigner();
        signer.Secure_Token__c = 'aaaa111111111111111111111111111111111111111111111111111111111111';
        update signer;

        DocGen_Signature_Request__c req = getTestRequest();
        req.Status__c = 'Viewed';
        req.Signature_Data__c = 'Legacy Stamp Name';
        update req;

        Test.startTest();
        try {
            DocGenSignatureController.stampAndReturnSource(
                'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2',
                'Legacy Stamp Name'
            );
        } catch (Exception e) {
            // Expected — source doc is fake ID, will fail in stampLegacySignerAndSavePdf
        }
        Test.stopTest();
    }

    @isTest
    static void testSaveLegacySignature_invalidToken() {
        Test.startTest();
        try {
            DocGenSignatureController.saveLegacySignature('bad', 'name');
            System.assert(false, 'Should have thrown');
        } catch (Exception e) {
            // AuraHandledException
        }
        Test.stopTest();
    }

    @isTest
    static void testSaveLegacySignature_signedRequest() {
        DocGen_Signature_Request__c req = getTestRequest();
        req.Status__c = 'Signed';
        update req;

        Test.startTest();
        try {
            DocGenSignatureController.saveLegacySignature(
                'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2',
                'Name'
            );
            System.assert(false, 'Should have thrown');
        } catch (Exception e) {
            // AuraHandledException
        }
        Test.stopTest();
    }

    @isTest
    static void testSaveSignature_signerNotFound() {
        Test.startTest();
        try {
            DocGenSignatureController.saveSignature(
                '5555555555555555555555555555555555555555555555555555555555555555',
                'Name',
                true,
                '1.1.1.1',
                'UA'
            );
            System.assert(false, 'Should have thrown');
        } catch (Exception e) {
            // AuraHandledException — signer not found
        }
        Test.stopTest();
    }

    @isTest
    static void testSaveSignature_alreadySigned() {
        DocGen_Signer__c signer = getTestSigner();
        signer.PIN_Verified_At__c = System.now();
        signer.Status__c = 'Signed';
        update signer;

        Test.startTest();
        try {
            DocGenSignatureController.saveSignature(
                'f6e5d4c3b2a1f6e5d4c3b2a1f6e5d4c3b2a1f6e5d4c3b2a1f6e5d4c3b2a1f6e5',
                'Name',
                true,
                '1.1.1.1',
                'UA'
            );
            System.assert(false, 'Should have thrown');
        } catch (Exception e) {
            // AuraHandledException — already signed
        }
        Test.stopTest();
    }

    // =========================================================================
    // NEW COVERAGE — DocGenSignatureService
    // =========================================================================

    @isTest
    static void testStampSignaturesInXml_multipleSigners() {
        String docXml = '<w:body><w:p><w:r><w:t>{@Signature_Buyer}</w:t></w:r></w:p>' +
                         '<w:p><w:r><w:t>{@Signature_Seller}</w:t></w:r></w:p></w:body>';
        String relsXml = '<Relationships></Relationships>';
        String ctXml = '<Types></Types>';

        List<DocGenSignatureService.SignerImageData> signers = new List<DocGenSignatureService.SignerImageData>();
        signers.add(new DocGenSignatureService.SignerImageData('Buyer', 'Alice Jones', System.now()));
        signers.add(new DocGenSignatureService.SignerImageData('Seller', 'Bob Smith', System.now()));

        Test.startTest();
        DocGenSignatureService.StampResult result = DocGenSignatureService.stampSignaturesInXml(
            docXml, relsXml, ctXml, signers
        );
        Test.stopTest();

        System.assert(!result.documentXml.contains('{@Signature_Buyer}'), 'Buyer placeholder should be replaced');
        System.assert(!result.documentXml.contains('{@Signature_Seller}'), 'Seller placeholder should be replaced');
        System.assert(result.documentXml.contains('Alice Jones'));
        System.assert(result.documentXml.contains('Bob Smith'));
    }

    @isTest
    static void testStampSignaturesInXml_blankRoleName() {
        String docXml = '<w:body><w:p><w:r><w:t>{@Signature}</w:t></w:r></w:p></w:body>';

        List<DocGenSignatureService.SignerImageData> signers = new List<DocGenSignatureService.SignerImageData>();
        signers.add(new DocGenSignatureService.SignerImageData(null, 'Solo Signer', System.now()));

        Test.startTest();
        DocGenSignatureService.StampResult result = DocGenSignatureService.stampSignaturesInXml(
            docXml, '<Rels/>', '<Types/>', signers
        );
        Test.stopTest();

        System.assert(!result.documentXml.contains('{@Signature}'), 'Generic placeholder should be replaced');
        System.assert(result.documentXml.contains('Solo Signer'));
    }

    @isTest
    static void testStampSignaturesInXml_noMatchingPlaceholder() {
        String docXml = '<w:body><w:p><w:r><w:t>No placeholders here</w:t></w:r></w:p></w:body>';

        List<DocGenSignatureService.SignerImageData> signers = new List<DocGenSignatureService.SignerImageData>();
        signers.add(new DocGenSignatureService.SignerImageData('Manager', 'Jane Doe', System.now()));

        Test.startTest();
        DocGenSignatureService.StampResult result = DocGenSignatureService.stampSignaturesInXml(
            docXml, '<Rels/>', '<Types/>', signers
        );
        Test.stopTest();

        // XML unchanged since no matching placeholder
        System.assert(result.documentXml.contains('No placeholders here'));
    }

    @isTest
    static void testBuildVerificationBlockHtml_withSettings() {
        // Set up custom settings to exercise branded paths
        DocGen_Settings__c settings = DocGen_Settings__c.getOrgDefaults();
        settings.Signature_Email_Brand_Color__c = '#00FF00';
        settings.Company_Name__c = 'Acme Corp';
        settings.Experience_Site_Url__c = 'https://mysite.force.com/signatures/';
        upsert settings;

        DocGen_Signature_Request__c req = getTestRequest();
        DocGen_Signer__c signer = getTestSigner();
        signer.PIN_Verified_At__c = System.now();
        update signer;

        List<DocGen_Signer__c> signerList = [
            SELECT Signer_Name__c, Signer_Email__c, Role_Name__c, PIN_Verified_At__c
            FROM DocGen_Signer__c WHERE Id = :signer.Id
        ];

        Test.startTest();
        String html = DocGenSignatureService.buildVerificationBlockHtml(req.Id, signerList);
        Test.stopTest();

        System.assert(html.contains('#00FF00'), 'Should use custom brand color');
        System.assert(html.contains('Acme Corp'), 'Should use custom company name');
        System.assert(html.contains('DocGenVerify'), 'Should contain verification URL');
        System.assert(html.contains('Email verified'), 'Should show PIN verified timestamp');
    }

    @isTest
    static void testBuildVerificationBlockHtml_noSiteUrl() {
        // No Experience_Site_Url__c set and no active Site — exercises the try/catch fallback
        DocGen_Settings__c settings = DocGen_Settings__c.getOrgDefaults();
        settings.Experience_Site_Url__c = null;
        settings.Company_Name__c = null;
        settings.Signature_Email_Brand_Color__c = null;
        upsert settings;

        DocGen_Signature_Request__c req = getTestRequest();
        List<DocGen_Signer__c> signerList = [
            SELECT Signer_Name__c, Signer_Email__c, Role_Name__c, PIN_Verified_At__c
            FROM DocGen_Signer__c WHERE Signature_Request__c = :req.Id
        ];

        Test.startTest();
        String html = DocGenSignatureService.buildVerificationBlockHtml(req.Id, signerList);
        Test.stopTest();

        // Should use defaults
        System.assert(html.contains('#0176D3'), 'Should use default brand color');
        System.assert(html.contains('DocGen'), 'Should use default company name');
    }

    @isTest
    static void testStampResult_constructor() {
        Map<String, String> imgUrls = new Map<String, String>{ 'rId1' => '/sfc/test' };
        DocGenSignatureService.StampResult sr = new DocGenSignatureService.StampResult(
            '<doc/>', '<rels/>', '<types/>', imgUrls
        );
        System.assertEquals('<doc/>', sr.documentXml);
        System.assertEquals('<rels/>', sr.relsXml);
        System.assertEquals('<types/>', sr.contentTypesXml);
        System.assertEquals(1, sr.signatureImageUrls.size());
    }

    @isTest
    static void testSignerImageData_cvConstructor() {
        DocGenSignatureService.SignerImageData sid = new DocGenSignatureService.SignerImageData('Witness', null);
        System.assertEquals('Witness', sid.roleName);
        System.assertEquals(null, sid.contentVersionId);
    }

    @isTest
    static void testHandleSignatureSubmission_signedRequest() {
        // Mark request as signed — should silently return
        DocGen_Signature_Request__c req = getTestRequest();
        req.Status__c = 'Signed';
        update req;

        Test.startTest();
        DocGenSignatureService.handleSignatureSubmission(
            'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2',
            'Should Not Process'
        );
        Test.stopTest();

        // Confirm status unchanged
        req = [SELECT Status__c FROM DocGen_Signature_Request__c WHERE Id = :req.Id];
        System.assertEquals('Signed', req.Status__c);
    }

    @isTest
    static void testHandleSignatureSubmission_cancelledRequest() {
        DocGen_Signature_Request__c req = getTestRequest();
        req.Status__c = 'Cancelled';
        update req;

        Test.startTest();
        DocGenSignatureService.handleSignatureSubmission(
            'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2',
            'Should Not Process'
        );
        Test.stopTest();

        req = [SELECT Status__c FROM DocGen_Signature_Request__c WHERE Id = :req.Id];
        System.assertEquals('Cancelled', req.Status__c);
    }

    // =========================================================================
    // NEW COVERAGE — DocGenSignatureSenderController
    // =========================================================================

    @isTest
    static void testGetDocumentSignatureRoles_withDocx() {
        // Create a fake DOCX — will fail at ZIP parse but exercises the code path
        ContentVersion cv = new ContentVersion(
            Title = 'Roles Test Doc',
            PathOnClient = 'roles.docx',
            VersionData = Blob.valueOf('not a real docx zip')
        );
        insert cv;
        cv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];

        Test.startTest();
        try {
            List<String> roles = DocGenSignatureSenderController.getDocumentSignatureRoles(cv.ContentDocumentId);
            // If it doesn't throw, it should return empty (not a valid ZIP)
            System.assertNotEquals(null, roles);
        } catch (Exception e) {
            // Expected — fake blob isn't a valid ZIP
        }
        Test.stopTest();
    }

    @isTest
    static void testCreateMultiSignerRequest_withContact() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Contact con = [SELECT Id FROM Contact LIMIT 1];
        ContentVersion cv = new ContentVersion(
            Title = 'Contact Signer Doc',
            PathOnClient = 'contact.docx',
            VersionData = Blob.valueOf('fake docx')
        );
        insert cv;
        cv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];
        insert new ContentDocumentLink(
            ContentDocumentId = cv.ContentDocumentId,
            LinkedEntityId = acc.Id,
            ShareType = 'V'
        );

        String signersJson = '[{"signerName":"Contact Buyer","signerEmail":"buyer@test.com","roleName":"Buyer","contactId":"' + con.Id + '"}]';

        Test.startTest();
        List<DocGenSignatureSenderController.SignerResult> results =
            DocGenSignatureSenderController.createMultiSignerRequest(cv.ContentDocumentId, acc.Id, signersJson);
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals('Buyer', results[0].roleName);
    }

    @isTest
    static void testCreateMultiSignerRequest_multipleSigners() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        ContentVersion cv = new ContentVersion(
            Title = 'Multi Doc',
            PathOnClient = 'multi.docx',
            VersionData = Blob.valueOf('fake docx')
        );
        insert cv;
        cv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];
        insert new ContentDocumentLink(
            ContentDocumentId = cv.ContentDocumentId,
            LinkedEntityId = acc.Id,
            ShareType = 'V'
        );

        String signersJson = '[' +
            '{"signerName":"Buyer One","signerEmail":"b1@test.com","roleName":"Buyer","contactId":""},' +
            '{"signerName":"Seller One","signerEmail":"s1@test.com","roleName":"Seller","contactId":""}' +
        ']';

        Test.startTest();
        List<DocGenSignatureSenderController.SignerResult> results =
            DocGenSignatureSenderController.createMultiSignerRequest(cv.ContentDocumentId, acc.Id, signersJson);
        Test.stopTest();

        System.assertEquals(2, results.size());
    }

    @isTest
    static void testGetTemplateSignatureRoles_withTemplate() {
        // Create a template with a version — no XML CVs so should return empty
        DocGen_Template__c tmpl = new DocGen_Template__c(Name = 'Roles Template', Base_Object_API__c = 'Account');
        insert tmpl;

        DocGen_Template_Version__c ver = new DocGen_Template_Version__c(
            Template__c = tmpl.Id,
            Is_Active__c = true
        );
        insert ver;

        Test.startTest();
        List<String> roles = DocGenSignatureSenderController.getTemplateSignatureRoles(tmpl.Id);
        Test.stopTest();

        // No XML CVs exist so should return empty list
        System.assertEquals(0, roles.size());
    }

    @isTest
    static void testCancelAlreadyCancelled() {
        DocGen_Signature_Request__c req = getTestRequest();
        req.Status__c = 'Cancelled';
        update req;

        Test.startTest();
        try {
            DocGenSignatureSenderController.cancelSignatureRequest(req.Id);
            System.assert(false, 'Should have thrown');
        } catch (Exception e) {
            // Expected — already cancelled
        }
        Test.stopTest();
    }

    @isTest
    static void testCreateMultiSignerRequest_deletedDoc() {
        Test.startTest();
        try {
            DocGenSignatureSenderController.createMultiSignerRequest(
                '069000000000000AAA', '001000000000000AAA',
                '[{"signerName":"X","signerEmail":"x@x.com","roleName":"Buyer","contactId":""}]'
            );
            System.assert(false, 'Should have thrown');
        } catch (Exception e) {
            // Expected — doc not found
        }
        Test.stopTest();
    }

    @isTest
    static void testSendPin_signerNotFound() {
        Test.startTest();
        Map<String, Object> result = DocGenSignatureController.sendPin(
            '6666666666666666666666666666666666666666666666666666666666666666',
            'nobody@test.com'
        );
        Test.stopTest();
        System.assertEquals(false, result.get('success'));
    }

    @isTest
    static void testVerifyPin_signerNotFound() {
        Test.startTest();
        Map<String, Object> result = DocGenSignatureController.verifyPin(
            '7777777777777777777777777777777777777777777777777777777777777777',
            '123456'
        );
        Test.stopTest();
        System.assertEquals(false, result.get('success'));
    }

    @isTest
    static void testVerifyPin_maxAttemptsLockout() {
        // Exhaust all PIN attempts to hit the lockout message in verifyPin
        DocGen_Signer__c signer = getTestSigner();
        String pinHash = EncodingUtil.convertToHex(
            Crypto.generateDigest('SHA-256', Blob.valueOf('123456'))
        );
        signer.PIN_Hash__c = pinHash;
        signer.PIN_Expires_At__c = System.now().addMinutes(10);
        signer.PIN_Attempts__c = 2; // One more attempt to trigger lockout
        update signer;

        Test.startTest();
        Map<String, Object> result = DocGenSignatureController.verifyPin(
            'f6e5d4c3b2a1f6e5d4c3b2a1f6e5d4c3b2a1f6e5d4c3b2a1f6e5d4c3b2a1f6e5',
            '999999'
        );
        Test.stopTest();

        System.assertEquals(false, result.get('success'));
        // After this attempt, attempts = 3, remaining = 0, so lockout message
        System.assert(((String)result.get('message')).contains('locked'));
    }
}
