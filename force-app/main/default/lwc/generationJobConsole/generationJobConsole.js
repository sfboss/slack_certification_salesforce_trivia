import { LightningElement, track, wire } from "lwc";
import { refreshApex } from "@salesforce/apex";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { subscribe, unsubscribe, onError } from "lightning/empApi";

import listJobs from "@salesforce/apex/CertGameGenerationJobController.listJobs";
import getJobDetail from "@salesforce/apex/CertGameGenerationJobController.getJobDetail";
import listExamDomains from "@salesforce/apex/CertGameGenerationJobController.listExamDomains";
import startJob from "@salesforce/apex/CertGameGenerationJobController.startJob";
import rerunJob from "@salesforce/apex/CertGameGenerationJobController.rerunJob";
import listExams from "@salesforce/apex/CertGameQuestionBankController.listExams";

const CHANNEL = "/event/QuestionGenerationJob__e";

const STEP_TARGET = "target";
const STEP_MIX = "mix";
const STEP_NOTES = "notes";
const STEP_CONFIRM = "confirm";

export default class GenerationJobConsole extends LightningElement {
    @track summary = {
        jobs: [],
        totalJobs: 0,
        runningJobs: 0,
        completedJobs: 0,
        failedJobs: 0,
        questionsGenerated: 0,
        tokenCostMtd: 0
    };
    @track jobDetail = null;
    @track selectedJobId = null;
    @track liveEvents = [];
    @track wireResult;
    @track exams = [];

    // Wizard
    @track wizardOpen = false;
    @track step = STEP_TARGET;
    @track selectedExamId = null;
    @track examDomains = [];
    @track selectedDomains = [];
    @track difficulty = "Mixed";
    @track provider = "OpenAI";
    @track questionCount = 5;
    @track promptNotes = "";
    @track busy = false;

    placeholderPrompt = "Focus areas, edge cases, scenarios to emphasize...";
    empSubscription = {};

    // -------------------- Wires --------------------

    @wire(listJobs, { maxRows: 50 })
    wiredJobs(result) {
        this.wireResult = result;
        if (result.data) this.summary = this.decorateSummary(result.data);
    }

    @wire(listExams)
    wiredExams({ data }) {
        if (data) this.exams = data;
    }

    // -------------------- emp/api live updates --------------------

    connectedCallback() {
        onError((err) => {
            // Surface a single console warning, not a noisy stream
            console.error("CometD error", err);
        });
        subscribe(CHANNEL, -1, (ev) => this.handleLiveEvent(ev))
            .then((s) => {
                this.empSubscription = s;
            })
            .catch((err) => console.error("subscribe failed", err));
    }
    disconnectedCallback() {
        if (this.empSubscription && this.empSubscription.channel) {
            unsubscribe(this.empSubscription, () => {});
        }
    }
    handleLiveEvent(ev) {
        const p = ev && ev.data && ev.data.payload ? ev.data.payload : {};
        this.liveEvents = [
            {
                ts: new Date().toLocaleTimeString(),
                jobId: p.Job_Id__c,
                status: p.Status__c,
                count: p.Generated_Count__c,
                message: p.Message__c
            },
            ...this.liveEvents
        ].slice(0, 10);
        // Refresh the historical list whenever a Completed/Failed event lands
        if (p.Status__c === "Completed" || p.Status__c === "Failed") {
            this.handleRefresh();
        }
    }

    // -------------------- Derived --------------------

    get viewMode() {
        if (this.wizardOpen) return "wizard";
        if (this.jobDetail) return "detail";
        return "list";
    }
    get isListView() {
        return this.viewMode === "list";
    }
    get isWizardView() {
        return this.viewMode === "wizard";
    }
    get isDetailView() {
        return this.viewMode === "detail";
    }

    get hasJobs() {
        return (
            this.summary && this.summary.jobs && this.summary.jobs.length > 0
        );
    }
    get hasLiveEvents() {
        return this.liveEvents && this.liveEvents.length > 0;
    }
    get tokenCostMtdDisplay() {
        const v =
            this.summary && this.summary.tokenCostMtd != null
                ? this.summary.tokenCostMtd
                : 0;
        return "$" + Number(v).toFixed(2);
    }

