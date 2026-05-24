import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';

import listExams from '@salesforce/apex/CertGameTournamentService.listExams';
import listTournaments from '@salesforce/apex/CertGameTournamentService.listTournaments';
import getDetail from '@salesforce/apex/CertGameTournamentService.getTournamentDetail';
import createTournamentFull from '@salesforce/apex/CertGameTournamentService.createTournamentFull';
import updateTournament from '@salesforce/apex/CertGameTournamentService.updateTournament';
import searchPlayers from '@salesforce/apex/CertGameTournamentService.searchPlayers';
import enrollPlayer from '@salesforce/apex/CertGameTournamentService.enrollPlayer';
import enrollByEmail from '@salesforce/apex/CertGameTournamentService.enrollPlayersByEmail';
import removeParticipant from '@salesforce/apex/CertGameTournamentService.removeParticipant';
import startTournament from '@salesforce/apex/CertGameTournamentService.startTournament';
import completeTournament from '@salesforce/apex/CertGameTournamentService.completeTournament';
import cancelTournament from '@salesforce/apex/CertGameTournamentService.cancelTournament';
import recomputeStandings from '@salesforce/apex/CertGameTournamentService.recomputeStandings';

const STATUS_FILTERS = [
    { label: 'All', value: 'All' },
    { label: 'Scheduled', value: 'Scheduled' },
    { label: 'Active', value: 'Active' },
    { label: 'Complete', value: 'Complete' },
    { label: 'Cancelled', value: 'Cancelled' }
];

const BRACKET_OPTIONS = [
    { label: 'Round Robin', value: 'RoundRobin' },
    { label: 'Single Elimination', value: 'Elimination' },
    { label: 'Open Ladder', value: 'OpenLadder' }
];

const DETAIL_TABS = [
    { key: 'overview', label: 'Overview', icon: 'utility:summary' },
    { key: 'leaderboard', label: 'Leaderboard', icon: 'utility:trophy' },
    { key: 'participants', label: 'Participants', icon: 'utility:groups' },
    { key: 'settings', label: 'Settings', icon: 'utility:settings' }
];

export default class TournamentConsole extends LightningElement {
    @track tournaments = [];
    @track statusFilter = 'All';
    @track loading = false;
    @track error;

    // detail
    @track selectedId;
    @track detail;
    @track detailTab = 'overview';
    @track detailLoading = false;

    // exam options
    @track examOptions = [];

    // create / edit
    @track showCreate = false;
    @track form = this._emptyForm();
    @track editing = false;

    // enroll modal
    @track showEnroll = false;
    @track enrollTab = 'search';
    @track searchQuery = '';
    @track searchResults = [];
    @track bulkEmails = '';
    @track enrolling = false;

    statusFilters = STATUS_FILTERS;
    bracketOptions = BRACKET_OPTIONS;
    detailTabs = DETAIL_TABS;

    _wiredExamsResult;
    _wiredTournamentsResult;

    connectedCallback() {
        this.refresh();
    }

    @wire(listExams)
    wiredExams(result) {
        this._wiredExamsResult = result;
        if (result.data) {
            this.examOptions = result.data.map(o => ({ label: o.label, value: o.id }));
        }
    }

    @wire(listTournaments, { statusFilter: '$statusFilter' })
    wiredTournaments(result) {
        this._wiredTournamentsResult = result;
        if (result.data) {
            this.tournaments = result.data;
        } else if (result.error) {
            this.error = this._msg(result.error);
        }
    }

    get hasTournaments() { return this.tournaments && this.tournaments.length > 0; }
    get isAdminView() { return !this.selectedId; }
    get currentTab() { return this.detailTab; }
    get publicLink() {
        if (!this.detail || !this.detail.tournament || !this.detail.tournament.publicJoinToken) return '';
        const base = (window && window.location && window.location.origin) ? window.location.origin : '';
        return `${base}/certgame/?t=${this.detail.tournament.publicJoinToken}`;
    }

    get overviewActive() { return this.detailTab === 'overview'; }
    get leaderboardActive() { return this.detailTab === 'leaderboard'; }
    get participantsActive() { return this.detailTab === 'participants'; }
    get settingsActive() { return this.detailTab === 'settings'; }
    get isEnrollSearchTab() { return this.enrollTab === 'search'; }
    get isEnrollBulkTab() { return this.enrollTab === 'bulk'; }

    get computedTabs() {
        return this.detailTabs.map(t => ({
            ...t,
            cls: this.detailTab === t.key
                ? 'slds-tabs_default__item slds-is-active'
                : 'slds-tabs_default__item'
        }));
    }

    get computedTournaments() {
        return (this.tournaments || []).map(t => ({
            ...t,
            statusBadge: this._badgeClass(t.status),
            displayStart: this._fmt(t.startAt),
            displayEnd: this._fmt(t.endAt)
        }));
    }

    get computedParticipants() {
        if (!this.detail || !this.detail.participants) return [];
        return this.detail.participants.map(p => ({
            ...p,
            accuracyPct: p.accuracy != null ? Math.round(p.accuracy * 100) + '%' : '—',
            statusBadge: this._badgeClass(p.status),
            initials: this._initials(p.name)
        }));
    }

