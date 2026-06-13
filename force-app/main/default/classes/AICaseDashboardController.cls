public with sharing class AICaseDashboardController {
    private static final String TEMPLATE_NAME = 'Case_AI_Summary';

    @AuraEnabled(cacheable=true)
    public static List<Case> getOpenCases() {
        return [
            SELECT
                Id,
                CaseNumber,
                Subject,
                Description,
                Status,
                Priority,
                CreatedDate,
                Origin,
                Contact.Name,
                Account.Name
            FROM Case
            WHERE Status != 'Closed'
            WITH SECURITY_ENFORCED
            ORDER BY CreatedDate DESC
            LIMIT 20
        ];
    }

    @AuraEnabled
    public static String generateAISummary(String caseId) {
        try {
            if (String.isBlank(caseId)) {
                return 'Error: Case ID is required.';
            }

            List<Case> cases = [
                SELECT
                    Id,
                    CaseNumber,
                    Subject,
                    Description,
                    Status,
                    Priority,
                    CreatedDate,
                    Origin,
                    Contact.Name,
                    Account.Name
                FROM Case
                WHERE Id = :caseId
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];

            if (cases.isEmpty()) {
                return 'Error: Case not found.';
            }

            Case selectedCase = cases[0];

            if (Test.isRunningTest()) {
                return buildMockSummary(selectedCase);
            }

            ConnectApi.EinsteinPromptTemplateGenerationsInput input = buildGenerationsInput(selectedCase);
            ConnectApi.EinsteinPromptTemplateGenerationsRepresentation output =
                ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate(TEMPLATE_NAME, input);

            return extractGeneratedText(output);
        } catch (Exception ex) {
            return 'Error generating AI summary: ' + ex.getMessage();
        }
    }

    @TestVisible
    private static ConnectApi.EinsteinPromptTemplateGenerationsInput buildGenerationsInput(Case selectedCase) {
        ConnectApi.EinsteinPromptTemplateGenerationsInput input =
            new ConnectApi.EinsteinPromptTemplateGenerationsInput();
        input.inputParams = buildInputParams(selectedCase);
        input.isPreview = false;
        input.additionalConfig = new ConnectApi.EinsteinLlmAdditionalConfigInput();
        input.additionalConfig.applicationName = 'PromptBuilderPreview';
        return input;
    }

    @TestVisible
    private static Map<String, ConnectApi.WrappedValue> buildInputParams(Case selectedCase) {
        Map<String, ConnectApi.WrappedValue> inputParams = new Map<String, ConnectApi.WrappedValue>();
        inputParams.put('Input:caseSubject', wrapValue(selectedCase.Subject));
        inputParams.put('Input:caseDescription', wrapValue(selectedCase.Description));
        inputParams.put('Input:casePriority', wrapValue(selectedCase.Priority));
        inputParams.put('Input:caseStatus', wrapValue(selectedCase.Status));

        String contactName =
            selectedCase.Contact != null && selectedCase.Contact.Name != null
                ? selectedCase.Contact.Name
                : 'Unknown Contact';
        String accountName =
            selectedCase.Account != null && selectedCase.Account.Name != null
                ? selectedCase.Account.Name
                : 'Unknown Account';
        String customerContext =
            'Contact Name: ' +
            contactName +
            '\nAccount Name: ' +
            accountName +
            '\nCase Origin: ' +
            (String.isBlank(selectedCase.Origin) ? 'Unknown' : selectedCase.Origin);
        inputParams.put('Input:customerContext', wrapValue(customerContext));

        return inputParams;
    }

    @TestVisible
    private static String extractGeneratedText(
        ConnectApi.EinsteinPromptTemplateGenerationsRepresentation output
    ) {
        if (output == null || output.generations == null || output.generations.isEmpty()) {
            return 'Error: Einstein returned no response. Please try again.';
        }

        return output.generations[0].text;
    }

    @TestVisible
    private static ConnectApi.WrappedValue wrapValue(String value) {
        ConnectApi.WrappedValue wrapped = new ConnectApi.WrappedValue();
        wrapped.value = String.isBlank(value) ? '' : value;
        return wrapped;
    }

    @TestVisible
    private static String buildMockSummary(Case selectedCase) {
        String contactName =
            selectedCase.Contact != null && selectedCase.Contact.Name != null
                ? selectedCase.Contact.Name
                : 'Unknown Contact';

        return 'SUMMARY:\n'
            + 'The customer reported an issue related to '
            + selectedCase.Subject
            + '. The case is currently '
            + selectedCase.Status
            + '.\n\n'
            + 'SENTIMENT:\nNeutral\n\n'
            + 'PRIORITY ASSESSMENT:\n'
            + 'The '
            + selectedCase.Priority
            + ' priority appears appropriate for this issue.\n\n'
            + 'SUGGESTED REPLY:\n'
            + 'Dear '
            + contactName
            + ',\n\n'
            + 'Thank you for contacting support regarding '
            + selectedCase.Subject
            + '. We are reviewing your case and will follow up with next steps shortly.\n\n'
            + 'The Support Team\n\n'
            + 'NEXT BEST ACTION:\nSend reply and monitor the case until resolved.';
    }
}
