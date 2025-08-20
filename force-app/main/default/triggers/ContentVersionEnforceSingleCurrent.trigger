trigger ContentVersionEnforceSingleCurrent on ContentVersion (after insert, after update) {
    // Collect versions that have just been set to current with the proper description
    Set<Id> turnedOn = new Set<Id>();
    for (ContentVersion cv : Trigger.new) {
        Boolean becameTrue = cv.Is_Currently_Displayed__c == true &&
            (Trigger.isInsert || (Trigger.oldMap.get(cv.Id)?.Is_Currently_Displayed__c != true));
        if (becameTrue && cv.Description == 'record photo') {
            turnedOn.add(cv.Id);
        }
    }
    if (turnedOn.isEmpty()) return;

    // Map version -> its linked record(s)
    Map<Id, Set<Id>> versionToEntities = new Map<Id, Set<Id>>();
    for (ContentDocumentLink link : [
        SELECT ContentDocumentId, LinkedEntityId
        FROM ContentDocumentLink
        WHERE ContentDocumentId IN (
            SELECT ContentDocumentId FROM ContentVersion WHERE Id IN :turnedOn
        )
    ]) {
        if (!versionToEntities.containsKey(link.ContentDocumentId)) {
            versionToEntities.put(link.ContentDocumentId, new Set<Id>());
        }
        versionToEntities.get(link.ContentDocumentId).add(link.LinkedEntityId);
    }

    // All entity IDs receiving a "turn on"
    Set<Id> allEntities = new Set<Id>();
    for (Set<Id> s : versionToEntities.values()) allEntities.addAll(s);
    if (allEntities.isEmpty()) return;

    // All docIds linked to those entities
    Set<Id> allDocIds = new Set<Id>();
    for (ContentDocumentLink l2 : [
        SELECT ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId IN :allEntities
    ]) {
        allDocIds.add(l2.ContentDocumentId);
    }
    if (allDocIds.isEmpty()) return;

    // Flip off other "current" versions on those entities
    List<ContentVersion> toUpdate = [
        SELECT Id, Is_Currently_Displayed__c
        FROM ContentVersion
        WHERE ContentDocumentId IN :allDocIds
          AND Description = 'record photo'
          AND Is_Currently_Displayed__c = TRUE
          AND Id NOT IN :turnedOn
    ];
    for (ContentVersion cvu : toUpdate) cvu.Is_Currently_Displayed__c = false;
    if (!toUpdate.isEmpty()) update toUpdate;
}