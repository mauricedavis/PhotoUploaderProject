import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import fetchDocumentInfo from '@salesforce/apex/FileUploaderController.fetchDocumentInfo';

export default class FileUploader extends LightningElement {
    @api recordId;
    @track fileUrl;
    @track contentDocumentId;
    allowMultiple = false;

    connectedCallback() {
        if (this.recordId) {
            fetchDocumentInfo({ recordId: this.recordId })
                .then(result => {
                    if (result) {
                        this.fileUrl = result;
                    }
                });
        }
    }

    get acceptedFormats() {
        return ['.jpg', '.jpeg', '.png'];
    }

    handleUploadFinished(event) {
        const file = event.detail.files[0];
        const versionId = file.contentVersionId;
        this.fileUrl = '/sfc/servlet.shepherd/version/renditionDownload?rendition=ORIGINAL_JPG&versionId=' + versionId;

        this.dispatchEvent(new ShowToastEvent({
            title: 'Success',
            message: 'Picture uploaded.',
            variant: 'success'
        }));
    }
}
