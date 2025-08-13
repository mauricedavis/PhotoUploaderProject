public with sharing class FileUploaderController {

    @AuraEnabled(cacheable=true)
    public static ContentVersion getCurrentPhoto(Id recordId) {
        List<ContentDocumentLink> links = [
            SELECT ContentDocumentId 
            FROM ContentDocumentLink 
            WHERE LinkedEntityId = :recordId
        ];
        if (links.isEmpty()) return null;

        List<ContentVersion> versions = [
            SELECT Id, Title, Description, ContentDocumentId 
            FROM ContentVersion 
            WHERE Is_Currently_Displayed__c = TRUE 
              AND ContentDocumentId = :links[0].ContentDocumentId
            LIMIT 1
        ];

        return versions.isEmpty() ? null : versions[0];
    }

    @AuraEnabled
    public static void updatePhotoStatus(Id recordId, Id contentVersionId, Id documentId) {
        List<ContentVersion> existing = [
            SELECT Id, Is_Currently_Displayed__c 
            FROM ContentVersion 
            WHERE ContentDocumentId IN (
                SELECT ContentDocumentId 
                FROM ContentDocumentLink 
                WHERE LinkedEntityId = :recordId
            )
        ];

        for (ContentVersion cv : existing) {
            cv.Is_Currently_Displayed__c = false;
        }

        ContentVersion target = [SELECT Id, Is_Currently_Displayed__c FROM ContentVersion WHERE Id = :contentVersionId LIMIT 1];
        target.Is_Currently_Displayed__c = true;

        update existing;
        update target;
    }
}
