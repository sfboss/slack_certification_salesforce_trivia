import { LightningElement, api, track } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import load from "@salesforce/apex/CertGameAdminDashboardController.load";

const SPRITES = {
    standard: "/assets/icons/standard-sprite/svg/symbols.svg",
    utility: "/assets/icons/utility-sprite/svg/symbols.svg"
};

const TAB_DEFS = [
    { key: "dashboard", label: "Dashboard", icon: "dashboard" },
    { key: "leaderboard", label: "Leaderboard", icon: "ranking" },
    { key: "review", label: "Review Drafts", icon: "edit" },
    { key: "bank", label: "Question Bank", icon: "knowledge_base" },
    { key: "gen", label: "Generation Jobs", icon: "recipe" },
    { key: "tournaments", label: "Tournaments", icon: "campaign" }
];

function spriteHref(spriteName, symbolName) {
    return `${SPRITES[spriteName]}#${symbolName}`;
}

export default class CertGameAdminHome extends LightningElement {
    @api recordId;

    activeTab = "dashboard";
    @track summaryData;
    @track error;
    @track loading = false;

    headerMenuOpen = false;
    questionBankFocus;

    connectedCallback() {
        this.fetchSummary();
    }

    get tenantId() {
        return this.recordId || null;
    }

    async fetchSummary() {
        this.loading = true;
        this.error = undefined;

        try {
            this.summaryData = await load({ tenantId: this.tenantId });
        } catch (e) {
            this.summaryData = undefined;
            this.error = this.msg(e);
        } finally {
            this.loading = false;
        }
    }

    async handleRefresh() {
        this.headerMenuOpen = false;
        await this.fetchSummary();

        const dashboard = this.template.querySelector(
            "c-cert-game-admin-dashboard"
        );
        if (dashboard && dashboard.refreshData) {
            await dashboard.refreshData();
        }

        this.toast("Refreshed", "Admin console metrics updated.", "success");
    }

    handleTabClick(event) {
        event.preventDefault();
        this.activeTab = event.currentTarget.dataset.tab;
        this.headerMenuOpen = false;
    }

    handleActionClick(event) {
        const action = event.currentTarget.dataset.action;

        if (action === "gen") {
            this.activeTab = "gen";
            this.toast(
                "Generation jobs",
                "Open the Generation Jobs tab to manage live generation activity.",
                "info"
            );
        } else if (action === "tournaments") {
            this.activeTab = "tournaments";
        }
    }

    handleOverflowToggle() {
        this.headerMenuOpen = !this.headerMenuOpen;
    }

    handleOverflowAction(event) {
        const action = event.currentTarget.dataset.action;
        this.headerMenuOpen = false;

        if (action === "refresh") {
            this.handleRefresh();
            return;
        }

        if (action === "export") {
            this.toast(
                "Export",
                "Export actions are not wired in this console yet.",
                "info"
            );
            return;
        }

        this.toast(
            "Settings",
            "Settings remain managed in Salesforce setup and metadata.",
            "info"
        );
    }

    handleHealthAction(event) {
        this.questionBankFocus = event.detail.focusLabel;
        this.activeTab = "bank";
        this.toast(
            "Question Bank focus",
            `${event.detail.focusLabel} highlighted in Question Bank.`,
            "warning"
        );
    }

    handleDashboardNavigate(event) {
        this.activeTab = event.detail.tab;
        if (event.detail.message) {
            this.toast(
                event.detail.title || "Updated",
                event.detail.message,
                event.detail.variant || "info"
            );
        }
    }

