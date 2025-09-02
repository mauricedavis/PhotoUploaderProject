# Changelog

## 2025-09-02--1132AM – HEIC support (client-convert) + drop zone

- Added **heic2any** static resource and lazy-loaded it in LWC.
- New **drag & drop** area converts **.heic → .jpg** in the browser and uploads via Apex.
- Kept standard **lightning-file-upload** path for all types (.jpg/.jpeg/.png/.pdf/.heic).
- Instant render after upload remains unchanged.## 2025-09-02--1258PM
- Add PDF preview (inline iframe) and accept .pdf uploads; Client-side HEIC?JPEG conversion using heic2any static resource; Drag-and-drop to replace current image; Enforce single 'Is Currently Displayed' on every upload (Apex + safety trigger); Instant render after upload; no page refresh


## 2025-09-02--0119PM
- LWC: HEIC?JPEG, drag-n-drop replace, instant render; Apex: single-current enforcement; heic2any SR; PDF preview; log 2025-09-02--0119PM
### 2025-09-02--0218PM
- Add configurable max file size guard (default 12 MB) to Photo Uploader
- Pre-validate in picker & drag-and-drop before upload
- Instant render preserved via Apex route

