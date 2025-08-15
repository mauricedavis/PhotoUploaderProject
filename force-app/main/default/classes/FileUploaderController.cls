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

        // Prefer the flagged "record photo"
        List<ContentVersion> flagged = [
            SELECT Id, ContentDocumentId, Description, Is_Currently_Displayed__c
            FROM ContentVersion
            WHERE ContentDocumentId IN :docIds
              AND Description = 'record photo'
              AND Is_Currently_Displayed__c = TRUE
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ];
        if (!flagged.isEmpty()) return flagged[0];

        // Fallback: most recent "record photo"
        List<ContentVersion> fallback = [
            SELECT Id, ContentDocumentId, Description
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
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :recordId
        ]) {
            docIds.add(cdl.ContentDocumentId);
        }
        if (docIds.isEmpty()) return;

        // Unflag any currently displayed "record photo" on this record
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

        // Flag the requested version (and ensure it's typed as a record photo)
        ContentVersion newCv = [
            SELECT Id, Description, Is_Currently_Displayed__c
            FROM ContentVersion
            WHERE Id = :versionId
            LIMIT 1
        ];
        if (newCv.Description != 'record photo') newCv.Description = 'record photo';
        newCv.Is_Currently_Displayed__c = true;
        toUpdate.add(newCv);

        update toUpdate;
    }
}