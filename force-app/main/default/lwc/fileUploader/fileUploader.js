import { LightningElement, api, track } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getCurrentPhoto       from "@salesforce/apex/FileUploaderController.getCurrentPhoto";
import uploadPhotoFromLwc    from "@salesforce/apex/FileUploaderController.uploadPhotoFromLwc";

export default class FileUploader extends LightningElement {
  @api recordId;
  @track fileUrl;

  connectedCallback() { this.refresh(); }

  refresh() {
    if (!this.recordId) { this.fileUrl = null; return; }
    getCurrentPhoto({ recordId: this.recordId })
      .then(cv => {
        this.fileUrl = cv ? ("/sfc/servlet.shepherd/version/download/" + cv.Id) : null;
      })
      .catch(e => {
        // eslint-disable-next-line no-console
        console.error("getCurrentPhoto error", e);
        this.fileUrl = null;
      });
  }

  onDragOver(evt) {
    evt.preventDefault();
    this.template.querySelector(".frame")?.classList.add("dragging");
  }
  onDragLeave() {
    this.template.querySelector(".frame")?.classList.remove("dragging");
  }

  async onDrop(evt) {
    evt.preventDefault();
    this.template.querySelector(".frame")?.classList.remove("dragging");
    const file = evt?.dataTransfer?.files?.[0];
    if (file) { await this.upload(file); }
  }

  openPicker() {
    const input = this.template.querySelector(".picker");
    if (input) input.click();
  }
  async onPickChange(evt) {
    const file = evt?.target?.files?.[0];
    if (file) { await this.upload(file); }
    evt.target.value = ""; // allow same-file re-select
  }

  async upload(file) {
    if (!this.recordId) return;

    // 1) Optimistic preview
    const tempUrl = URL.createObjectURL(file);
    this.fileUrl  = tempUrl;

    // 2) Read as base64 data URL and send to Apex
    const dataUrl = await new Promise((resolve, reject) => {
      const r = new FileReader();
      r.onload = () => resolve(r.result);
      r.onerror = reject;
      r.readAsDataURL(file);
    });

    uploadPhotoFromLwc({
      recordId: this.recordId,
      fileName: file.name,
      dataUrl: dataUrl,
      contentType: file.type
    })
    .then(versionId => {
      // 3) Swap to the persisted file URL
      URL.revokeObjectURL(tempUrl);
      this.fileUrl = "/sfc/servlet.shepherd/version/download/" + versionId;

      this.dispatchEvent(new ShowToastEvent({
        title: "Success",
        message: "Photo uploaded and set as current.",
        variant: "success"
      }));
    })
    .catch(err => {
      // eslint-disable-next-line no-console
      console.error("uploadPhotoFromLwc error", err);
      URL.revokeObjectURL(tempUrl);
      this.dispatchEvent(new ShowToastEvent({
        title: "Upload Error",
        message: err?.body?.message || "Unable to upload photo.",
        variant: "error"
      }));
      this.refresh(); // fall back to persisted state
    });
  }

  get allowMultiple() { return false; }
}