public with sharing class DocGenSetupController {
    /**
     * Returns the org's domain URL for configuration display.
     * @return The external form of the org domain URL
     */
    @AuraEnabled(cacheable=true)
    public static String getOrgUrl() {
        // Return the core my.salesforce.com URL, not the Lightning domain
        return Url.getOrgDomainUrl().toExternalForm();
    }

    /**
     * Returns the org-level DocGen settings custom setting.
     * @return The DocGen_Settings__c org defaults record
     */
    @AuraEnabled(cacheable=true)
    public static DocGen_Settings__c getSettings() {
        return DocGen_Settings__c.getOrgDefaults();
    }

    /**
     * Saves the Experience Site URL to DocGen settings.
     * @param experienceSiteUrl The Experience Site base URL to store
     */
    @AuraEnabled
    public static void saveSettings(String experienceSiteUrl) {
        // Only allow users with Customize Application or DocGen_Admin permission set
        if (!FeatureManagement.checkPermission('DocGen_Admin_Access') &&
            !Schema.sObjectType.DocGen_Settings__c.isUpdateable()) {
            throw DocGenService.ahe('Insufficient privileges to modify DocGen settings.');
        }
        DocGen_Settings__c settings = DocGen_Settings__c.getOrgDefaults();
        settings.Experience_Site_Url__c = experienceSiteUrl;
        // Package-internal object — CRUD controlled by DocGen permission sets
        upsert settings; // NOPMD ApexCRUDViolation - package-internal custom setting; CRUD checked on lines 15-18 above
    }

    /**
     * Saves signature-specific settings (email branding, site URL).
     */
    @AuraEnabled
    public static void saveSignatureSettings(String brandColor, String logoUrl, String emailSubject,
                                              String emailMessage, String footerText, String companyName) {
        if (!FeatureManagement.checkPermission('DocGen_Admin_Access') &&
            !Schema.sObjectType.DocGen_Settings__c.isUpdateable()) {
            throw DocGenService.ahe('Insufficient privileges to modify DocGen settings.');
        }
        DocGen_Settings__c settings = DocGen_Settings__c.getOrgDefaults();
        settings.Signature_Email_Brand_Color__c = brandColor;
        settings.Signature_Email_Logo_Url__c = logoUrl;
        settings.Signature_Email_Subject__c = emailSubject;
        settings.Signature_Email_Message__c = emailMessage;
        settings.Signature_Email_Footer_Text__c = footerText;
        settings.Company_Name__c = companyName;
        upsert settings; // NOPMD ApexCRUDViolation - package-internal custom setting
    }
}