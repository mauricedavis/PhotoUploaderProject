# Changelog

## 2025-09-02--1132AM â€“ HEIC support (client-convert) + drop zone

- Added **heic2any** static resource and lazy-loaded it in LWC.
- New **drag & drop** area converts **.heic â†’ .jpg** in the browser and uploads via Apex.
- Kept standard **lightning-file-upload** path for all types (.jpg/.jpeg/.png/.pdf/.heic).
- Instant render after upload remains unchanged.## 2025-09-02--1258PM
- Add PDF preview (inline iframe) and accept .pdf uploads; Client-side HEIC?JPEG conversion using heic2any static resource; Drag-and-drop to replace current image; Enforce single 'Is Currently Displayed' on every upload (Apex + safety trigger); Instant render after upload; no page refresh


## 2025-09-02--0119PM
- LWC: HEIC?JPEG, drag-n-drop replace, instant render; Apex: single-current enforcement; heic2any SR; PDF preview; log 2025-09-02--0119PM
### 2025-09-02--0218PM
- Add configurable max file size guard (default 12 MB) to Photo Uploader
- Pre-validate in picker & drag-and-drop before upload
- Instant render preserved via Apex route

## 2025-09-02--0253PM – Enforce 12MB limit, custom picker
- Added client-side file size gate (default 12 MB, configurable) for click & drag-drop
- Kept HEIC?JPEG conversion and first page PDF?JPEG render before upload
- Uses custom file input to pre-validate size/type (replaces lightning-file-upload for intake)
- Preserves persistence and single 'Is Currently Displayed'

## 2025-09-02--0327PM – Enforce 12 MB (client + server)
- LWC: block >12 MB on original file *and* on converted payload (HEIC/PDF) before upload
- Apex: re-check decoded blob (body.size) and reject >12 MB with clear error
- Keeps instant render + single 'Is Currently Displayed' behavior

## 2025-09-05--1102AM – 12 MB cap (client+server+trigger)
- LWC: custom picker & drag-drop; block >12 MB before upload; HEIC/PDF convert then re-check size
- Apex: reject >12 MB on server (ody.size()), still enforces single 'Is Currently Displayed'
- Trigger (ContentVersion): for Description='record photo', block >12 MB on any path and ensure single-current on manual edits

## 2025-09-08--1823PM
- Added **FileUploadConfig__mdt** (Custom Metadata) with MaxFileSizeMB__c
- DefaultConfig record deployed with 12MB
- LWC + Apex enforce max file size (configurable)
- Fixed PS script variable scoping for logs/branch

## 2025-09-08--1839PM
- 12MB configurable limit enforced (client + server)


### 2025-09-08--0746PM
- 12MB configurable limit enforced (client + server)


### 2025-09-09--0917AM
- 12MB configurable limit enforced (client + server)

### 2025-09-09--1141AM
- 12MB configurable limit enforced (client + server)
### 2025-09-09--1317PM
- 12MB configurable limit enforced (client + server)
- Oversize uploads are immediately deleted and never displayed
### 2025-09-16--0127PM
- 12MB configurable limit enforced (client + server)
- Oversize uploads are immediately deleted and never displayed
### 2025-09-16 14:10
- 12MB configurable limit enforced (client + server)
- Oversize uploads are blocked before display and rejected on server
## 2025-09-17 12:24
- 12MB configurable limit enforced (client + server, dynamic from Custom Metadata)
## 2025-09-17--1353PM
- 12MB configurable limit enforced (client + server)
- Oversize uploads are blocked client-side and rejected server-side
### 2025-09-17--1453
- 12MB configurable limit enforced (client + server)
- Oversize uploads are blocked client-side and server-side
## 2025-09-17--1542
- 12MB configurable limit enforced (client + server)
- Oversize uploads are blocked before display
## 2025-09-17--1754
- 12MB configurable limit enforced (client + server)
- Oversize uploads are blocked before display
