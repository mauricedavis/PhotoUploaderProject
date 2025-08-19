public with sharing class FileUploaderController {

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
    public static void setCurrentPhoto(Id recordId, Id versionId) {
        if (recordId == null || versionId == null) return;

        Set<Id> docIds = new Set<Id>();
        for (ContentDocumentLink cdl : [
            SELECT ContentDocumentId FROM ContentDocumentLink
            WHERE LinkedEntityId = :recordId
        ]) {
            docIds.add(cdl.ContentDocumentId);
        }
        if (docIds.isEmpty()) return;

        List<ContentVersion> updates = new List<ContentVersion>();

        for (ContentVersion cv : [
            SELECT Id, Is_Currently_Displayed__c
            FROM ContentVersion
            WHERE ContentDocumentId IN :docIds
              AND Description = 'record photo'
              AND Is_Currently_Displayed__c = TRUE
              AND Id != :versionId
        ]) {
            cv.Is_Currently_Displayed__c = false;
            updates.add(cv);
        }

        ContentVersion chosen = [
            SELECT Id, Is_Currently_Displayed__c, Description, ContentDocumentId
            FROM ContentVersion
            WHERE Id = :versionId
            LIMIT 1
        ];
        chosen.Is_Currently_Displayed__c = true;
        if (chosen.Description != 'record photo') chosen.Description = 'record photo';
        updates.add(chosen);

        update updates;
    }

    @AuraEnabled
    public static Id uploadPhotoFromLwc(Id recordId, String fileName, String dataUrl, String contentType) {
        if (recordId == null || String.isBlank(fileName) || String.isBlank(dataUrl)) return null;

        // data:image/png;base64,AAAA...
        String base64Body = dataUrl.contains(',') ? dataUrl.substring(dataUrl.indexOf(',')+1) : dataUrl;
        Blob body = EncodingUtil.base64Decode(base64Body);

        ContentVersion cv = new ContentVersion();
        cv.Title        = (fileName.contains('.') ? fileName.substring(0, fileName.lastIndexOf('.')) : fileName);
        cv.PathOnClient = fileName;
        cv.VersionData  = body;
        cv.Description  = 'record photo';
        insert cv;

        Id docId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;

        ContentDocumentLink cdl = new ContentDocumentLink(
            ContentDocumentId = docId,
            LinkedEntityId    = recordId,
            ShareType         = 'V',
            Visibility        = 'AllUsers'
        );
        insert cdl;

        setCurrentPhoto(recordId, cv.Id);
        return cv.Id;
    }
}