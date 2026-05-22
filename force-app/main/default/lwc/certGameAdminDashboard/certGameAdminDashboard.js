import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import load from '@salesforce/apex/CertGameAdminDashboardController.load';

const COLORS = {
    blue: '#1B96FF',
    blueDark: '#0176D3',
    blueDeep: '#014486',
    teal: '#2EB4A6',
    gray: '#706E6B',
    border: '#D8DDE6',
    success: '#2E844A',
    warning: '#FE9339',
    error: '#EA001E'
};

const HELP_TEXT = {
    questionsServed: 'Questions delivered during the current billing period.',
    gamesStarted: 'Game sessions launched during the current billing period.',
    activePlayers: 'Distinct players who answered at least one question this period.'
};

function formatNumber(value) {
    return new Intl.NumberFormat('en-US').format(value || 0);
}

function formatCurrency(value) {
    if (value === null || value === undefined) {
        return '—';
    }
    return new Intl.NumberFormat('en-US', {
        style: 'currency',
        currency: 'USD',
        maximumFractionDigits: 0
    }).format(value);
}

function formatDecimal(value) {
    if (value === null || value === undefined) {
        return '—';
    }
    return new Intl.NumberFormat('en-US', { maximumFractionDigits: 0 }).format(value);
}

function formatShortDate(value) {
    if (!value) {
        return '';
    }
    return new Intl.DateTimeFormat('en-US', { month: 'short', day: 'numeric' }).format(new Date(value));
}

function chartBaseOptions() {
    return {
        animation: false,
        plugins: {
            legend: {
                labels: {
                    color: '#181818',
                    usePointStyle: true,
                    boxWidth: 8,
                    font: {
                        family: 'Salesforce Sans, Arial, sans-serif'
                    }
                }
            },
            tooltip: {
                backgroundColor: '#16325C',
                titleColor: '#FFFFFF',
                bodyColor: '#FFFFFF',
                padding: 12,
                cornerRadius: 4,
                displayColors: true
            }
        }
    };
}

export default class CertGameAdminDashboard extends LightningElement {
    @api tenantId;
    @track data;
    @track error;
    @track loading = false;

    sortField = 'games';
    sortDirection = 'desc';
    expandedErrorKey;
    errorMenuKey;
    examMenuId;
    selectedExam;
    selectedErrorGroup;

    connectedCallback() {
        this.fetch();
    }

    renderedCallback() {
        this.template.querySelectorAll('[data-width]').forEach(element => {
            element.style.width = `${element.dataset.width}%`;
        });
    }

    @api
    async refreshData() {
        await this.fetch();
    }

    async fetch() {
        this.loading = true;
        this.error = undefined;
        try {
            this.data = await load({ tenantId: this.tenantId || null });
        } catch (e) {
            this.error = this.msg(e);
            this.data = undefined;
        } finally {
            this.loading = false;
        }
    }

    handleRefresh() {
        this.fetch();
        this.toast('Refreshed', 'Dashboard metrics refreshed.', 'success');
    }

    handleSort(event) {
        const field = event.currentTarget.dataset.field;
        if (this.sortField === field) {
            this.sortDirection = this.sortDirection === 'asc' ? 'desc' : 'asc';
        } else {
            this.sortField = field;
            this.sortDirection = field === 'examName' ? 'asc' : 'desc';
        }
    }

    handleExamOpen(event) {
        const examId = event.currentTarget.dataset.id;
        this.selectedExam = this.topExamRows.find(row => row.examId === examId);
        this.examMenuId = undefined;
    }

    handleExamMenuToggle(event) {
        const examId = event.currentTarget.dataset.id;
        this.examMenuId = this.examMenuId === examId ? undefined : examId;
    }

    handleExamAction(event) {
        const examId = event.currentTarget.dataset.id;
        const action = event.currentTarget.dataset.action;
        const exam = this.topExamRows.find(row => row.examId === examId);

        this.examMenuId = undefined;

        if (action === 'details') {
            this.selectedExam = exam;
            return;
        }

        this.toast('Exam action', `${exam.examName} is ready for a deeper drill-in flow.`, 'info');
    }

