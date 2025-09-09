public with sharing class FileUploaderController {

    @AuraEnabled(cacheable=true)
    public static ContentVersion getCurrentPhoto(Id recordId) {
        if (recordId == null) return null;

        Set<Id> docIds = new Set<Id>();
        for (ContentDocumentLink cdl : [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :recordId
        ]) docIds.add(cdl.ContentDocumentId);

        if (docIds.isEmpty()) return null;

        List<ContentVersion> flagged = [
            SELECT Id, ContentDocumentId
            FROM ContentVersion
            WHERE ContentDocumentId IN :docIds
              AND Description = 'record photo'
              AND Is_Currently_Displayed__c = TRUE
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ];
        if (!flagged.isEmpty()) return flagged[0];

        List<ContentVersion> fallback = [
            SELECT Id, ContentDocumentId
            FROM ContentVersion
            WHERE ContentDocumentId IN :docIds
              AND Description = 'record photo'
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ];
        return fallback.isEmpty() ? null : fallback[0];
    }

    @AuraEnabled
    public static Integer getMaxLimitBytes() {
        PhotoUploaderConfig__mdt cfg = [
            SELECT Max_File_Size_MB__c
            FROM PhotoUploaderConfig__mdt
            WHERE DeveloperName = 'DefaultConfig'
            LIMIT 1
        ];
        Integer mb = (cfg == null || cfg.Max_File_Size_MB__c == null) ? 12 : Integer.valueOf(cfg.Max_File_Size_MB__c);
        return mb * 1024 * 1024;
    }

    @AuraEnabled
    public static void uploadPhotoFromLwc(Id recordId, String fileName, String base64Body, String contentType, Integer fileSizeBytes) {
        if (recordId == null || String.isBlank(fileName) || String.isBlank(base64Body)) {
            throw new AuraHandledException('Missing required parameters.');
        }

        Integer maxBytes = getMaxLimitBytes();
        if (fileSizeBytes != null && fileSizeBytes > maxBytes) {
            Decimal limitMb = Decimal.valueOf(maxBytes) / (1024*1024);
            Decimal actualMb = Decimal.valueOf(fileSizeBytes) / (1024*1024);
            throw new AuraHandledException('File is ' + actualMb.setScale(1) + ' MB. Limit is ' + limitMb.setScale(1) + ' MB.');
        }

        // clear previous "current" flags on this record's "record photo" versions
        Set<Id> docIds = new Set<Id>();
        for (ContentDocumentLink cdl : [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :recordId
        ]) docIds.add(cdl.ContentDocumentId);

        if (!docIds.isEmpty()) {
            List<ContentVersion> toUnset = [
                SELECT Id, Is_Currently_Displayed__c
                FROM ContentVersion
                WHERE ContentDocumentId IN :docIds
                  AND Description = 'record photo'
                  AND Is_Currently_Displayed__c = TRUE
            ];
            for (ContentVersion cv : toUnset) cv.Is_Currently_Displayed__c = false;
            if (!toUnset.isEmpty()) update toUnset;
        }

        // create new ContentVersion, mark as current
        ContentVersion cv = new ContentVersion();
        cv.Title            = fileName;
        cv.PathOnClient     = fileName;
        cv.VersionData      = EncodingUtil.base64Decode(base64Body);
        cv.IsMajorVersion   = true;
        cv.Description      = 'record photo';
        cv.Is_Currently_Displayed__c = true;
        insert cv;

        // link to the record
        Id docId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
        ContentDocumentLink link = new ContentDocumentLink(
            ContentDocumentId = docId,
            LinkedEntityId    = recordId,
            ShareType         = 'V'
        );
        insert link;
    }
}