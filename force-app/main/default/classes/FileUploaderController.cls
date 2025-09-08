public with sharing class FileUploaderController {

    @AuraEnabled(cacheable=true)
    public static ContentVersion getCurrentPhoto(Id recordId) {
        if (recordId == null) return null;

        // Collect DocIds linked to record
        Set<Id> docIds = new Set<Id>();
        for (ContentDocumentLink cdl : [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :recordId
        ]) {
            docIds.add(cdl.ContentDocumentId);
        }
        if (docIds.isEmpty()) return null;

        // Prefer 'record photo' & Is_Currently_Displayed__c = true
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

        // Else any 'record photo'
        List<ContentVersion> anyPhoto = [
            SELECT Id, ContentDocumentId
            FROM ContentVersion
            WHERE ContentDocumentId IN :docIds
              AND Description = 'record photo'
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ];
        return anyPhoto.isEmpty() ? null : anyPhoto[0];
    }

    // Manual uploader (LWC drag/drop path) – also enforces single-current
    @AuraEnabled
    public static Id uploadPhotoFromLwc(Id recordId, String base64Body, String fileName, String contentType) {
        if (recordId == null || String.isBlank(base64Body) || String.isBlank(fileName)) {
            throw new AuraHandledException('Missing parameters.');
        }

        // Decode
        Blob body = EncodingUtil.base64Decode(base64Body);

        // Create ContentVersion
        ContentVersion cv = new ContentVersion();
        cv.Title = fileName;
        cv.PathOnClient = fileName;
        cv.VersionData = body;
        cv.Description = 'record photo';
        insert cv;

        // Link to record (ContentDocument is created on first insert)
        ContentDocumentLink cdl = new ContentDocumentLink(
            ContentDocumentId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId,
            LinkedEntityId = recordId,
            ShareType = 'V'
        );
        insert cdl;

        // Enforce single 'Is_Currently_Displayed__c'
        enforceSingleCurrent(recordId, cv.Id);

        return cv.Id;
    }

    // Utility: mark only this version as current for the record
    private static void enforceSingleCurrent(Id recordId, Id madeCurrentVersionId) {
        // Gather docIds for the record
        Set<Id> docIds = new Set<Id>();
        for (ContentDocumentLink cdl : [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :recordId
        ]) {
            docIds.add(cdl.ContentDocumentId);
        }
        if (docIds.isEmpty()) return;

        List<ContentVersion> toUpdate = new List<ContentVersion>();

        // Clear existing currents
        for (ContentVersion eachCv : [
            SELECT Id, Is_Currently_Displayed__c, Description
            FROM ContentVersion
            WHERE ContentDocumentId IN :docIds
              AND Description = 'record photo'
              AND Is_Currently_Displayed__c = TRUE
        ]) {
            eachCv.Is_Currently_Displayed__c = false;
            toUpdate.add(eachCv);
        }

        // Set the new one true
        ContentVersion newCv = [
            SELECT Id, Is_Currently_Displayed__c, Description
            FROM ContentVersion
            WHERE Id = :madeCurrentVersionId
            LIMIT 1
        ];
        newCv.Is_Currently_Displayed__c = true;
        if (newCv.Description != 'record photo') newCv.Description = 'record photo';
        toUpdate.add(newCv);

        update toUpdate;
    }
}