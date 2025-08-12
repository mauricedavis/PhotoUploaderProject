public with sharing class FileUploaderController {
    @AuraEnabled
    public static void deleteContentDocument(String documentId) {
        List<ContentDocumentLink> links = [SELECT Id FROM ContentDocumentLink WHERE ContentDocumentId = :documentId];
        delete links;
    }
}
