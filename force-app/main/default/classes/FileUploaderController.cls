public with sharing class FileUploaderController {

    @AuraEnabled(cacheable=true)
    public static ContentVersion getCurrentPhoto(Id recordId) {
        if (recordId == null) return null;

        // Collect linked documents for this record
        Set<Id> docIds = new Set<Id>();
        for (ContentDocumentLink cdl : [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :recordId
        ]) {
            docIds.add(cdl.ContentDocumentId);
        }
        if (docIds.isEmpty()) return null;

        // Preferred match: flagged as 'record photo' and currently displayed
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

        // Fallback: most recent 'record photo' among linked documents
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

        // Collect linked documents for this record
        Set<Id> docIds = new Set<Id>();
        for (ContentDocumentLink cdl : [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :recordId
        ]) {
            docIds.add(cdl.ContentDocumentId);
        }
        if (docIds.isEmpty()) return;

        // Unset any previous current photos for this record
        List<ContentVersion> toUpdate = new List<ContentVersion>();
        for (ContentVersion cv : [
            SELECT Id, Is_Currently_Displayed__c
            FROM ContentVersion
            WHERE ContentDocumentId IN :docIds
              AND Description = 'record photo'
              AND Is_Currently_Displayed__c = TRUE
        ]) {
            cv.Is_Currently_Displayed__c = false;
            toUpdate.add(cv);
        }

        // Set the uploaded version as current + ensure proper description
        ContentVersion newCv = [
            SELECT Id, Is_Currently_Displayed__c, Description
            FROM ContentVersion
            WHERE Id = :versionId
            LIMIT 1
        ];
        newCv.Is_Currently_Displayed__c = true;
        if (newCv.Description != 'record photo') {
            newCv.Description = 'record photo';
        }
        toUpdate.add(newCv);

        update toUpdate;
    }
}
