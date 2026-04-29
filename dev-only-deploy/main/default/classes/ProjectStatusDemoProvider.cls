/**
 * Demo data provider showcasing every IF feature that landed in v1.72:
 *
 *   • Bare boolean IF              {#IF IsAtRisk__c}
 *   • Comparison IF                {#IF Spent__c > Budget__c}
 *   • AND / OR / NOT / parens      {#IF (CompletionPercent__c >= 100) OR (IsOnTrack__c AND DaysRemaining__c > 5)}
 *   • Nested IF blocks             phase loop with inner {#IF Tasks.totalSize != 0}
 *   • Empty-rel totalSize = 0      Approvals + Risks come back empty; {#IF Approvals.totalSize != 0}
 *                                  must correctly suppress (was always-truthy on V1/V2 SOQL pre-1.72)
 *   • Inverse {^Field} loop        {^Issues}{:else}…{/Issues}
 *   • Dotted child-of-child paths  {#Phases}{Name}{#Tasks}{Name}{/Tasks}{/Phases}
 *
 * Pair with `template-project-status.html` to render a one-page status report.
 *
 * To use:
 *   1. Deploy this class to your org.
 *   2. Create a new HTML template; paste the contents of
 *      `template-project-status.html` into the body.
 *   3. Set the template's Query_Config__c to:
 *        {"v":4,"provider":"ProjectStatusDemoProvider"}
 *   4. Generate from any record (recordId is ignored — data is synthetic).
 */
public with sharing class ProjectStatusDemoProvider implements portwoodglobal.DocGenDataProvider {

    public Map<String, Object> getData(Id recordId) {
        return buildSample();
    }

    public List<String> getFieldNames() {
        return new List<String>{
            'Name', 'ProjectCode__c', 'Manager', 'Customer',
            'StartDate', 'TargetDate',
            'Budget__c', 'Spent__c', 'CompletionPercent__c', 'DaysRemaining__c',
            'IsOnTrack__c', 'IsAtRisk__c', 'RequiresEscalation__c', 'Status',
            '#Phases', 'Phases.Name', 'Phases.Status__c', 'Phases.IsComplete__c',
            'Phases.Tasks.totalSize',
            '#Phases.Tasks', 'Phases.Tasks.Name', 'Phases.Tasks.Hours__c', '/Phases.Tasks',
            '/Phases',
            '#Issues', 'Issues.Title', 'Issues.Severity', '/Issues',
            'Risks.totalSize', 'Approvals.totalSize'
        };
    }

    @TestVisible
    private static Map<String, Object> buildSample() {
        Map<String, Object> data = new Map<String, Object>();

        // ── Top-level fields ───────────────────────────────────────────
        data.put('Name', 'Acme Migration — Phase 2');
        data.put('ProjectCode__c', 'PRJ-2026-042');
        data.put('Manager', 'Dave Moudy');
        data.put('Customer', 'Acme Corporation');
        data.put('StartDate', Date.newInstance(2026, 1, 15));
        data.put('TargetDate', Date.newInstance(2026, 6, 30));
        data.put('Budget__c', 250000);
        data.put('Spent__c', 187500);
        data.put('CompletionPercent__c', 78);
        data.put('DaysRemaining__c', 42);
        data.put('IsOnTrack__c', true);
        data.put('IsAtRisk__c', false);
        data.put('RequiresEscalation__c', false);
        data.put('Status', 'Green');

        // ── Phases (with nested Tasks) ─────────────────────────────────
        data.put('Phases', new Map<String, Object>{
            'totalSize' => 3,
            'records' => new List<Object>{
                phase('Discovery & Planning', 'Complete', true, new List<Object>{
                    task('Stakeholder interviews', 24),
                    task('Requirements doc',       16),
                    task('Architecture review',    12),
                    task('Sign-off',                4)
                }),
                phase('Build & Configure', 'In Progress', false, new List<Object>{
                    task('Data migration scripts', 32),
                    task('Custom integrations',    48),
                    task('Permission set design',  12)
                }),
                // Phase with NO tasks — exercises empty-rel totalSize=0 inside a nested IF
                phase('Test & Deploy', 'Not Started', false, new List<Object>())
            }
        });

        // ── Issues (populated) ─────────────────────────────────────────
        data.put('Issues', new Map<String, Object>{
            'totalSize' => 2,
            'records' => new List<Object>{
                new Map<String, Object>{
                    'Title' => 'API rate limit reached during initial migration',
                    'Severity' => 'High'
                },
                new Map<String, Object>{
                    'Title' => 'Custom field mapping ambiguity (legacy → new)',
                    'Severity' => 'Medium'
                }
            }
        });

        // ── Risks (empty) ──────────────────────────────────────────────
        // Demonstrates v1.72 fix: {Risks.totalSize} renders 0 (not blank),
        // {#IF Risks.totalSize != 0} correctly suppresses.
        data.put('Risks', new Map<String, Object>{
            'totalSize' => 0,
            'records' => new List<Object>()
        });

        // ── Approvals (empty) ──────────────────────────────────────────
        data.put('Approvals', new Map<String, Object>{
            'totalSize' => 0,
            'records' => new List<Object>()
        });

        return data;
    }

    private static Map<String, Object> phase(String name, String status, Boolean done, List<Object> tasks) {
        return new Map<String, Object>{
            'Name' => name,
            'Status__c' => status,
            'IsComplete__c' => done,
            'Tasks' => new Map<String, Object>{
                'totalSize' => tasks.size(),
                'records' => tasks
            }
        };
    }

    private static Map<String, Object> task(String name, Integer hours) {
        return new Map<String, Object>{ 'Name' => name, 'Hours__c' => hours };
    }
}
