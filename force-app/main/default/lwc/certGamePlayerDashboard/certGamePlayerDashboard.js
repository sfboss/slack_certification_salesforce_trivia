import { LightningElement, api, track } from 'lwc';
import load from '@salesforce/apex/CertGamePlayerDashboardController.load';
import loadCurrentUser from '@salesforce/apex/CertGamePlayerDashboardController.loadCurrentUser';

export default class CertGamePlayerDashboard extends LightningElement {
    @api recordId;
    @api playerId;
    @api currentUser = false;

    @track data;
    @track error;
    @track loading = false;

    connectedCallback() { this.fetch(); }

    async fetch() {
        this.loading = true;
        this.error = undefined;
        try {
            const pid = this.resolvedId;
            if (this.currentUser || !pid) {
                this.data = await loadCurrentUser();
            } else {
                this.data = await load({ playerId: pid });
            }
        } catch (e) {
            this.error = this.msg(e);
            this.data = undefined;
        } finally {
            this.loading = false;
        }
    }

    get resolvedId() { return this.recordId || this.playerId || null; }
    get hasPlayer() { return this.data && this.data.player; }
    get hasDomains() { return this.data && this.data.domains && this.data.domains.length > 0; }
    get hasAnswers() { return this.data && this.data.recentAnswers && this.data.recentAnswers.length > 0; }
    get hasAchievements() { return this.data && this.data.achievements && this.data.achievements.length > 0; }
    get hasPlans() { return this.data && this.data.studyPlans && this.data.studyPlans.length > 0; }
    get rankLabel() { const p = this.data.player; return `Rank ${p.rank} of ${p.rankPool}`; }
    get statTiles() {
        const p = this.data.player;
        return [
            { label: 'Total points', value: p.totalPoints },
            { label: 'Games played', value: p.totalGames },
            { label: 'Accuracy', value: `${p.accuracy || 0}%` },
            { label: 'Last 25 acc.', value: `${p.accuracyLast50 || 0}%` },
            { label: 'Current streak', value: `${p.currentStreakDays}d` },
            { label: 'Longest streak', value: `${p.longestStreakDays}d` }
        ];
    }
    msg(e) { return e && e.body && e.body.message ? e.body.message : (e.message || 'Unknown error'); }
}