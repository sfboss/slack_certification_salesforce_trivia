trigger QuestionAnsweredEventTrigger on QuestionAnswered__e (after insert) {
    CertGameAchievementService.evaluate(Trigger.new);
}