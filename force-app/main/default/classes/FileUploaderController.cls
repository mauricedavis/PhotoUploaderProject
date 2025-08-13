public with sharing class FileUploaderController {
  @AuraEnabled(cacheable=true)
  public static String fetchImageUrl(Id recordId) {
    List<ContentDocumentLink> links = [SELECT ContentDocument.LatestPublishedVersionId
      FROM ContentDocumentLink
      WHERE LinkedEntityId = :recordId
      ORDER BY ContentDocument.CreatedDate DESC LIMIT 1];
    if (!links.isEmpty()) {
      return '/sfc/servlet.shepherd/version/renditionDownload?rendition=ORIGINAL_JPG&versionId='
             + links[0].ContentDocument.LatestPublishedVersionId;
    }
    return null;
  }
}
