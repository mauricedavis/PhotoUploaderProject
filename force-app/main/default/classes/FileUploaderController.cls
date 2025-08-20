public with sharing class FileUploaderController {
    private static final String RECORD_PHOTO_DESC = 'record photo';

    // Return the current photo (preferred: Is_Currently_Displayed__c=true)
    @AuraEnabled(cacheable=true)
    public static ContentVersion getCurrentPhoto(Id recordId) {
        if (recordId == null) return null;

        Set<Id> docIds = new Set<Id>();
        for (ContentDocumentLink cdl : [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :recordId
        ]) {
            docIds.add(cdl.ContentDocumentId);
        }
        if (docIds.isEmpty()) return null;

        // Prefer flagged current
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

        // Fallback to latest "record photo"
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

    // Flip off every other "current" for that Account and set target version true
    @AuraEnabled
    public static void setCurrentPhotoSmart(Id recordId, Id versionId) {
        if (recordId == null || versionId == null) return;

        Set<Id> docIds = new Set<Id>();
        for (ContentDocumentLink cdl : [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :recordId
        ]) {
            docIds.add(cdl.ContentDocumentId);
        }
        if (docIds.isEmpty()) return;

        List<ContentVersion> upd = new List<ContentVersion>();

        for (ContentVersion cv : [
            SELECT Id, Is_Currently_Displayed__c
            FROM ContentVersion
            WHERE ContentDocumentId IN :docIds
              AND Description = :RECORD_PHOTO_DESC
              AND Is_Currently_Displayed__c = TRUE
              AND Id != :versionId
        ]) {
            cv.Is_Currently_Displayed__c = false;
            upd.add(cv);
        }

        ContentVersion target = [
            SELECT Id, Is_Currently_Displayed__c, Description
            FROM ContentVersion
            WHERE Id = :versionId
            LIMIT 1
        ];
        target.Is_Currently_Displayed__c = true;
        if (target.Description != RECORD_PHOTO_DESC) target.Description = RECORD_PHOTO_DESC;
        upd.add(target);

        if (!upd.isEmpty()) update upd;
    }

    public class UploadResult {
        @AuraEnabled public Id versionId;
        @AuraEnabled public Id contentDocumentId;
        @AuraEnabled public String message;
    }

    // Create a new ContentVersion from base64 and make it current
    // NOTE: ~6 MB limit for synchronous Apex uploads
    @AuraEnabled
    public static UploadResult createAndSetPhoto(Id recordId, String fileName, String base64Data, String contentType) {
        if (String.isBlank(base64Data) || recordId == null)
            throw new AuraHandledException('No file contents or recordId.');

        Blob body = EncodingUtil.base64Decode(base64Data);
        if (body.size() > 6000000) { // guard for big files
            throw new AuraHandledException('File too large to upload inline (>6 MB). Please use the Upload Files button.');
        }

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

        // Get the ContentDocumentId then link it to the record
        cv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];
        insert new ContentDocumentLink(
            ContentDocumentId = cv.ContentDocumentId,
            LinkedEntityId = recordId,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );

        // Enforce single current for that record
        setCurrentPhotoSmart(recordId, cv.Id);

        UploadResult res = new UploadResult();
        res.versionId = cv.Id;
        res.contentDocumentId = cv.ContentDocumentId;
        res.message = 'Uploaded';
        return res;
    }
}