import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import fetchImageUrl from '@salesforce/apex/FileUploaderController.fetchImageUrl';

export default class FileUploader extends LightningElement {
  @api recordId;
  @track fileUrl;

  get acceptedFormats() {
    return ['.jpg', '.jpeg', '.png'];
  }

  connectedCallback() {
    if (this.recordId) {
      fetchImageUrl({ recordId: this.recordId })
        .then(url => { if (url) this.fileUrl = url; })
        .catch(console.error);
    }
  }

  handleUploadFinished(event) {
    const versionId = event.detail.files[0].contentVersionId;
    this.fileUrl = \/sfc/servlet.shepherd/version/renditionDownload?rendition=ORIGINAL_JPG&versionId=\\;

    this.dispatchEvent(new ShowToastEvent({
      title: 'Success',
      message: 'Picture uploaded.',
      variant: 'success'
    }));
  }
}
