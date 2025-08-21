public with sharing class FileUploaderController {
    private static final String RECORD_PHOTO_DESC = 'record photo';

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

    // Flip OFF all others for this Account and set the provided version ON
    @AuraEnabled
    public static void setCurrentPhotoSmart(Id recordId, Id versionId) {
        if (recordId == null || versionId == null) return;

        Set<Id> docIds = new Set<Id>();
        for (ContentDocumentLink cdl : [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :recordId
        ]) docIds.add(cdl.ContentDocumentId);
        if (docIds.isEmpty()) return;

        List<ContentVersion> updates = new List<ContentVersion>();

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

    public class UploadResult {
        @AuraEnabled public Id versionId;
        @AuraEnabled public Id contentDocumentId;
        @AuraEnabled public String message;
    }

    // Create version from base64, link to record, enforce single-current
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

        ContentVersion cv = new ContentVersion(
            Title = title,
            PathOnClient = fileName,
            VersionData = body,
            IsMajorVersion = true,
            Description = RECORD_PHOTO_DESC,
            Is_Currently_Displayed__c = true
        );
        insert cv;

        // Link document to the record
        cv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];
        insert new ContentDocumentLink(
            ContentDocumentId = cv.ContentDocumentId,
            LinkedEntityId    = recordId,
            ShareType         = 'V',
            Visibility        = 'AllUsers'
        );

        // Enforce single-current
        setCurrentPhotoSmart(recordId, cv.Id);

        UploadResult res = new UploadResult();
        res.versionId = cv.Id;
        res.contentDocumentId = cv.ContentDocumentId;
        res.message = 'Uploaded';
        return res;
    }

    // Back-compat: single AuraEnabled method name; resolve latest version then enforce
    @AuraEnabled
    public static void uploadPhotoFromLwc(Id recordId, Id contentDocumentId) {
        if (recordId == null || contentDocumentId == null) return;
        List<ContentVersion> latest = [
            SELECT Id
            FROM ContentVersion
            WHERE ContentDocumentId = :contentDocumentId
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ];
        if (!latest.isEmpty()) {
            setCurrentPhotoSmart(recordId, latest[0].Id);
        }
    }
}