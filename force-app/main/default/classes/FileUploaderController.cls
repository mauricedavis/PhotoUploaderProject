public with sharing class FileUploaderController {
    @AuraEnabled(cacheable=true)
    public static String fetchLatestImage(Id recordId) {
        ContentDocumentLink cdl = [
            SELECT ContentDocumentId, ContentDocument.LatestPublishedVersionId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :recordId
            ORDER BY ContentDocument.CreatedDate DESC
            LIMIT 1
        ];
        return cdl.ContentDocument.LatestPublishedVersionId;
    }
}
