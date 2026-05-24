@IsTest
private class CertGameGenerationJobQueueable_Test {
    public class StubProvider implements QuestionGenerationProvider {
        public String name() {
            return 'stub';
        }
        public String generate(
            String examCode,
            List<String> domains,
            String difficulty,
            Integer count
        ) {
            return JSON.serialize(
                new Map<String, Object>{
                    'exam' => new Map<String, Object>{
                        'name' => 'Stub',
                        'code' => 'STUB-1',
                        'vendor' => 'SF'
                    },
                    'questionBank' => new Map<String, Object>{
                        'name' => 'B',
                        'externalId' => 'B-STUB',
                        'version' => '1.0',
                        'sourceType' => 'Generated',
                        'status' => 'Draft'
                    },
                    'questions' => new List<Object>{
                        new Map<String, Object>{
                            'externalId' => 'STUB-Q1',
                            'domain' => 'D',
                            'difficulty' => 'Beginner',
                            'questionType' => 'Single Select',
                            'question' => 'Q?',
                            'choices' => new List<Object>{
                                new Map<String, Object>{
                                    'label' => 'A',
                                    'text' => 'a',
                                    'isCorrect' => true
                                },
                                new Map<String, Object>{
                                    'label' => 'B',
                                    'text' => 'b',
                                    'isCorrect' => false
                                },
                                new Map<String, Object>{
                                    'label' => 'C',
                                    'text' => 'c',
                                    'isCorrect' => false
                                }
                            },
                            'citations' => new List<Object>{
                                new Map<String, Object>{
                                    'title' => 'T',
                                    'url' => 'https://x',
                                    'sourceType' => 'Salesforce Help'
                                }
                            }
                        }
                    }
                }
            );
        }
    }

    public class FailingProvider implements QuestionGenerationProvider {
        public String name() {
            return 'fail';
        }
        public String generate(
            String examCode,
            List<String> domains,
            String difficulty,
            Integer count
        ) {
            return 'not-json';
        }
    }

    private static Question_Generation_Job__c buildJob(
        String teamId,
        String plan
    ) {
        Tenant__c t = new Tenant__c(
            Slack_Team_Id__c = teamId,
            Workspace_Name__c = 'W',
            Plan__c = plan,
            Status__c = 'Active',
            Installed_At__c = System.now()
        );
        insert t;
        Certification_Exam__c ex = new Certification_Exam__c(
            Name = 'E',
            Certification_Code__c = 'GEN-' + teamId,
            Vendor__c = 'SF',
            Active__c = true
        );
        insert ex;
        Question_Generation_Job__c job = new Question_Generation_Job__c(
            Tenant__c = t.Id,
            Certification_Exam__c = ex.Id,
            Requested_Question_Count__c = 1,
            Provider__c = 'OpenAI',
            Status__c = 'Queued'
        );
        insert job;
        return job;
    }

    @IsTest
    static void successfulJobImportsAndCompletes() {
        QuestionGenerationProviderFactory.providerOverride = new StubProvider();
        Question_Generation_Job__c job = buildJob('T_GEN_OK', 'Pro');
        Test.startTest();
        System.enqueueJob(new CertGameGenerationJobQueueable(job.Id));
        Test.stopTest();
        Question_Generation_Job__c after = [
            SELECT Status__c, Generated_Question_Count__c
            FROM Question_Generation_Job__c
            WHERE Id = :job.Id
        ];
        System.assertEquals('Completed', after.Status__c);
        System.assert(after.Generated_Question_Count__c >= 1);
    }

    @IsTest
    static void quotaBlocksFreePlan() {
        QuestionGenerationProviderFactory.providerOverride = new StubProvider();
        Question_Generation_Job__c job = buildJob('T_GEN_FREE', 'Free');
        Test.startTest();
        System.enqueueJob(new CertGameGenerationJobQueueable(job.Id));
        Test.stopTest();
        Question_Generation_Job__c after = [
            SELECT Status__c, Error_Message__c
            FROM Question_Generation_Job__c
            WHERE Id = :job.Id
        ];
        System.assertEquals('Failed', after.Status__c);
    }

    @IsTest
    static void invalidProviderOutputFailsJob() {
        QuestionGenerationProviderFactory.providerOverride = new FailingProvider();
        Question_Generation_Job__c job = buildJob('T_GEN_BAD', 'Pro');
        Test.startTest();
        System.enqueueJob(new CertGameGenerationJobQueueable(job.Id));
        Test.stopTest();
        Question_Generation_Job__c after = [
            SELECT Status__c
            FROM Question_Generation_Job__c
            WHERE Id = :job.Id
        ];
        System.assertEquals('Failed', after.Status__c);
    }

    @IsTest
    static void missingJobIsSafe() {
        Test.startTest();
        System.enqueueJob(
            new CertGameGenerationJobQueueable('a02000000000000')
        );
        Test.stopTest();
    }
}