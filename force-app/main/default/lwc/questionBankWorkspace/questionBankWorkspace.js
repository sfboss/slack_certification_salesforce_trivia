import { LightningElement, track, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import listBanks from '@salesforce/apex/CertGameQuestionBankController.listBanks';
import getBankDetail from '@salesforce/apex/CertGameQuestionBankController.getBankDetail';
import loadSamplesCatalog from '@salesforce/apex/CertGameQuestionBankController.loadSamplesCatalog';
import loadSampleJson from '@salesforce/apex/CertGameQuestionBankController.loadSampleJson';
import validateJson from '@salesforce/apex/CertGameQuestionBankController.validateJson';
import importPack from '@salesforce/apex/CertGameQuestionBankController.importPack';
import listExams from '@salesforce/apex/CertGameQuestionBankController.listExams';
import startGenerationJob from '@salesforce/apex/CertGameQuestionBankController.startGenerationJob';

const SOURCE_PASTE = 'paste';
const SOURCE_UPLOAD = 'upload';
const SOURCE_SAMPLE = 'sample';
const SOURCE_GENERATE = 'generate';

const STEP_SOURCE = 'source';
const STEP_VALIDATE = 'validate';
const STEP_COMMIT = 'commit';
const STEP_DONE = 'done';

export default class QuestionBankWorkspace extends LightningElement {
    @track banks = [];
    @track loading = false;
    @track selectedBankId = null;
    @track bankDetail = null;
    @track wireResult;

    // Wizard state
    @track wizardOpen = false;
    @track step = STEP_SOURCE;
    @track source = SOURCE_PASTE;
    @track jsonText = '';

    placeholderJson = '{ "exam": ..., "questionBank": ..., "questions": [...] }';
    placeholderPrompt = 'Focus areas, domains, difficulty bias...';
    @track validation = null;
    @track importResult = null;
    @track samples = [];
    @track selectedSampleKey = null;
    @track exams = [];
    @track selectedExamId = null;
    @track provider = 'OpenAI';
    @track questionCount = 5;
    @track promptText = '';
    @track busy = false;

    @wire(listBanks)
    wiredBanks(result) {
        this.wireResult = result;
        if (result.data) {
            this.banks = result.data.map((b) => this.decorateBank(b));
        } else if (result.error) {
            this.toast('Error', this.errMsg(result.error), 'error');
        }
    }

    @wire(listExams)
    wiredExams({ data }) {
        if (data) this.exams = data;
    }

    @wire(loadSamplesCatalog)
    wiredSamples({ data }) {
        if (data && data.samples) {
            this.samples = data.samples.map((s) => ({
                ...s,
                checked: false
            }));
        }
    }

    // -------------------- Derived --------------------

    get hasBanks() { return this.banks && this.banks.length > 0; }
    get bankCount() { return this.banks ? this.banks.length : 0; }
    get publishedTotal() {
        return this.banks.reduce((acc, b) => acc + (b.publishedCount || 0), 0);
    }
    get draftTotal() {
        return this.banks.reduce((acc, b) => acc + (b.draftCount || 0), 0);
    }
    get questionTotal() {
        return this.banks.reduce((acc, b) => acc + (b.questionCount || 0), 0);
    }

    get sourceOptions() {
        return [
            { label: 'Paste JSON', value: SOURCE_PASTE, description: 'Paste a full pack JSON into a textarea.' },
            { label: 'Upload .json file', value: SOURCE_UPLOAD, description: 'Pick a JSON file from your computer.' },
            { label: 'Pick a sample', value: SOURCE_SAMPLE, description: 'Load a bundled starter pack.' },
            { label: 'Generate via LLM', value: SOURCE_GENERATE, description: 'Create new questions from an exam and prompt.' }
        ];
    }
    get providerOptions() {
        return [
            { label: 'OpenAI', value: 'OpenAI' },
            { label: 'Gemini', value: 'Gemini' },
            { label: 'Claude', value: 'Claude' }
        ];
    }
    get examOptions() { return this.exams || []; }
    get sampleOptions() {
        return (this.samples || []).map((s) => ({ label: s.label, value: s.key }));
    }

    get isPaste() { return this.source === SOURCE_PASTE; }
    get isUpload() { return this.source === SOURCE_UPLOAD; }
    get isSample() { return this.source === SOURCE_SAMPLE; }
    get isGenerate() { return this.source === SOURCE_GENERATE; }

    get isStepSource() { return this.step === STEP_SOURCE; }
    get isStepValidate() { return this.step === STEP_VALIDATE; }
    get isStepCommit() { return this.step === STEP_COMMIT; }
    get isStepDone() { return this.step === STEP_DONE; }

    get step1Class() { return this.stepClass(STEP_SOURCE); }
    get step2Class() { return this.stepClass(STEP_VALIDATE); }
    get step3Class() { return this.stepClass(STEP_COMMIT); }

    stepClass(target) {
        const order = [STEP_SOURCE, STEP_VALIDATE, STEP_COMMIT, STEP_DONE];
        const current = order.indexOf(this.step);
        const at = order.indexOf(target);
        if (at < current) return 'qbw-step qbw-step-done';
        if (at === current) return 'qbw-step qbw-step-current';
        return 'qbw-step';
    }

    get nextDisabled() {
        if (this.busy) return true;
        if (this.isStepSource) {
            if (this.isGenerate) return !this.selectedExamId;
            if (this.isSample) return !this.selectedSampleKey;
            return !this.jsonText || this.jsonText.trim().length < 10;
        }
        if (this.isStepValidate) return !(this.validation && this.validation.valid);
        return false;
    }

    get commitDisabled() {
        return this.busy || !(this.validation && this.validation.valid);
    }

    get hasImportErrors() {
        return this.importResult && this.importResult.errors && this.importResult.errors.length > 0;
    }
    get hasImportDuplicates() {
        return this.importResult && this.importResult.duplicateExternalIds && this.importResult.duplicateExternalIds.length > 0;
    }
    get hasValidationErrors() {
        return this.validation && this.validation.errors && this.validation.errors.length > 0;
    }

    get selectedExamLabel() {
        const found = (this.exams || []).find((e) => e.value === this.selectedExamId);
        return found ? found.label : '';
    }
    get selectedSampleLabel() {
        const found = (this.samples || []).find((s) => s.key === this.selectedSampleKey);
        return found ? found.label : '';
    }

    // -------------------- Bank list --------------------

    decorateBank(b) {
        const status = b.status || 'Draft';
        const statusClass = status === 'Published'
            ? 'qbw-status qbw-status-published'
            : status === 'Retired'
                ? 'qbw-status qbw-status-retired'
                : 'qbw-status qbw-status-draft';
        const examLabel = b.examCode ? `${b.examCode} — ${b.examName || ''}` : (b.examName || '—');
        const last = b.lastImportedAt ? new Date(b.lastImportedAt).toLocaleString() : '—';
        return { ...b, statusClass, examLabel, lastImportedDisplay: last };
    }

    handleBankClick(e) {
        const id = e.currentTarget.dataset.id;
        this.selectedBankId = id;
        getBankDetail({ bankId: id })
            .then((d) => { this.bankDetail = d; })
            .catch((err) => this.toast('Error', this.errMsg(err), 'error'));
    }

    handleCloseDetail() {
        this.selectedBankId = null;
        this.bankDetail = null;
    }

    handleRefresh() {
        if (this.wireResult) refreshApex(this.wireResult);
    }

    handleReviewDeepLink(e) {
        const status = e.currentTarget.dataset.status || 'Needs Review';
        // Open the review console tab; we cannot pre-filter without nav state in plain LWC,
        // but firing the navigation is enough for the user to land in the right place.
        const url = `/lightning/n/Question_Review?c__status=${encodeURIComponent(status)}`;
        window.open(url, '_blank');
    }

    // -------------------- Wizard --------------------

    handleOpenWizard() {
        this.wizardOpen = true;
        this.resetWizard();
    }

    handleCloseWizard() {
        this.wizardOpen = false;
        this.resetWizard();
        if (this.importResult && this.importResult.success) {
            this.handleRefresh();
        }
    }

    resetWizard() {
        this.step = STEP_SOURCE;
        this.source = SOURCE_PASTE;
        this.jsonText = '';
        this.validation = null;
        this.importResult = null;
        this.selectedSampleKey = null;
        this.selectedExamId = null;
        this.provider = 'OpenAI';
        this.questionCount = 5;
        this.promptText = '';
        this.busy = false;
    }

    handleSourceChange(e) { this.source = e.detail.value; }
    handleJsonChange(e) { this.jsonText = e.target.value; }
    handleSampleChange(e) { this.selectedSampleKey = e.detail.value; }
    handleExamChange(e) { this.selectedExamId = e.detail.value; }
    handleProviderChange(e) { this.provider = e.detail.value; }
    handleCountChange(e) { this.questionCount = parseInt(e.target.value, 10) || 5; }
    handlePromptChange(e) { this.promptText = e.target.value; }

    async handleFileChange(e) {
        const file = e.target.files && e.target.files[0];
        if (!file) return;
        try {
            const text = await file.text();
            this.jsonText = text;
            this.toast('File loaded', `${file.name} (${text.length.toLocaleString()} chars)`, 'success');
        } catch (err) {
            this.toast('Read error', err && err.message ? err.message : 'Could not read file.', 'error');
        }
    }

    async handleNext() {
        if (this.isStepSource) {
            if (this.isGenerate) {
                await this.kickoffGeneration();
                return;
            }
            if (this.isSample && this.selectedSampleKey) {
                try {
                    this.busy = true;
                    this.jsonText = await loadSampleJson({ sampleKey: this.selectedSampleKey });
                } catch (err) {
                    this.toast('Sample load failed', this.errMsg(err), 'error');
                    this.busy = false;
                    return;
                } finally {
                    this.busy = false;
                }
            }
            await this.runValidation();
            return;
        }
        if (this.isStepValidate) {
            this.step = STEP_COMMIT;
            return;
        }
    }

    handleBack() {
        if (this.isStepValidate) { this.step = STEP_SOURCE; this.validation = null; }
        else if (this.isStepCommit) { this.step = STEP_VALIDATE; }
    }

    async runValidation() {
        if (!this.jsonText) {
            this.toast('Nothing to validate', 'Provide a JSON pack first.', 'warning');
            return;
        }
        try {
            this.busy = true;
            this.validation = await validateJson({ jsonBody: this.jsonText });
            this.step = STEP_VALIDATE;
        } catch (err) {
            this.toast('Validation error', this.errMsg(err), 'error');
        } finally {
            this.busy = false;
        }
    }

    async handleCommit() {
        try {
            this.busy = true;
            this.importResult = await importPack({ jsonBody: this.jsonText });
            this.step = STEP_DONE;
            if (this.importResult.success) {
                this.toast('Imported',
                    `${this.importResult.questionsCreated} created · ${this.importResult.questionsUpdated} updated. All Drafts.`,
                    'success');
            } else {
                this.toast('Import returned errors',
                    (this.importResult.errors && this.importResult.errors[0]) || 'See errors below.',
                    'warning');
            }
        } catch (err) {
            this.toast('Import error', this.errMsg(err), 'error');
        } finally {
            this.busy = false;
        }
    }

    async kickoffGeneration() {
        try {
            this.busy = true;
            const res = await startGenerationJob({
                examId: this.selectedExamId,
                provider: this.provider,
                questionCount: this.questionCount,
                promptText: this.promptText
            });
            this.toast('Generation queued',
                `Job ${res.jobId} status ${res.status}. Drafts will appear once the queueable completes.`,
                'success');
            this.handleCloseWizard();
        } catch (err) {
            this.toast('Could not queue job', this.errMsg(err), 'error');
        } finally {
            this.busy = false;
        }
    }

    // -------------------- Helpers --------------------

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
    errMsg(e) {
        if (!e) return 'Unknown error';
        if (e.body && e.body.message) return e.body.message;
        if (e.message) return e.message;
        return JSON.stringify(e);
    }
}
