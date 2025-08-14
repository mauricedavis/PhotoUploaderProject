import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getCurrentPhoto from '@salesforce/apex/FileUploaderController.getCurrentPhoto';
import setCurrentPhoto from '@salesforce/apex/FileUploaderController.setCurrentPhoto';

export default class FileUploader extends LightningElement {
    @api recordId;
    @track fileUrl;
    @track contentDocumentId;

    connectedCallback() {
        if (!this.recordId) return;
        getCurrentPhoto({ recordId: this.recordId })
            .then(result => {
                if (result) {
                    this.contentDocumentId = result.ContentDocumentId;
                    this.fileUrl = '/sfc/servlet.shepherd/version/renditionDownload?rendition=ORIGINAL_JPG&versionId=' + result.Id;
                } else {
                    this.fileUrl = null;
                }
            })
            .catch(error => {
                // eslint-disable-next-line no-console
                console.error('Error fetching current photo', error);
            });
    }

    get acceptedFormats() {
        return ['.jpg', '.jpeg', '.png'];
    }
    get allowMultiple() { return false; }

    handleUploadFinished(event) {
        const file = event.detail.files?.[0];
        if (!file || !this.recordId) return;

        const versionId = file.contentVersionId;
        this.contentDocumentId = file.documentId;
        this.fileUrl = '/sfc/servlet.shepherd/version/renditionDownload?rendition=ORIGINAL_JPG&versionId=' + versionId;

        // Persist: flag this version as the current "record photo" and unset previous ones
        setCurrentPhoto({ recordId: this.recordId, versionId })
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Success',
                    message: 'Photo uploaded and saved.',
                    variant: 'success'
                }));
            })
            .catch(error => {
                // eslint-disable-next-line no-console
                console.error('Error setting current photo', error);
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Upload Error',
                    message: error?.body?.message || 'Unable to set photo.',
                    variant: 'error'
                }));
            });
    }
}
