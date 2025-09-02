## Changelog
### 2025-08-12 03:37PM
- Removed email notification
- Removed automatic browser launch

# Salesforce DX Project: Next Steps

Now that you’ve created a Salesforce DX project, what’s next? Here are some documentation resources to get you started.

## How Do You Plan to Deploy Your Changes?

Do you want to deploy a set of changes, or create a self-contained application? Choose a [development model](https://developer.salesforce.com/tools/vscode/en/user-guide/development-models).

## Configure Your Salesforce DX Project

The `sfdx-project.json` file contains useful configuration information for your project. See [Salesforce DX Project Configuration](https://developer.salesforce.com/docs/atlas.en-us.sfdx_dev.meta/sfdx_dev/sfdx_dev_ws_config.htm) in the _Salesforce DX Developer Guide_ for details about this file.

## Read All About It

- [Salesforce Extensions Documentation](https://developer.salesforce.com/tools/vscode/)
- [Salesforce CLI Setup Guide](https://developer.salesforce.com/docs/atlas.en-us.sfdx_setup.meta/sfdx_setup/sfdx_setup_intro.htm)
- [Salesforce DX Developer Guide](https://developer.salesforce.com/docs/atlas.en-us.sfdx_dev.meta/sfdx_dev/sfdx_dev_intro.htm)
- [Salesforce CLI Command Reference](https://developer.salesforce.com/docs/atlas.en-us.sfdx_cli_reference.meta/sfdx_cli_reference/cli_reference.htm)

### deploy/2025-08-12--0457PM
- ? Removed 'Picture uploaded' text
- ??? Fixed duplicate folder creation logic


### deploy/2025-08-12--0504PM
- ?? Enlarged uploaded image to 400px height, responsive width


### deploy/2025-08-12--0507PM
- ??? Enlarged image to full width inside the card container


### deploy/2025-08-13--0824AM
- ?? Image now persists after page reload by retrieving latest ContentDocumentLink


### deploy/2025-08-13--0830AM
- ?? Image now persists across page reloads.


### ?? deploy/2025-08-13--0910AM � Ensure uploaded image persists after page refresh

## deploy/2025-08-13--0914AM
- Persist image after refresh


### deploy/2025-08-13--0918AM
- ?? Added debug logging for persistent image rendering

### ?? 2025-08-13--0923AM - Deployment changes:
- Fixed image persistence on refresh
- Max-height adjustment for image
- Log encoding fix (UTF-8)


### deploy/2025-08-13--1002AM
- Fix image persistence after page refresh


### 2025-08-13--0122PM
- Added support for 'Is Currently Displayed' field on ContentVersion
- Enabled drag-and-drop image replacement with persistence


### 2025-08-13--0225PM
- Added Is_Currently_Displayed__c field to ContentVersion object
- Fixed deployment errors in Apex controller and LWC
- Ensured image persists after page refresh


### 2025-08-14--0902AM
- ? FIXED Apex syntax errors in FileUploaderController.cls
- ? Added working Apex methods: getCurrentPhoto & setCurrentPhoto
- ? Confirmed LWC JS references match controller methods

### 2025-08-14--0909AM
- Fixed Apex syntax errors
- Added getCurrentPhoto & setCurrentPhoto methods


### 2025-08-14--0913AM
- Fix: Corrected syntax in FileUploaderController.cls for Apex compatibility


### 2025-08-15 12:42:10
- Feature: drag-n-drop replace + single-current enforcement; show uploader when none current; absolute path + UTF-8 no BOM; deploy 2025-08-15 12:42:10


## Changelog


### 2025-08-15--0559PM
- Drag-and-drop **replace** over current image
- Enforce **single** “Is Currently Displayed” photo per record
- Persist photo across refresh; show **Upload** when none flagged
- Auto-branch + tag; changelog update


### 2025-08-19--1539PM
- Drag-and-drop image replace (no page refresh)
- Instant preview during upload; swap to persisted URL on save
- Server-side single **Is Currently Displayed** enforcement on ContentVersion
- Description auto-set to **record photo**

### 2025-08-19--0505PM
- Enforce single 'Is Currently Displayed' on every set
- Instant preview after upload (no refresh)
- LWC/JS + Apex updated

### 2025-08-20--0831AM
- Add back-compat Apex wrappers: uploadPhotoFromLwc(..) -> setCurrentPhotoSmart(..)
- Prevent 'No apex action available' error from older/cached LWC bundles
## deploy/2025-08-20--0914AM
- Drag&Drop replace + instant render; single-current enforcement (Apex + optional trigger); LWC polish
- Drag-and-drop over image (inline Apex upload, ~6 MB limit)
- Instant image render after both paths (drop or Upload Files)
- Enforce only one **Is Currently Displayed** per Account
- Optional trigger: keeps rule even when changes happen outside the LWC

## deploy/2025-08-20--1247PM
- Fix: robust drag-and-drop + enforce single 'Is Currently Displayed' (Apex + trigger); instant render preserved
- Drag-and-drop now uses DataTransfer **items** or **files**; stopPropagation + dropEffect
- Enforce one-and-only-one **Is Currently Displayed** per Account (Apex + Trigger)
- Instant render preserved for both Upload button and drop
## deploy/2025-08-20--0558PM
- Apex patch: explicit single 'Is Currently Displayed' enforcement on every upload/set; keep trigger
- setCurrentPhotoSmart(): flips OFF other current 'record photo' versions, sets target ON
- createAndSetPhoto(): creates version, links to record, then calls setCurrentPhotoSmart()
- Back-compat wrappers preserved for older LWC bundles
## deploy/2025-08-21--1021AM
- Fix: remove @AuraEnabled overload + LWC literal {false}; keep single-current enforcement
- Keep ONE @AuraEnabled back-compat method: uploadPhotoFromLwc(recordId, contentDocumentId)
- Remove method overload (Apex disallows @AuraEnabled overloading)
- LWC: replace any literal {false} with getter allowMultiple; fix template error
## deploy/2025-08-21--0641PM
- Drag&Drop (base64) replace + instant render; enforce single 'Is Currently Displayed' on all paths; trigger retained
- LWC: true drop zone (FileReader -> base64 -> Apex createAndSetPhoto); instant render
- LWC: native Upload button path enforces single-current; falls back to uploadPhotoFromLwc if versionId missing
- Apex: createAndSetPhoto + setCurrentPhotoSmart ensure only one current; back-compat method preserved
- Trigger: keeps invariant when Files are edited outside the LWC

### 2025-09-02--1132AM � HEIC support added
- Drag & drop .heic converts to .jpg and uploads immediately.


### 2025-09-02--1258PM
- Add PDF preview (inline iframe) and accept .pdf uploads; Client-side HEIC?JPEG conversion using heic2any static resource; Drag-and-drop to replace current image; Enforce single 'Is Currently Displayed' on every upload (Apex + safety trigger); Instant render after upload; no page refresh


## 2025-09-02--0119PM
- LWC: HEIC?JPEG, drag-n-drop replace, instant render; Apex: single-current enforcement; heic2any SR; PDF preview; log 2025-09-02--0119PM
