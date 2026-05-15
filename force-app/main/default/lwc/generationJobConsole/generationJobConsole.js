import { LightningElement, track } from 'lwc';
import { subscribe, unsubscribe, onError } from 'lightning/empApi';

const CHANNEL = '/event/QuestionGenerationJob__e';

export default class GenerationJobConsole extends LightningElement {
    @track events = [];
    subscription = {};

    connectedCallback() {
        onError(err => console.error('CometD error', err));
        subscribe(CHANNEL, -1, ev => {
            this.events = [{
                ts: new Date().toLocaleTimeString(),
                jobId: ev.data.payload.Job_Id__c,
                tenantId: ev.data.payload.Tenant_Id__c,
                status: ev.data.payload.Status__c,
                count: ev.data.payload.Generated_Count__c,
                message: ev.data.payload.Message__c
            }, ...this.events].slice(0, 50);
        }).then(s => { this.subscription = s; });
    }

    disconnectedCallback() {
        if (this.subscription && this.subscription.channel) unsubscribe(this.subscription, () => {});
    }
}
