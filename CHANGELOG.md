# Changelog

## v1.5.0
- **Command Hub** — Single-tab UX replacing 7 tabs. Wizard-first onboarding, embedded bulk generator, contextual help.
- **Deep Grandchild Relationships** — Multi-level query stitching: Account → Opportunities → Line Items → Schedules. One SOQL per level, stitched in Apex. Query builder UI supports "Add Related List" inside child cards.
- **Signature Feature Removed** — E-signatures carry legal requirements a doc gen tool should not implement. Use dedicated providers (DocuSign, Adobe Sign).
- **Custom Font Upload Removed** — `Blob.toPdf()` does not support CSS `@font-face` (confirmed via data URIs, static resources, and ContentVersion URLs). PDF supports Helvetica, Times, Courier, Arial Unicode MS. DOCX preserves template fonts.
- **Font Documentation** — PDF font limitations documented. DOCX recommended for custom fonts.
- **DOCX Download Only** — Save to Record removed for DOCX output (Aura 4MB payload limit). Download works for any size.

## v1.3.4
- **Zero-Heap PDF Images** — `{%ImageField}` tags skip blob loading for PDF; images resolved by URL with zero heap cost
- **Pre-Decomposed Templates** — Template XML stored as ContentVersions on save; PDF generation skips ZIP decompression (~75% heap reduction)
- **PDF Image Fix** — Relative Salesforce URLs for `Blob.toPdf()` compatibility
- **Bold Space Fix** — Preserved whitespace between adjacent bold merge fields
- **Encoding Fix** — `&` no longer double-encoded in PDF output
- **Documentation Overhaul** — Release Update visibility, query builder limits, troubleshooting, known limitations table
- **Rich Text Fields** — Bold, italic, paragraph structure, and embedded images preserved in Word and PDF output

## v1.2.2
- **Admin Guide** — Data Model section with object reference tables
- **Page Layouts** — Added layouts for all custom objects

## v1.2.0
- **Unified PDF Generation** — Single code path for single and bulk PDF. -766 lines of duplicated logic.
- **Spring '26 Blob.toPdf() Compatibility** — Native rendering with Release Update, VF fallback without
- **Page Break Fix** — `page-break-inside: avoid` on paragraphs and list items

## v1.1.1
- **PDF Renderer** — Full DOCX style conversion: headings, lists, line spacing, page breaks, borders, shading, hyperlinks, superscript/subscript, tables
- **Merge Fields** — `{!Field}` Salesforce-style syntax and base object prefix stripping
- **Query Parser** — Auto-splits fields from adjacent subqueries

## v1.1.0
- **Admin Guide** — In-app guide covering all features
- **Version Preview** — Query display, template download, sample generation
- **Security** — `Security.stripInaccessible()`, sanitization hardening, error genericization

## v1.0.0
- **Server-Side PDF** — All generation via `DocGenHtmlRenderer` + `Blob.toPdf()`. Zero client-side JavaScript.
- **Security** — API v66.0, CRUD/FLS enforcement

## v0.9.x
- PKCE Auth Fix, wizard UX improvements, credential provisioning

## v0.8.0
- Fixed package uninstall blockers, updated terminology

## v0.7.0 and earlier
- Bulk PDF generation, transaction finalizers, security hardening, compression API migration, rich text support, 2GP package
