import { LightningElement, api, track } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getCurrentPhoto      from "@salesforce/apex/FileUploaderController.getCurrentPhoto";
import setCurrentPhotoSmart from "@salesforce/apex/FileUploaderController.setCurrentPhotoSmart";
import createAndSetPhoto    from "@salesforce/apex/FileUploaderController.createAndSetPhoto";

export default class FileUploader extends LightningElement {
  @api recordId;
  @track fileUrl;
  @track contentDocumentId;

  connectedCallback() { this.refreshCurrent(); }

  get acceptedFormats() { return [".jpg", ".jpeg", ".png"]; }
  get allowMultiple()   { return false; } // avoid {false} literal in template

  makeUrl(versionId) {
    return "/sfc/servlet.shepherd/version/renditionDownload?rendition=ORIGINAL_JPG&versionId=" + versionId;
  }

  refreshCurrent() {
    if (!this.recordId) return;
    getCurrentPhoto({ recordId: this.recordId })
      .then(cv => {
        if (cv) {
          this.contentDocumentId = cv.ContentDocumentId;
          this.fileUrl = this.makeUrl(cv.Id);
        } else {
          this.contentDocumentId = null;
          this.fileUrl = null;
        }
      })
      .catch(err => console.error("getCurrentPhoto error", err));
  }

  async handleUploadFinished(evt) {
    try {
      const f = evt.detail?.files?.[0];
      if (!f) return;
      this.fileUrl = this.makeUrl(f.contentVersionId);  // instant render
      this.contentDocumentId = f.documentId;
      await setCurrentPhotoSmart({ recordId: this.recordId, versionId: f.contentVersionId });
      this.toast("Photo uploaded and set as current.", "success");
    } catch (e) {
      console.error(e);
      this.toast(e?.body?.message || e.message, "error");
    }
  }

  toast(message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title: "Photo Uploader", message, variant }));
  }
}