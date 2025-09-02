import { LightningElement, api, track } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { loadScript } from "lightning/platformResourceLoader";
import heic2any from "@salesforce/resourceUrl/heic2any";

import getCurrentPhoto from "@salesforce/apex/FileUploaderController.getCurrentPhoto";
import setCurrentPhoto from "@salesforce/apex/FileUploaderController.setCurrentPhoto";
import uploadPhotoFromLwc from "@salesforce/apex/FileUploaderController.uploadPhotoFromLwc";

export default class FileUploader extends LightningElement {
  @api recordId;
  @track fileUrl;
  @track contentDocumentId;

  heicReady = false;
  acceptHeic = true; // controls if dropzone will allow .heic

  connectedCallback() {
    // fetch current photo so it persists across refreshes
    this.refreshCurrent();
  }

  renderedCallback() {
    if (this.heicReady) return;
    this.heicReady = true;
    loadScript(this, heic2any)
      .then(() => {
        // library loaded (or stub present)
        // console.log("heic2any loaded");
      })
      .catch((e) => {
        // stub remains; conversion will throw if attempted
        // console.warn("heic2any load failed", e);
      });
  }

  refreshCurrent() {
    if (!this.recordId) return;
    getCurrentPhoto({ recordId: this.recordId })
      .then((cv) => {
        if (cv) {
          this.contentDocumentId = cv.ContentDocumentId;
          this.fileUrl =
            "/sfc/servlet.shepherd/version/renditionDownload?rendition=ORIGINAL_JPG&versionId=" +
            cv.Id;
        } else {
          this.fileUrl = null;
          this.contentDocumentId = null;
        }
      })
      .catch((err) => {
        // keep UI functional even if call fails
        // console.error(err);
      });
  }

  // keep your existing file-upload flow
  get acceptedFormats() {
    // Let standard upload accept JPEG/PNG/PDF/HEIC, even if conversion
    // only occurs on drop. PDF will upload as-is (no conversion).
    return [".jpg", ".jpeg", ".png", ".pdf", ".heic"];
  }
  get allowMultiple() {
    return false;
  }

  handleUploadFinished(evt) {
    // Standard lightning-file-upload finished -> immediate render
    const f = evt.detail.files?.[0];
    if (!f) return;

    this.contentDocumentId = f.documentId;
    const versionId = f.contentVersionId;
    this.fileUrl =
      "/sfc/servlet.shepherd/version/renditionDownload?rendition=ORIGINAL_JPG&versionId=" +
      versionId;

    // also mark single-current (server-side enforces uniqueness)
    setCurrentPhoto({ recordId: this.recordId, documentId: this.contentDocumentId })
      .catch(() => {});
  }

  // ---- Drag & drop HEIC support (client conversion -> Apex upload) ----

  handleDragOver(e) {
    e.preventDefault();
    e.dataTransfer.dropEffect = "copy";
  }

  async handleDrop(e) {
    e.preventDefault();
    const files = e.dataTransfer?.files;
    if (!files || files.length === 0) return;

    const file = files[0];
    const name = file.name || "photo.heic";
    const isHeic = /\.heic$/i.test(name);
    if (!isHeic) {
      this.toast("Only HEIC is converted on drop. Use button for other types.", "warning");
      return;
    }

    try {
      if (!window.heic2any) {
        throw new Error("heic2any not available.");
      }
      // Convert to JPEG Blob
      const jpegBlob = await window.heic2any({ blob: file, toType: "image/jpeg" });

      // Read as base64 for Apex upload
      const base64 = await this.blobToBase64(jpegBlob);
      const safeName = name.replace(/\.heic$/i, ".jpg");

      const result = await uploadPhotoFromLwc({
        recordId: this.recordId,
        fileName: safeName,
        base64Data: base64,
        contentType: "image/jpeg"
      });

      // expect { versionId, documentId } from Apex
      if (result && result.versionId) {
        this.contentDocumentId = result.documentId;
        this.fileUrl =
          "/sfc/servlet.shepherd/version/renditionDownload?rendition=ORIGINAL_JPG&versionId=" +
          result.versionId;
        this.toast("Photo replaced.", "success");
      } else {
        this.toast("Upload finished, but response was unexpected.", "warning");
      }
    } catch (err) {
      this.toast(
        "HEIC convert/upload failed. You can still use the Upload button.",
        "error"
      );
      // console.error(err);
    }
  }

  blobToBase64(blob) {
    return new Promise((resolve, reject) => {
      const r = new FileReader();
      r.onload = () => {
        const dataUrl = r.result; // data:<type>;base64,XXXXX
        const base64 = dataUrl.split(",")[1] || "";
        resolve(base64);
      };
      r.onerror = reject;
      r.readAsDataURL(blob);
    });
  }

  toast(msg, variant="info") {
    this.dispatchEvent(
      new ShowToastEvent({
        title: variant === "error" ? "Error" : variant === "success" ? "Success" : "Notice",
        message: msg,
        variant
      })
    );
  }
}