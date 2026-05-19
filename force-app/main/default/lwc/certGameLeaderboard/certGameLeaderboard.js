import { LightningElement, api, track } from 'lwc';
import load from '@salesforce/apex/CertGameLeaderboardController.load';

export default class CertGameLeaderboard extends LightningElement {
    @api tenantId;
    @api defaultLimit = 25;

    @track examId = null;
    @track data;
    @track error;
    @track loading = false;

    connectedCallback() { this.fetch(); }

    async fetch() {
        this.loading = true;
        this.error = undefined;
        try {
            this.data = await load({
                tenantId: this.tenantId || null,
                examId: this.examId || null,
                limitRows: this.defaultLimit || 25
            });
        } catch (e) {
            this.error = this.msg(e);
            this.data = undefined;
        } finally {
            this.loading = false;
        }
    }

    get hasRows() { return this.data && this.data.rows && this.data.rows.length > 0; }
    get examOptions() {
        const base = [{ label: 'All exams', value: '' }];
        if (!this.data || !this.data.exams) return base;
        return base.concat(this.data.exams.map(e => ({ label: e.name, value: e.id })));
    }

    onExamChange(e) {
        this.examId = e.detail.value || null;
        this.fetch();
    }
    refresh() { this.fetch(); }
    msg(e) { return e && e.body && e.body.message ? e.body.message : (e && e.message) || 'Unknown error'; }
}