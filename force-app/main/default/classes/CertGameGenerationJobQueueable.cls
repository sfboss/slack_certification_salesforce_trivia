/**
 * Async pipeline: provider callout → schema validation → duplicate detection → import as Draft.
 * Records lifecycle on Question_Generation_Job__c and emits QuestionGenerationJob__e.
 */
public with sharing class CertGameGenerationJobQueueable implements Queueable, Database.AllowsCallouts {
    private Id jobId;

    public CertGameGenerationJobQueueable(Id jobId) {
        this.jobId = jobId;
    }

    public void execute(QueueableContext ctx) {
        Question_Generation_Job__c job;
        try {
            List<Question_Generation_Job__c> jobs = [
                SELECT
                    Id,
                    Tenant__c,
                    Certification_Exam__c,
                    Certification_Exam__r.Certification_Code__c,
                    Requested_Question_Count__c,
                    Provider__c,
                    Status__c,
                    Prompt_Text__c,
                    Domain_Focus__c,
                    Difficulty_Focus__c
                FROM Question_Generation_Job__c
                WHERE Id = :jobId
                WITH SYSTEM_MODE
                LIMIT 1
            ];
            if (jobs.isEmpty())
                return;
            job = jobs[0];

            Integer count = job.Requested_Question_Count__c == null
                ? 5
                : job.Requested_Question_Count__c.intValue();
            if (!EntitlementGuard.canGenerateQuestions(job.Tenant__c, count)) {
                fail(job, CertGameStrings.QUOTA_REACHED);
                return;
            }

            setStatus(job, 'Running', null);

            QuestionGenerationProvider p = QuestionGenerationProviderFactory.provider();
            String examCode = job.Certification_Exam__r == null
                ? null
                : job.Certification_Exam__r.Certification_Code__c;
            List<String> domains = new List<String>();
            if (String.isNotBlank(job.Domain_Focus__c)) {
                for (String d : job.Domain_Focus__c.split(',')) {
                    if (String.isNotBlank(d))
                        domains.add(d.trim());
                }
            }
            String diff = (job.Difficulty_Focus__c == null ||
                job.Difficulty_Focus__c == 'Mixed')
                ? null
                : job.Difficulty_Focus__c;
            String genJson = p.generate(examCode, domains, diff, count);

            QuestionJsonValidator.Result vr = QuestionJsonValidator.validate(
                genJson
            );
            if (!vr.valid) {
                fail(job, 'Validation failed: ' + String.join(vr.errors, '; '));
                return;
            }

            CertGameImportService.ImportResult ir = CertGameImportService.importPack(
                genJson
            );
            if (!ir.success) {
                fail(job, 'Import failed: ' + String.join(ir.errors, '; '));
                return;
            }

            recordUsage(job.Tenant__c, vr.questionCount);
            job.Generated_Question_Count__c =
                ir.questionsCreated + ir.questionsUpdated;
            job.Output_JSON__c = genJson.left(131000);
            setStatus(job, 'Completed', null);
            emit(
                job,
                'Completed',
                ir.questionsCreated + ir.questionsUpdated,
                null
            );
        } catch (Exception e) {
            AppLogger.error('GenerationJob', 'execute', 'Job ' + jobId, e);
            if (job != null)
                fail(job, e.getMessage());
        }
    }

    private void fail(Question_Generation_Job__c job, String reason) {
        setStatus(job, 'Failed', reason);
        emit(job, 'Failed', 0, reason);
    }

    private void setStatus(
        Question_Generation_Job__c job,
        String status,
        String message
    ) {
        job.Status__c = status;
        if (message != null)
            job.Error_Message__c = message.left(32000);
        update as system job;
    }

    private void emit(
        Question_Generation_Job__c job,
        String status,
        Integer count,
        String message
    ) {
        EventBus.publish(
            new QuestionGenerationJob__e(
                Job_Id__c = job.Id,
                Tenant_Id__c = job.Tenant__c,
                Status__c = status,
                Generated_Count__c = count,
                Message__c = message == null ? '' : message.left(255)
            )
        );
    }

    private void recordUsage(Id tenantId, Integer count) {
        String period = EntitlementGuard.currentPeriod();
        String uniqueKey = tenantId + ':' + period;
        Usage_Metric__c m = new Usage_Metric__c(
            Tenant__c = tenantId,
            Period__c = period,
            Questions_Served__c = count,
            Unique_Key__c = uniqueKey
        );
        Database.upsert(m, Usage_Metric__c.Unique_Key__c, false);
    }
}