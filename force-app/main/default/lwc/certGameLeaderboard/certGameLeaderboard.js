import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import load from '@salesforce/apex/CertGameLeaderboardController.load';

const WINDOW_OPTIONS = [
    { label: 'All time', value: 'all' },
    { label: 'Last 30 days', value: '30d' },
    { label: 'Last 7 days', value: '7d' },
    { label: 'Today', value: 'today' }
];

const LIMIT_OPTIONS = [
    { label: 'Top 10', value: 10 },
    { label: 'Top 25', value: 25 },
    { label: 'Top 50', value: 50 },
    { label: 'Top 100', value: 100 }
];

const SORTABLE = new Set(['rank', 'displayName', 'points', 'games', 'answerCount', 'accuracy', 'currentStreak', 'longestStreak', 'achievementCount', 'lastPlayedAt']);

export default class CertGameLeaderboard extends NavigationMixin(LightningElement) {
    @api tenantId;
    @api defaultLimit = 25;

    @track examId = null;
    @track windowKey = 'all';
    @track rowLimit = 25;
    @track searchTerm = '';
    @track sortBy = 'rank';
    @track sortDir = 'asc';

    @track data;
    @track error;
    @track loading = false;

    connectedCallback() {
        if (this.defaultLimit) this.rowLimit = Number(this.defaultLimit) || 25;
        this.fetch();
    }

    async fetch() {
        this.loading = true;
        this.error = undefined;
        try {
            this.data = await load({
                tenantId: this.tenantId || null,
                examId: this.examId || null,
                windowKey: this.windowKey,
                limitRows: this.rowLimit
            });
        } catch (e) {
            this.error = this.msg(e);
            this.data = undefined;
        } finally {
            this.loading = false;
        }
    }

    // ------- option lists -------
    get windowOptions() { return WINDOW_OPTIONS; }
    get limitOptions() { return LIMIT_OPTIONS; }
    get examOptions() {
        const base = [{ label: 'All exams', value: '' }];
        if (!this.data || !this.data.exams) return base;
        return base.concat(this.data.exams.map(e => ({ label: e.name, value: e.id })));
    }

    // ------- summary / KPI tiles -------
    get summary() { return this.data && this.data.summary; }
    get hasSummary() { return !!this.summary; }
    get kpiTiles() {
        const s = this.summary;
        if (!s) return [];
        return [
            { key: 'players', label: 'Active players', value: this.fmtInt(s.activePlayers), sub: `of ${this.fmtInt(s.totalPlayers)} registered`, icon: 'utility:groups', tone: 'brand' },
            { key: 'games', label: 'Games played', value: this.fmtInt(s.totalGames), sub: `${this.fmtInt(s.totalAnswers)} answers`, icon: 'utility:trophy', tone: 'success' },
            { key: 'points', label: 'Points awarded', value: this.fmtInt(s.totalPoints), sub: s.windowLabel, icon: 'utility:advertising', tone: 'warning' },
            { key: 'accuracy', label: 'Avg accuracy', value: `${(s.avgAccuracy || 0).toFixed(1)}%`, sub: `Top streak: ${this.fmtInt(s.topStreak)}d`, icon: 'utility:target', tone: 'inverse' }
        ];
    }

    // ------- podium (top 3) -------
    get podium() {
        if (!this.data || !this.data.rows) return [];
        const top = this.data.rows.slice(0, 3);
        // visual order: silver(2), gold(1), bronze(3)
        const byRank = {};
        top.forEach(r => { byRank[r.rank] = r; });
        const ordered = [];
        if (byRank[2]) ordered.push({ ...byRank[2], podiumClass: 'podium-card podium-silver', label: '2nd', emoji: '🥈' });
        if (byRank[1]) ordered.push({ ...byRank[1], podiumClass: 'podium-card podium-gold center', label: '1st', emoji: '🥇' });
        if (byRank[3]) ordered.push({ ...byRank[3], podiumClass: 'podium-card podium-bronze', label: '3rd', emoji: '🥉' });
        return ordered.map(r => ({
            ...r,
            initials: this.initialsOf(r.displayName),
            accuracyStr: `${(r.accuracy || 0).toFixed(1)}%`
        }));
    }
    get hasPodium() { return this.podium.length > 0; }

    // ------- filtered + sorted rows -------
    get rows() {
        if (!this.data || !this.data.rows) return [];
        let list = this.data.rows.slice();
        const term = (this.searchTerm || '').trim().toLowerCase();
        if (term) {
            list = list.filter(r => (r.displayName || '').toLowerCase().includes(term));
        }
        const dir = this.sortDir === 'desc' ? -1 : 1;
        const key = this.sortBy;
        list.sort((a, b) => {
            const av = a[key]; const bv = b[key];
            if (av == null && bv == null) return 0;
            if (av == null) return 1;
            if (bv == null) return -1;
            if (typeof av === 'string') return av.localeCompare(bv) * dir;
            return (av - bv) * dir;
        });
        return list.map((r, i) => ({
            ...r,
            displayRank: r.rank,
            initials: this.initialsOf(r.displayName),
            accuracyStr: r.accuracy != null ? `${(r.accuracy).toFixed(1)}%` : '—',
            accuracyStyle: `width:${Math.max(0, Math.min(100, r.accuracy || 0))}%`,
            accuracyBarClass: this.accuracyBarClass(r.accuracy),
            lastPlayedStr: r.lastPlayedAt ? this.relTime(r.lastPlayedAt) : '—',
            rowClass: 'lb-row' + (i % 2 === 0 ? ' lb-row-even' : '') + (r.medal ? ` lb-row-${r.medal}` : ''),
            medalBadgeClass: r.medal ? `medal-badge medal-${r.medal}` : 'medal-badge medal-none',
            medalIcon: r.medal === 'gold' ? '🥇' : r.medal === 'silver' ? '🥈' : r.medal === 'bronze' ? '🥉' : '',
            streakIcon: (r.currentStreak || 0) >= 3 ? '🔥' : '',
            achievementsLabel: r.achievementCount ? `🏆 ${r.achievementCount}` : '—'
        }));
    }
    get hasRows() { return this.rows.length > 0; }
    get totalRowsLabel() {
        const t = this.data && this.data.rows ? this.data.rows.length : 0;
        const v = this.rows.length;
        return v === t ? `${t} players` : `${v} of ${t} players`;
    }
    get generatedAtLabel() {
        const s = this.summary;
        if (!s || !s.generatedAt) return '';
        return `Updated ${this.relTime(s.generatedAt)}`;
    }
    get windowSubtitle() {
        const s = this.summary;
        return s ? s.windowLabel : '';
    }

