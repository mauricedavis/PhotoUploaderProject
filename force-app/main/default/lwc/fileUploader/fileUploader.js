import { LightningElement, api, track } from 'lwc';
import getLatestImageVersionId from '@salesforce/apex/FileUploaderController.getLatestImageVersionId';

export default class FileUploader extends LightningElement {
    @api recordId;
    @track fileUrl;
    @track contentDocumentId;
    allowMultiple = false;

    get acceptedFormats() {
        return ['.jpg', '.jpeg', '.png'];
    }

    connectedCallback() {
        if (this.recordId) {
            getLatestImageVersionId({ recordId: this.recordId })
                .then(versionId => {
                    if (versionId) {
                        this.fileUrl = '/sfc/servlet.shepherd/version/renditionDownload?rendition=ORIGINAL_JPG&versionId=' + versionId;
                    }
                })
                .catch(error => {
                    console.error('Error fetching image version:', error);
                });
        }
    }

    handleUploadFinished(event) {
        const file = event.detail.files[0];
        const versionId = file.contentVersionId;
        this.fileUrl = '/sfc/servlet.shepherd/version/renditionDownload?rendition=ORIGINAL_JPG&versionId=' + versionId;
    }
}
