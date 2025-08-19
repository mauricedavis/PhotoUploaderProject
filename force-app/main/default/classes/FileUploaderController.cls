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

        // Prefer explicitly pinned "record photo"
        List<ContentVersion> pinned = [
            SELECT Id, ContentDocumentId
            FROM ContentVersion
            WHERE ContentDocumentId IN :docIds
              AND Is_Currently_Displayed__c = TRUE
              AND Description = 'record photo'
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ];
        if (!pinned.isEmpty()) return pinned[0];

        // Fallback: latest "record photo" even if not pinned
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
    public static void setCurrentPhotoSmart(Id recordId, Id documentId, Id versionId) {
        if (recordId == null && documentId == null && versionId == null) return;

        // Gather all docs linked to the record so we can unpin them
        Set<Id> docIds = new Set<Id>();
        if (recordId != null) {
            for (ContentDocumentLink cdl : [
                SELECT ContentDocumentId
                FROM ContentDocumentLink
                WHERE LinkedEntityId = :recordId
            ]) {
                docIds.add(cdl.ContentDocumentId);
            }
        }
        if (documentId != null) {
            docIds.add(documentId);
        }

        // Resolve the target version
        ContentVersion target;
        if (versionId != null) {
            List<ContentVersion> tmp = [
                SELECT Id, ContentDocumentId, Is_Currently_Displayed__c, Description
                FROM ContentVersion
                WHERE Id = :versionId
                LIMIT 1
            ];
            if (!tmp.isEmpty()) target = tmp[0];
        }
        if (target == null && documentId != null) {
            List<ContentVersion> latest = [
                SELECT Id, ContentDocumentId, Is_Currently_Displayed__c, Description
                FROM ContentVersion
                WHERE ContentDocumentId = :documentId
                ORDER BY LastModifiedDate DESC
                LIMIT 1
            ];
            if (!latest.isEmpty()) target = latest[0];
        }
        if (target == null) return;

        // Unpin everything else for this record
        List<ContentVersion> updates = new List<ContentVersion>();
        if (!docIds.isEmpty()) {
            for (ContentVersion cv : [
                SELECT Id, Is_Currently_Displayed__c
                FROM ContentVersion
                WHERE ContentDocumentId IN :docIds
                  AND Is_Currently_Displayed__c = TRUE
            ]) {
                cv.Is_Currently_Displayed__c = false;
                updates.add(cv);
            }
        }

        // Pin the chosen version and mark as "record photo"
        target.Is_Currently_Displayed__c = true;
        if (target.Description != 'record photo') target.Description = 'record photo';
        updates.add(target);

        update updates;
    }
}