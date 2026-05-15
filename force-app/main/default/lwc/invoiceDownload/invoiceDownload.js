import { LightningElement, api } from 'lwc';
import getInvoiceData from '@salesforce/apex/InvoicePDFController.getInvoiceData';
import getInvoiceFileUrl from '@salesforce/apex/InvoicePDFController.getInvoiceFileUrl';


export default class invoiceDownload extends LightningElement {

    @api recordId;

    invoice;
    lines = [];
    grandTotal = 0;

    connectedCallback() {
        this.loadInvoice();
        this.loadFile();
    }

    loadInvoice() {
        getInvoiceData({ workOrderId: this.recordId })
            .then(data => {

                this.invoice = data.invoice;

                let total = 0;

                this.lines = data.lines.map(line => {

                    let base = line.Quantity__c * line.Unit_Price__c;
                    let tax = base * 0.18;
                    let lineTotal = base + tax;

                    total += lineTotal;

                    return {
                        ...line,
                        tax: tax.toFixed(2),
                        total: lineTotal.toFixed(2)
                    };
                });

                this.grandTotal = total.toFixed(2);

            })
            .catch(error => {
                console.error(error);
            });
    }

    loadFile(){
        getInvoiceFileUrl({ workOrderId: this.recordId })
            .then(result => {
                this.fileUrl = result;
            })
            .catch(error => {
                console.error(error);
            });
    }

    handleDownload(){
    window.open(this.fileUrl, '_blank');
}

}
