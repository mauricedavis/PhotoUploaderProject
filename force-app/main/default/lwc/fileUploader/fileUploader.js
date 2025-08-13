import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getImageUrl from '@salesforce/apex/FileUploaderController.getImageUrl';

export default class FileUploader extends LightningElement {
    @api recordId;
    @track fileUrl;
    allowMultiple = false;

    get acceptedFormats() {
        return ['.jpg', '.jpeg', '.png'];
    }

    connectedCallback() {
        if (this.recordId) {
            getImageUrl({ recordId: this.recordId })
                .then(url => {
                    this.fileUrl = url;
                })
                .catch(error => {
                    console.error('Error retrieving image:', error);
                });
        }
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
