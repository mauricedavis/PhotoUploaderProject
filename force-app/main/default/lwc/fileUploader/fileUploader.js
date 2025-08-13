import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getCurrentPhoto from '@salesforce/apex/FileUploaderController.getCurrentPhoto';
import updatePhotoStatus from '@salesforce/apex/FileUploaderController.updatePhotoStatus';

export default class FileUploader extends LightningElement {
    @api recordId;
    @track fileUrl;
    @track contentDocumentId;

    get acceptedFormats() {
        return ['.jpg', '.jpeg', '.png'];
    }

    connectedCallback() {
        this.loadCurrentPhoto();
    }

    loadCurrentPhoto() {
        getCurrentPhoto({ recordId: this.recordId })
            .then(result => {
                if (result) {
                    this.contentDocumentId = result.ContentDocumentId;
                    this.fileUrl = '/sfc/servlet.shepherd/version/renditionDownload?rendition=ORIGINAL_JPG&versionId=' + result.Id;
                }
            })
            .catch(error => {
                console.error(error);
            });
    }

    handleUploadFinished(event) {
        const uploadedFile = event.detail.files[0];
        const documentId = uploadedFile.documentId;
        updatePhotoStatus({ recordId: this.recordId, contentVersionId: uploadedFile.contentVersionId, documentId: documentId })
            .then(() => {
                this.fileUrl = '/sfc/servlet.shepherd/version/renditionDownload?rendition=ORIGINAL_JPG&versionId=' + uploadedFile.contentVersionId;
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Success',
                    message: 'Photo uploaded and set as current.',
                    variant: 'success'
                }));
            })
            .catch(error => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Upload failed',
                    message: error.body.message,
                    variant: 'error'
                }));
            });
    }
}
