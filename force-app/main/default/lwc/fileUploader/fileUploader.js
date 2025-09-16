import { LightningElement, api, track } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getMaxUploadSizeMb from "@salesforce/apex/FileUploaderController.getMaxUploadSizeMb";
import validateAndApply   from "@salesforce/apex/FileUploaderController.validateAndApply";

export default class FileUploader extends LightningElement {
    @api recordId;
    @track fileUrl;

    maxMb = 12;
    maxBytes = 12 * 1024 * 1024;
    acceptedFormats = [".jpg", ".jpeg", ".png", ".heic"]; // add more if required

    connectedCallback() {
        getMaxUploadSizeMb()
            .then(mb => {
                if (mb && mb > 0) {
                    this.maxMb = mb;
                    this.maxBytes = mb * 1024 * 1024;
                }
            })
            .catch(() => {});
    }

    get limitText() {
        return `Max file size: ${this.maxMb} MB`;
    }

    // --- Drag & drop over preview ------------------------------------
    handleDragOver(evt) {
        evt.preventDefault();
    }
    async handleDrop(evt) {
        evt.preventDefault();
        const files = evt.dataTransfer?.files;
        if (!files || files.length === 0) return;
        await this.uploadViaBrowser(files[0]);
    }

    // --- lightning-file-upload finished ------------------------------
    async handleUploadFinished(event) {
        const file = event.detail.files?.[0];
        // DO NOT render yet; validate on the server first
        if (!file?.contentVersionId) return;
        await this.validateOnServer(file.contentVersionId);
    }

    // --- Manual upload (drag onto preview) ---------------------------
    async uploadViaBrowser(file) {
        // client-side pre-check
        if (file.size > this.maxBytes) {
            this.toast("Photo Uploader", `This file is larger than ${this.maxMb} MB.`, "error");
            return;
        }
        // Use the hidden lightning-file-upload input by clicking it
        const lfu = this.template.querySelector("lightning-file-upload");
        if (lfu) {
            lfu.uploadFiles([file]); // modern API (Winter '25+); if not available, fallback to user click
        } else {
            this.toast("Photo Uploader", "Drop-to-upload not available in this browser.", "error");
        }
    }

    // --- Call Apex to validate size & set current --------------------
    async validateOnServer(versionId) {
        try {
            const res = await validateAndApply({ recordId: this.recordId, versionId });
            if (!res || !res.ok) {
                this.toast("Photo Uploader", res?.msg || `Upload rejected (>${this.maxMb} MB).`, "error");
                return;
            }
            // Only now set the preview URL (so oversize never flashes on screen)
            this.fileUrl =
                "/sfc/servlet.shepherd/version/renditionDownload?rendition=ORIGINAL_JPG&versionId=" + res.versionId;

            this.toast("Photo Uploader", "Photo uploaded and set as current.", "success");
        } catch (e) {
            this.toast("Photo Uploader", e?.body?.message || "Upload failed.", "error");
        }
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}