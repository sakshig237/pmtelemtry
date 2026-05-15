import { LightningElement, api, wire } from 'lwc';
import getAssetHealth from '@salesforce/apex/AssetHealthController.getAssetHealth';
import { refreshApex } from '@salesforce/apex';

export default class AssetHealthDashboard extends LightningElement {

    @api recordId;
    healthData;
    wiredResult;

    @wire(getAssetHealth, { assetId: '$recordId' })
    wiredHealth(result) {
        this.wiredResult = result;
        if (result.data) {
            this.healthData = result.data;
        }
    }

    connectedCallback() {
        setTimeout(() => {
            refreshApex(this.wiredResult);
        }, 1000);
    }

   get riskClass() {
        if (!this.healthData) return '';

        if (this.healthData.riskLevel === 'Critical') {
            return 'slds-text-color_error';
        } else if (this.healthData.riskLevel === 'High') {
            return 'slds-text-color_error';
        } else if (this.healthData.riskLevel === 'Medium') {
            return 'slds-text-color_warning';
        }
        return 'slds-text-color_success';
    }
}
