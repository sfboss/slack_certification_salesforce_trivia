import { LightningElement, track, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import fetchQueue from '@salesforce/apex/QuestionReviewController.fetchQueue';
import saveEdits from '@salesforce/apex/QuestionReviewController.saveEdits';
import markFactsVerified from '@salesforce/apex/QuestionReviewController.markFactsVerified';
import clearFactsVerified from '@salesforce/apex/QuestionReviewController.clearFactsVerified';
import publish from '@salesforce/apex/QuestionReviewController.publish';
import needsRevisionApex from '@salesforce/apex/QuestionReviewController.needsRevision';
import retireApex from '@salesforce/apex/QuestionReviewController.retire';
import verifyCitation from '@salesforce/apex/QuestionReviewController.verifyCitation';

const STATUS_OPTIONS = [
    { label: 'Needs Review', value: 'Needs Review' },
    { label: 'Draft', value: 'Draft' },
    { label: 'Needs Revision', value: 'Needs Revision' },
    { label: 'Fact Verified', value: 'Fact Verified' },
    { label: 'Reviewed', value: 'Reviewed' },
    { label: 'Published', value: 'Published' },
    { label: 'Retired', value: 'Retired' }
];

const SORT_OPTIONS = [
    { label: 'Oldest first', value: 'CreatedDate' },
    { label: 'Difficulty', value: 'Difficulty__c' },
    { label: 'Domain', value: 'Exam_Domain__r.Name' }
];

const DIFFICULTY_OPTIONS = [
    { label: 'Beginner', value: 'Beginner' },
    { label: 'Intermediate', value: 'Intermediate' },
    { label: 'Advanced', value: 'Advanced' },
    { label: 'Expert', value: 'Expert' }
];

const QTYPE_OPTIONS = [
    { label: 'Single Select', value: 'Single Select' },
    { label: 'Multi Select', value: 'Multi Select' },
    { label: 'True False', value: 'True False' }
];

export default class QuestionReviewConsole extends LightningElement {
    @track status = 'Needs Review';
    @track sortBy = 'CreatedDate';
    @track queue = [];
    @track total = 0;
    @track index = 0;
    @track loading = false;
    @track saving = false;
    @track dirty = false;
    @track current = null;
    @track citationStatusById = {};
    wiredResult;

    statusOptions = STATUS_OPTIONS;
    sortOptions = SORT_OPTIONS;
    difficultyOptions = DIFFICULTY_OPTIONS;
    qtypeOptions = QTYPE_OPTIONS;

    connectedCallback() {
        window.addEventListener('keydown', this.handleKey);
    }
    disconnectedCallback() {
        window.removeEventListener('keydown', this.handleKey);
    }

    @wire(fetchQueue, { status: '$status', sortBy: '$sortBy', maxRows: 100 })
    wireQueue(result) {
        this.wiredResult = result;
        if (result.data) {
            this.queue = (result.data.questions || []).map((q) => this.normalize(q));
            this.total = result.data.total || 0;
            this.index = 0;
            this.loadCurrent();
        } else if (result.error) {
            this.toast('Error', this.errMsg(result.error), 'error');
        }
    }

    // ------------------------------ getters

    get hasQueue() { return this.queue && this.queue.length > 0; }
    get isEmpty() { return !this.loading && !this.hasQueue; }
    get queuePosition() {
        if (!this.hasQueue) return '0 of 0';
        return `${this.index + 1} of ${this.queue.length}`;
    }
    get atStart() { return this.index <= 0; }
    get atEnd() { return this.index >= this.queue.length - 1; }
    get factVerified() { return !!(this.current && this.current.factCheckPassed); }
    get publishDisabled() { return !this.factVerified || this.saving; }
    get publishHelp() {
        return this.factVerified ? 'Two confirmations recorded — safe to publish.' : 'Verify facts first to enable publish.';
    }
    get factsButtonLabel() { return this.factVerified ? '✓ Facts Verified' : 'Facts Verified'; }
    get factsButtonVariant() { return this.factVerified ? 'success' : 'brand-outline'; }
    get saveButtonLabel() { return this.dirty ? 'Save draft edits *' : 'Save draft edits'; }
    get reviewerNotesRequired() { return false; }
    get currentChoices() {
        return this.current ? this.current.choices : [];
    }
    get currentCitations() {
        if (!this.current) return [];
        return this.current.citations.map((c) => ({
            ...c,
            statusIcon: this.citationStatusById[c.id] || (c.brokenLink ? '❌' : (c.lastVerifiedDate ? '✅' : ''))
        }));
    }

    // ------------------------------ navigation

    handleStatusChange(e) { this.status = e.detail.value; this.dirty = false; }
    handleSortChange(e) { this.sortBy = e.detail.value; }

    handlePrev() { if (!this.atStart) { this.index--; this.loadCurrent(); } }
    handleNext() { if (!this.atEnd) { this.index++; this.loadCurrent(); } }
    handleSkip() {
        if (!this.hasQueue) return;
        const cur = this.queue.splice(this.index, 1)[0];
        this.queue.push(cur);
        if (this.index >= this.queue.length) this.index = 0;
        this.loadCurrent();
    }

    loadCurrent() {
        if (!this.hasQueue) { this.current = null; return; }
        // Deep clone the entry at index so edits don't mutate the wire cache.
        this.current = JSON.parse(JSON.stringify(this.queue[this.index]));
        this.dirty = false;
        this.citationStatusById = {};
    }

    normalize(q) {
        return {
            ...q,
            choices: (q.choices || []).map((c) => ({ ...c })),
            citations: (q.citations || []).map((c) => ({ ...c }))
        };
    }

    // ------------------------------ edit handlers

    handleField(e) {
        const f = e.target.dataset.field;
        const val = e.target.value;
        if (!this.current || !f) return;
        this.current[f] = val;
        this.dirty = true;
    }

    handleChoiceText(e) {
        const id = e.target.dataset.id;
        const val = e.target.value;
        this.current.choices = this.current.choices.map((c) =>
            c.id === id ? { ...c, text: val } : c
        );
        this.dirty = true;
    }

    handleChoiceExplanation(e) {
        const id = e.target.dataset.id;
        const val = e.target.value;
        this.current.choices = this.current.choices.map((c) =>
            c.id === id ? { ...c, explanation: val } : c
        );
        this.dirty = true;
    }

    handleCorrectChange(e) {
        const id = e.target.dataset.id;
        const isMulti = this.current.questionType === 'Multi Select';
        this.current.choices = this.current.choices.map((c) => {
            if (c.id === id) return { ...c, isCorrect: e.target.checked };
            return isMulti ? c : { ...c, isCorrect: false };
        });
        this.dirty = true;
    }

    // ------------------------------ citation verify

    async handleVerifyCitation(e) {
        const id = e.target.dataset.id;
        if (!id) return;
        this.citationStatusById = { ...this.citationStatusById, [id]: '…' };
        try {
            const updated = await verifyCitation({ citationId: id });
            this.current.citations = this.current.citations.map((c) =>
                c.id === id ? { ...c, brokenLink: updated.brokenLink, lastVerifiedDate: updated.lastVerifiedDate } : c
            );
            this.citationStatusById = { ...this.citationStatusById, [id]: updated.brokenLink ? '❌' : '✅' };
        } catch (err) {
            this.citationStatusById = { ...this.citationStatusById, [id]: '❌' };
            this.toast('Verify failed', this.errMsg(err), 'warning');
        }
    }

    // ------------------------------ actions

    buildPayload() {
        if (!this.current) return null;
        return {
            id: this.current.id,
            questionText: this.current.questionText,
            scenarioText: this.current.scenarioText,
            explanation: this.current.explanation,
            difficulty: this.current.difficulty,
            questionType: this.current.questionType,
            tags: this.current.tags,
            reviewerNotes: this.current.reviewerNotes,
            choices: this.current.choices.map((c) => ({
                id: c.id,
                label: c.label,
                text: c.text,
                isCorrect: !!c.isCorrect,
                explanation: c.explanation,
                sortOrder: c.sortOrder
            })),
            citations: this.current.citations.map((c) => ({
                id: c.id,
                title: c.title,
                url: c.url,
                sourceType: c.sourceType,
                brokenLink: !!c.brokenLink,
                lastVerifiedDate: c.lastVerifiedDate
            }))
        };
    }

    async handleSaveDraft() {
        const payload = this.buildPayload();
        if (!payload) return;
        this.saving = true;
        try {
            await saveEdits({ payload });
            this.dirty = false;
            this.toast('Saved', 'Draft edits saved.', 'success');
        } catch (err) {
            this.toast('Error', this.errMsg(err), 'error');
        } finally {
            this.saving = false;
        }
    }

    async handleToggleFacts() {
        if (!this.current) return;
        this.saving = true;
        try {
            if (this.factVerified) {
                await clearFactsVerified({ questionId: this.current.id });
                this.current.factCheckPassed = false;
                this.current.status = 'Needs Review';
                this.toast('Cleared', 'Fact-check confirmation removed.', 'info');
            } else {
                await markFactsVerified({ payload: this.buildPayload() });
                this.current.factCheckPassed = true;
                this.current.factCheckedDate = new Date().toISOString();
                this.current.status = 'Fact Verified';
                this.dirty = false;
                this.toast('Facts verified', 'You may now publish.', 'success');
            }
        } catch (err) {
            this.toast('Error', this.errMsg(err), 'error');
        } finally {
            this.saving = false;
        }
    }

    async handlePublish() {
        if (this.publishDisabled) return;
        this.saving = true;
        try {
            await publish({ payload: this.buildPayload() });
            this.toast('Published', 'Question is now live in Slack trivia.', 'success');
            await this.advanceAfterAction();
        } catch (err) {
            this.toast('Error', this.errMsg(err), 'error');
        } finally {
            this.saving = false;
        }
    }

    async handleNeedsRevision() {
        if (!this.current) return;
        if (!this.current.reviewerNotes || !this.current.reviewerNotes.trim()) {
            this.toast('Notes required', 'Add reviewer notes before sending for revision.', 'warning');
            const ta = this.template.querySelector('[data-field="reviewerNotes"]');
            if (ta) ta.focus();
            return;
        }
        this.saving = true;
        try {
            await needsRevisionApex({ payload: this.buildPayload() });
            this.toast('Sent for revision', 'Marked Needs Revision.', 'success');
            await this.advanceAfterAction();
        } catch (err) {
            this.toast('Error', this.errMsg(err), 'error');
        } finally {
            this.saving = false;
        }
    }

    async handleRetire() {
        if (!this.current) return;
        if (!confirm('Retire this question? It will no longer appear in trivia.')) return;
        this.saving = true;
        try {
            await retireApex({ questionId: this.current.id });
            this.toast('Retired', 'Question retired.', 'success');
            await this.advanceAfterAction();
        } catch (err) {
            this.toast('Error', this.errMsg(err), 'error');
        } finally {
            this.saving = false;
        }
    }

    async advanceAfterAction() {
        // Remove the current item locally, then refresh the wire to pick up any new entries.
        this.queue.splice(this.index, 1);
        if (this.index >= this.queue.length) this.index = Math.max(0, this.queue.length - 1);
        this.loadCurrent();
        try { await refreshApex(this.wiredResult); } catch (e) { /* swallow */ }
    }

    // ------------------------------ keyboard shortcuts

    handleKey = (evt) => {
        if (!this.isElementVisible()) return;
        const tag = (evt.target && evt.target.tagName) || '';
        if (['INPUT', 'TEXTAREA', 'SELECT'].includes(tag)) return;
        switch (evt.key.toLowerCase()) {
            case 'j': this.handleNext(); break;
            case 'k': this.handlePrev(); break;
            case 'f': this.handleToggleFacts(); break;
            case 'p': if (!this.publishDisabled) this.handlePublish(); break;
            case 'r': this.handleNeedsRevision(); break;
            case 'x': this.handleRetire(); break;
            default: return;
        }
    };

    isElementVisible() {
        const el = this.template.querySelector('.qrc-root');
        return el && el.offsetParent !== null;
    }

    // ------------------------------ utils

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