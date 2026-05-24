import { LightningElement, api, track } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import uploadPack from "@salesforce/apex/QuestionReviewController.uploadPack";

export default class QuestionBankManager extends LightningElement {
    @api focusLabel;
    @track jsonText = "";
    @track loading = false;
    @track lastResult;

    placeholderText =
        '{ "exam": ..., "questionBank": ..., "questions": [...] }';

    handleChange(e) {
        this.jsonText = e.target.value;
    }

    async handleUpload() {
        if (!this.jsonText) {
            this.toast("Empty", "Paste a pack JSON first.", "warning");
            return;
        }
        this.loading = true;
        try {
            const res = await uploadPack({ jsonBody: this.jsonText });
            this.lastResult = res;
            if (res.success) {
                this.toast(
                    "Imported",
                    `${res.questionsCreated} created, ${res.questionsUpdated} updated. All Drafts.`,
                    "success"
                );
            } else {
                this.toast(
                    "Import failed",
                    (res.errors && res.errors[0]) || "See errors below.",
                    "error"
                );
            }
        } catch (e) {
            this.toast("Error", this.errMsg(e), "error");
        } finally {
            this.loading = false;
        }
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
    errMsg(e) {
        return e && e.body && e.body.message
            ? e.body.message
            : e.message || "Unknown error";
    }

    get hasErrors() {
        return (
            this.lastResult &&
            this.lastResult.errors &&
            this.lastResult.errors.length > 0
        );
    }
    get hasDuplicates() {
        return (
            this.lastResult &&
            this.lastResult.duplicateExternalIds &&
            this.lastResult.duplicateExternalIds.length > 0
        );
    }
    get hasFocusLabel() {
        return !!this.focusLabel;
    }
}