    handleCloseModal() {
        this.selectedExam = undefined;
        this.selectedErrorGroup = undefined;
    }

    handleReviewHealth(event) {
        const focusLabel = event.currentTarget.dataset.focus;
        this.dispatchEvent(new CustomEvent('healthaction', { detail: { focusLabel } }));
    }

    handleErrorExpand(event) {
        const key = event.currentTarget.dataset.key;
        this.expandedErrorKey = this.expandedErrorKey === key ? undefined : key;
    }

    handleErrorMenuToggle(event) {
        const key = event.currentTarget.dataset.key;
        this.errorMenuKey = this.errorMenuKey === key ? undefined : key;
    }

    handleErrorAction(event) {
        const key = event.currentTarget.dataset.key;
        const action = event.currentTarget.dataset.action;
        const group = this.groupedErrorRows.find(row => row.key === key);

        this.errorMenuKey = undefined;
        this.toast(action === 'acknowledge' ? 'Acknowledged' : 'Muted pattern', `${group.title} updated.`, 'success');
    }

    handleErrorGroupOpen(event) {
        const key = event.currentTarget.dataset.key;
        this.selectedErrorGroup = this.groupedErrorRows.find(row => row.key === key);
    }

    handleViewAllErrors(event) {
        event.preventDefault();
        const firstGroup = this.groupedErrorRows[0];
        if (firstGroup) {
            this.selectedErrorGroup = {
                ...firstGroup,
                modalTitle: 'Recent error groups',
                showAllGroups: true,
                groups: this.groupedErrorRows
            };
        }
    }

    handleRunGenerationJob() {
        this.dispatchEvent(new CustomEvent('navigate', {
            detail: {
                tab: 'gen',
                title: 'Generation jobs',
                message: 'Open the Generation Jobs tab to manage live generation activity.',
                variant: 'info'
            }
        }));
    }

    get kpiTiles() {
        const k = this.data && this.data.kpis ? this.data.kpis : {};
        const questionHealth = this.data && this.data.questionHealth ? this.data.questionHealth : {};
        const activity = this.activityRows;
        const gamesSeries = activity.map(point => point.gamesStarted);
        const answersSeries = activity.map(point => point.answers);

        return [
            {
                key: 'totalPlayers',
                row: 'engagement',
                label: 'Total Players',
                eyebrow: 'Engagement',
                value: formatNumber(k.totalPlayers || 0),
                sub: 'Registered competitors',
                className: 'slds-tile slds-tile_board kpi-tile',
                chartConfig: null
            },
            {
                key: 'activePlayers7d',
                row: 'engagement',
                label: 'Active (7d)',
                eyebrow: 'Engagement',
                value: formatNumber(k.activePlayers7d || 0),
                sub: 'Players who answered',
                className: `slds-tile slds-tile_board kpi-tile${(k.activePlayers7d || 0) === 0 ? ' kpi-tile_warning' : ''}`,
                chartConfig: null
            },
            {
                key: 'gamesStarted7d',
                row: 'engagement',
                label: 'Games Started (7d)',
                eyebrow: 'Engagement',
                value: formatNumber(k.gamesStarted7d || 0),
                sub: 'Launches over the last 7 days',
                className: 'slds-tile slds-tile_board kpi-tile',
                chartConfig: this.sparklineConfig(gamesSeries, COLORS.blueDark)
            },
            {
                key: 'answers7d',
                row: 'content',
                label: 'Answers (7d)',
                eyebrow: 'Content & Activity',
                value: formatNumber(k.questionsAnswered7d || 0),
                sub: `${k.accuracy7d || 0}% accuracy`,
                className: 'slds-tile slds-tile_board kpi-tile',
                chartConfig: this.sparklineConfig(answersSeries.slice(-7), COLORS.teal)
            },
            {
                key: 'answers30d',
                row: 'content',
                label: 'Answers (30d)',
                eyebrow: 'Content & Activity',
                value: formatNumber(k.questionsAnswered30d || 0),
                sub: 'Rolling 30-day total',
                className: 'slds-tile slds-tile_board kpi-tile',
                chartConfig: this.sparklineConfig(answersSeries, COLORS.teal)
            },
            {
                key: 'publishedQuestions',
                row: 'content',
                label: 'Published Qs',
                eyebrow: 'Content & Activity',
                value: formatNumber(questionHealth.published || 0),
                sub: 'Live question inventory',
                className: 'slds-tile slds-tile_board kpi-tile',
                chartConfig: null
            },
            {
                key: 'draftQuestions',
                row: 'content',
                label: 'Draft Qs',
                eyebrow: 'Content & Activity',
                value: formatNumber(questionHealth.draft || 0),
                sub: 'Awaiting review and publication',
                className: 'slds-tile slds-tile_board kpi-tile',
                chartConfig: null
            }
        ];
    }

