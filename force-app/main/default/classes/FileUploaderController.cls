public with sharing class FileUploaderController {

    private static Integer defaultMb = 12;

    private static Integer maxMb() {
        try {
            PhotoUploaderConfig__mdt cfg = [
                SELECT Max_Size_MB__c
                FROM PhotoUploaderConfig__mdt
                WHERE DeveloperName = 'DefaultConfig'
                LIMIT 1
            ];
            Integer n = (cfg.Max_Size_MB__c == null) ? defaultMb : Integer.valueOf(cfg.Max_Size_MB__c);
            return (n > 0) ? n : defaultMb;
        } catch (Exception e) {
            return defaultMb;
        }
    }
    private static Long maxBytes() {
        return (Long)maxMb() * 1024L * 1024L;
    }

    @AuraEnabled(cacheable=true)
    public static Integer getMaxUploadSizeMb() {
        return maxMb();
    }

    /**
     * Validate the uploaded version and, if OK, set it as the single "current".
     * If oversize: immediately delete the uploaded doc + versions and return ok=false.
     */
    @AuraEnabled
    public static Map<String,Object> validateAndApply(Id recordId, Id versionId) {
        Map<String,Object> res = new Map<String,Object>();
        if (recordId == null || versionId == null) {
            res.put('ok', false);
            res.put('msg', 'Missing record or file.');
            return res;
        }

        ContentVersion cv = [
            SELECT Id, ContentDocumentId, ContentSize, FileType, Description, Is_Currently_Displayed__c
            FROM ContentVersion
            WHERE Id = :versionId
            LIMIT 1
        ];

        if (cv.ContentSize > maxBytes()) {
            // Remove links and the uploaded doc entirely
            List<ContentDocumentLink> links = [
                SELECT Id FROM ContentDocumentLink
                WHERE ContentDocumentId = :cv.ContentDocumentId
            ];
            if (!links.isEmpty()) delete links;
            // Delete all versions then document
            List<ContentVersion> vers = [
                SELECT Id FROM ContentVersion
                WHERE ContentDocumentId = :cv.ContentDocumentId
            ];
            if (!vers.isEmpty()) delete vers;
            delete new ContentDocument(Id=cv.ContentDocumentId);

            res.put('ok', false);
            res.put('msg', 'File exceeds the configured limit of ' + maxMb() + ' MB. Upload discarded.');
            return res;
        }

        // Ensure a link to the target record exists
        List<ContentDocumentLink> existing = [
            SELECT Id FROM ContentDocumentLink
            WHERE ContentDocumentId = :cv.ContentDocumentId AND LinkedEntityId = :recordId
            LIMIT 1
        ];
        if (existing.isEmpty()) {
            insert new ContentDocumentLink(
                ContentDocumentId = cv.ContentDocumentId,
                LinkedEntityId    = recordId,
                ShareType         = 'V',
                Visibility        = 'AllUsers',
                LinkType          = 'V'
            );
        }

        // Turn off any other "current" flags for photos on this record
        Set<Id> docIds = new Set<Id>();
        for (ContentDocumentLink cdl : [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :recordId
        ]) docIds.add(cdl.ContentDocumentId);
        if (!docIds.contains(cv.ContentDocumentId)) docIds.add(cv.ContentDocumentId);

        List<ContentVersion> toUpd = new List<ContentVersion>();
        for (ContentVersion other : [
            SELECT Id, Is_Currently_Displayed__c
            FROM ContentVersion
            WHERE ContentDocumentId IN :docIds
            AND   Description = 'record photo'
            AND   Is_Currently_Displayed__c = true
        ]) {
            other.Is_Currently_Displayed__c = false;
            toUpd.add(other);
        }

        cv.Is_Currently_Displayed__c = true;
        if (cv.Description != 'record photo') cv.Description = 'record photo';
        toUpd.add(cv);
        update toUpd;

        res.put('ok', true);
        res.put('versionId', cv.Id);
        res.put('docId', cv.ContentDocumentId);
        return res;
    }
}