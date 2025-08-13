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
            SELECT Id, ContentDocumentId 
            FROM ContentVersion 
            WHERE Is_Currently_Displayed__c = TRUE 
              AND ContentDocumentId IN :new Set<Id>(links.stream().map(l -> l.ContentDocumentId).toList())
            LIMIT 1
        ];
        return versions.isEmpty() ? null : versions[0];
    }

    @AuraEnabled
    public static void setCurrentPhoto(Id recordId, Id documentId) {
        List<ContentDocumentLink> links = [
            SELECT ContentDocumentId 
            FROM ContentDocumentLink 
            WHERE LinkedEntityId = :recordId
        ];
        if (links.isEmpty()) return;

        Set<Id> documentIds = new Set<Id>();
        for (ContentDocumentLink link : links) {
            documentIds.add(link.ContentDocumentId);
        }

        List<ContentVersion> toUpdate = [
            SELECT Id, Is_Currently_Displayed__c 
            FROM ContentVersion 
            WHERE ContentDocumentId IN :documentIds
        ];
        for (ContentVersion cv : toUpdate) {
            cv.Is_Currently_Displayed__c = (cv.ContentDocumentId == documentId);
        }
        update toUpdate;
    }
}
