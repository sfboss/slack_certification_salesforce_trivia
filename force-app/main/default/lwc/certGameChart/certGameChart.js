import { LightningElement, api } from "lwc";
import { loadScript } from "lightning/platformResourceLoader";
import CHART_JS from "@salesforce/resourceUrl/chartJs";

export default class CertGameChart extends LightningElement {
    @api height = 220;

    chart;
    chartJsReady = false;
    chartJsPromise;
    renderedSignature;
    _config;

    @api
    get config() {
        return this._config;
    }

    set config(value) {
        this._config = value;
        if (this.chartJsReady) {
            this.renderChart();
        }
    }

    get containerStyle() {
        return `height: ${this.height}px;`;
    }

    renderedCallback() {
        if (this.chartJsReady) {
            this.renderChart();
            return;
        }

        if (!this.chartJsPromise) {
            this.chartJsPromise = loadScript(
                this,
                `${CHART_JS}/chart.umd.js`
            ).then(() => {
                this.chartJsReady = true;
                this.renderChart();
            });
        }
    }

    disconnectedCallback() {
        this.destroyChart();
    }

    renderChart() {
        const canvas = this.template.querySelector("canvas");
        const nextConfig = this.normalizedConfig;

        if (!canvas || !nextConfig || !window.Chart) {
            return;
        }

        const nextSignature = JSON.stringify(nextConfig);
        if (this.chart && this.renderedSignature === nextSignature) {
            return;
        }

        this.destroyChart();
        this.chart = new window.Chart(canvas.getContext("2d"), nextConfig);
        this.renderedSignature = nextSignature;
    }

    destroyChart() {
        if (this.chart) {
            this.chart.destroy();
            this.chart = undefined;
        }
    }

    get normalizedConfig() {
        if (!this._config) {
            return undefined;
        }

        const config = JSON.parse(JSON.stringify(this._config));
        config.options = config.options || {};
        config.options.responsive = true;
        config.options.maintainAspectRatio = false;
        return config;
    }
}