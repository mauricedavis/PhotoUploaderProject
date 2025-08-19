import { LightningElement, api, track } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getCurrentPhoto from "@salesforce/apex/FileUploaderController.getCurrentPhoto";
import setCurrentPhotoSmart from "@salesforce/apex/FileUploaderController.setCurrentPhotoSmart";

export default class FileUploader extends LightningElement {
  @api recordId;
  @track fileUrl;

  connectedCallback() {
    this.refresh();
  }

  refresh() {
    if (!this.recordId) { this.fileUrl = null; return; }
    getCurrentPhoto({ recordId: this.recordId })
      .then(cv => {
        this.fileUrl = cv ? ("/sfc/servlet.shepherd/version/download/" + cv.Id) : null;
      })
      .catch(() => { this.fileUrl = null; });
  }

  get acceptedFormats() { return [".jpg", ".jpeg", ".png"]; }
  get allowMultiple() { return false; }

  handleUploadFinished(event) {
    const file = event?.detail?.files?.[0];
    if (!file) return;

    // Instant preview: documentId always present
    const docId = file.documentId;
    this.fileUrl = "/sfc/servlet.shepherd/document/download/" + docId;

    // Server-side: always enforce single "Is Currently Displayed"
    const versionId = file.contentVersionId || file.versionId || null;
    setCurrentPhotoSmart({
      recordId: this.recordId,
      documentId: docId,
      versionId: versionId
    })
    .then(() => {
      this.dispatchEvent(new ShowToastEvent({
        title: "Success",
        message: "Photo uploaded and set as current.",
        variant: "success"
      }));
      // Optional: refresh persisted URL (not required for instant preview)
      // this.refresh();
    })
    .catch(() => {
      // Non-blocking; preview already shown
    });
  }
}