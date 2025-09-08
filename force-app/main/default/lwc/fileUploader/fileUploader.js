import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import setCurrentPhotoByVersion from '@salesforce/apex/FileUploaderController.setCurrentPhotoByVersion';

export default class FileUploader extends LightningElement {
    @api recordId;                       // Account Id
    @api maxFileSizeMB = 12; // configurable (default 12MB)
    @api multiple = false;

    @track fileUrl;

    // Accepted types we claim at the input level
    acceptAttr = '.jpg,.jpeg,.png,.heic,.pdf,image/jpeg,image/png,image/heic,application/pdf';

    connectedCallback() {
        // fetch current photo URL from existing Apex you've been using
        this.refreshCurrentImage();
    }

    async refreshCurrentImage() {
        try {
            // Minimal call you already have in your org:
            // getCurrentPhoto returns latest ContentVersion (Id, ContentDocumentId)
            // Re-use your earlier wire or imperative fetch
            const resp = await fetch('/services/data/v62.0/query/?q='
                + encodeURIComponent(SELECT Id, ContentDocumentId 
                                       FROM ContentVersion 
                                       WHERE Is_Currently_Displayed__c = TRUE 
                                         AND ContentDocument.LatestPublishedVersionId = Id
                                         AND ContentDocument.LatestPublishedVersion.IsDeleted = FALSE
                                         AND ContentDocument.LatestPublishedVersion.Description = 'record photo'
                                         AND ContentDocument.LatestPublishedVersion.ContentDocument.LatestPublishedVersionId = Id
                                         AND ContentDocumentId IN (SELECT ContentDocumentId 
                                                                   FROM ContentDocumentLink 
                                                                   WHERE LinkedEntityId='')
                                       ORDER BY LastModifiedDate DESC LIMIT 1));
            const data = await resp.json();
            if (data.records?.length) {
                const vId = data.records[0].Id;
                this.fileUrl = /sfc/servlet.shepherd/version/renditionDownload?rendition=ORIGINAL_JPG&versionId=;
            } else {
                this.fileUrl = null;
            }
        } catch(e) {
            // fail-soft
            // eslint-disable-next-line no-console
            console.error(e);
        }
    }

    // UI: open file picker
    openPicker() {
        this.template.querySelector('input[type="file"]').click();
    }

    // Drag-n-drop
    handleDragOver(evt) {
        evt.preventDefault();
        evt.dataTransfer.dropEffect = 'copy';
    }
    handleDrop(evt) {
        evt.preventDefault();
        const files = evt.dataTransfer?.files;
        if (files && files.length) {
            this.processFiles(files);
        }
    }

    // Picker select
    handleSelect(evt) {
        const files = evt.target.files;
        if (files && files.length) {
            this.processFiles(files);
            evt.target.value = ''; // reset input for same-name reselects
        }
    }

    // ----- hard size check + upload -----
    get maxBytes() {
        return (parseInt(this.maxFileSizeMB, 10) || 12) * 1024 * 1024;
    }

    async processFiles(fileList) {
        for (const file of Array.from(fileList)) {
            if (file.size > this.maxBytes) {
                this.toast('Photo Uploader', File is too large ( MB). Max is  MB., 'error');
                continue;
            }
            try {
                const prepared = await this.prepareFile(file);   // HEIC/PDF hooks
                const versionId = await this.createVersion(prepared.blob, prepared.name, prepared.type);
                await setCurrentPhotoByVersion({ recordId: this.recordId, versionId }); // server-side single-current enforcement
                await this.refreshCurrentImage();
                this.toast('Photo Uploader', 'Photo uploaded.', 'success');
            } catch (e) {
                // eslint-disable-next-line no-console
                console.error(e);
                this.toast('Photo Uploader', (e?.body?.message || e?.message || 'Upload failed'), 'error');
            }
            if (!this.multiple) break;
        }
    }

    // Optionally convert HEIC/PDF – stubs left in place (HEIC if static resource included)
    async prepareFile(file) {
        const lower = (file.name || '').toLowerCase();
        if (lower.endsWith('.heic') || file.type === 'image/heic') {
            // If you uploaded Static Resource "heic2any_min", we can try client conversion
            if (window.heic2any) {
                const blob = await window.heic2any({ blob: file, toType: 'image/jpeg' });
                const name = lower.replace(/\.heic$/, '.jpg');
                return { blob, name, type: 'image/jpeg' };
            }
            // else block HEIC if not convertible in this browser
            throw new Error('HEIC not supported in this browser. Please use JPG/PNG.');
        }
        if (lower.endsWith('.pdf') || file.type === 'application/pdf') {
            // For now, we don’t convert PDF to image here; block with a clear message.
            // (You can later wire pdf.js to render first page to a canvas and upload as JPEG.)
            throw new Error('PDF not supported for rendering. Please use JPG/PNG (or add pdf.js conversion).');
        }
        // JPG/PNG straight-through
        return { blob: file, name: file.name, type: file.type || 'application/octet-stream' };
    }

    // Multipart to ContentVersion (no Apex heap limits)
    async createVersion(blob, name, mime) {
        const meta = {
            Title: (name || 'upload').replace(/\.[^.]+$/, ''),
            PathOnClient: name || 'upload',
            FirstPublishLocationId: this.recordId,
            Description: 'record photo',
            Is_Currently_Displayed__c: true
        };
        const form = new FormData();
        form.append('entity_content', new Blob([JSON.stringify(meta)], { type: 'application/json' }));
        form.append('VersionData', blob, name);

        const resp = await fetch('/services/data/v62.0/sobjects/ContentVersion', {
            method: 'POST',
            body: form
        });
        if (!resp.ok) {
            const txt = await resp.text();
            throw new Error(txt);
        }
        const json = await resp.json();
        return json.id; // ContentVersion Id
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}