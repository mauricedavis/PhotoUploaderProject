public with sharing class FileUploaderController {
    @AuraEnabled(cacheable=true)
    public static Map<String, String> getLatestContentDocument(Id recordId) {
        List<ContentDocumentLink> links = [
            SELECT ContentDocumentId, ContentDocument.LatestPublishedVersionId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :recordId
            ORDER BY ContentDocument.CreatedDate DESC
            LIMIT 1
        ];

        if (!links.isEmpty()) {
            return new Map<String, String>{
                'documentId' => links[0].ContentDocumentId,
                'versionId' => links[0].ContentDocument.LatestPublishedVersionId
            };
        }
        return null;
    }
}
