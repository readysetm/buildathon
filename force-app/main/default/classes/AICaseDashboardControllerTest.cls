@IsTest
private class AICaseDashboardControllerTest {
    @TestSetup
    static void setupTestData() {
        Account account = new Account(Name = 'Acme Corp');
        insert account;

        Contact contact = new Contact(
            LastName = 'Smith',
            AccountId = account.Id
        );
        insert contact;

        List<Case> cases = new List<Case>{
            new Case(
                Subject = 'Login issue',
                Description = 'User cannot log in.',
                Status = 'New',
                Priority = 'High',
                Origin = 'Phone',
                ContactId = contact.Id,
                AccountId = account.Id
            ),
            new Case(
                Subject = 'Report filter issue',
                Description = 'Report filters are incorrect.',
                Status = 'Working',
                Priority = 'Medium',
                Origin = 'Email',
                ContactId = contact.Id,
                AccountId = account.Id
            )
        };
        insert cases;
    }

    @IsTest
    static void testGetOpenCases() {
        Test.startTest();
        List<Case> openCases = AICaseDashboardController.getOpenCases();
        Test.stopTest();

        System.assertEquals(2, openCases.size(), 'Expected two open cases.');
        System.assertNotEquals('Closed', openCases[0].Status);
    }

    @IsTest
    static void testGenerateAISummary() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        String summary = AICaseDashboardController.generateAISummary(testCase.Id);
        Test.stopTest();

        System.assert(summary.contains('SUMMARY:'), 'Summary section should be present.');
        System.assert(summary.contains('SENTIMENT:'), 'Sentiment section should be present.');
        System.assert(summary.contains('SUGGESTED REPLY:'), 'Suggested reply should be present.');
        System.assert(summary.contains('NEXT BEST ACTION:'), 'Next best action should be present.');
    }

    @IsTest
    static void testGenerateAISummaryInvalidId() {
        Test.startTest();
        String summary = AICaseDashboardController.generateAISummary(null);
        Test.stopTest();

        System.assert(summary.startsWith('Error'), 'Invalid case ID should return an error message.');
    }

    @IsTest
    static void testGenerateAISummaryMissingCase() {
        Id missingId = Case.SObjectType.getDescribe().getKeyPrefix() + '000000000000';

        Test.startTest();
        String summary = AICaseDashboardController.generateAISummary(missingId);
        Test.stopTest();

        System.assert(summary.contains('Case not found'), 'Missing case should return not found message.');
    }

    @IsTest
    static void testBuildInputParamsAndGenerationsInput() {
        Case testCase = [
            SELECT Id, Subject, Description, Status, Priority, Origin, Contact.Name, Account.Name
            FROM Case
            LIMIT 1
        ];

        Test.startTest();
        Map<String, ConnectApi.WrappedValue> inputParams = AICaseDashboardController.buildInputParams(testCase);
        ConnectApi.EinsteinPromptTemplateGenerationsInput input =
            AICaseDashboardController.buildGenerationsInput(testCase);
        String emptyResponse = AICaseDashboardController.extractGeneratedText(null);
        Test.stopTest();

        System.assertEquals(5, inputParams.size(), 'Expected five prompt inputs.');
        System.assertNotEquals(null, input.inputParams);
        System.assertEquals(false, input.isPreview);
        System.assert(emptyResponse.contains('no response'), 'Null output should return an error message.');
    }

    @IsTest
    static void testWrapValueHandlesBlankValues() {
        Test.startTest();
        ConnectApi.WrappedValue wrapped = AICaseDashboardController.wrapValue(null);
        Test.stopTest();

        System.assertEquals('', wrapped.value, 'Blank values should be converted to empty strings.');
    }
}
