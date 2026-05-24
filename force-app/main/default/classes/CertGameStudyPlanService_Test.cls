@IsTest
private class CertGameStudyPlanService_Test {
    @TestSetup
    static void setup() {
        Certification_Exam__c e = new Certification_Exam__c(
            Name = 'Admin',
            Certification_Code__c = 'ADM-201',
            Vendor__c = 'SF',
            Active__c = true
        );
        insert e;
    }

    @IsTest
    static void openPlanSafelyHandlesNoCallout() {
        CertGameStudyPlanService.openPlanModal('T_PL', 'U1', 'TR1');
    }

    private static Map<String, Object> submission(
        String examCode,
        String target,
        String daily
    ) {
        return new Map<String, Object>{
            'state' => new Map<String, Object>{
                'values' => new Map<String, Object>{
                    'exam_block' => new Map<String, Object>{
                        'exam' => new Map<String, Object>{ 'value' => examCode }
                    },
                    'target_block' => new Map<String, Object>{
                        'target' => new Map<String, Object>{ 'value' => target }
                    },
                    'daily_block' => new Map<String, Object>{
                        'daily' => new Map<String, Object>{ 'value' => daily }
                    }
                }
            }
        };
    }

    @IsTest
    static void unknownExamReturnsText() {
        String r = CertGameStudyPlanService.handlePlanSubmission(
            'T_PL',
            'U1',
            submission('NOPE', '2030-01-01', '5')
        );
        System.assert(r.contains('ephemeral'));
    }

    @IsTest
    static void validSubmissionInsertsPlan() {
        CertGameStudyPlanService.handlePlanSubmission(
            'T_PL',
            'U1',
            submission('ADM-201', '2030-01-01', '5')
        );
        System.assertEquals(1, [SELECT COUNT() FROM Study_Plan__c]);
    }

    @IsTest
    static void invalidDateAndDailyFallback() {
        CertGameStudyPlanService.handlePlanSubmission(
            'T_PL',
            'U1',
            submission('ADM-201', 'not-a-date', 'notnum')
        );
        System.assertEquals(1, [SELECT COUNT() FROM Study_Plan__c]);
    }
}