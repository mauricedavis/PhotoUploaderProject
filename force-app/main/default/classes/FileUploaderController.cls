public with sharing class FileUploaderController {
    @AuraEnabled(cacheable=true)
    public static String getLatestImageVersionId(String recordId) {
        ContentDocumentLink link = [
            SELECT ContentDocument.LatestPublishedVersionId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :recordId
            ORDER BY ContentDocument.CreatedDate DESC
            LIMIT 1
        ];
        return link.ContentDocument.LatestPublishedVersionId;
    }
}
