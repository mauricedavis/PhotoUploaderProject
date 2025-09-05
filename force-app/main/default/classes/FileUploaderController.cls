public with sharing class FileUploaderController {
    private static final Integer MAX_BYTES = 12 * 1024 * 1024;

    @AuraEnabled(cacheable=true)
    public static ContentVersion getCurrentPhoto(Id recordId){
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

        List<ContentVersion> flagged = [
            SELECT Id, ContentDocumentId
            FROM ContentVersion
            WHERE ContentDocumentId IN :docIds
              AND Description = 'record photo'
              AND Is_Currently_Displayed__c = TRUE
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ];
        if (!flagged.isEmpty()) return flagged[0];

        List<ContentVersion> fallback = [
            SELECT Id, ContentDocumentId
            FROM ContentVersion
            WHERE ContentDocumentId IN :docIds
              AND Description = 'record photo'
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ];
        return fallback.isEmpty() ? null : fallback[0];
    }

    @AuraEnabled
    public static void setCurrentPhoto(Id recordId, Id versionId){
        if (recordId == null || versionId == null) return;

        // collect all ContentDocumentIds for the record
        Set<Id> docIds = new Set<Id>();
        for (ContentDocumentLink cdl : [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :recordId
        ]) docIds.add(cdl.ContentDocumentId);
        if (docIds.isEmpty()) return;

        // turn off any other "current" photos for the same record
        List<ContentVersion> toUpdate = new List<ContentVersion>();
        for (ContentVersion cv : [
            SELECT Id, Is_Currently_Displayed__c
            FROM ContentVersion
            WHERE ContentDocumentId IN :docIds
              AND Description = 'record photo'
              AND Is_Currently_Displayed__c = TRUE
              AND Id != :versionId
        ]) {
            cv.Is_Currently_Displayed__c = false;
            toUpdate.add(cv);
        }

        ContentVersion chosen = [
            SELECT Id, Description, Is_Currently_Displayed__c
            FROM ContentVersion
            WHERE Id = :versionId
            LIMIT 1
        ];
        chosen.Is_Currently_Displayed__c = true;
        if (chosen.Description != 'record photo') chosen.Description = 'record photo';
        toUpdate.add(chosen);

        if (!toUpdate.isEmpty()) update toUpdate;
    }

    @AuraEnabled
    public static FileUploadResponse uploadPhotoFromLwc(Id recordId, String filename, String base64){
        if (recordId == null || String.isBlank(base64)) {
            throw new AuraHandledException('Missing recordId or file data.');
        }
        Blob body = EncodingUtil.base64Decode(base64);

        // hard-stop anything over 12 MB on server
        if (body.size() > MAX_BYTES) {
            throw new AuraHandledException('File exceeds the 12 MB limit.');
        }

        if (String.isBlank(filename)) filename = 'photo.jpg';

        ContentVersion cv = new ContentVersion(
            Title = filename,
            PathOnClient = filename,
            VersionData = body,
            Description = 'record photo',
            Is_Currently_Displayed__c = true
        );
        insert cv;

        Id docId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;

        insert new ContentDocumentLink(
            ContentDocumentId = docId,
            LinkedEntityId    = recordId,
            ShareType         = 'V',
            Visibility        = 'AllUsers'
        );

        // single-current enforcement
        setCurrentPhoto(recordId, cv.Id);

        return new FileUploadResponse(cv.Id, docId);
    }

    public class FileUploadResponse {
        @AuraEnabled public Id versionId;
        @AuraEnabled public Id documentId;
        public FileUploadResponse(Id v, Id d){ versionId=v; documentId=d; }
    }
}