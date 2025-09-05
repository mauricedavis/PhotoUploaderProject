import { LightningElement, api, track } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getCurrentPhoto from "@salesforce/apex/FileUploaderController.getCurrentPhoto";
import uploadPhotoFromLwc from "@salesforce/apex/FileUploaderController.uploadPhotoFromLwc";
import setCurrentPhoto from "@salesforce/apex/FileUploaderController.setCurrentPhoto";

export default class FileUploader extends LightningElement {
    @api recordId;
    /** admin-configurable in App Builder; default 12 */
    @api maxFileSizeMb = 12;

    @track fileUrl;
    @track contentDocumentId;

    get acceptString() {
        return ".jpg,.jpeg,.png,.heic,.pdf";
    }

    connectedCallback() {
        this.loadCurrent();
    }

    loadCurrent() {
        if (!this.recordId) return;
        getCurrentPhoto({ recordId: this.recordId })
            .then(cv => {
                if (cv) {
                    this.contentDocumentId = cv.ContentDocumentId;
                    this.fileUrl =
                        "/sfc/servlet.shepherd/version/renditionDownload?rendition=ORIGINAL_JPG&versionId=" + cv.Id;
                } else {
                    this.contentDocumentId = null;
                    this.fileUrl = null;
                }
            })
            .catch(e => console.error("getCurrentPhoto", e));
    }

    openPicker() {
        this.template.querySelector("input[type=file]").click();
    }
    handleDragOver(evt) {
        evt.preventDefault();
        evt.dataTransfer.dropEffect = "copy";
    }
    handleDrop(evt) {
        evt.preventDefault();
        const f = evt.dataTransfer?.files?.[0];
        if (f) this.processIncomingFile(f);
    }
    handleFilePicked(evt) {
        const f = evt.target.files?.[0];
        if (f) this.processIncomingFile(f);
        evt.target.value = "";
    }

    async processIncomingFile(file) {
        const maxBytes = this.maxBytes;
        // 1) block on original size
        if (this.hasSize(file) && file.size > maxBytes) {
            this.toast("Photo Uploader", `Max file size is ${this.maxFileSizeMb} MB.`, "error");
            return;
        }

        let workFile = file;
        const nameLower = (file.name || "").toLowerCase();
        const typeLower = (file.type || "").toLowerCase();
        const isHeic = typeLower.includes("heic") || nameLower.endsWith(".heic");
        const isPdf  = typeLower.includes("pdf")  || nameLower.endsWith(".pdf");

        try {
            if (isHeic) {
                await this.ensureHeic2Any();
                if (typeof window.heic2any !== "function") throw new Error("HEIC converter unavailable.");
                const blob = await window.heic2any({ blob: file, toType: "image/jpeg", quality: 0.9 });
                workFile = new File([blob], file.name.replace(/\.heic$/i, ".jpg"), { type: "image/jpeg" });
            } else if (isPdf) {
                workFile = await this.pdfFirstPageToJpeg(file);
            }
        } catch (e) {
            console.error("convert", e);
            this.toast("Photo Uploader", "Unable to convert file. Please use JPG or PNG.", "error");
            return;
        }

        // 2) block on converted size
        if (this.hasSize(workFile) && workFile.size > maxBytes) {
            this.toast("Photo Uploader", `Converted image exceeds ${this.maxFileSizeMb} MB.`, "error");
            return;
        }

        try {
            const base64 = await this.toBase64(workFile);
            const resp = await uploadPhotoFromLwc({
                recordId: this.recordId,
                filename: workFile.name,
                base64: base64
            });
            await setCurrentPhoto({ recordId: this.recordId, versionId: resp.versionId });
            this.fileUrl =
                "/sfc/servlet.shepherd/version/renditionDownload?rendition=ORIGINAL_JPG&versionId=" + resp.versionId;
            this.toast("Success", "Photo uploaded.", "success");
        } catch (e) {
            console.error("upload", e);
            this.toast("Upload Error", e?.body?.message || e.message || "Upload failed.", "error");
        }
    }

    get maxBytes() {
        const n = Number(this.maxFileSizeMb);
        return (isNaN(n) || n <= 0 ? 12 : n) * 1024 * 1024;
    }
    hasSize(f){ return typeof f.size === "number" && isFinite(f.size); }

    toBase64(file) {
        return new Promise((resolve, reject) => {
            const r = new FileReader();
            r.onload = () => resolve(String(r.result).split(",")[1] || "");
            r.onerror = reject;
            r.readAsDataURL(file);
        });
    }

    async pdfFirstPageToJpeg(file) {
        // Minimal approach; for fidelity consider pdf.js
        const buf = await file.arrayBuffer();
        const blobUrl = URL.createObjectURL(new Blob([buf], { type: "application/pdf" }));
        const img = new Image();
        img.crossOrigin = "anonymous";

        const loaded = new Promise((res, rej) => {
            img.onload = () => res(true);
            img.onerror = () => rej(new Error("Browser cannot render PDF as image."));
        });
        img.src = blobUrl;
        await loaded;

        const canvas = document.createElement("canvas");
        canvas.width = img.width || 1200;
        canvas.height = img.height || 800;
        const ctx = canvas.getContext("2d");
        ctx.drawImage(img, 0, 0, canvas.width, canvas.height);

        URL.revokeObjectURL(blobUrl);
        const dataUrl = canvas.toDataURL("image/jpeg", 0.9);
        const bin = atob(dataUrl.split(",")[1]);
        const u8 = new Uint8Array(bin.length);
        for (let i=0;i<bin.length;i++) u8[i] = bin.charCodeAt(i);
        return new File([u8], file.name.replace(/\.pdf$/i, ".jpg"), { type: "image/jpeg" });
    }

    async ensureHeic2Any() {
        if (typeof window.heic2any === "function") return;
        const ts = Date.now();
        const src = `/resource/${ts}/heic2any/heic2any.min.js`;
        await new Promise((resolve, reject) => {
            const s = document.createElement("script");
            s.src = src;
            s.onload = resolve;
            s.onerror = reject;
            document.head.appendChild(s);
        });
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}