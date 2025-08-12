public with sharing class FileUploaderController {
    @AuraEnabled(cacheable=true)
    public static String getLatestPhoto(Id recordId) {
        List<ContentDocumentLink> links = [
            SELECT ContentDocument.LatestPublishedVersionId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :recordId
            ORDER BY SystemModstamp DESC
            LIMIT 1
        ];
        if (!links.isEmpty()) {
            return links[0].ContentDocument.LatestPublishedVersionId;
        }
        return null;
    }

    @AuraEnabled
    public static void deleteLatestPhoto(Id recordId) {
        List<ContentDocumentLink> links = [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :recordId
            ORDER BY SystemModstamp DESC
            LIMIT 1
        ];
        if (!links.isEmpty()) {
            ContentDocumentLink link = links[0];
            delete link;
        }
    }
}
