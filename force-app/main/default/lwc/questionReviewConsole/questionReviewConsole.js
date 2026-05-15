import { LightningElement, track, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import listDrafts from '@salesforce/apex/QuestionReviewController.listDrafts';
import setStatus from '@salesforce/apex/QuestionReviewController.setStatus';

export default class QuestionReviewConsole extends LightningElement {
    @track status = 'Draft';
    @track questions = [];
    @track loading = false;
    wiredResult;

    statusOptions = [
        { label: 'Draft', value: 'Draft' },
        { label: 'Reviewed', value: 'Reviewed' },
        { label: 'Published', value: 'Published' },
        { label: 'Retired', value: 'Retired' }
    ];

    @wire(listDrafts, { status: '$status', maxRows: 100 })
    wireQuestions(result) {
        this.wiredResult = result;
        if (result.data) {
            this.questions = result.data;
        } else if (result.error) {
            this.toast('Error', this.errMsg(result.error), 'error');
        }
    }

    handleStatusChange(e) { this.status = e.detail.value; }

    async handleSetStatus(e) {
        const id = e.target.dataset.id;
        const next = e.target.dataset.next;
        this.loading = true;
        try {
            await setStatus({ questionId: id, newStatus: next });
            this.toast('Updated', `Question moved to ${next}`, 'success');
            await refreshApex(this.wiredResult);
        } catch (err) {
            this.toast('Error', this.errMsg(err), 'error');
        } finally {
            this.loading = false;
        }
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
    errMsg(e) { return e && e.body && e.body.message ? e.body.message : (e.message || 'Unknown error'); }

    get hasQuestions() { return this.questions && this.questions.length > 0; }
    get nextStatusLabel() {
        return this.status === 'Draft' ? 'Mark Reviewed'
             : this.status === 'Reviewed' ? 'Publish'
             : this.status === 'Published' ? 'Retire' : '';
    }
    get nextStatusValue() {
        return this.status === 'Draft' ? 'Reviewed'
             : this.status === 'Reviewed' ? 'Published'
             : this.status === 'Published' ? 'Retired' : null;
    }
}