    get topThree() {
        if (!this.detail || !this.detail.participants) return [];
        return this.detail.participants
            .filter(p => p.rank != null && p.rank <= 3)
            .map(p => ({ ...p, podiumClass: 'podium podium-' + p.rank, initials: this._initials(p.name) }));
    }

    get canStart() {
        return this.detail && this.detail.tournament && this.detail.tournament.status === 'Scheduled';
    }
    get canComplete() {
        return this.detail && this.detail.tournament && this.detail.tournament.status === 'Active';
    }
    get canCancel() {
        return this.detail && this.detail.tournament &&
            this.detail.tournament.status !== 'Cancelled' && this.detail.tournament.status !== 'Complete';
    }

    // ---- Handlers ----

    handleStatusFilter(e) { this.statusFilter = e.detail.value; }

    handleRefresh() { this.refresh(); }

    async refresh() {
        try {
            this.loading = true;
            this.error = null;
            const promises = [];
            if (this._wiredTournamentsResult) promises.push(refreshApex(this._wiredTournamentsResult));
            if (this._wiredExamsResult) promises.push(refreshApex(this._wiredExamsResult));
            await Promise.all(promises);
            if (this.selectedId) await this._loadDetail(this.selectedId);
        } catch (e) { this.error = this._msg(e); }
        finally { this.loading = false; }
    }

    handleOpenCreate() {
        this.editing = false;
        this.form = this._emptyForm();
        this.showCreate = true;
    }

    handleOpenEdit() {
        if (!this.detail || !this.detail.tournament) return;
        const t = this.detail.tournament;
        this.editing = true;
        this.form = {
            name: t.name,
            description: this.detail.description,
            bracketType: t.bracketType || 'RoundRobin',
            examId: this.detail.examId,
            startAt: t.startAt,
            endAt: t.endAt,
            questionsPerMatch: t.questionsPerMatch,
            maxParticipants: t.maxParticipants,
            publicJoinEnabled: t.publicJoinEnabled,
            prizeDescription: t.prizeDescription
        };
        this.showCreate = true;
    }

    handleCancelCreate() { this.showCreate = false; }

    handleFormChange(e) {
        const f = e.target.dataset.field;
        let v = e.target.type === 'checkbox' ? e.target.checked : e.detail.value;
        if (v === undefined) v = e.target.value;
        this.form = { ...this.form, [f]: v };
    }

    async handleSaveTournament() {
        if (!this.form.name || !this.form.examId || !this.form.bracketType) {
            this._toast('Missing', 'Name, exam, and bracket type are required.', 'warning');
            return;
        }
        try {
            this.loading = true;
            if (this.editing) {
                await updateTournament({ tournamentId: this.selectedId, input: this.form });
                this._toast('Saved', 'Tournament updated.', 'success');
            } else {
                const id = await createTournamentFull({ input: this.form });
                this._toast('Created', 'Tournament created.', 'success');
                this.selectedId = id;
            }
            this.showCreate = false;
            await this.refresh();
        } catch (e) { this._toast('Error', this._msg(e), 'error'); }
        finally { this.loading = false; }
    }

    handleOpenTournament(e) {
        const id = e.currentTarget.dataset.id;
        this.selectedId = id;
        this.detailTab = 'overview';
        this._loadDetail(id);
    }

    handleBackToList() {
        this.selectedId = null;
        this.detail = null;
    }

    handleTabClick(e) {
        e.preventDefault();
        this.detailTab = e.currentTarget.dataset.tab;
    }

    async handleStart() {
        if (!confirm('Start this tournament? Public players will be able to play.')) return;
        try {
            this.loading = true;
            await startTournament({ tournamentId: this.selectedId });
            this._toast('Started', 'Tournament is now active.', 'success');
            await this.refresh();
        } catch (e) { this._toast('Error', this._msg(e), 'error'); }
        finally { this.loading = false; }
    }

    async handleComplete() {
        if (!confirm('Complete this tournament and declare the winner?')) return;
        try {
            this.loading = true;
            await completeTournament({ tournamentId: this.selectedId });
            this._toast('Complete', 'Winner declared.', 'success');
            await this.refresh();
        } catch (e) { this._toast('Error', this._msg(e), 'error'); }
        finally { this.loading = false; }
    }

    async handleCancel() {
        if (!confirm('Cancel this tournament? This cannot be undone.')) return;
        try {
            this.loading = true;
            await cancelTournament({ tournamentId: this.selectedId });
            this._toast('Cancelled', 'Tournament cancelled.', 'success');
            await this.refresh();
        } catch (e) { this._toast('Error', this._msg(e), 'error'); }
        finally { this.loading = false; }
    }

    async handleRecompute() {
        try {
            this.loading = true;
            await recomputeStandings({ tournamentId: this.selectedId });
            await this._loadDetail(this.selectedId);
            this._toast('Refreshed', 'Standings recomputed.', 'success');
        } catch (e) { this._toast('Error', this._msg(e), 'error'); }
        finally { this.loading = false; }
    }

