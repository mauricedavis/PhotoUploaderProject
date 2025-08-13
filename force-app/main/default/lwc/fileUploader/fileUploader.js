import { LightningElement, api, track } from 'lwc';
import getLatestContentDocument from '@salesforce/apex/FileUploaderController.getLatestContentDocument';

export default class FileUploader extends LightningElement {
    @api recordId;
    @track fileUrl;
    @track contentDocumentId;
    allowMultiple = false;

    get acceptedFormats() {
        return ['.jpg', '.jpeg', '.png'];
    }

    connectedCallback() {
        console.log('DEBUG: connectedCallback triggered - checking for existing image');
        if (this.recordId) {
            getLatestContentDocument({ recordId: this.recordId })
                .then(result => {
                    if (result && result.versionId) {
                        this.contentDocumentId = result.documentId;
                        this.fileUrl = '/sfc/servlet.shepherd/version/renditionDownload?rendition=ORIGINAL_JPG&versionId=' + result.versionId;
                        console.log('DEBUG: Image loaded from server: ' + this.fileUrl);
                    } else {
                        console.log('DEBUG: No image found for record');
                    }
                })
                .catch(error => {
                    console.error('DEBUG: Error in getLatestContentDocument: ', error);
                });
        }
    }

    handleUploadFinished(event) {
        const file = event.detail.files[0];
        this.contentDocumentId = file.documentId;
        const versionId = file.contentVersionId;
        this.fileUrl = '/sfc/servlet.shepherd/version/renditionDownload?rendition=ORIGINAL_JPG&versionId=' + versionId;
        console.log('DEBUG: Uploaded file URL: ' + this.fileUrl);
    }
}
