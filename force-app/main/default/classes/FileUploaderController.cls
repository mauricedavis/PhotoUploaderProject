public with sharing class FileUploaderController {
    private static final String RECORD_PHOTO_DESC = 'record photo';

    // Fetch the "current" photo; prefer explicitly pinned; else latest "record photo"
    @AuraEnabled(cacheable=true)
    public static ContentVersion getCurrentPhoto(Id recordId) {
        if (recordId == null) return null;

        Set<Id> docIds = new Set<Id>();
        for (ContentDocumentLink cdl : [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :recordId
        ]) docIds.add(cdl.ContentDocumentId);
        if (docIds.isEmpty()) return null;

        List<ContentVersion> flagged = [
            SELECT Id, ContentDocumentId
            FROM ContentVersion
            WHERE ContentDocumentId IN :docIds
              AND Description = :RECORD_PHOTO_DESC
              AND Is_Currently_Displayed__c = TRUE
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ];
        if (!flagged.isEmpty()) return flagged[0];

        List<ContentVersion> latest = [
            SELECT Id, ContentDocumentId
            FROM ContentVersion
            WHERE ContentDocumentId IN :docIds
              AND Description = :RECORD_PHOTO_DESC
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ];
        return latest.isEmpty() ? null : latest[0];
    }

    /**
     * Explicitly enforce: for the given record, ONLY this version is "current".
     * - Flips OFF any other ContentVersion with Description='record photo' that is current.
     * - Forces this version to Description='record photo' and current=true.
     */
    @AuraEnabled
    public static void setCurrentPhotoSmart(Id recordId, Id versionId) {
        if (recordId == null || versionId == null) return;

        // Collect all ContentDocuments linked to the record
        Set<Id> docIds = new Set<Id>();
        for (ContentDocumentLink cdl : [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :recordId
        ]) docIds.add(cdl.ContentDocumentId);
        if (docIds.isEmpty()) return;

        List<ContentVersion> updates = new List<ContentVersion>();

        // Turn OFF all other "current" record photos
        for (ContentVersion other : [
            SELECT Id, Is_Currently_Displayed__c
            FROM ContentVersion
            WHERE ContentDocumentId IN :docIds
              AND Description = :RECORD_PHOTO_DESC
              AND Is_Currently_Displayed__c = TRUE
              AND Id != :versionId
        ]) {
            other.Is_Currently_Displayed__c = false;
            updates.add(other);
        }

        // Turn ON the chosen one; enforce description
        ContentVersion target = [
            SELECT Id, ContentDocumentId, Is_Currently_Displayed__c, Description
            FROM ContentVersion
            WHERE Id = :versionId
            LIMIT 1
        ];
        if (target.Description != RECORD_PHOTO_DESC) target.Description = RECORD_PHOTO_DESC;
        target.Is_Currently_Displayed__c = true;
        updates.add(target);

        if (!updates.isEmpty()) update updates;
    }

    // Response DTO for createAndSetPhoto
    public class UploadResult {
        @AuraEnabled public Id versionId;
        @AuraEnabled public Id contentDocumentId;
        @AuraEnabled public String message;
    }

    /**
     * Create ContentVersion from base64, link to record, and enforce single-current immediately.
     * NOTE: ~6MB body limit for synchronous Apex; larger files should use the native uploader.
     */
    @AuraEnabled
    public static UploadResult createAndSetPhoto(Id recordId, String fileName, String base64Data, String contentType) {
        if (recordId == null || String.isBlank(base64Data))
            throw new AuraHandledException('Missing recordId or file data.');

        Blob body = EncodingUtil.base64Decode(base64Data);
        if (body.size() > 6000000)
            throw new AuraHandledException('File too large for inline upload (>6 MB). Please use the Upload Files button.');

        if (String.isBlank(fileName)) fileName = 'photo.jpg';
        String title = fileName;
        Integer dot = fileName.lastIndexOf('.');
        if (dot > 0) title = fileName.substring(0, dot);

        // Create initial version (marked current + description set)
        ContentVersion cv = new ContentVersion(
            Title = title,
            PathOnClient = fileName,
            VersionData = body,
            IsMajorVersion = true,
            Description = RECORD_PHOTO_DESC,
            Is_Currently_Displayed__c = true
        );
        insert cv;

        // Link the document to the record
        cv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];
        insert new ContentDocumentLink(
            ContentDocumentId = cv.ContentDocumentId,
            LinkedEntityId    = recordId,
            ShareType         = 'V',
            Visibility        = 'AllUsers'
        );

        // ENFORCE single-current (flip off others, confirm this one on)
        setCurrentPhotoSmart(recordId, cv.Id);

        UploadResult res = new UploadResult();
        res.versionId = cv.Id;
        res.contentDocumentId = cv.ContentDocumentId;
        res.message = 'Uploaded';
        return res;
    }

    // ---- Back-compat wrappers (old LWC calls) ----
    @AuraEnabled
    public static void uploadPhotoFromLwc(Id recordId, Id documentId, Id versionId) {
        // Resolve to versionId if only docId is supplied
        if (versionId == null && documentId != null) {
            List<ContentVersion> latest = [
                SELECT Id FROM ContentVersion
                WHERE ContentDocumentId = :documentId
                ORDER BY LastModifiedDate DESC
                LIMIT 1
            ];
            if (!latest.isEmpty()) versionId = latest[0].Id;
        }
        setCurrentPhotoSmart(recordId, versionId);
    }

    @AuraEnabled
    public static void uploadPhotoFromLwc(Id recordId, Id contentDocumentId) {
        // For older signatures: pick latest version of that document
        if (contentDocumentId == null) return;
        List<ContentVersion> latest = [
            SELECT Id FROM ContentVersion
            WHERE ContentDocumentId = :contentDocumentId
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ];
        if (!latest.isEmpty()) {
            setCurrentPhotoSmart(recordId, latest[0].Id);
        }
    }
}