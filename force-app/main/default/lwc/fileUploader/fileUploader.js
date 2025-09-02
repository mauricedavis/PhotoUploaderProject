import { LightningElement, api, track } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getCurrentPhoto from "@salesforce/apex/FileUploaderController.getCurrentPhoto";
import uploadPhotoFromLwc from "@salesforce/apex/FileUploaderController.uploadPhotoFromLwc";
import Heic2any from "@salesforce/resourceUrl/heic2any";
import { loadScript } from "lightning/platformResourceLoader";

export default class FileUploader extends LightningElement {
    @api recordId;
    @track fileUrl;
    @track isPdf = false;
    heicLoaded = false;

    connectedCallback() {
        this.refreshCurrent();
    }

    renderedCallback() {
        if (!this.heicLoaded) {
            this.heicLoaded = true;
            loadScript(this, Heic2any + "/heic2any.min.js").catch(() => {
                // If the static resource is missing we just proceed without HEIC conversion
                this.heicLoaded = false;
            });
        }
    }

    refreshCurrent() {
        getCurrentPhoto({ recordId: this.recordId })
            .then(cv => {
                if (cv) {
                    this.isPdf = (cv.FileType === "PDF");
                    // Use direct version download so <img> and <iframe> both work
                    this.fileUrl = "/sfc/servlet.shepherd/version/download/" + cv.Id;
                } else {
                    this.fileUrl = null;
                    this.isPdf = false;
                }
            })
            .catch(err => {
                // Ignore if first load; show a console only
                // eslint-disable-next-line no-console
                console.error(err);
            });
    }

    // ------------- UI events -------------
    handleFilePick(evt) {
        const file = evt.target.files && evt.target.files[0];
        if (file) this.processAndUpload(file);
        evt.target.value = "";
    }
    handleDragOver(evt) {
        evt.preventDefault();
    }
    handleDrop(evt) {
        evt.preventDefault();
        const file = evt.dataTransfer && evt.dataTransfer.files && evt.dataTransfer.files[0];
        if (file) this.processAndUpload(file);
    }

    // ------------- Core -------------
    async processAndUpload(file) {
        try {
            let blob = file;
            let name = file.name;
            const lower = name.toLowerCase();

            // HEIC -> JPEG (if heic2any is present)
            if (lower.endsWith(".heic") && window.heic2any) {
                const converted = await window.heic2any({ blob: file, toType: "image/jpeg" });
                blob = converted instanceof Blob ? converted : converted[0];
                name = name.replace(/\.heic$/i, ".jpg");
            }

            // We read as base64 and send it to Apex; Apex enforces single-current flag
            const base64 = await this.readAsBase64(blob);

            const result = await uploadPhotoFromLwc({
                recordId: this.recordId,
                fileName: name,
                base64Data: base64,
                contentType: blob.type || this.guessType(name)
            });

            // result => { versionId, fileType }
            this.isPdf  = (result.fileType === "PDF");
            this.fileUrl = "/sfc/servlet.shepherd/version/download/" + result.versionId;

            this.dispatchEvent(
                new ShowToastEvent({
                    title: "Success",
                    message: "Photo uploaded.",
                    variant: "success"
                })
            );
        } catch (e) {
            // eslint-disable-next-line no-console
            console.error(e);
            this.dispatchEvent(
                new ShowToastEvent({
                    title: "Upload Error",
                    message: (e && e.body && e.body.message) ? e.body.message : (e.message || "Unknown error"),
                    variant: "error"
                })
            );
        }
    }

    readAsBase64(file) {
        return new Promise((resolve, reject) => {
            const r = new FileReader();
            r.onload = () => {
                const s = r.result;
                const i = s.indexOf("base64,");
                resolve(i >= 0 ? s.substring(i + 7) : s);
            };
            r.onerror = reject;
            r.readAsDataURL(file);
        });
    }

    guessType(name) {
        const n = name.toLowerCase();
        if (n.endsWith(".png")) return "image/png";
        if (n.endsWith(".jpg") || n.endsWith(".jpeg")) return "image/jpeg";
        if (n.endsWith(".pdf")) return "application/pdf";
        return "application/octet-stream";
    }
}