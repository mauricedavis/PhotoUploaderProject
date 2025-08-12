public with sharing class FileUploaderController {
    @AuraEnabled(cacheable=true)
    public static String getLatestPhoto(Id recordId) {
        ContentDocumentLink cdl = [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :recordId
            ORDER BY SystemModstamp DESC
            LIMIT 1
        ];
        ContentVersion cv = [
            SELECT Id, VersionData, ContentDocumentId
            FROM ContentVersion
            WHERE ContentDocumentId = :cdl.ContentDocumentId
            ORDER BY VersionNumber DESC
            LIMIT 1
        ];
        return cv.Id;
    }

    @AuraEnabled
    public static void deleteLatestPhoto(Id recordId) {
        List<ContentDocumentLink> links = [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :recordId
        ];
        if (!links.isEmpty()) {
            delete [SELECT Id FROM ContentVersion WHERE ContentDocumentId = :links[0].ContentDocumentId];
        }
    }
}