    handleCopyLink() {
        const link = this.publicLink;
        if (!link) return;
        try {
            if (navigator && navigator.clipboard) {
                navigator.clipboard.writeText(link);
                this._toast('Copied', 'Public join link copied to clipboard.', 'success');
            } else {
                const tmp = document.createElement('textarea');
                tmp.value = link;
                document.body.appendChild(tmp);
                tmp.select();
                document.execCommand('copy');
                document.body.removeChild(tmp);
                this._toast('Copied', 'Public join link copied.', 'success');
            }
        } catch (e) { this._toast('Copy failed', this._msg(e), 'warning'); }
    }

    handleOpenEnroll() {
        this.showEnroll = true;
        this.enrollTab = 'search';
        this.searchQuery = '';
        this.searchResults = [];
        this.bulkEmails = '';
        this._runSearch();
    }

    handleCloseEnroll() { this.showEnroll = false; }
    handleEnrollTab(e) { this.enrollTab = e.currentTarget.dataset.tab; }
    handleSearchInput(e) { this.searchQuery = e.target.value; this._debouncedSearch(); }
    handleBulkInput(e) { this.bulkEmails = e.target.value; }

    _debouncedSearch() {
        clearTimeout(this._t);
        this._t = setTimeout(() => this._runSearch(), 250);
    }

    async _runSearch() {
        try {
            const rows = await searchPlayers({ tournamentId: this.selectedId, query: this.searchQuery || '' });
            this.searchResults = rows;
        } catch (e) { this._toast('Search failed', this._msg(e), 'error'); }
    }

    async handleAddPlayer(e) {
        const playerId = e.currentTarget.dataset.id;
        try {
            this.enrolling = true;
            await enrollPlayer({ tournamentId: this.selectedId, playerId });
            this._toast('Enrolled', 'Player added.', 'success');
            await this._runSearch();
            await this._loadDetail(this.selectedId);
        } catch (e2) { this._toast('Error', this._msg(e2), 'error'); }
        finally { this.enrolling = false; }
    }

    async handleBulkSubmit() {
        const list = (this.bulkEmails || '').split(/[\s,;]+/).map(s => s.trim()).filter(Boolean);
        if (list.length === 0) { this._toast('Empty', 'Paste at least one email.', 'warning'); return; }
        try {
            this.enrolling = true;
            const r = await enrollByEmail({ tournamentId: this.selectedId, emails: list });
            let msg = `Added ${r.added}, already enrolled ${r.existing}, not found ${r.notFound}`;
            if (r.notFoundEmails && r.notFoundEmails.length > 0) {
                msg += ' (' + r.notFoundEmails.slice(0, 5).join(', ') + (r.notFoundEmails.length > 5 ? '…' : '') + ')';
            }
            this._toast('Bulk enroll', msg, r.notFound > 0 ? 'warning' : 'success');
            this.bulkEmails = '';
            await this._loadDetail(this.selectedId);
        } catch (e) { this._toast('Error', this._msg(e), 'error'); }
        finally { this.enrolling = false; }
    }

    async handleRemove(e) {
        const id = e.currentTarget.dataset.id;
        if (!confirm('Remove this participant?')) return;
        try {
            await removeParticipant({ participantId: id });
            await this._loadDetail(this.selectedId);
            this._toast('Removed', 'Participant removed.', 'success');
        } catch (e2) { this._toast('Error', this._msg(e2), 'error'); }
    }

    // ---- internal ----

    async _loadDetail(id) {
        try {
            this.detailLoading = true;
            this.detail = await getDetail({ tournamentId: id });
        } catch (e) { this.error = this._msg(e); }
        finally { this.detailLoading = false; }
    }

    _emptyForm() {
        return {
            name: '',
            description: '',
            bracketType: 'RoundRobin',
            examId: null,
            startAt: null,
            endAt: null,
            questionsPerMatch: 10,
            maxParticipants: null,
            publicJoinEnabled: true,
            prizeDescription: ''
        };
    }

    _badgeClass(status) {
        switch ((status || '').toLowerCase()) {
            case 'active': return 'badge badge-active';
            case 'scheduled': return 'badge badge-scheduled';
            case 'complete': case 'completed': return 'badge badge-complete';
            case 'winner': return 'badge badge-winner';
            case 'cancelled': return 'badge badge-cancelled';
            case 'eliminated': case 'withdrawn': return 'badge badge-muted';
            default: return 'badge';
        }
    }

    _initials(name) {
        if (!name) return '?';
        return name.trim().split(/\s+/).map(p => p[0]).slice(0, 2).join('').toUpperCase();
    }

    _fmt(dt) {
        if (!dt) return '—';
        try { return new Date(dt).toLocaleString(); } catch (e) { return dt; }
    }

    _toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    _msg(e) {
        if (!e) return 'Unknown error';
        if (e.body && e.body.message) return e.body.message;
        if (e.message) return e.message;
        return JSON.stringify(e);
    }
}
