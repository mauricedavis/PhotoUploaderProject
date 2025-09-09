import { LightningElement, api, track } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getMaxUploadMb from "@salesforce/apex/FileUploaderController.getMaxUploadMb";
import uploadPhotoFromLwc from "@salesforce/apex/FileUploaderController.uploadPhotoFromLwc";

export default class FileUploader extends LightningElement {
  @api recordId;
  @track maxMb = 12;   // fallback until server value arrives

  connectedCallback() {
    getMaxUploadMb()
      .then(v => { if (v) this.maxMb = v; })
      .catch(() => { /* leave fallback */ });
  }

  // Convert a File → base64 (string without prefix)
  fileToBase64(file) {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onload = () => {
        const base64 = reader.result.split(",")[1];
        resolve(base64);
      };
      reader.onerror = reject;
      reader.readAsDataURL(file);
    });
  }

  onPick(event) {
    const file = event.target.files && event.target.files[0];
    if (!file) return;

    const maxBytes = this.maxMb * 1024 * 1024;
    if (file.size > maxBytes) {
      this.notify(
        "File too large",
        `Maximum allowed size is ${this.maxMb}MB. Your file is ${ (file.size/1024/1024).toFixed(2) }MB.`,
        "error"
      );
      event.target.value = null; // clear selection
      return;
    }

    // OK – proceed to upload
    this.fileToBase64(file)
      .then(b64 => uploadPhotoFromLwc({
        parentId: this.recordId,
        fileName: file.name,
        base64Data: b64,
        contentType: file.type || "application/octet-stream"
      }))
      .then(() => {
        this.notify("Photo Uploader", "Photo uploaded and set as current.", "success");
        // emit event so host page can refresh if needed
        this.dispatchEvent(new CustomEvent("refresh"));
      })
      .catch(err => {
        const msg = err?.body?.message || err?.message || "Upload failed.";
        this.notify("Upload Error", msg, "error");
      });
  }

  notify(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }
}