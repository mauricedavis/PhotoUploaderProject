import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getCurrentPhoto from '@salesforce/apex/FileUploaderController.getCurrentPhoto';
import setCurrentPhoto from '@salesforce/apex/FileUploaderController.setCurrentPhoto';

export default class FileUploader extends LightningElement {
    @api recordId;
    @track fileUrl;
    @track contentDocumentId;

    connectedCallback() {
        getCurrentPhoto({ recordId: this.recordId })
            .then(result => {
                if (result) {
                    this.contentDocumentId = result.ContentDocumentId;
                    this.fileUrl = '/sfc/servlet.shepherd/version/renditionDownload?rendition=ORIGINAL_JPG&versionId=' + result.Id;
                }
            })
            .catch(error => {
                console.error('Error fetching current photo: ', error);
            });
    }

    get acceptedFormats() {
        return ['.jpg', '.jpeg', '.png'];
    }

    get allowMultiple() {
        return false;
    }

    handleUploadFinished(event) {
        const file = event.detail.files[0];
        this.contentDocumentId = file.documentId;
        const versionId = file.contentVersionId;
        this.fileUrl = '/sfc/servlet.shepherd/version/renditionDownload?rendition=ORIGINAL_JPG&versionId=' + versionId;

        setCurrentPhoto({ recordId: this.recordId, documentId: this.contentDocumentId })
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Success',
                    message: 'Photo uploaded and set as current.',
                    variant: 'success'
                }));
            })
            .catch(error => {
                console.error('Error setting current photo: ', error);
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Upload Error',
                    message: error.body.message,
                    variant: 'error'
                }));
            });
    }
}
