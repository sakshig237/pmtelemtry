import { LightningElement, api, wire } from 'lwc';
import getTelemetry from '@salesforce/apex/TelemetryController.getTelemetry';

export default class TelemetryComponent extends LightningElement {

    @api recordId;
    telemetry;

    @wire(getTelemetry, { serviceAppointmentId: '$recordId' })
    wiredTelemetry({ error, data }) {

        if (data) {

            this.telemetry = data.map(item => {

                let probability = item.Failure_Probability__c;

                let formattedTime = item.Timestamp__c
                    ? new Date(item.Timestamp__c).toLocaleString()
                    : '';

                return {
                    ...item,
                    formattedProbability: probability
                        ? Number(probability).toFixed(2)
                        : '0.00',
                    formattedTimestamp: formattedTime
                };

            });

        } else if (error) {
            console.error(error);
        }
    }
}