    get sourceOptions() {
        return this.exams || [];
    }
    get providerOptions() {
        return [
            { label: "OpenAI", value: "OpenAI" },
            { label: "Gemini", value: "Gemini" },
            { label: "Claude", value: "Claude" }
        ];
    }
    get difficultyOptions() {
        return [
            { label: "Mixed (recommended)", value: "Mixed" },
            { label: "Beginner only", value: "Beginner" },
            { label: "Intermediate only", value: "Intermediate" },
            { label: "Advanced only", value: "Advanced" }
        ];
    }

    get isStepTarget() {
        return this.step === STEP_TARGET;
    }
    get isStepMix() {
        return this.step === STEP_MIX;
    }
    get isStepNotes() {
        return this.step === STEP_NOTES;
    }
    get isStepConfirm() {
        return this.step === STEP_CONFIRM;
    }

    get step1Class() {
        return this.stepClass(STEP_TARGET);
    }
    get step2Class() {
        return this.stepClass(STEP_MIX);
    }
    get step3Class() {
        return this.stepClass(STEP_NOTES);
    }
    get step4Class() {
        return this.stepClass(STEP_CONFIRM);
    }

    stepClass(target) {
        const order = [STEP_TARGET, STEP_MIX, STEP_NOTES, STEP_CONFIRM];
        const at = order.indexOf(target);
        const cur = order.indexOf(this.step);
        if (at < cur) return "gjc-step gjc-step-done";
        if (at === cur) return "gjc-step gjc-step-current";
        return "gjc-step";
    }

    get selectedExamLabel() {
        const found = (this.exams || []).find(
            (e) => e.value === this.selectedExamId
        );
        return found ? found.label : "";
    }
    get selectedDomainsLabel() {
        return (
            (this.selectedDomains || []).join(", ") || "All domains (no filter)"
        );
    }
    get nextDisabled() {
        if (this.busy) return true;
        if (this.isStepTarget)
            return (
                !this.selectedExamId ||
                !this.questionCount ||
                this.questionCount < 1
            );
        return false;
    }

    // -------------------- List actions --------------------

    handleRefresh() {
        if (this.wireResult) refreshApex(this.wireResult);
    }

    decorateSummary(s) {
        const jobs = (s.jobs || []).map((j) => {
            const status = j.status || "Queued";
            const statusClass =
                status === "Completed"
                    ? "gjc-pill gjc-pill-completed"
                    : status === "Failed"
                      ? "gjc-pill gjc-pill-failed"
                      : status === "Running"
                        ? "gjc-pill gjc-pill-running"
                        : "gjc-pill gjc-pill-queued";
            const examLabel = j.examCode
                ? `${j.examCode} — ${j.examName || ""}`
                : j.examName || "—";
            const createdDisplay = j.createdDate
                ? new Date(j.createdDate).toLocaleString()
                : "—";
            const costDisplay = j.tokenCostUsd
                ? "$" + Number(j.tokenCostUsd).toFixed(3)
                : "—";
            return {
                ...j,
                statusClass,
                examLabel,
                createdDisplay,
                costDisplay
            };
        });
        return { ...s, jobs };
    }

    handleJobClick(e) {
        const id = e.currentTarget.dataset.id;
        this.selectedJobId = id;
        getJobDetail({ jobId: id })
            .then((d) => {
                this.jobDetail = d;
            })
            .catch((err) => this.toast("Error", this.errMsg(err), "error"));
    }

    handleBackToList() {
        this.jobDetail = null;
        this.selectedJobId = null;
        if (this.wizardOpen) this.handleCloseWizard();
    }

    async handleRerun(e) {
        e.stopPropagation();
        const id = e.currentTarget.dataset.id;
        try {
            await rerunJob({ jobId: id });
            this.toast(
                "Re-queued",
                "A fresh generation job has been queued.",
                "success"
            );
            this.handleRefresh();
        } catch (err) {
            this.toast("Re-run failed", this.errMsg(err), "error");
        }
    }

