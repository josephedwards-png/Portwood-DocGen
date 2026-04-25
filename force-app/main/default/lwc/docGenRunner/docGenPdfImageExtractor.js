/**
 * Extracts the first embedded image from a PDF (base64-encoded).
 *
 * Use case: server renders a single-image PDF via Blob.toPdf() — the only
 * Salesforce-platform path that can fetch Lightning rich text inline images
 * (0EM ContentReference) without session-ID exposure or LWS/CORS issues.
 * We pull the embedded /XObject /Image stream out of that PDF and use it
 * as the image bytes for DOCX assembly.
 *
 * Handles the two compression modes Flying Saucer / Blob.toPdf actually emits:
 *   - DCTDecode: raw JPEG bytes — use directly, just wrap with proper extension
 *   - FlateDecode + DeviceRGB: zlib-compressed raw RGB pixels — re-encode as PNG
 *
 * Returns { base64, ext } or null if no extractable image found.
 */

function latin1Decode(bytes) {
    let s = '';
    for (let i = 0; i < bytes.length; i++) s += String.fromCharCode(bytes[i]);
    return s;
}

function base64ToBytes(b64) {
    const bin = atob(b64);
    const bytes = new Uint8Array(bin.length);
    for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
    return bytes;
}

function bytesToBase64(bytes) {
    let bin = '';
    const chunk = 0x8000;
    for (let i = 0; i < bytes.length; i += chunk) {
        bin += String.fromCharCode.apply(null, bytes.subarray(i, i + chunk));
    }
    return btoa(bin);
}

/**
 * Walk PDF objects looking for /Subtype /Image. Returns the first match's
 * dict text + raw stream bytes.
 */
function findFirstImageObject(bytes) {
    const str = latin1Decode(bytes);
    const objRe = /\b(\d+)\s+0\s+obj\b/g;
    let m;
    while ((m = objRe.exec(str)) !== null) {
        const headerEnd = m.index + m[0].length;
        const endIdx = str.indexOf('endobj', headerEnd);
        if (endIdx === -1) continue;
        const body = str.substring(headerEnd, endIdx);

        // Quick reject — must be image XObject
        if (!/\/Subtype\s*\/Image/.test(body)) continue;

        const si = body.indexOf('stream');
        if (si === -1) continue;
        const dictText = body.substring(0, si);

        let dStart = headerEnd + si + 6;
        if (bytes[dStart] === 0x0d) dStart++;
        if (bytes[dStart] === 0x0a) dStart++;

        const lenMatch = dictText.match(/\/Length\s+(\d+)(?!\s+\d+\s+R)/);
        let streamBytes;
        if (lenMatch) {
            const len = parseInt(lenMatch[1], 10);
            streamBytes = bytes.slice(dStart, dStart + len);
        } else {
            const esIdx = str.indexOf('endstream', dStart);
            let dEnd = esIdx;
            if (bytes[dEnd - 1] === 0x0a) dEnd--;
            if (bytes[dEnd - 1] === 0x0d) dEnd--;
            streamBytes = bytes.slice(dStart, dEnd);
        }

        return { dictText, streamBytes };
    }
    return null;
}

/**
 * Extracts the first image from a base64-encoded PDF. Returns
 * { base64, mediaType, ext } or null.
 *
 * mediaType is 'image/jpeg' or 'image/png'. ext is 'jpeg' or 'png'.
 */
export function extractFirstImageFromPdfBase64(pdfBase64) {
    if (!pdfBase64) return null;
    let bytes;
    try { bytes = base64ToBytes(pdfBase64); }
    catch (e) { console.warn('[DocGen] PDF base64 decode failed', e); return null; }

    const found = findFirstImageObject(bytes);
    if (!found) return null;

    const { dictText, streamBytes } = found;

    // DCTDecode = raw JPEG bytes. Use directly.
    if (/\/Filter\s*(?:\[\s*)?\/DCTDecode/.test(dictText)) {
        return {
            base64: bytesToBase64(streamBytes),
            mediaType: 'image/jpeg',
            ext: 'jpeg'
        };
    }

    // JPXDecode = JPEG 2000. Salesforce's Flying Saucer rarely emits this; if
    // it does, the bytes are a JP2 file. Word may or may not render it; pass through.
    if (/\/Filter\s*(?:\[\s*)?\/JPXDecode/.test(dictText)) {
        return {
            base64: bytesToBase64(streamBytes),
            mediaType: 'image/jp2',
            ext: 'jp2'
        };
    }

    // FlateDecode = zlib-compressed raw pixels. Reconstructing a PNG would
    // require pako (inflate) + a PNG encoder — too heavy. Skip for now; the
    // user will see a missing image and we can add this later if needed.
    console.warn('[DocGen] PDF image uses unsupported filter, dict:', dictText.slice(0, 200));
    return null;
}
