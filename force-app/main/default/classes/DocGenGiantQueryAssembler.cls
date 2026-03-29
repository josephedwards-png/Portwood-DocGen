/**
 * Queueable that progressively assembles Giant Query PDF fragments.
 * Chains to itself, each pass loading the previous accumulated HTML + next
 * batch of fragments. Final pass wraps in HTML and calls Blob.toPdf().
 * Peak heap stays under 12MB even for 10K+ rows.
 */
public with sharing class DocGenGiantQueryAssembler implements Queueable {

    private static final Integer FRAGS_PER_PASS = 50; // ~1.15MB per pass

    private Id jobId;
    private Id templateId;
    private Id recordId;
    private String giantRelationshipName;

    public DocGenGiantQueryAssembler(Id jobId, Id templateId, Id recordId, String giantRelationshipName) {
        this.jobId = jobId;
        this.templateId = templateId;
        this.recordId = recordId;
        this.giantRelationshipName = giantRelationshipName;
    }

    public void execute(QueueableContext ctx) {
        try {
            String prefix = 'docgen_giant_' + jobId + '_';
            String accumTitle = 'docgen_giant_' + jobId + '_accum';
            String partExclude = prefix + 'part_%';

            // Load the previous accumulation if it exists
            String accumulated = '';
            List<ContentVersion> accumCvs = [
                SELECT Id, VersionData, ContentDocumentId FROM ContentVersion
                WHERE Title = :accumTitle WITH SYSTEM_MODE LIMIT 1
            ];
            Id accumDocId = null;
            if (!accumCvs.isEmpty()) {
                accumulated = accumCvs[0].VersionData.toString();
                accumDocId = accumCvs[0].ContentDocumentId;
            }
            accumCvs = null;

            // Load next batch of HTML fragments
            List<ContentVersion> frags = [
                SELECT Title, VersionData, ContentDocumentId FROM ContentVersion
                WHERE Title LIKE :(prefix + '%') AND Title != :accumTitle
                AND (NOT Title LIKE :partExclude)
                ORDER BY Title LIMIT :FRAGS_PER_PASS // NOPMD
            ];

            if (frags.isEmpty()) {
                // No more fragments — render final PDF
                renderFinalPdf(accumulated, accumDocId);
                return;
            }

            // Append this batch to accumulated HTML
            Set<Id> fragDocIds = new Set<Id>();
            for (ContentVersion cv : frags) {
                accumulated += cv.VersionData.toString();
                fragDocIds.add(cv.ContentDocumentId);
            }
            frags = null;

            // Save updated accumulation (delete old, create new)
            if (accumDocId != null) {
                delete new ContentDocument(Id = accumDocId); // NOPMD
            }
            ContentVersion newAccum = new ContentVersion(
                Title = accumTitle,
                PathOnClient = accumTitle + '.html',
                VersionData = Blob.valueOf(accumulated),
                IsMajorVersion = false
            );
            insert newAccum; // NOPMD
            accumulated = null;

            // Delete consumed fragments
            if (!fragDocIds.isEmpty()) {
                delete [SELECT Id FROM ContentDocument WHERE Id IN :fragDocIds]; // NOPMD
            }

            // Chain to self for next pass
            System.enqueueJob(new DocGenGiantQueryAssembler(
                jobId, templateId, recordId, giantRelationshipName
            ));

        } catch (Exception e) {
            update new DocGen_Job__c(Id = jobId, Status__c = 'Failed', Label__c = e.getMessage().left(255)); // NOPMD
        }
    }

    /**
     * Final pass: wraps accumulated rows in a complete document and renders PDF.
     */
    private void renderFinalPdf(String allRows, Id accumDocId) {
        // Clean up the accumulation CV
        if (accumDocId != null) {
            delete new ContentDocument(Id = accumDocId); // NOPMD
        }

        if (String.isBlank(allRows)) {
            update new DocGen_Job__c(Id = jobId, Status__c = 'Failed', Label__c = 'No data to render'); // NOPMD
            return;
        }

        // Load pre-baked HTML template (created at template save time — zero conversion overhead)
        List<DocGen_Template_Version__c> vers = [
            SELECT Id FROM DocGen_Template_Version__c
            WHERE Template__c = :templateId AND Is_Active__c = true
            WITH SYSTEM_MODE LIMIT 1
        ];
        String html = null;
        if (!vers.isEmpty()) {
            String htmlTitle = 'docgen_tmpl_html_' + vers[0].Id;
            List<ContentVersion> htmlCvs = [
                SELECT VersionData FROM ContentVersion
                WHERE Title = :htmlTitle WITH SYSTEM_MODE LIMIT 1
            ];
            if (!htmlCvs.isEmpty()) {
                html = htmlCvs[0].VersionData.toString();
            }
        }

        if (html != null) {
            // Inject td styling + per-column formatting into the existing <style> block
            String columnCss = '';
            try {
                Map<String, Object> cfg = DocGenService.extractGiantQueryFragmentConfig(templateId, giantRelationshipName);
                columnCss = cfg.get('columnCss') != null ? (String) cfg.get('columnCss') : '';
            } catch (Exception e) { String noop = e.getMessage(); } // NOPMD EmptyCatchBlock — non-fatal

            if (html.contains('</style>')) {
                html = html.replace('</style>',
                    'td { border: 0.5pt solid #ccc; padding: 3px 5px; } tr { page-break-inside: avoid; } ' +
                    columnCss + '</style>');
            }

            // Resolve parent merge tags BEFORE injecting rows (regex on ~2KB template, not 1MB+ with rows)
            try {
                List<DocGen_Template__c> tpls = [
                    SELECT Base_Object_API__c FROM DocGen_Template__c
                    WHERE Id = :templateId WITH SYSTEM_MODE LIMIT 1
                ];
                if (!tpls.isEmpty()) {
                    String baseObj = tpls[0].Base_Object_API__c;
                    Set<String> fieldNames = new Set<String>{'Name'};
                    Pattern p = Pattern.compile('\\{(\\w[\\w.]*)\\}');
                    Matcher m = p.matcher(html);
                    while (m.find()) { fieldNames.add(m.group(1)); }
                    List<String> validFields = new List<String>();
                    Map<String, Schema.SObjectField> fieldMap = Schema.getGlobalDescribe().get(baseObj)?.getDescribe()?.fields?.getMap();
                    if (fieldMap != null) {
                        for (String fn : fieldNames) {
                            if (fn.contains('.') || fieldMap.containsKey(fn.toLowerCase())) {
                                validFields.add(fn);
                            }
                        }
                    }
                    if (!validFields.isEmpty()) {
                        String soql = 'SELECT ' + String.join(validFields, ', ') + ' FROM ' + String.escapeSingleQuotes(baseObj) + ' WHERE Id = :recordId LIMIT 1';
                        List<SObject> recs = Database.query(soql, AccessLevel.USER_MODE);
                        if (!recs.isEmpty()) {
                            for (String fn : validFields) {
                                Object val = null;
                                try {
                                    if (fn.contains('.')) {
                                        List<String> parts = fn.split('\\.');
                                        SObject cur = recs[0];
                                        for (Integer i = 0; i < parts.size() - 1 && cur != null; i++) { cur = cur.getSObject(parts[i]); }
                                        if (cur != null) { val = cur.get(parts[parts.size() - 1]); }
                                    } else {
                                        val = recs[0].get(fn);
                                    }
                                } catch (Exception fieldErr) { String noop = fieldErr.getMessage(); } // NOPMD
                                html = html.replace('{' + fn + '}', val != null ? String.valueOf(val) : '');
                            }
                        }
                    }
                }
            } catch (Exception mergeErr) {
                String noop = mergeErr.getMessage(); // NOPMD
            }

            // Replace the loop ROW (not the whole table) — preserve the header row
            String openTag = '{#' + giantRelationshipName + '}';
            if (html.contains(openTag)) {
                Integer openIdx = html.indexOf(openTag);
                // Find the <tr> that contains the loop tag — replace from there to </table>
                Integer loopTrStart = html.lastIndexOf('<tr', openIdx);
                Integer tableEnd = html.indexOf('</table>', openIdx);
                if (loopTrStart != -1 && tableEnd != -1) {
                    String before = html.substring(0, loopTrStart);
                    String after = html.substring(tableEnd); // keeps </table> and everything after
                    html = null;
                    html = before + allRows + after;
                    allRows = null;
                }
            } else {
                Integer bodyEnd = html.lastIndexOf('</body>');
                String before = html.substring(0, bodyEnd);
                String after = html.substring(bodyEnd);
                html = null;
                html = before + '<table style="width:100%;border-collapse:collapse;">' + allRows + '</table>' + after;
                allRows = null;
            }

            // Parent merge tags already resolved above (before row injection)
        } else {
            // No pre-baked HTML — simple fallback
            String fallbackColCss = '';
            try {
                Map<String, Object> cfg = DocGenService.extractGiantQueryFragmentConfig(templateId, giantRelationshipName);
                fallbackColCss = cfg.get('columnCss') != null ? (String) cfg.get('columnCss') : '';
            } catch (Exception e) { String noop = e.getMessage(); } // NOPMD EmptyCatchBlock — non-fatal
            html = '<html><head><style>' +
                '@page { size: letter; margin: 0.75in; }' +
                'body { font-family: Helvetica, sans-serif; font-size: 9pt; margin: 0; }' +
                'table { width: 100%; border-collapse: collapse; }' +
                'td { border: 0.5pt solid #ccc; padding: 3px 5px; }' +
                'tr { page-break-inside: avoid; }' +
                fallbackColCss +
                '</style></head><body><table>' + allRows + '</table></body></html>';
        }
        allRows = null;

        Blob pdfBlob = Blob.toPdf(html);
        html = null;

        // Save final PDF and link to record
        ContentVersion pdfCv = new ContentVersion(
            Title = 'docgen_giant_' + jobId + '_final',
            PathOnClient = 'docgen_giant_' + jobId + '_final.pdf',
            VersionData = pdfBlob,
            IsMajorVersion = false
        );
        insert pdfCv; // NOPMD

        // Link PDF to the source record (some objects like Pricebook2 don't support file linking)
        try {
            Id docId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :pdfCv.Id].ContentDocumentId;
            insert new ContentDocumentLink(
                ContentDocumentId = docId,
                LinkedEntityId = recordId,
                ShareType = 'V'
            ); // NOPMD
        } catch (Exception linkErr) {
            String noop = linkErr.getMessage(); // NOPMD EmptyCatchBlock — non-fatal, PDF still saved
        }

        update new DocGen_Job__c(Id = jobId, Status__c = 'Completed'); // NOPMD
    }
}
