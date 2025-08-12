import { LightningElement, api } from 'lwc';
import getLatestPhoto from '@salesforce/apex/FileUploaderController.getLatestPhoto';
import deleteLatestPhoto from '@salesforce/apex/FileUploaderController.deleteLatestPhoto';

export default class FileUploader extends LightningElement {
    @api recordId;
    photoUrl;

    acceptedFormats = ['.jpg', '.jpeg', '.png'];

    connectedCallback() {
        this.loadPhoto();
    }

    loadPhoto() {
        getLatestPhoto({ recordId: this.recordId })
            .then(result => {
                if (result) {
                    this.photoUrl = /sfc/servlet.shepherd/version/renditionDownload?rendition=THUMB720BY480&versionId=;
                } else {
                    this.photoUrl = null;
                }
            })
            .catch(error => {
                console.error('Error loading photo', error);
            });
    }

    handleUploadFinished(event) {
        this.loadPhoto();
    }

    handleDelete() {
        deleteLatestPhoto({ recordId: this.recordId })
            .then(() => {
                this.photoUrl = null;
            })
            .catch(error => {
                console.error('Delete failed', error);
            });
    }
}
