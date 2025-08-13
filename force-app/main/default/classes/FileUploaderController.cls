public with sharing class FileUploaderController {
    @AuraEnabled(cacheable=true)
    public static String getImageUrl(Id recordId) {
        ContentDocumentLink link = [
            SELECT ContentDocument.LatestPublishedVersionId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :recordId
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        if (link != null) {
            String versionId = link.ContentDocument.LatestPublishedVersionId;
            return '/sfc/servlet.shepherd/version/renditionDownload?rendition=ORIGINAL_JPG&versionId=' + versionId;
        }

        return null;
    }
}