    get engagementTiles() {
        return this.kpiTiles.filter(tile => tile.row === 'engagement');
    }

    get contentTiles() {
        return this.kpiTiles.filter(tile => tile.row === 'content');
    }

    get healthTiles() {
        const h = this.data && this.data.questionHealth ? this.data.questionHealth : {};
        return [
            { label: 'Draft', value: h.draft || 0 },
            { label: 'Reviewed', value: h.reviewed || 0 },
            { label: 'Published', value: h.published || 0 },
            { label: 'Retired', value: h.retired || 0 }
        ];
    }

    get usageBars() {
        const u = this.data && this.data.usage ? this.data.usage : {};
        const bars = [];
        const push = (key, label, val, quota) => {
            if (!quota || quota <= 0) {
                bars.push({
                    key,
                    label,
                    help: HELP_TEXT[key],
                    text: `${formatNumber(val || 0)}`,
                    pct: 0,
                    hasQuota: false
                });
                return;
            }
            const pct = Math.min(100, Math.round(((val || 0) * 100) / quota));
            bars.push({
                key,
                label,
                help: HELP_TEXT[key],
                text: `${formatNumber(val || 0)} / ${formatNumber(quota)}`,
                pct,
                hasQuota: true,
                isEmpty: pct === 0,
                percentLabel: `${pct}%`,
                toneClass: pct >= 90 ? 'meter-fill_error' : pct >= 70 ? 'meter-fill_warning' : 'meter-fill_brand',
                barClass: `slds-progress-bar__value meter-fill ${pct >= 90 ? 'meter-fill_error' : pct >= 70 ? 'meter-fill_warning' : 'meter-fill_brand'}`
            });
        };
        push('questionsServed', 'Questions served', u.questionsServed, u.questionsServedQuota);
        push('gamesStarted', 'Games started', u.gamesStarted, u.gamesQuota);
        push('activePlayers', 'Active players', u.activePlayers, 0);
        return bars;
    }

    get usageFooter() {
        const usage = this.data && this.data.usage ? this.data.usage : {};
        return [
            { key: 'cost', label: 'LLM cost', value: formatCurrency(usage.llmCostUsd) },
            { key: 'tokensIn', label: 'Tokens in', value: formatDecimal(usage.llmTokensIn) },
            { key: 'tokensOut', label: 'Tokens out', value: formatDecimal(usage.llmTokensOut) }
        ];
    }

    get activityRows() {
        const rows = this.data && this.data.activity30d ? this.data.activity30d : [];
        return rows.map(point => ({
            key: point.day,
            dayLabel: formatShortDate(point.day),
            gamesStarted: point.gamesStarted || 0,
            answers: point.answers || 0
        }));
    }

