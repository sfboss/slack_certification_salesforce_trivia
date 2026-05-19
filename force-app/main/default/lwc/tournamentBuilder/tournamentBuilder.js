import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import createTournament from '@salesforce/apex/CertGameTournamentService.createTournament';
import buildBracket from '@salesforce/apex/CertGameTournamentService.buildBracket';
import listExams from '@salesforce/apex/CertGameTournamentService.listExams';

const TYPES = [
    { label: 'Round Robin', value: 'RoundRobin' },
    { label: 'Single Elimination', value: 'Elimination' },
    { label: 'Open Ladder', value: 'OpenLadder' }
];

export default class TournamentBuilder extends LightningElement {
    @track name = '';
    @track bracketType = 'RoundRobin';
    @track examId;
    @track examOptions = [];
    @track playerIdsCsv = '';
    @track tournamentId;
    @track bracketJson;

    typeOptions = TYPES;

    @wire(listExams)
    wiredExams({ data }) {
        if (data) {
            this.examOptions = data.map(o => ({ label: o.label, value: o.id }));
        }
    }

    handleName(e) { this.name = e.target.value; }
    handleType(e) { this.bracketType = e.detail.value; }
    handleExam(e) { this.examId = e.detail.value; }
    handlePlayers(e) { this.playerIdsCsv = e.target.value; }

    async handleCreate() {
        if (!this.examId) { this.toast('Missing', 'Select a certification exam.', 'warning'); return; }
        try {
            this.tournamentId = await createTournament({
                name: this.name,
                bracketType: this.bracketType,
                examId: this.examId, startAt: null, endAt: null
            });
            this.toast('Created', 'Tournament ' + this.tournamentId, 'success');
        } catch (e) { this.toast('Error', this.msg(e), 'error'); }
    }

    async handleBuild() {
        if (!this.tournamentId) { this.toast('Missing', 'Create the tournament first.', 'warning'); return; }
        const ids = this.playerIdsCsv.split(',').map(s => s.trim()).filter(Boolean);
        try {
            this.bracketJson = await buildBracket({ tournamentId: this.tournamentId, playerIds: ids });
            this.toast('Built', 'Bracket generated', 'success');
        } catch (e) { this.toast('Error', this.msg(e), 'error'); }
    }

    toast(t, m, v) { this.dispatchEvent(new ShowToastEvent({ title: t, message: m, variant: v })); }
    msg(e) { return e && e.body && e.body.message ? e.body.message : e.message; }
}