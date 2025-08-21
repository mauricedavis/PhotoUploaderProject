trigger ContentVersionEnforceSingleCurrent on ContentVersion (after insert, after update) {
    // Identify versions just set to current and tagged as "record photo"
    Set<Id> turnedOn = new Set<Id>();
    for (ContentVersion cv : Trigger.new) {
        Boolean becameTrue = cv.Is_Currently_Displayed__c == true &&
            (Trigger.isInsert || (Trigger.oldMap.get(cv.Id)?.Is_Currently_Displayed__c != true));
        if (becameTrue && cv.Description == 'record photo') {
            turnedOn.add(cv.Id);
        }
    }
    if (turnedOn.isEmpty()) return;

    // Find entities those docs are linked to
    Set<Id> docIdsTurnedOn = new Set<Id>();
    for (ContentVersion cv2 : [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id IN :turnedOn]) {
        docIdsTurnedOn.add(cv2.ContentDocumentId);
    }
    if (docIdsTurnedOn.isEmpty()) return;

    Set<Id> entityIds = new Set<Id>();
    for (ContentDocumentLink l1 : [
        SELECT ContentDocumentId, LinkedEntityId
        FROM ContentDocumentLink
        WHERE ContentDocumentId IN :docIdsTurnedOn
    ]) entityIds.add(l1.LinkedEntityId);
    if (entityIds.isEmpty()) return;

    // All docs linked to those entities
    Set<Id> allDocIds = new Set<Id>();
    for (ContentDocumentLink l2 : [
        SELECT ContentDocumentId
        FROM ContentDocumentLink
        WHERE LinkedEntityId IN :entityIds
    ]) allDocIds.add(l2.ContentDocumentId);
    if (allDocIds.isEmpty()) return;

    // Flip others OFF
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