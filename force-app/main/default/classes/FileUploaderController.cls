public with sharing class FileUploaderController {

    public class PhotoInfo {
        @AuraEnabled public Id   Id;
        @AuraEnabled public Id   ContentDocumentId;
        @AuraEnabled public String FileType;
    }

    // Returns the single currently-displayed "record photo" if any
    @AuraEnabled(cacheable=true)
    public static ContentVersion getCurrentPhoto(Id recordId) {
        if (recordId == null) return null;

        // Find all docs linked to record
        Set<Id> docIds = new Set<Id>();
        for (ContentDocumentLink cdl : [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :recordId
        ]) {
            docIds.add(cdl.ContentDocumentId);
        }
        if (docIds.isEmpty()) return null;

        // Prefer the flagged current
        List<ContentVersion> flagged = [
            SELECT Id, ContentDocumentId, FileType
            FROM ContentVersion
            WHERE ContentDocumentId IN :docIds
              AND Description = 'record photo'
              AND Is_Currently_Displayed__c = TRUE
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ];
        if (!flagged.isEmpty()) return flagged[0];

        // Fallback to latest "record photo"
        List<ContentVersion> fallback = [
            SELECT Id, ContentDocumentId, FileType
            FROM ContentVersion
            WHERE ContentDocumentId IN :docIds
              AND Description = 'record photo'
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ];
        return fallback.isEmpty() ? null : fallback[0];
    }

    // Uploads content bytes and strictly enforces "only one current" per record
    @AuraEnabled
    public static PhotoInfo uploadPhotoFromLwc(
        Id recordId,
        String fileName,
        String base64Data,
        String contentType
    ) {
        if (recordId == null || String.isBlank(base64Data)) {
            throw new AuraHandledException('Missing recordId or data');
        }

        // Create new ContentVersion (auto-creates ContentDocument)
        Blob body = EncodingUtil.base64Decode(base64Data);
        ContentVersion cv = new ContentVersion();
        cv.Title          = (String.isBlank(fileName) ? 'photo' : fileName);
        cv.PathOnClient   = (String.isBlank(fileName) ? 'photo' : fileName);
        cv.VersionData    = body;
        cv.Description    = 'record photo';
        if (!String.isBlank(contentType)) cv.FileType = fileTypeFromMime(contentType);
        insert cv;

        // Link to the record
        Id docId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
        upsert new ContentDocumentLink(
            LinkedEntityId = recordId,
            ContentDocumentId = docId,
            ShareType = 'V'
        );

        // Enforce single-current: clear all true flags then set this one true
        enforceSingleCurrent(recordId, cv.Id);

        // Return info used by the LWC to decide <img> vs <iframe>
        ContentVersion cv2 = [SELECT Id, FileType FROM ContentVersion WHERE Id = :cv.Id];
        PhotoInfo info = new PhotoInfo();
        info.Id = cv2.Id;
        info.ContentDocumentId = docId;
        info.FileType = cv2.FileType;
        return info;
    }

    private static void enforceSingleCurrent(Id recordId, Id newVersionId) {
        Set<Id> docIds = new Set<Id>();
        for (ContentDocumentLink cdl : [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :recordId
        ]) {
            docIds.add(cdl.ContentDocumentId);
        }
        if (docIds.isEmpty()) return;

        List<ContentVersion> toUpdate = new List<ContentVersion>();
        for (ContentVersion other : [
            SELECT Id, Is_Currently_Displayed__c
            FROM ContentVersion
            WHERE ContentDocumentId IN :docIds
              AND Description = 'record photo'
              AND Is_Currently_Displayed__c = TRUE
              AND Id != :newVersionId
        ]) {
            other.Is_Currently_Displayed__c = false;
            toUpdate.add(other);
        }
        if (!toUpdate.isEmpty()) update toUpdate;

        ContentVersion makeCurrent = [SELECT Id, Is_Currently_Displayed__c FROM ContentVersion WHERE Id = :newVersionId LIMIT 1];
        makeCurrent.Is_Currently_Displayed__c = true;
        update makeCurrent;
    }

    // Map MIME -> FileType field (optional; keeps FileType tidy)
    private static String fileTypeFromMime(String mime) {
        String m = mime == null ? '' : mime.toLowerCase();
        if (m.contains('png'))  return 'PNG';
        if (m.contains('jpeg') || m.contains('jpg')) return 'JPG';
        if (m.contains('pdf'))  return 'PDF';
        return null;
    }
}