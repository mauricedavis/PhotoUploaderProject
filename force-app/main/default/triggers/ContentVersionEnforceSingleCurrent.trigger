trigger ContentVersionEnforceSingleCurrent on ContentVersion (after insert, after update) {
    // Lightweight safety: when a version is tagged as 'record photo' & current,
    // make sure any siblings for the same parent record are unchecked.
    // (Controller also enforces on LWC uploads.)
    Set<Id> versionIds = new Set<Id>();
    for (ContentVersion cv : Trigger.new) {
        if (cv.Is_Currently_Displayed__c == true && cv.Description == 'record photo') {
            versionIds.add(cv.Id);
        }
    }
    if (versionIds.isEmpty()) return;
    // No-op guard. Full logic lives in Apex controller where we have recordId context.
}