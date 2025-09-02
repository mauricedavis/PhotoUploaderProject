# Changelog

## 2025-09-02--1132AM – HEIC support (client-convert) + drop zone

- Added **heic2any** static resource and lazy-loaded it in LWC.
- New **drag & drop** area converts **.heic → .jpg** in the browser and uploads via Apex.
- Kept standard **lightning-file-upload** path for all types (.jpg/.jpeg/.png/.pdf/.heic).
- Instant render after upload remains unchanged.