import { LightningElement, api, track } from 'lwc';
import fetchLatestImage from '@salesforce/apex/FileUploaderController.fetchLatestImage';

export default class FileUploader extends LightningElement {
    @api recordId;
    @track fileUrl;
    @track allowMultiple = false;

    get acceptedFormats() {
        return ['.jpg', '.jpeg', '.png'];
    }

    connectedCallback() {
        if (this.recordId) {
            fetchLatestImage({ recordId: this.recordId })
                .then((result) => {
                    if (result) {
                        this.fileUrl = '/sfc/servlet.shepherd/version/renditionDownload?rendition=ORIGINAL_JPG&versionId=' + result;
                    }
                })
                .catch((error) => {
                    console.error('Error fetching image', error);
                });
        }
    }

    handleUploadFinished(event) {
        const file = event.detail.files[0];
        const versionId = file.contentVersionId;
        this.fileUrl = '/sfc/servlet.shepherd/version/renditionDownload?rendition=ORIGINAL_JPG&versionId=' + versionId;
    }
}