    handleCopyJson() {
        if (!this.jobDetail || !this.jobDetail.outputJson) return;
        navigator.clipboard
            .writeText(this.jobDetail.outputJson)
            .then(() =>
                this.toast(
                    "Copied",
                    "Output JSON copied to clipboard.",
                    "success"
                )
            )
            .catch(() =>
                this.toast(
                    "Copy failed",
                    "Clipboard not available in this browser.",
                    "warning"
                )
            );
    }

    handleDownloadJson() {
        if (!this.jobDetail || !this.jobDetail.outputJson) return;
        const blob = new Blob([this.jobDetail.outputJson], {
            type: "application/json"
        });
        const url = URL.createObjectURL(blob);
        const a = document.createElement("a");
        a.href = url;
        a.download = `generation-job-${this.jobDetail.job.id}.json`;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        URL.revokeObjectURL(url);
    }

    handleViewQuestionsDeepLink() {
        window.open(
            "/lightning/n/Question_Review?c__status=Needs Review",
            "_blank"
        );
    }

    // -------------------- Wizard --------------------

    handleOpenWizard() {
        this.wizardOpen = true;
        this.resetWizard();
    }

    handleCloseWizard() {
        this.wizardOpen = false;
        this.resetWizard();
    }

    resetWizard() {
        this.step = STEP_TARGET;
        this.selectedExamId = null;
        this.examDomains = [];
        this.selectedDomains = [];
        this.difficulty = "Mixed";
        this.provider = "OpenAI";
        this.questionCount = 5;
        this.promptNotes = "";
        this.busy = false;
    }

    handleExamChange(e) {
        this.selectedExamId = e.detail.value;
        this.selectedDomains = [];
        if (this.selectedExamId) {
            listExamDomains({ examId: this.selectedExamId })
                .then((rows) => {
                    this.examDomains = rows;
                })
                .catch(() => {
                    this.examDomains = [];
                });
        } else {
            this.examDomains = [];
        }
    }
    handleProviderChange(e) {
        this.provider = e.detail.value;
    }
    handleCountChange(e) {
        this.questionCount = parseInt(e.target.value, 10) || 5;
    }
    handleDifficultyChange(e) {
        this.difficulty = e.detail.value;
    }
    handleDomainsChange(e) {
        this.selectedDomains = e.detail.value || [];
    }
    handleNotesChange(e) {
        this.promptNotes = e.target.value;
    }

    handleNext() {
        if (this.isStepTarget) {
            this.step = STEP_MIX;
            return;
        }
        if (this.isStepMix) {
            this.step = STEP_NOTES;
            return;
        }
        if (this.isStepNotes) {
            this.step = STEP_CONFIRM;
            return;
        }
    }
    handleBack() {
        if (this.isStepConfirm) {
            this.step = STEP_NOTES;
            return;
        }
        if (this.isStepNotes) {
            this.step = STEP_MIX;
            return;
        }
        if (this.isStepMix) {
            this.step = STEP_TARGET;
            return;
        }
    }

    async handleConfirm() {
        try {
            this.busy = true;
            const res = await startJob({
                input: {
                    examId: this.selectedExamId,
                    provider: this.provider,
                    questionCount: this.questionCount,
                    difficulty: this.difficulty,
                    domains: this.selectedDomains,
                    promptNotes: this.promptNotes
                }
            });
            this.toast(
                "Generation queued",
                `Job ${res.jobId} is ${res.status}. Drafts will appear in the Review Console once the run completes.`,
                "success"
            );
            this.handleCloseWizard();
            this.handleRefresh();
        } catch (err) {
            this.toast("Could not queue job", this.errMsg(err), "error");
        } finally {
            this.busy = false;
        }
    }

    // -------------------- Helpers --------------------

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
    errMsg(e) {
        if (!e) return "Unknown error";
        if (e.body && e.body.message) return e.body.message;
        if (e.message) return e.message;
        return JSON.stringify(e);
    }
}