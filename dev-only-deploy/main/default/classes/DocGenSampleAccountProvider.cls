/**
 * Devbox-only sample DocGenDataProvider — NOT shipped with the managed package.
 *
 * Lives in scripts/devbox-only/ so it deploys only to dave's devbox for hands-on
 * testing of the v4 Apex Provider path. Subscribers learn from the example code
 * in UserGuide.md and write their own provider class in their own org.
 *
 * Demonstrates every shape the merge engine consumes:
 *   - Simple fields, parent lookups, computed values, child loops, aggregates
 */
public with sharing class DocGenSampleAccountProvider implements DocGenDataProvider {

    public Map<String, Object> getData(Id recordId) {
        if (recordId == null) {
            throw new DocGenException('DocGenSampleAccountProvider requires an Account record ID.');
        }

        Account a;
        try {
            a = [SELECT Id, Name, Industry, Phone, Website, AnnualRevenue, NumberOfEmployees,
                        BillingStreet, BillingCity, BillingState, BillingPostalCode,
                        Owner.Name, Owner.Email, Owner.Phone
                 FROM Account WHERE Id = :recordId WITH USER_MODE LIMIT 1];
        } catch (System.QueryException qe) {
            throw new DocGenException('Account not found or access denied: ' + recordId);
        }

        Decimal score = computeCustomerScore(a.AnnualRevenue, a.NumberOfEmployees);
        String tier = score >= 75 ? 'Strategic' : score >= 50 ? 'Growth' : score >= 25 ? 'Standard' : 'Watchlist';

        List<Object> contactRecords = new List<Object>();
        for (Contact c : [SELECT FirstName, LastName, Title, Email, Phone
                          FROM Contact WHERE AccountId = :recordId
                          WITH USER_MODE ORDER BY LastName ASC LIMIT 200]) {
            contactRecords.add(new Map<String, Object>{
                'FirstName' => c.FirstName,
                'LastName' => c.LastName,
                'FullName' => (c.FirstName != null ? c.FirstName + ' ' : '') + (c.LastName != null ? c.LastName : ''),
                'Title' => c.Title,
                'Email' => c.Email,
                'Phone' => c.Phone
            });
        }

        List<Object> oppRecords = new List<Object>();
        Decimal totalPipeline = 0;
        Integer wonCount = 0;
        for (Opportunity o : [SELECT Name, StageName, Amount, CloseDate, IsWon, IsClosed
                              FROM Opportunity WHERE AccountId = :recordId
                              WITH USER_MODE ORDER BY CloseDate DESC LIMIT 200]) {
            oppRecords.add(new Map<String, Object>{
                'Name' => o.Name,
                'StageName' => o.StageName,
                'Amount' => o.Amount != null ? o.Amount : 0,
                'CloseDate' => o.CloseDate,
                'IsWon' => o.IsWon
            });
            if (o.Amount != null && !o.IsClosed) { totalPipeline += o.Amount; }
            if (o.IsWon) { wonCount++; }
        }

        return new Map<String, Object>{
            'Name' => a.Name,
            'Industry' => a.Industry,
            'Phone' => a.Phone,
            'Website' => a.Website,
            'AnnualRevenue' => a.AnnualRevenue,
            'NumberOfEmployees' => a.NumberOfEmployees,
            'BillingAddress' => buildBillingAddress(a),
            'Owner' => new Map<String, Object>{
                'Name' => a.Owner.Name,
                'Email' => a.Owner.Email,
                'Phone' => a.Owner.Phone
            },
            'CustomerScore' => score,
            'RiskTier' => tier,
            'GeneratedAt' => Datetime.now(),
            'GeneratedBy' => UserInfo.getName(),
            'Contacts' => new Map<String, Object>{
                'records' => contactRecords,
                'totalSize' => contactRecords.size()
            },
            'Opportunities' => new Map<String, Object>{
                'records' => oppRecords,
                'totalSize' => oppRecords.size()
            },
            'TotalPipeline' => totalPipeline,
            'WonOpportunityCount' => wonCount
        };
    }

    public List<String> getFieldNames() {
        return new List<String>{
            'Name', 'Industry', 'Phone', 'Website',
            'AnnualRevenue', 'NumberOfEmployees', 'BillingAddress',
            'Owner.Name', 'Owner.Email', 'Owner.Phone',
            'CustomerScore', 'RiskTier', 'GeneratedAt', 'GeneratedBy',
            'TotalPipeline', 'WonOpportunityCount',
            '#Contacts', 'Contacts.FirstName', 'Contacts.LastName', 'Contacts.FullName',
                          'Contacts.Title', 'Contacts.Email', 'Contacts.Phone', '/Contacts',
            '#Opportunities', 'Opportunities.Name', 'Opportunities.StageName',
                              'Opportunities.Amount', 'Opportunities.CloseDate',
                              'Opportunities.IsWon', '/Opportunities'
        };
    }

    private static Decimal computeCustomerScore(Decimal revenue, Decimal employees) {
        if (revenue == null) { revenue = 0; }
        if (employees == null) { employees = 0; }
        Double revScore = revenue <= 0 ? 0 : Math.min(60.0, Math.log(revenue.doubleValue() + 1) * 6);
        Double empScore = employees <= 0 ? 0 : Math.min(40.0, Math.log(employees.doubleValue() + 1) * 5);
        return Decimal.valueOf(String.valueOf(revScore + empScore)).setScale(1);
    }

    private static String buildBillingAddress(Account a) {
        List<String> parts = new List<String>();
        if (String.isNotBlank(a.BillingStreet)) { parts.add(a.BillingStreet); }
        String cityState = '';
        if (String.isNotBlank(a.BillingCity)) { cityState = a.BillingCity; }
        if (String.isNotBlank(a.BillingState)) { cityState += (cityState.length() > 0 ? ', ' : '') + a.BillingState; }
        if (String.isNotBlank(a.BillingPostalCode)) { cityState += ' ' + a.BillingPostalCode; }
        if (cityState.length() > 0) { parts.add(cityState); }
        return String.join(parts, '\n');
    }
}
