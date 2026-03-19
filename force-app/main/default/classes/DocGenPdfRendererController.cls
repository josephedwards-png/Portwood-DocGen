/**
 * Controller for DocGenPdfRenderer.page — generates PDF by rendering HTML via
 * the VF renderAs="pdf" engine (Flying Saucer) for signature workflows.
 *
 * Uses 'without sharing' because this runs in VF page context for PDF rendering.
 * The page is accessed by system processes (Queueable jobs, platform event triggers)
 * that need to read ContentVersion and template data regardless of the running user's
 * sharing rules. Access is gated by requiring valid requestId/batchKey params.
 */
public without sharing class DocGenPdfRendererController {

    public String htmlContent { get; private set; }

    public DocGenPdfRendererController() {
        String mode = ApexPages.currentPage().getParameters().get('mode');

        if (mode == 'signature') {
            renderSignaturePdf();
        } else if (mode == 'sigbatch') {
            renderSignatureBatchPdf();
        } else if (mode == 'document') {
            renderDocumentPdf();
        } else {
            htmlContent = '<html><body><p>Invalid mode.</p></body></html>';
        }
    }

    /**
     * Renders a signed document PDF by stamping all signatures and converting to HTML.
     * URL params: requestId
     */
    private void renderSignaturePdf() {
        String requestId = ApexPages.currentPage().getParameters().get('requestId');
        if (String.isBlank(requestId)) {
            htmlContent = '<html><body><p>Error: Missing request ID.</p></body></html>';
            return;
        }

        try {
            List<DocGen_Signature_Request__c> requests = [
                SELECT Source_Document_Id__c, Signature_Data__c
                FROM DocGen_Signature_Request__c
                WHERE Id = :requestId
                WITH SYSTEM_MODE LIMIT 1
            ];
            if (requests.isEmpty()) {
                htmlContent = '<html><body><p>Error: Request not found.</p></body></html>';
                return;
            }

            Id sourceDocId = requests[0].Source_Document_Id__c;

            // Try multi-signer path first
            List<DocGen_Signer__c> signers = [
                SELECT Role_Name__c, Signature_Data__c
                FROM DocGen_Signer__c
                WHERE Signature_Request__c = :requestId AND Status__c = 'Signed'
                WITH SYSTEM_MODE
                ORDER BY Sort_Order__c ASC
            ];

            Blob stampedBlob;
            if (!signers.isEmpty()) {
                // Multi-signer: build from signer records
                List<DocGenSignatureService.SignerData> signerDataList = new List<DocGenSignatureService.SignerData>();
                for (DocGen_Signer__c s : signers) {
                    signerDataList.add(new DocGenSignatureService.SignerData(s.Role_Name__c, s.Signature_Data__c));
                }
                stampedBlob = DocGenSignatureService.stampAllSignaturesToBlob(sourceDocId, signerDataList);
            } else if (String.isNotBlank(requests[0].Signature_Data__c)) {
                // Legacy single-signer: image stored on request record
                stampedBlob = DocGenSignatureService.stampSignatureToBlob(
                    sourceDocId, requests[0].Signature_Data__c, requestId
                );
            }

            if (stampedBlob == null) {
                htmlContent = '<html><body><p>Error: Could not generate stamped document.</p></body></html>';
                return;
            }

            // Convert stamped DOCX to HTML with images
            htmlContent = DocGenSignatureController.convertStampedDocxToHtml(stampedBlob);

        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'DocGen: PDF render error: ' + e.getMessage());
            htmlContent = '<html><body><p>Error generating document.</p></body></html>';
        }
    }

    /**
     * Renders a signed document PDF using pre-saved stamped DOCX XML and image
     * ContentVersion records from SignaturePdfQueueable stage 1.
     * URL params: batchKey
     */
    private void renderSignatureBatchPdf() {
        String batchKey = ApexPages.currentPage().getParameters().get('batchKey');
        if (String.isBlank(batchKey)) {
            htmlContent = '<html><body><p>Error: Missing batch key.</p></body></html>';
            return;
        }

        try {
            // Read saved document XML
            List<ContentVersion> xmlCvs = [
                SELECT VersionData FROM ContentVersion
                WHERE Title = :('docgen_sig_' + batchKey + '_xml')
                WITH SYSTEM_MODE LIMIT 1
            ];
            if (xmlCvs.isEmpty()) {
                htmlContent = '<html><body><p>Error: Document not found for batch.</p></body></html>';
                return;
            }
            String documentXml = xmlCvs[0].VersionData.toString();

            // Build URL-based image map
            String prefix = 'docgen_sig_' + batchKey + '_';
            Map<String, String> imageUrlMap = new Map<String, String>();
            List<ContentVersion> imgCvs = [
                SELECT Id, Title FROM ContentVersion
                WHERE Title LIKE :(prefix + '%') AND Title != :('docgen_sig_' + batchKey + '_xml')
                WITH SYSTEM_MODE
            ];
            for (ContentVersion cv : imgCvs) {
                String relId = cv.Title.substring(prefix.length());
                imageUrlMap.put(relId, '/sfc/servlet.shepherd/version/download/' + cv.Id);
            }

            htmlContent = DocGenHtmlRenderer.convertToHtml(documentXml, imageUrlMap);

        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'DocGen: Signature batch PDF error: ' + e.getMessage());
            htmlContent = '<html><body><p>Error generating signed document.</p></body></html>';
        }
    }

    /**
     * Renders a document PDF by merging a template with record data.
     * Uses pre-committed template image CVs for URL-based rendering.
     * URL params: templateId, recordId
     */
    private void renderDocumentPdf() {
        String templateId = ApexPages.currentPage().getParameters().get('templateId');
        String recordId = ApexPages.currentPage().getParameters().get('recordId');

        if (String.isBlank(templateId) || String.isBlank(recordId)) {
            htmlContent = '<html><body><p>Error: Missing template or record ID.</p></body></html>';
            return;
        }

        try {
            htmlContent = DocGenService.renderDocumentHtml(templateId, recordId);
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'DocGen: Document PDF render error: ' + e.getMessage());
            htmlContent = '<html><body><p>Error generating document: ' + e.getMessage().escapeHtml4() + '</p></body></html>';
        }
    }
}
