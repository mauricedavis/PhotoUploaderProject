import { LightningElement, api, track } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";

import getCurrentPhoto      from "@salesforce/apex/FileUploaderController.getCurrentPhoto";
import setCurrentPhotoSmart from "@salesforce/apex/FileUploaderController.setCurrentPhotoSmart";
import createAndSetPhoto    from "@salesforce/apex/FileUploaderController.createAndSetPhoto";
import uploadPhotoFromLwc   from "@salesforce/apex/FileUploaderController.uploadPhotoFromLwc";

export default class FileUploader extends LightningElement {
  @api recordId;

  @track fileUrl;
  @track contentDocumentId;
  @track isDragging = false;

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

  // --- Native upload button path (instant render + enforce single-current) ---
  async handleUploadFinished(evt) {
    try {
      const f = evt.detail?.files?.[0];
      if (!f) return;

      // Instant render
      if (f.contentVersionId) {
        this.fileUrl = this.makeUrl(f.contentVersionId);
      }
      this.contentDocumentId = f.documentId;

      // Enforce single-current for the Account
      if (f.contentVersionId) {
        await setCurrentPhotoSmart({ recordId: this.recordId, versionId: f.contentVersionId });
      } else if (f.documentId) {
        // Fallback for orgs/events that don't include versionId
        await uploadPhotoFromLwc({ recordId: this.recordId, contentDocumentId: f.documentId });
      }

      this.toast("Photo uploaded and set as current.", "success");
    } catch (e) {
      console.error(e);
      this.toast(e?.body?.message || e.message, "error");
    }
  }

  // --- Drag & Drop path (custom base64 -> Apex) ---
  handleDragOver(e) { e.preventDefault(); e.stopPropagation(); if (e.dataTransfer) e.dataTransfer.dropEffect = "copy"; }
  handleDragEnter(e){ e.preventDefault(); e.stopPropagation(); this.isDragging = true; }
  handleDragLeave(e){ e.preventDefault(); e.stopPropagation(); this.isDragging = false; }

  handleDrop(e) {
    e.preventDefault(); e.stopPropagation(); this.isDragging = false;

    const dt = e.dataTransfer;
    let file = null;
    if (dt?.files?.length) file = dt.files[0];
    else if (dt?.items?.length) {
      for (const it of dt.items) if (it.kind === "file") { file = it.getAsFile(); break; }
    }
    if (!file) return this.toast("No file detected in drop.", "error");
    if (!/image\/(jpeg|png)/i.test(file.type)) return this.toast("Use JPG or PNG.", "error");

    const reader = new FileReader();
    reader.onload = async () => {
      try {
        const base64 = String(reader.result).split("base64,").pop();
        const res = await createAndSetPhoto({
          recordId: this.recordId,
          fileName: file.name,
          base64Data: base64,
          contentType: file.type
        });

        if (res?.versionId) {
          // Instant render after drop
          this.fileUrl = this.makeUrl(res.versionId);
          this.contentDocumentId = res.contentDocumentId;
          this.toast("Photo replaced.", "success");
        } else {
          this.toast("Upload failed.", "error");
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