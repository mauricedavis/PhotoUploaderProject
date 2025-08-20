import { LightningElement, api, track } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";

import getCurrentPhoto        from "@salesforce/apex/FileUploaderController.getCurrentPhoto";
import setCurrentPhotoSmart   from "@salesforce/apex/FileUploaderController.setCurrentPhotoSmart";
import createAndSetPhoto      from "@salesforce/apex/FileUploaderController.createAndSetPhoto";

export default class FileUploader extends LightningElement {
  @api recordId;

  @track fileUrl;
  @track contentDocumentId;

  @track isDragging = false;

  connectedCallback() {
    this.refreshCurrent();
  }

  // ----- UI helpers -----
  get acceptedFormats() {
    return [".jpg", ".jpeg", ".png"];
  }

  // Build CDN URL quickly
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

  // ----- Standard upload button path -----
  async handleUploadFinished(evt) {
    try {
      const f = evt.detail.files?.[0];
      if (!f) return;

      // Render immediately from event
      this.fileUrl = this.makeUrl(f.contentVersionId);
      this.contentDocumentId = f.documentId;

      // Enforce single-current
      await setCurrentPhotoSmart({ recordId: this.recordId, versionId: f.contentVersionId });

      this.dispatchEvent(
        new ShowToastEvent({
          title: "Uploaded",
          message: "Photo uploaded and set as current.",
          variant: "success"
        })
      );
    } catch (e) {
      console.error(e);
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Upload Error",
          message: e?.body?.message || e.message,
          variant: "error"
        })
      );
    }
  }

  // ----- Drag & Drop path -----
  handleDragOver(e) {
    e.preventDefault();
  }
  handleDragEnter(e) {
    e.preventDefault();
    this.isDragging = true;
  }
  handleDragLeave(e) {
    e.preventDefault();
    this.isDragging = false;
  }

  handleDrop(e) {
    e.preventDefault();
    this.isDragging = false;

    const files = e.dataTransfer?.files;
    if (!files || !files.length) return;
    const file = files[0];

    // Light check (Apex will hard-enforce limits)
    if (!/image\/(jpeg|png)/i.test(file.type)) {
      this.toast("Unsupported file type. Use JPG or PNG.", "error");
      return;
    }

    // Read as base64 then call Apex to create + set current
    const reader = new FileReader();
    reader.onload = async () => {
      try {
        // result like: data:image/png;base64,AAAA...
        const base64 = String(reader.result).split("base64,").pop();

        const res = await createAndSetPhoto({
          recordId: this.recordId,
          fileName: file.name,
          base64Data: base64,
          contentType: file.type
        });

        if (res && res.versionId) {
          this.fileUrl = this.makeUrl(res.versionId);
          this.contentDocumentId = res.contentDocumentId;
          this.toast("Photo replaced.", "success");
        } else {
          this.toast("Upload failed. No result returned.", "error");
        }
      } catch (err) {
        console.error(err);
        this.toast(err?.body?.message || err.message, "error");
      }
    };
    reader.readAsDataURL(file);
  }

  toast(message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title: "Photo Uploader", message, variant }));
  }
}