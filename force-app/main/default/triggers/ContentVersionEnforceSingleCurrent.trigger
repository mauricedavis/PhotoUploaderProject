trigger ContentVersionEnforceSingleCurrent on ContentVersion (after insert, after update) {
    // If a "record photo" is flagged current, ensure siblings are unflagged
    Set<Id> docIds = new Set<Id>();
    for (ContentVersion cv : Trigger.new) {
        if (cv.Description == 'record photo' && cv.Is_Currently_Displayed__c == true) {
            docIds.add(cv.ContentDocumentId);
        }
    }
    if (docIds.isEmpty()) return;

    // Find records linked to these ContentDocuments
    Set<Id> linked = new Set<Id>();
    for (ContentDocumentLink l : [
        SELECT ContentDocumentId, LinkedEntityId
        FROM ContentDocumentLink
        WHERE ContentDocumentId IN :docIds
    ]) {
        linked.add(l.LinkedEntityId);
    }
    if (linked.isEmpty()) return;

    // Unflag other versions for the same linked records
    List<ContentVersion> toUpdate = new List<ContentVersion>();
    for (ContentVersion other : [
        SELECT Id, ContentDocumentId, Is_Currently_Displayed__c
        FROM ContentVersion
        WHERE Description = 'record photo'
          AND Is_Currently_Displayed__c = TRUE
          AND Id NOT IN :Trigger.newMap.keySet()
    ]) {
        toUpdate.add(new ContentVersion(Id = other.Id, Is_Currently_Displayed__c = false));
    }
    if (!toUpdate.isEmpty()) update toUpdate;
}