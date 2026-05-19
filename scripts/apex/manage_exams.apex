// scripts/apex/manage_exams.apex
// Quick admin actions. Uncomment the block you need, then run:
//   sf apex run -o certgame -f scripts/apex/manage_exams.apex

// --- 1. List exams with question counts ---
for (CertGameExamManager.ExamStats s : CertGameExamManager.listAll()) {
    System.debug('EXAM ' + s.code + ' | ' + s.name
        + ' | active=' + s.active
        + ' | published=' + s.published
        + ' | reviewed=' + s.reviewed
        + ' | draft=' + s.draft
        + ' | retired=' + s.retired);
}

// --- 2. Publish every Draft/Reviewed question for ONE exam ---
// Integer n = CertGameExamManager.publishAll('CRT-LWC');
// System.debug('Published ' + n + ' questions for CRT-LWC');

// --- 3. Publish ALL Draft/Reviewed across all exams ---
// Integer n = CertGameExamManager.publishAll(null);
// System.debug('Published ' + n + ' total questions');

// --- 4. Deactivate / Reactivate an exam ---
// CertGameExamManager.setActive('CRT-LWC', false);
// CertGameExamManager.setActive('CRT-LWC', true);

// --- 5. Retire an exam (Published -> Retired, Active=false) ---
// Integer r = CertGameExamManager.retireExam('CRT-RPT');
// System.debug('Retired ' + r + ' questions for CRT-RPT');
