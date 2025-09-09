public with sharing class FileUploaderController {

    // Returns configured limit in MB (CMDT DefaultConfig), or 12 if unset.
    @AuraEnabled(cacheable=true)
    public static Integer getMaxUploadMb() {
        Integer fallback = 12;
        try {
            PhotoUploaderConfig__mdt cfg = PhotoUploaderConfig__mdt.getInstance('DefaultConfig');
            if (cfg != null && cfg.MaxFileSizeMB__c != null) return Integer.valueOf(cfg.MaxFileSizeMB__c);
        } catch (Exception e) { /* ignore, use fallback */ }
        return fallback;
    }

    // Minimal uploader entry-point – validate size and create ContentVersion
    @AuraEnabled
    public static Id uploadPhotoFromLwc(Id parentId, String fileName, String base64Data, String contentType) {

        if (parentId == null || String.isBlank(fileName) || String.isBlank(base64Data)) {
            throw new AuraHandledException('Missing parameters.');
        }

        Integer maxMb = getMaxUploadMb();
        Integer maxBytes = maxMb * 1024 * 1024;

        Blob body = EncodingUtil.base64Decode(base64Data);
        Integer actual = body.size();
        if (actual > maxBytes) {
            throw new AuraHandledException('File exceeds maximum allowed size of ' + maxMb + 'MB.');
        }

        ContentVersion cv = new ContentVersion();
        cv.Title = fileName;
        cv.PathOnClient = fileName;
        cv.VersionData = body;
        cv.Origin = 'H';
        insert cv;

        // Link to parent
        ContentDocumentLink cdl = new ContentDocumentLink(
            ContentDocumentId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId,
            LinkedEntityId     = parentId,
            ShareType          = 'V'
        );
        insert cdl;

        return cv.Id;
    }
}