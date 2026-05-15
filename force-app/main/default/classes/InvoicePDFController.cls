public with sharing class InvoicePDFController {

    @AuraEnabled(cacheable=true)
public static String getInvoiceFileUrl(Id workOrderId){

    // 1. Get ContentDocumentLinks
    List<ContentDocumentLink> links = [
        SELECT ContentDocumentId
        FROM ContentDocumentLink
        WHERE LinkedEntityId = :workOrderId
    ];

    if(links.isEmpty()) return null;

    Set<Id> docIds = new Set<Id>();
    for(ContentDocumentLink link : links){
        docIds.add(link.ContentDocumentId);
    }

    // 2. Get latest PDF
    List<ContentVersion> versions = [
        SELECT Id, ContentDocumentId, Title
        FROM ContentVersion
        WHERE ContentDocumentId IN :docIds
        AND FileType = 'PDF'
        ORDER BY CreatedDate DESC
        LIMIT 1
    ];

    if(versions.isEmpty()) return null;

    // 3. Return URL
    return '/sfc/servlet.shepherd/document/download/' + versions[0].ContentDocumentId;
}


    @AuraEnabled(cacheable=true)
    public static InvoiceWrapper getInvoiceData(Id workOrderId){

        Invoice__c inv = [
            SELECT Id, Name, Account__r.Name
            FROM Invoice__c
            WHERE Work_Order__c = :workOrderId
            LIMIT 1
        ];

        List<Invoice_Line__c> lines = [
            SELECT Id, Quantity__c, Unit_Price__c, Product__r.Name
            FROM Invoice_Line__c
            WHERE CInvoice__c = :inv.Id
        ];

        return new InvoiceWrapper(inv, lines);
    }

    public class InvoiceWrapper {
        @AuraEnabled public Invoice__c invoice;
        @AuraEnabled public List<Invoice_Line__c> lines;

        public InvoiceWrapper(Invoice__c inv, List<Invoice_Line__c> l){
            this.invoice = inv;
            this.lines = l;
        }
    }
}
