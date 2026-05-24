import { LightningElement, wire, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToast';
import listUsers from '@salesforce/apex/UserAdminController.listUsers';
import summary from '@salesforce/apex/UserAdminController.summary';

const COLUMNS = [
    { label: 'Display name', fieldName: 'displayName', type: 'text', wrapText: false },
    { label: 'Google email', fieldName: 'googleEmail', type: 'email' },
    {
        label: 'Linked',
        fieldName: 'googleLinked',
        type: 'boolean',
        initialWidth: 80,
        cellAttributes: { alignment: 'center' }
    },
    { label: 'Slack user', fieldName: 'slackUserId', type: 'text', initialWidth: 140 },
    { label: 'Tenant', fieldName: 'tenantName', type: 'text' },
    { label: 'Web last login', fieldName: 'webLastLoginAt', type: 'date', typeAttributes: { year: 'numeric', month: 'short', day: '2-digit', hour: '2-digit', minute: '2-digit' } },
    { label: 'Last played', fieldName: 'lastPlayedAt', type: 'date', typeAttributes: { year: 'numeric', month: 'short', day: '2-digit', hour: '2-digit', minute: '2-digit' } },
    { label: 'Games', fieldName: 'totalGames', type: 'number', initialWidth: 90, cellAttributes: { alignment: 'right' } },
    { label: 'Points', fieldName: 'totalPoints', type: 'number', initialWidth: 100, cellAttributes: { alignment: 'right' } },
    { label: 'Accuracy', fieldName: 'accuracy', type: 'percent', initialWidth: 110, cellAttributes: { alignment: 'right' }, typeAttributes: { maximumFractionDigits: 1 } }
];

export default class UserAdminConsole extends LightningElement {
    columns = COLUMNS;
    @track filter = '';
    wiredUsersResult;
    wiredSummaryResult;

    @wire(listUsers)
    wiredUsers(result) {
        this.wiredUsersResult = result;
    }

    @wire(summary)
    wiredSummary(result) {
        this.wiredSummaryResult = result;
    }

    get rows() {
        const data = this.wiredUsersResult && this.wiredUsersResult.data;
        if (!data) return [];
        if (!this.filter) return data;
        const f = this.filter.toLowerCase();
        return data.filter(r =>
            (r.displayName || '').toLowerCase().includes(f) ||
            (r.googleEmail || '').toLowerCase().includes(f) ||
            (r.slackUserId || '').toLowerCase().includes(f) ||
            (r.tenantName || '').toLowerCase().includes(f)
        );
    }

    get isLoading() {
        return !(this.wiredUsersResult && (this.wiredUsersResult.data || this.wiredUsersResult.error));
    }

    get loadError() {
        return this.wiredUsersResult && this.wiredUsersResult.error
            ? (this.wiredUsersResult.error.body && this.wiredUsersResult.error.body.message) || 'Failed to load users'
            : null;
    }

    get rowCount() {
        return this.rows.length;
    }

    get summaryRow() {
        const s = (this.wiredSummaryResult && this.wiredSummaryResult.data) || {};
        return {
            players: s.players || 0,
            googleLinked: s.googleLinked || 0,
            slackLinked: s.slackLinked || 0,
            tenants: s.tenants || 0
        };
    }

    handleFilterChange(event) {
        this.filter = event.target.value || '';
    }

    handleRefresh() {
        Promise.all([
            refreshApex(this.wiredUsersResult),
            refreshApex(this.wiredSummaryResult)
        ])
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({ title: 'Refreshed', variant: 'success' }));
            })
            .catch(err => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Refresh failed',
                    message: (err && err.body && err.body.message) || 'unknown',
                    variant: 'error'
                }));
            });
    }
}
