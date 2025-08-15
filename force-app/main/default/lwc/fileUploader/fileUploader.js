import { LightningElement, api, track } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getCurrentPhoto from "@salesforce/apex/FileUploaderController.getCurrentPhoto";
import setCurrentPhoto from "@salesforce/apex/FileUploaderController.setCurrentPhoto";

export default class FileUploader extends LightningElement {
    @api recordId;
    @track fileUrl;
    @track versionId;

    connectedCallback() {
        this.refreshCurrent();
    }

    refreshCurrent() {
        if (!this.recordId) return;
        getCurrentPhoto({ recordId: this.recordId })
            .then((cv) => {
                if (cv) {
                    this.versionId = cv.Id;
                    this.fileUrl =
                        "/sfc/servlet.shepherd/version/renditionDownload?rendition=ORIGINAL_JPG&versionId=" +
                        cv.Id;
                } else {
                    this.versionId = null;
                    this.fileUrl = null;
                }
            })
            .catch((e) => {
                // Silently fail to avoid blocking page
                /* eslint-disable no-console */
                console.error("getCurrentPhoto error", e);
            });
    }

    get acceptedFormats() {
        return [".jpg", ".jpeg", ".png"];
    }
    get allowMultiple() {
        return false;
    }

    handleUploadFinished(event) {
        const file = event.detail?.files?.[0];
        if (!file) return;

        const newVersionId = file.contentVersionId;

        // Optimistic UI
        this.fileUrl =
            "/sfc/servlet.shepherd/version/renditionDownload?rendition=ORIGINAL_JPG&versionId=" +
            newVersionId;

        // Mark the uploaded image as the only "currently displayed"
        setCurrentPhoto({ recordId: this.recordId, versionId: newVersionId })
            .then(() => {
                this.versionId = newVersionId;
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: "Success",
                        message: "Photo uploaded and set as current.",
                        variant: "success"
                    })
                );
                this.refreshCurrent();
            })
            .catch((e) => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: "Upload Error",
                        message: e?.body?.message || "Unable to set current photo",
                        variant: "error"
                    })
                );
            });
    }
}