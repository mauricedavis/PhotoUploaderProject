import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import deleteContentDocument from '@salesforce/apex/FileUploaderController.deleteContentDocument';

export default class FileUploader extends LightningElement {
    @api recordId;
    @track fileUrl;
    @track contentDocumentId;
    allowMultiple = false;

    get acceptedFormats() {
        return ['.jpg', '.jpeg', '.png'];
    }

    handleUploadFinished(event) {
        const file = event.detail.files[0];
        this.contentDocumentId = file.documentId;
        const versionId = file.contentVersionId;
        this.fileUrl = '/sfc/servlet.shepherd/version/renditionDownload?rendition=ORIGINAL_JPG&versionId=' + versionId;

        this.dispatchEvent(new ShowToastEvent({
            title: 'Success',
            message: 'Picture uploaded.',
            variant: 'success'
        }));
    }

    handleDelete() {
        if (!this.contentDocumentId) return;

        deleteContentDocument({ documentId: this.contentDocumentId })
            .then(() => {
                this.fileUrl = null;
                this.contentDocumentId = null;

                this.dispatchEvent(new ShowToastEvent({
                    title: 'Deleted',
                    message: 'Photo removed.',
                    variant: 'info'
                }));
            })
            .catch(error => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Error deleting file',
                    message: error.body.message,
                    variant: 'error'
                }));
            });
    }
}
