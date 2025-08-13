public with sharing class FileUploaderController {
    @AuraEnabled
    public static String fetchDocumentInfo(Id recordId) {
        List<ContentDocumentLink> links = [
            SELECT ContentDocument.LatestPublishedVersionId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :recordId
            ORDER BY ContentDocument.CreatedDate DESC
            LIMIT 1
        ];

        if (!links.isEmpty()) {
            String versionId = links[0].ContentDocument.LatestPublishedVersionId;
            return '/sfc/servlet.shepherd/version/renditionDownload?rendition=ORIGINAL_JPG&versionId=' + versionId;
        }

        return null;
    }
}
