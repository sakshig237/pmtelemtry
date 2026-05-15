public with sharing class TelemetryController {

    @AuraEnabled(cacheable=true)
    public static List<Telemetry__c> getTelemetry(Id serviceAppointmentId){

        ServiceAppointment sa = [
            SELECT ParentRecordId
            FROM ServiceAppointment
            WHERE Id = :serviceAppointmentId
            LIMIT 1
        ];

        if(sa.ParentRecordId == null){
            return new List<Telemetry__c>();
        }

        return [
            SELECT Id,
                   Temperature__c,
                   Vibration__c,
                   Failure_Probability__c,
                   Timestamp__c
            FROM Telemetry__c
            WHERE Work_Order__c = :sa.ParentRecordId
            ORDER BY Timestamp__c DESC
            LIMIT 20
        ];
    }


    @AuraEnabled(cacheable=true)
    public static WorkOrder getWorkOrder(Id serviceAppointmentId){

        ServiceAppointment sa = [
            SELECT ParentRecordId
            FROM ServiceAppointment
            WHERE Id = :serviceAppointmentId
            LIMIT 1
        ];

        if(sa.ParentRecordId == null){
            return null;
        }

        return [
            SELECT Id,
                   Asset.Name,
                   Asset.SerialNumber
            FROM WorkOrder
            WHERE Id = :sa.ParentRecordId
            LIMIT 1
        ];
    }
}