    get activityChartConfig() {
        const rows = this.activityRows;
        return {
            type: 'bar',
            data: {
                labels: rows.map(row => row.dayLabel),
                datasets: [
                    {
                        type: 'bar',
                        label: 'Games started',
                        data: rows.map(row => row.gamesStarted),
                        backgroundColor: COLORS.blue,
                        borderRadius: 8,
                        borderSkipped: false,
                        yAxisID: 'yGames'
                    },
                    {
                        type: 'line',
                        label: 'Answers',
                        data: rows.map(row => row.answers),
                        borderColor: COLORS.teal,
                        backgroundColor: 'rgba(46, 180, 166, 0.18)',
                        borderWidth: 3,
                        pointRadius: 0,
                        pointHoverRadius: 4,
                        tension: 0.35,
                        yAxisID: 'yAnswers'
                    }
                ]
            },
            options: {
                ...chartBaseOptions(),
                scales: {
                    x: {
                        grid: { display: false },
                        ticks: { color: COLORS.gray, maxTicksLimit: 8 }
                    },
                    yGames: {
                        beginAtZero: true,
                        position: 'left',
                        grid: { color: '#EEF1F6' },
                        ticks: { color: COLORS.gray }
                    },
                    yAnswers: {
                        beginAtZero: true,
                        position: 'right',
                        grid: { drawOnChartArea: false },
                        ticks: { color: COLORS.gray }
                    }
                }
            }
        };
    }

    get questionPathSteps() {
        const steps = this.healthTiles;
        const focus = steps.reduce((current, step) => {
            if (!current || step.value > current.value) {
                return step;
            }
            return current;
        }, null);

        return steps.map(step => ({
            ...step,
            key: step.label.toLowerCase(),
            ariaSelected: focus && focus.label === step.label ? 'true' : 'false',
            className: `slds-path__item ${focus && focus.label === step.label ? 'slds-is-current slds-is-active' : step.value > 0 ? 'slds-is-complete' : 'slds-is-incomplete'}`
        }));
    }

    get brokenCitationCard() {
        const health = this.data && this.data.questionHealth ? this.data.questionHealth : {};
        return {
            count: formatNumber(health.brokenCitations || 0),
            buttonLabel: 'Review',
            focus: 'Broken citations'
        };
    }

    get lowQualityCard() {
        const health = this.data && this.data.questionHealth ? this.data.questionHealth : {};
        return {
            count: formatNumber(health.lowQuality || 0),
            buttonLabel: 'Review',
            focus: 'Low quality'
        };
    }

    get topExamRows() {
        const source = this.data && this.data.topExams ? [...this.data.topExams] : [];
        const maxGames = source.reduce((maxValue, row) => Math.max(maxValue, row.games || 0), 0) || 1;

        source.sort((left, right) => {
            let leftValue = left[this.sortField] || 0;
            let rightValue = right[this.sortField] || 0;

            if (this.sortField === 'examName') {
                leftValue = left.examName || '';
                rightValue = right.examName || '';
            }

            if (leftValue === rightValue) {
                return 0;
            }

            const direction = this.sortDirection === 'asc' ? 1 : -1;
            return leftValue > rightValue ? direction : -direction;
        });

        return source.map(row => ({
            ...row,
            gamesText: formatNumber(row.games || 0),
            answersText: formatNumber(row.answers || 0),
            menuClass: `slds-dropdown-trigger slds-dropdown-trigger_click${this.examMenuId === row.examId ? ' slds-is-open' : ''}`,
            volumePct: Math.max(6, Math.round(((row.games || 0) * 100) / maxGames))
        }));
    }

