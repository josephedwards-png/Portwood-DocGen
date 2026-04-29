// Probe bare-boolean IF behavior (non-nested vs nested).

Map<String, Object> data = new Map<String, Object>{ 'Active__c' => true, 'Count__c' => 5 };

// Probe 1: bare boolean IF, non-nested
String t1 = '{#IF Active__c}YES{/IF}';
String r1 = portwoodglobal.DocGenService.processXmlForTest(t1, data);
System.debug('Probe 1 [bare bool, non-nested]: [' + r1 + ']');

// Probe 2: bare boolean IF compared to true literal
String t2 = '{#IF Active__c == true}YES{/IF}';
String r2 = portwoodglobal.DocGenService.processXmlForTest(t2, data);
System.debug('Probe 2 [bool == true, non-nested]: [' + r2 + ']');

// Probe 3: nested with bare boolean inner
String t3 = '{#IF Count__c > 0}HAS{#IF Active__c}ACTIVE{/IF}END{/IF}';
String r3 = portwoodglobal.DocGenService.processXmlForTest(t3, data);
System.debug('Probe 3 [nested with bare bool inner]: [' + r3 + ']');

// Probe 4: nested with bool == true inner
String t4 = '{#IF Count__c > 0}HAS{#IF Active__c == true}ACTIVE{/IF}END{/IF}';
String r4 = portwoodglobal.DocGenService.processXmlForTest(t4, data);
System.debug('Probe 4 [nested with bool == true inner]: [' + r4 + ']');