    get tabs() {
        const questionHealth =
            this.summaryData && this.summaryData.questionHealth
                ? this.summaryData.questionHealth
                : {};
        const recentGenerations =
            this.summaryData && this.summaryData.recentGenerations
                ? this.summaryData.recentGenerations
                : [];
        const totalPlayers =
            this.summaryData && this.summaryData.kpis
                ? this.summaryData.kpis.totalPlayers || 0
                : 0;
        const reviewCount = questionHealth.draft || 0;
        const bankAttention =
            (questionHealth.brokenCitations || 0) +
            (questionHealth.lowQuality || 0);
        const generationAttention = recentGenerations.filter(
            (job) => job.status === "Failed"
        ).length;

        return TAB_DEFS.map((tab) => {
            let count = null;
            let attentionCount = null;

            if (tab.key === "leaderboard") {
                count = totalPlayers;
            } else if (tab.key === "review") {
                count = reviewCount;
                attentionCount = reviewCount > 0 ? reviewCount : null;
            } else if (tab.key === "bank") {
                count = bankAttention;
                attentionCount = bankAttention > 0 ? bankAttention : null;
            } else if (tab.key === "gen") {
                count = recentGenerations.length;
                attentionCount =
                    generationAttention > 0 ? generationAttention : null;
            }

            return {
                ...tab,
                iconHref: spriteHref("utility", tab.icon),
                iconName: `utility:${tab.icon}`,
                itemClass: `slds-tabs_default__item${this.activeTab === tab.key ? " slds-is-active" : ""}`,
                ariaSelected: this.activeTab === tab.key ? "true" : "false",
                tabIndex: this.activeTab === tab.key ? "0" : "-1",
                countLabel: count === null ? null : count,
                badgeClass: `slds-badge tab-badge${attentionCount ? " slds-theme_warning" : ""}`,
                attentionCount
            };
        });
    }

    get metadataItems() {
        const data = this.summaryData || {};
        const kpis = data.kpis || {};
        const questionHealth = data.questionHealth || {};
        const usage = data.usage || {};

        return [
            {
                key: "players",
                label: "Players",
                value: this.formatNumber(kpis.totalPlayers || 0)
            },
            {
                key: "published",
                label: "Published Qs",
                value: this.formatNumber(questionHealth.published || 0)
            },
            {
                key: "games",
                label: "Active Games",
                value: this.formatNumber(kpis.gamesStarted7d || 0)
            },
            {
                key: "cost",
                label: "LLM Cost MTD",
                value: this.formatCurrency(usage.llmCostUsd)
            },
            {
                key: "citations",
                label: "Broken Citations",
                value: this.formatNumber(questionHealth.brokenCitations || 0)
            }
        ];
    }

    get tenantName() {
        return this.summaryData && this.summaryData.tenant
            ? this.summaryData.tenant.name
            : "All Workspaces";
    }

    get tenantContext() {
        if (!this.summaryData || !this.summaryData.tenant) {
            return "Certification trivia management";
        }

        const tenant = this.summaryData.tenant;
        return `Certification trivia management for ${tenant.name}`;
    }

    get pagePlan() {
        return this.summaryData && this.summaryData.tenant
            ? this.summaryData.tenant.plan
            : "Org Overview";
    }

    get pageStatus() {
        return this.summaryData && this.summaryData.tenant
            ? this.summaryData.tenant.status
            : "Active";
    }

    get pagePlanClass() {
        return "slds-badge";
    }

    get pageStatusClass() {
        const status = this.pageStatus;
        if (status === "Active") {
            return "slds-badge slds-theme_success";
        }
        if (status === "Trial") {
            return "slds-badge slds-theme_warning";
        }
        return "slds-badge slds-theme_error";
    }

    get headerIconHref() {
        return spriteHref("standard", "knowledge");
    }

    get refreshIconHref() {
        return spriteHref("utility", "refresh");
    }

    get overflowIconHref() {
        return spriteHref("utility", "down");
    }

    get headerMenuClass() {
        return `slds-dropdown-trigger slds-dropdown-trigger_click slds-button_last${this.headerMenuOpen ? " slds-is-open" : ""}`;
    }

    get dashboardTabClass() {
        return this.contentClass("dashboard");
    }

    get leaderboardTabClass() {
        return this.contentClass("leaderboard");
    }

    get reviewTabClass() {
        return this.contentClass("review");
    }

    get bankTabClass() {
        return this.contentClass("bank");
    }

    get generationTabClass() {
        return this.contentClass("gen");
    }

    get tournamentsTabClass() {
        return this.contentClass("tournaments");
    }

    contentClass(tabKey) {
        return `admin-tab-panel${this.activeTab === tabKey ? " slds-show" : " slds-hide"}`;
    }

    formatNumber(value) {
        return new Intl.NumberFormat("en-US").format(value || 0);
    }

    formatCurrency(value) {
        if (value === null || value === undefined) {
            return "—";
        }
        return new Intl.NumberFormat("en-US", {
            style: "currency",
            currency: "USD",
            maximumFractionDigits: 0
        }).format(value);
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    msg(error) {
        return error && error.body && error.body.message
            ? error.body.message
            : error.message;
    }
}