@IsTest
private class CertGameImportService_Test {
    private static String pack(String examCode, String qExtId) {
        return JSON.serialize(
            new Map<String, Object>{
                'exam' => new Map<String, Object>{
                    'name' => 'Test Exam',
                    'code' => examCode,
                    'vendor' => 'Salesforce'
                },
                'questionBank' => new Map<String, Object>{
                    'name' => 'B',
                    'externalId' => 'BANK-' + examCode,
                    'version' => '1.0',
                    'sourceType' => 'Manual',
                    'status' => 'Draft'
                },
                'questions' => new List<Object>{
                    new Map<String, Object>{
                        'externalId' => qExtId,
                        'domain' => 'Sharing',
                        'difficulty' => 'Beginner',
                        'questionType' => 'Single Select',
                        'question' => 'What is sharing in Salesforce?',
                        'choices' => new List<Object>{
                            new Map<String, Object>{
                                'label' => 'A',
                                'text' => 'aa',
                                'isCorrect' => true
                            },
                            new Map<String, Object>{
                                'label' => 'B',
                                'text' => 'bb',
                                'isCorrect' => false
                            },
                            new Map<String, Object>{
                                'label' => 'C',
                                'text' => 'cc',
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

    @IsTest
    static void importCreatesExamBankQuestion() {
        CertGameImportService.ImportResult r = CertGameImportService.importPack(
            pack('IMP-1', 'IMP-Q1')
        );
        System.assert(r.success, String.join(r.errors, '; '));
        System.assertNotEquals(null, r.examId);
        System.assertNotEquals(null, r.questionBankId);
        System.assertEquals(1, r.questionsCreated);
        System.assertEquals(
            1,
            [
                SELECT COUNT()
                FROM Trivia_Question__c
                WHERE External_Id__c = 'IMP-Q1'
            ]
        );
        System.assertEquals(
            3,
            [
                SELECT COUNT()
                FROM Trivia_Answer_Choice__c
                WHERE Trivia_Question__r.External_Id__c = 'IMP-Q1'
            ]
        );
    }

    @IsTest
    static void rerunUpdatesNotDuplicates() {
        CertGameImportService.importPack(pack('IMP-2', 'IMP-Q2'));
        CertGameImportService.ImportResult r = CertGameImportService.importPack(
            pack('IMP-2', 'IMP-Q2')
        );
        System.assert(r.success);
        System.assertEquals(0, r.questionsCreated);
        System.assertEquals(1, r.questionsUpdated);
    }

    @IsTest
    static void invalidPackReturnsErrors() {
        CertGameImportService.ImportResult r = CertGameImportService.importPack(
            'not-json'
        );
        System.assert(!r.success);
        System.assert(!r.errors.isEmpty());
    }
}