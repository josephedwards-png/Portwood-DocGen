/**
 * Devbox-only stub. The original DocGenLicenseSync was a stale orphan class
 * left over from prior LMA work that referenced an inaccessible MetadataPackage
 * SObject and stopped compiling — which broke every other Apex class that
 * referenced it (DocGenInstallsController.syncNow() in particular).
 *
 * This stub gives those dependents a valid type to compile against. It does
 * nothing. Not part of the package — lives in dev-only-deploy/.
 */
public class DocGenLicenseSync {
    public static void syncNow() {
        // no-op
    }
}
