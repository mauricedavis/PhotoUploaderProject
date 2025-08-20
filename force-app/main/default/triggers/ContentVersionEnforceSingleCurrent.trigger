trigger ContentVersionEnforceSingleCurrent on ContentVersion (after insert, after update) {
    Set<Id> turnedOn = new Set<Id>();
    for (ContentVersion cv : Trigger.new) {
        Boolean becameTrue = cv.Is_Currently_Displayed__c == true &&
            (Trigger.isInsert || (Trigger.oldMap.get(cv.Id)?.Is_Currently_Displayed__c != true));
        if (becameTrue && cv.Description == 'record photo') {
            turnedOn.add(cv.Id);
        }
    }
    if (turnedOn.isEmpty()) return;

    // Map turned-on versions to the records they are linked to.
    Map<Id, Set<Id>> docToEntities = new Map<Id, Set<Id>>();
    for (ContentDocumentLink l : [
        SELECT ContentDocumentId, LinkedEntityId
        FROM ContentDocumentLink
        WHERE ContentDocumentId IN (SELECT ContentDocumentId FROM ContentVersion WHERE Id IN :turnedOn)
    ]) {
        if (!docToEntities.containsKey(l.ContentDocumentId)) docToEntities.put(l.ContentDocumentId, new Set<Id>());
        docToEntities.get(l.ContentDocumentId).add(l.LinkedEntityId);
    }
    Set<Id> allEntities = new Set<Id>();
    for (Set<Id> s : docToEntities.values()) allEntities.addAll(s);
    if (allEntities.isEmpty()) return;

    Set<Id> allDocIds = new Set<Id>();
    for (ContentDocumentLink l2 : [
        SELECT ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId IN :allEntities
    ]) allDocIds.add(l2.ContentDocumentId);
    if (allDocIds.isEmpty()) return;

    List<ContentVersion> toFlipOff = [
        SELECT Id, Is_Currently_Displayed__c
        FROM ContentVersion
        WHERE ContentDocumentId IN :allDocIds
          AND Description = 'record photo'
          AND Is_Currently_Displayed__c = TRUE
          AND Id NOT IN :turnedOn
    ];
    for (ContentVersion cvu : toFlipOff) cvu.Is_Currently_Displayed__c = false;
    if (!toFlipOff.isEmpty()) update toFlipOff;
}