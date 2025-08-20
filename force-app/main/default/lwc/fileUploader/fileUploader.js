import { LightningElement, api, track } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getCurrentPhoto      from "@salesforce/apex/FileUploaderController.getCurrentPhoto";
import setCurrentPhotoSmart from "@salesforce/apex/FileUploaderController.setCurrentPhotoSmart";
import createAndSetPhoto    from "@salesforce/apex/FileUploaderController.createAndSetPhoto";

export default class FileUploader extends LightningElement {
  @api recordId;
  @track fileUrl;
  @track contentDocumentId;
  @track isDragging = false;

  connectedCallback() { this.refreshCurrent(); }

  get acceptedFormats() { return [".jpg", ".jpeg", ".png"]; }

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

  // --- Standard Upload button path (instant render) ---
  async handleUploadFinished(evt) {
    try {
      const f = evt.detail?.files?.[0];
      if (!f) return;

      this.fileUrl = this.makeUrl(f.contentVersionId);      // instant render
      this.contentDocumentId = f.documentId;

      await setCurrentPhotoSmart({ recordId: this.recordId, versionId: f.contentVersionId });

      this.toast("Photo uploaded and set as current.", "success");
    } catch (e) {
      console.error(e);
      this.toast(e?.body?.message || e.message, "error");
    }
  }

  // --- Drag & Drop path (robust: items or files) ---
  handleDragOver(e) {
    e.preventDefault();
    e.stopPropagation();
    if (e.dataTransfer) e.dataTransfer.dropEffect = "copy";
  }
  handleDragEnter(e) { e.preventDefault(); e.stopPropagation(); this.isDragging = true; }
  handleDragLeave(e) { e.preventDefault(); e.stopPropagation(); this.isDragging = false; }

  handleDrop(e) {
    e.preventDefault();
    e.stopPropagation();
    this.isDragging = false;

    const dt = e.dataTransfer;
    let file = null;

    if (dt?.files?.length) {
      file = dt.files[0];
    } else if (dt?.items?.length) {
      for (const it of dt.items) {
        if (it.kind === "file") { file = it.getAsFile(); break; }
      }
    }
    if (!file) return this.toast("No file detected in drop.", "error");

    if (!/image\/(jpeg|png)/i.test(file.type)) {
      return this.toast("Unsupported type. Please use JPG or PNG.", "error");
    }

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

        if (res && res.versionId) {
          this.fileUrl = this.makeUrl(res.versionId);      // instant render after drop
          this.contentDocumentId = res.contentDocumentId;
          this.toast("Photo replaced.", "success");
        } else {
          this.toast("Upload failed. No result.", "error");
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