    // ------- sort header helpers -------
    sortIcon(col) {
        if (this.sortBy !== col) return '';
        return this.sortDir === 'asc' ? ' ▲' : ' ▼';
    }
    get rankSortLabel() { return `#${this.sortIcon('rank')}`; }
    get nameSortLabel() { return `Player${this.sortIcon('displayName')}`; }
    get pointsSortLabel() { return `Points${this.sortIcon('points')}`; }
    get gamesSortLabel() { return `Games${this.sortIcon('games')}`; }
    get accuracySortLabel() { return `Accuracy${this.sortIcon('accuracy')}`; }
    get streakSortLabel() { return `Streak${this.sortIcon('currentStreak')}`; }
    get longestSortLabel() { return `Best${this.sortIcon('longestStreak')}`; }
    get achievementsSortLabel() { return `Badges${this.sortIcon('achievementCount')}`; }
    get lastPlayedSortLabel() { return `Last seen${this.sortIcon('lastPlayedAt')}`; }

    // ------- event handlers -------
    onExamChange(e) { this.examId = e.detail.value || null; this.fetch(); }
    onWindowChange(e) { this.windowKey = e.detail.value; this.fetch(); }
    onLimitChange(e) { this.rowLimit = Number(e.detail.value) || 25; this.fetch(); }
    onSearch(e) { this.searchTerm = e.target.value || ''; }
    onClearSearch() { this.searchTerm = ''; }
    refresh() { this.fetch(); }

    onSort(e) {
        const col = e.currentTarget.dataset.col;
        if (!SORTABLE.has(col)) return;
        if (this.sortBy === col) {
            this.sortDir = this.sortDir === 'asc' ? 'desc' : 'asc';
        } else {
            this.sortBy = col;
            // sensible defaults
            this.sortDir = (col === 'displayName') ? 'asc' : (col === 'rank' ? 'asc' : 'desc');
        }
    }

    onRowClick(e) {
        const id = e.currentTarget.dataset.id;
        if (!id) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: id, objectApiName: 'Player__c', actionName: 'view' }
        });
    }

    onExportCsv() {
        const rows = this.rows;
        if (!rows.length) {
            this.toast('No data to export', 'warning');
            return;
        }
        const headers = ['Rank', 'Player', 'Points', 'Games', 'Answers', 'Correct', 'Accuracy', 'Current Streak', 'Longest Streak', 'Achievements', 'Last Played'];
        const lines = [headers.join(',')];
        rows.forEach(r => {
            lines.push([
                r.rank,
                this.csvCell(r.displayName),
                r.points || 0,
                r.games || 0,
                r.answerCount || 0,
                r.correctCount || 0,
                r.accuracy || 0,
                r.currentStreak || 0,
                r.longestStreak || 0,
                r.achievementCount || 0,
                r.lastPlayedAt || ''
            ].join(','));
        });
        const blob = new Blob([lines.join('\n')], { type: 'text/csv' });
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = `leaderboard-${this.windowKey}-${Date.now()}.csv`;
        a.click();
        URL.revokeObjectURL(url);
        this.toast('CSV exported', 'success');
    }

    // ------- helpers -------
    accuracyBarClass(a) {
        const v = a || 0;
        if (v >= 85) return 'acc-bar acc-bar-high';
        if (v >= 60) return 'acc-bar acc-bar-mid';
        return 'acc-bar acc-bar-low';
    }
    initialsOf(name) {
        if (!name) return '?';
        const parts = name.trim().split(/\s+/);
        return ((parts[0] || '')[0] || '?') + (parts.length > 1 ? (parts[parts.length - 1][0] || '') : '');
    }
    relTime(iso) {
        const t = new Date(iso).getTime();
        if (isNaN(t)) return '';
        const diff = Date.now() - t;
        const s = Math.floor(diff / 1000);
        if (s < 60) return 'just now';
        const m = Math.floor(s / 60);
        if (m < 60) return `${m}m ago`;
        const h = Math.floor(m / 60);
        if (h < 24) return `${h}h ago`;
        const d = Math.floor(h / 24);
        if (d < 30) return `${d}d ago`;
        const mo = Math.floor(d / 30);
        if (mo < 12) return `${mo}mo ago`;
        return `${Math.floor(mo / 12)}y ago`;
    }
    fmtInt(n) {
        if (n == null) return '0';
        return Number(n).toLocaleString();
    }
    csvCell(v) {
        const s = (v == null ? '' : String(v));
        return /[",\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
    }
    toast(message, variant) {
        this.dispatchEvent(new ShowToastEvent({ message, variant: variant || 'info' }));
    }
    msg(e) { return e && e.body && e.body.message ? e.body.message : (e && e.message) || 'Unknown error'; }
}