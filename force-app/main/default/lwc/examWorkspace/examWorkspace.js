import { LightningElement, track, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import listExams from '@salesforce/apex/CertGameExamWorkspaceController.listExams';
import getExamDetail from '@salesforce/apex/CertGameExamWorkspaceController.getExamDetail';
import mintPracticeUrl from '@salesforce/apex/CertGameExamWorkspaceController.mintPracticeUrl';

export default class ExamWorkspace extends LightningElement {

    @track summary = { exams: [], totalExams: 0, activeExams: 0, examsWithPublished: 0, totalQuestions: 0, totalPublishedQuestions: 0 };
    @track examDetail = null;
    @track selectedExamId = null;
    @track wireResult;

    @track filterText = '';
    @track filterTrack = 'all';
    @track filterPublished = false;

    // Practice mint state
    @track mintOpen = false;
    @track mintBusy = false;
    @track mintExamId = null;
    @track mintQuestionCount = 10;
    @track mintRandomMix = false;
    @track mintedUrl = null;

    // -------------------- Wires --------------------

    @wire(listExams)
    wiredExams(result) {
        this.wireResult = result;
        if (result.data) this.summary = this.decorateSummary(result.data);
    }

    // -------------------- Derived --------------------

    get viewMode() {
        if (this.mintOpen) return 'mint';
        if (this.examDetail) return 'detail';
        return 'list';
    }
    get isListView() { return this.viewMode === 'list'; }
    get isDetailView() { return this.viewMode === 'detail'; }
    get isMintView() { return this.viewMode === 'mint'; }

    get hasExams() { return this.summary.exams && this.summary.exams.length > 0; }

    get filteredExams() {
        const q = (this.filterText || '').trim().toLowerCase();
        return (this.summary.exams || []).filter((e) => {
            if (this.filterPublished && (e.publishedCount || 0) === 0) return false;
            if (this.filterTrack !== 'all' && (e.track || '') !== this.filterTrack) return false;
            if (!q) return true;
            return (e.name || '').toLowerCase().includes(q)
                || (e.code || '').toLowerCase().includes(q)
                || (e.track || '').toLowerCase().includes(q);
        });
    }
    get filteredCount() { return this.filteredExams.length; }

    get trackOptions() {
        const tracks = new Set();
        (this.summary.exams || []).forEach((e) => { if (e.track) tracks.add(e.track); });
        const out = [{ label: 'All tracks', value: 'all' }];
        Array.from(tracks).sort().forEach((t) => out.push({ label: t, value: t }));
        return out;
    }

    get mintExamLabel() {
        if (this.mintRandomMix) return 'Random across all exams';
        const found = (this.summary.exams || []).find((e) => e.id === this.mintExamId);
        return found ? (found.code ? `${found.code} — ${found.name}` : found.name) : 'Pick an exam';
    }

    // -------------------- List actions --------------------

    decorateSummary(s) {
        const exams = (s.exams || []).map((e) => {
            const last = e.lastActivityAt ? new Date(e.lastActivityAt).toLocaleDateString() : '—';
            const activeClass = e.active ? 'qew-pill qew-pill-active' : 'qew-pill qew-pill-inactive';
            const activeLabel = e.active ? 'Active' : 'Inactive';
            const readinessClass = (e.publishedCount || 0) >= 25 ? 'qew-readiness qew-r-ready'
                : (e.publishedCount || 0) > 0 ? 'qew-readiness qew-r-partial'
                : 'qew-readiness qew-r-empty';
            const readinessLabel = (e.publishedCount || 0) >= 25 ? 'Ready'
                : (e.publishedCount || 0) > 0 ? 'Partial'
                : 'Empty';
            const costDisplay = e.cost != null ? '$' + Number(e.cost).toFixed(0) : '—';
            return { ...e, lastActivityDisplay: last, activeClass, activeLabel, readinessClass, readinessLabel, costDisplay };
        });
        return { ...s, exams };
    }

    handleRefresh() { if (this.wireResult) refreshApex(this.wireResult); }
    handleFilterTextChange(e) { this.filterText = e.target.value; }
    handleTrackChange(e) { this.filterTrack = e.detail.value; }
    handlePublishedToggle(e) { this.filterPublished = e.target.checked; }

    handleExamClick(e) {
        const id = e.currentTarget.dataset.id;
        this.selectedExamId = id;
        getExamDetail({ examId: id })
            .then((d) => { this.examDetail = d; })
            .catch((err) => this.toast('Error', this.errMsg(err), 'error'));
    }

    handleBackToList() {
        this.examDetail = null;
        this.selectedExamId = null;
        if (this.mintOpen) this.handleCloseMint();
    }

    // -------------------- Mint practice link --------------------

    handleOpenMintFromList() {
        this.mintExamId = null;
        this.mintRandomMix = false;
        this.mintQuestionCount = 10;
        this.mintedUrl = null;
        this.mintOpen = true;
    }

    handleOpenMintForExam(e) {
        e.stopPropagation();
        this.mintExamId = e.currentTarget.dataset.id;
        this.mintRandomMix = false;
        this.mintQuestionCount = 10;
        this.mintedUrl = null;
        this.mintOpen = true;
    }

    handleOpenMintFromDetail() {
        if (!this.examDetail) return;
        this.mintExamId = this.examDetail.exam.id;
        this.mintRandomMix = false;
        this.mintQuestionCount = 10;
        this.mintedUrl = null;
        this.mintOpen = true;
    }

    handleCloseMint() {
        this.mintOpen = false;
        this.mintedUrl = null;
    }

    handleMintExamChange(e) { this.mintExamId = e.detail.value; }
    handleMintCountChange(e) { this.mintQuestionCount = parseInt(e.target.value, 10) || 10; }
    handleMintRandomToggle(e) {
        this.mintRandomMix = e.target.checked;
        if (this.mintRandomMix) this.mintExamId = null;
    }

    async handleMint() {
        try {
            this.mintBusy = true;
            const res = await mintPracticeUrl({
                examId: this.mintRandomMix ? null : this.mintExamId,
                numQuestions: this.mintQuestionCount
            });
            this.mintedUrl = res.url;
            this.toast('Practice link ready', 'Mobile-friendly URL minted. Copy and share.', 'success');
        } catch (err) {
            this.toast('Mint failed', this.errMsg(err), 'error');
        } finally {
            this.mintBusy = false;
        }
    }

    handleCopyUrl() {
        if (!this.mintedUrl) return;
        navigator.clipboard.writeText(this.mintedUrl)
            .then(() => this.toast('Copied', 'URL is on your clipboard.', 'success'))
            .catch(() => this.toast('Copy failed', 'Clipboard not available.', 'warning'));
    }

    handleOpenUrlInNewTab() {
        if (this.mintedUrl) window.open(this.mintedUrl, '_blank', 'noopener');
    }

    get mintDisabled() {
        if (this.mintBusy) return true;
        if (!this.mintRandomMix && !this.mintExamId) return true;
        if (!this.mintQuestionCount || this.mintQuestionCount < 1) return true;
        return false;
    }

    get mintExamOptions() {
        return (this.summary.exams || []).map((e) => ({
            label: e.code ? `${e.code} — ${e.name}` : e.name,
            value: e.id
        }));
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
