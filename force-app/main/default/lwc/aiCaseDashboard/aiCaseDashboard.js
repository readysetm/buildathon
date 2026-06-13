import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getOpenCases from '@salesforce/apex/AICaseDashboardController.getOpenCases';
import generateAISummary from '@salesforce/apex/AICaseDashboardController.generateAISummary';

export default class AiCaseDashboard extends LightningElement {
    @track cases = [];
    @track selectedCase = null;
    @track aiResult = null;
    @track isLoading = false;
    @track isGenerating = false;
    @track error = null;
    _wiredCasesResult;

    @wire(getOpenCases)
    wiredCases(result) {
        this._wiredCasesResult = result;
        this.isLoading = true;

        if (result.data) {
            this.cases = result.data;
            this.error = null;
            this.isLoading = false;
        } else if (result.error) {
            this.error = this.reduceError(result.error);
            this.isLoading = false;
        }
    }

    get totalCases() {
        return this.cases.length;
    }

    get highPriorityCases() {
        return this.cases.filter((caseRecord) => caseRecord.Priority === 'High');
    }

    get todayCases() {
        const today = new Date();
        return this.cases.filter((caseRecord) => {
            if (!caseRecord.CreatedDate) {
                return false;
            }
            const createdDate = new Date(caseRecord.CreatedDate);
            return (
                createdDate.getFullYear() === today.getFullYear() &&
                createdDate.getMonth() === today.getMonth() &&
                createdDate.getDate() === today.getDate()
            );
        });
    }

    get hasSelectedCase() {
        return this.selectedCase !== null;
    }

    get hasAIResult() {
        return this.aiResult !== null;
    }

    get hasCases() {
        return this.cases.length > 0;
    }

    get sentimentClass() {
        if (!this.aiResult || !this.aiResult.sentiment) {
            return 'sentiment-pill sentiment-neutral';
        }

        const sentiment = this.aiResult.sentiment.toLowerCase();
        if (sentiment === 'frustrated') {
            return 'sentiment-pill sentiment-frustrated';
        }
        if (sentiment === 'satisfied') {
            return 'sentiment-pill sentiment-satisfied';
        }
        return 'sentiment-pill sentiment-neutral';
    }

    get selectedPriorityBadgeClass() {
        return this.getPriorityBadgeClass(this.selectedCase?.Priority);
    }

    get casesWithMeta() {
        return this.cases.map((caseRecord) => ({
            ...caseRecord,
            cardClass: this.getCaseCardClass(caseRecord.Id),
            priorityBadgeClass: this.getPriorityBadgeClass(caseRecord.Priority),
            contactDisplay: caseRecord.Contact?.Name || 'No contact',
            relativeTime: this.formatRelativeTime(caseRecord.CreatedDate)
        }));
    }

    handleCaseSelect(event) {
        const caseId = event.currentTarget.dataset.caseId;
        const selected = this.cases.find((caseRecord) => caseRecord.Id === caseId);
        this.selectedCase = selected || null;
        this.aiResult = null;
        this.error = null;
    }

    handleGenerateSummary() {
        if (!this.selectedCase) {
            return;
        }

        this.isGenerating = true;
        this.error = null;
        this.aiResult = null;

        generateAISummary({ caseId: this.selectedCase.Id })
            .then((responseText) => {
                if (responseText && responseText.startsWith('Error')) {
                    this.error = responseText;
                    return;
                }
                this.aiResult = this.parseAIResponse(responseText);
            })
            .catch((apexError) => {
                this.error = this.reduceError(apexError);
            })
            .finally(() => {
                this.isGenerating = false;
            });
    }

    parseAIResponse(text) {
        const emptyResult = {
            summary: '',
            sentiment: 'Neutral',
            priorityAssessment: '',
            suggestedReply: '',
            nextBestAction: ''
        };

        if (!text) {
            return emptyResult;
        }

        const sections = {
            summary: 'SUMMARY:',
            sentiment: 'SENTIMENT:',
            priorityAssessment: 'PRIORITY ASSESSMENT:',
            suggestedReply: 'SUGGESTED REPLY:',
            nextBestAction: 'NEXT BEST ACTION:'
        };

        const extractSection = (startKey, endKeys) => {
            const startIndex = text.indexOf(startKey);
            if (startIndex === -1) {
                return '';
            }

            const contentStart = startIndex + startKey.length;
            let endIndex = text.length;

            endKeys.forEach((endKey) => {
                const candidateIndex = text.indexOf(endKey, contentStart);
                if (candidateIndex !== -1 && candidateIndex < endIndex) {
                    endIndex = candidateIndex;
                }
            });

            return text.substring(contentStart, endIndex).trim();
        };

        return {
            summary: extractSection(sections.summary, [
                sections.sentiment,
                sections.priorityAssessment,
                sections.suggestedReply,
                sections.nextBestAction
            ]),
            sentiment: extractSection(sections.sentiment, [
                sections.priorityAssessment,
                sections.suggestedReply,
                sections.nextBestAction
            ]),
            priorityAssessment: extractSection(sections.priorityAssessment, [
                sections.suggestedReply,
                sections.nextBestAction
            ]),
            suggestedReply: extractSection(sections.suggestedReply, [sections.nextBestAction]),
            nextBestAction: extractSection(sections.nextBestAction, [])
        };
    }

    handleCopyReply() {
        if (!this.aiResult || !this.aiResult.suggestedReply) {
            return;
        }

        navigator.clipboard
            .writeText(this.aiResult.suggestedReply)
            .then(() => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'Copied!',
                        variant: 'success'
                    })
                );
            })
            .catch(() => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: 'Unable to copy reply.',
                        variant: 'error'
                    })
                );
            });
    }

    handleRefresh() {
        this.selectedCase = null;
        this.aiResult = null;
        this.error = null;
        this.isLoading = true;

        if (this._wiredCasesResult) {
            refreshApex(this._wiredCasesResult).finally(() => {
                this.isLoading = false;
            });
        } else {
            this.isLoading = false;
        }
    }

    formatRelativeTime(dateString) {
        if (!dateString) {
            return '';
        }

        const createdDate = new Date(dateString);
        const now = new Date();
        const diffMs = now.getTime() - createdDate.getTime();
        const diffMinutes = Math.floor(diffMs / (1000 * 60));
        const diffHours = Math.floor(diffMinutes / 60);
        const diffDays = Math.floor(diffHours / 24);

        if (diffMinutes < 1) {
            return 'Just now';
        }
        if (diffMinutes < 60) {
            return `${diffMinutes} minutes ago`;
        }
        if (diffHours < 24) {
            return `${diffHours} hours ago`;
        }
        return `${diffDays} days ago`;
    }

    getCaseCardClass(caseId) {
        return this.selectedCase && this.selectedCase.Id === caseId
            ? 'case-card active'
            : 'case-card';
    }

    getPriorityBadgeClass(priority) {
        if (priority === 'High') {
            return 'badge badge-high';
        }
        if (priority === 'Medium') {
            return 'badge badge-medium';
        }
        return 'badge badge-low';
    }

    reduceError(error) {
        if (typeof error === 'string') {
            return error;
        }
        if (error?.body?.message) {
            return error.body.message;
        }
        if (error?.message) {
            return error.message;
        }
        return 'An unexpected error occurred.';
    }
}
