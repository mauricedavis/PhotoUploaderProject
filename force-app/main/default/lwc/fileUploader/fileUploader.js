import { LightningElement, api, track } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getCurrentPhoto from "@salesforce/apex/FileUploaderController.getCurrentPhoto";
import uploadPhotoFromLwc from "@salesforce/apex/FileUploaderController.uploadPhotoFromLwc";
import getMaxLimitBytes from "@salesforce/apex/FileUploaderController.getMaxLimitBytes";

export default class FileUploader extends LightningElement {
    @api recordId;
    @track fileUrl;
    @track hasImage = false;
    maxBytes = 12 * 1024 * 1024; // default while we fetch CMDT

    get acceptAttr() {
        // keep common image types; HEIC/PDF can be supported by server if enabled elsewhere
        return ".jpg,.jpeg,.png,.heic,.pdf";
    }

    connectedCallback() {
        this.refreshImage();
        getMaxLimitBytes()
            .then(b => { if (b > 0) this.maxBytes = b; })
            .catch(() => {});
    }

    refreshImage() {
        getCurrentPhoto({ recordId: this.recordId })
            .then(cv => {
                if (cv && cv.Id) {
                    this.hasImage = true;
                    this.fileUrl = "/sfc/servlet.shepherd/version/renditionDownload?rendition=ORIGINAL_JPG&versionId=" + cv.Id;
                } else {
                    this.hasImage = false;
                    this.fileUrl = null;
                }
            })
            .catch(e => this.toast("Photo Uploader", e?.body?.message || "Error loading photo", "error"));
    }

    clickPicker() {
        this.template.querySelector(".picker").click();
    }

    handleDragOver(evt) {
        evt.preventDefault();
        evt.dataTransfer.dropEffect = "copy";
    }

    handleDrop(evt) {
        evt.preventDefault();
        const f = evt.dataTransfer?.files?.[0];
        if (f) this.preflightAndUpload(f);
    }

    handleFilePicked(evt) {
        const f = evt.target.files?.[0];
        if (f) this.preflightAndUpload(f);
        evt.target.value = ""; // reset
    }

    preflightAndUpload(file) {
        // client-side size guard
        if (file.size > this.maxBytes) {
            this.toast("Photo Uploader",
                `File is ${(file.size/1048576).toFixed(1)} MB. Limit is ${(this.maxBytes/1048576).toFixed(1)} MB.`,
                "error");
            return;
        }
        const reader = new FileReader();
        reader.onload = () => {
            const base64 = reader.result.split(",")[1];
            uploadPhotoFromLwc({
                recordId: this.recordId,
                fileName: file.name,
                base64Body: base64,
                contentType: file.type,
                fileSizeBytes: file.size
            })
            .then(() => {
                this.toast("Photo Uploader", "Photo uploaded and set as current.", "success");
                this.refreshImage(); // instant render
            })
            .catch(e => {
                this.toast("Photo Uploader", e?.body?.message || "Upload failed", "error");
            });
        };
        reader.readAsDataURL(file);
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}