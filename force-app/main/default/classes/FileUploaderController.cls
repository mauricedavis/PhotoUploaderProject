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

    // Turn off every other "current" for the same Account; set target true
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
        ]) { other.Is_Currently_Displayed__c = false; updates.add(other); }

        ContentVersion target = [
            SELECT Id, Is_Currently_Displayed__c, Description
            FROM ContentVersion
            WHERE Id = :versionId
            LIMIT 1
        ];
        target.Is_Currently_Displayed__c = true;
        if (target.Description != RECORD_PHOTO_DESC) target.Description = RECORD_PHOTO_DESC;
        updates.add(target);

        if (!updates.isEmpty()) update updates;
    }

    public class UploadResult {
        @AuraEnabled public Id versionId;
        @AuraEnabled public Id contentDocumentId;
        @AuraEnabled public String message;
    }

    // Drag&drop path: create version from base64, link to Account, mark current
    @AuraEnabled
    public static UploadResult createAndSetPhoto(Id recordId, String fileName, String base64Data, String contentType) {
        if (recordId == null || String.isBlank(base64Data))
            throw new AuraHandledException('Missing recordId or file data.');

        Blob body = EncodingUtil.base64Decode(base64Data);
        if (body.size() > 6000000)
            throw new AuraHandledException('File too large for inline upload (>6 MB). Use Upload Files button.');

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

        cv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];

        insert new ContentDocumentLink(
            ContentDocumentId = cv.ContentDocumentId,
            LinkedEntityId    = recordId,
            ShareType         = 'V',
            Visibility        = 'AllUsers'
        );

        setCurrentPhotoSmart(recordId, cv.Id);

        UploadResult res = new UploadResult();
        res.versionId = cv.Id;
        res.contentDocumentId = cv.ContentDocumentId;
        res.message = 'Uploaded';
        return res;
    }
}