    get groupedErrorRows() {
        const rows = this.data && this.data.recentErrors ? this.data.recentErrors : [];
        const groups = rows.reduce((accumulator, row) => {
            const key = `${row.level}|${row.className}|${row.methodName}|${row.message}`;
            if (!accumulator[key]) {
                accumulator[key] = {
                    key,
                    title: `${row.className}.${row.methodName}`,
                    message: row.message,
                    level: row.level,
                    count: 0,
                    lastSeen: row.occurredAt,
                    occurrences: []
                };
            }

            accumulator[key].count += 1;
            accumulator[key].occurrences.push(row);
            if (row.occurredAt > accumulator[key].lastSeen) {
                accumulator[key].lastSeen = row.occurredAt;
            }
            return accumulator;
        }, {});

        return Object.values(groups)
            .sort((left, right) => new Date(right.lastSeen) - new Date(left.lastSeen))
            .map(group => ({
                ...group,
                severityClass: group.level === 'ERROR' ? 'slds-badge slds-theme_error' : group.level === 'INFO' ? 'slds-badge slds-theme_info' : 'slds-badge slds-theme_warning',
                cardClass: `error-group-card${group.level === 'ERROR' ? ' error-group-card_error' : group.level === 'INFO' ? ' error-group-card_info' : ' error-group-card_warning'}`,
                expandLabel: `${group.count} ${group.level === 'ERROR' ? 'errors' : 'warnings'} in last 24h`,
                expanded: this.expandedErrorKey === group.key,
                menuClass: `slds-dropdown-trigger slds-dropdown-trigger_click${this.errorMenuKey === group.key ? ' slds-is-open' : ''}`,
                iconClass: this.expandedErrorKey === group.key ? 'slds-button slds-button_icon slds-button_icon-border-filled expanded' : 'slds-button slds-button_icon slds-button_icon-border-filled'
            }));
    }

    get visibleErrorGroups() {
        return this.groupedErrorRows.slice(0, 3);
    }

    get hasOverflowErrors() {
        return this.groupedErrorRows.length > 3;
    }

    get hasTopExams() { return this.data && this.data.topExams && this.data.topExams.length > 0; }
    get hasLicense() { return this.data && this.data.recentLicense && this.data.recentLicense.length > 0; }
    get hasErrors() { return this.data && this.data.recentErrors && this.data.recentErrors.length > 0; }
    get hasGenerations() { return this.data && this.data.recentGenerations && this.data.recentGenerations.length > 0; }
    get hasTenants() { return !this.tenantId && this.data && this.data.tenants && this.data.tenants.length > 0; }

    get refreshIconHref() {
        return '/assets/icons/utility-sprite/svg/symbols.svg#refresh';
    }

    get sortIconHref() {
        return '/assets/icons/utility-sprite/svg/symbols.svg#arrowdown';
    }

    get chevronIconHref() {
        return '/assets/icons/utility-sprite/svg/symbols.svg#chevronright';
    }

    get dropdownIconHref() {
        return '/assets/icons/utility-sprite/svg/symbols.svg#down';
    }

    get knowledgeIconHref() {
        return '/assets/icons/standard-sprite/svg/symbols.svg#knowledge';
    }

    get warningIconHref() {
        return '/assets/icons/utility-sprite/svg/symbols.svg#warning';
    }

    get qualityIconHref() {
        return '/assets/icons/utility-sprite/svg/symbols.svg#dash';
    }

    get jobsCardIconHref() {
        return '/assets/icons/standard-sprite/svg/symbols.svg#scan_card';
    }

    get trendCardIconHref() {
        return '/assets/icons/standard-sprite/svg/symbols.svg#report';
    }

    get usageCardIconHref() {
        return '/assets/icons/standard-sprite/svg/symbols.svg#metrics';
    }

    get errorCardIconHref() {
        return '/assets/icons/standard-sprite/svg/symbols.svg#maintenance_plan';
    }

    get selectedExamHasData() {
        return !!this.selectedExam;
    }

    get selectedErrorGroupHasData() {
        return !!this.selectedErrorGroup;
    }

    sparklineConfig(values, color) {
        const points = values && values.length ? values : [0, 0, 0, 0, 0];
        return {
            type: 'line',
            data: {
                labels: points.map((value, index) => index + 1),
                datasets: [
                    {
                        data: points,
                        borderColor: color,
                        backgroundColor: 'transparent',
                        borderWidth: 2,
                        pointRadius: 0,
                        tension: 0.35
                    }
                ]
            },
            options: {
                animation: false,
                plugins: {
                    legend: { display: false },
                    tooltip: { enabled: false }
                },
                scales: {
                    x: { display: false },
                    y: { display: false }
                },
                elements: {
                    line: { borderCapStyle: 'round' }
                }
            }
        };
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    msg(e) { return e && e.body && e.body.message ? e.body.message : (e.message || 'Unknown error'); }
}