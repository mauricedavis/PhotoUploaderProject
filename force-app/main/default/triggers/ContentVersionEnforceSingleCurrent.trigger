trigger ContentVersionEnforceSingleCurrent on ContentVersion (before insert, before update, after insert, after update) {
    Integer MAX_BYTES = 12 * 1024 * 1024;

    // BEFORE: block oversize "record photo" on any path
    if (Trigger.isBefore) {
        for (ContentVersion cv : Trigger.new) {
            if (cv.Description == 'record photo' && cv.VersionData != null) {
                try {
                    if (cv.VersionData.size() > MAX_BYTES) {
                        cv.addError('File exceeds the 12 MB limit for record photo.');
                    }
                } catch (Exception e) {
                    // If Blob.size() access throws, be conservative
                    cv.addError('Unable to validate file size.');
                }
            }
        }
    }

    // AFTER: when a user manually toggles Is_Currently_Displayed__c via UI,
    // enforce only one per Account/record.
    if (Trigger.isAfter && (Trigger.isInsert || Trigger.isUpdate)) {
        // Which versions were set to "current" in this DML
        Set<Id> newTrueVersionIds = new Set<Id>();
        Set<Id> docIdsNeedingEntity = new Set<Id>();
        for (ContentVersion cv : Trigger.new) {
            ContentVersion oldCv = Trigger.isUpdate ? Trigger.oldMap.get(cv.Id) : null;
            Boolean becameTrue = cv.Is_Currently_Displayed__c == true && (oldCv == null || oldCv.Is_Currently_Displayed__c != true);
            if (becameTrue && cv.Description == 'record photo') {
                newTrueVersionIds.add(cv.Id);
                if (cv.ContentDocumentId != null) docIdsNeedingEntity.add(cv.ContentDocumentId);
            }
        }
        if (newTrueVersionIds.isEmpty()) return;

        // Map doc -> one linked entity (record)
        Map<Id, Id> docToEntity = new Map<Id, Id>();
        for (ContentDocumentLink cdl : [
            SELECT ContentDocumentId, LinkedEntityId
            FROM ContentDocumentLink
            WHERE ContentDocumentId IN :docIdsNeedingEntity
        ]) {
            if (!docToEntity.containsKey(cdl.ContentDocumentId)) {
                docToEntity.put(cdl.ContentDocumentId, cdl.LinkedEntityId);
            }
        }
        if (docToEntity.isEmpty()) return;

        Set<Id> entityIds = new Set<Id>();
        entityIds.addAll(docToEntity.values());

        // Get all docs for those records
        Set<Id> allDocsForEntities = new Set<Id>();
        for (ContentDocumentLink cdl2 : [
            SELECT ContentDocumentId, LinkedEntityId
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :entityIds
        ]) {
            allDocsForEntities.add(cdl2.ContentDocumentId);
        }

        if (allDocsForEntities.isEmpty()) return;

        // Turn off all other "current" photos for those records
        List<ContentVersion> toUpdate = [
            SELECT Id, Is_Currently_Displayed__c
            FROM ContentVersion
            WHERE ContentDocumentId IN :allDocsForEntities
              AND Description = 'record photo'
              AND Is_Currently_Displayed__c = TRUE
              AND Id NOT IN :newTrueVersionIds
        ];
        for (ContentVersion otherCv : toUpdate) {
            otherCv.Is_Currently_Displayed__c = false;
        }
        if (!toUpdate.isEmpty()) {
            update toUpdate;
        }
    }
}