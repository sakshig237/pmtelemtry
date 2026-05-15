public with sharing class AssetHealthController {

    @AuraEnabled(cacheable=true)
    public static AssetHealthWrapper getAssetHealth(Id assetId) {

        // Query Asset for Latest Failure Probability
        Asset assetRec = [
            SELECT Latest_Failure_Probability__c
            FROM Asset
            WHERE Id = :assetId
            LIMIT 1
        ];

        // Query Latest Telemetry Record
        Telemetry__c latestTelemetry = [
            SELECT Temperature__c,
                   Vibration__c,
                   Machine_Age_Months__c,
                   Hours_Since_Service__c
            FROM Telemetry__c
            WHERE Asset__c = :assetId
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        Integer machineAgeMonths = 0;
        Integer hoursSinceService = 0;
        Decimal temperature = 0;
        Decimal vibration = 0;

        if(latestTelemetry != null){
            machineAgeMonths = latestTelemetry.Machine_Age_Months__c != null 
                ? latestTelemetry.Machine_Age_Months__c.intValue() : 0;

            hoursSinceService = latestTelemetry.Hours_Since_Service__c != null 
                ? latestTelemetry.Hours_Since_Service__c.intValue() : 0;

            temperature = latestTelemetry.Temperature__c != null 
                ? latestTelemetry.Temperature__c : 0;

            vibration = latestTelemetry.Vibration__c != null 
                ? latestTelemetry.Vibration__c : 0;
        }

        // Health Score Calculation
        Integer healthScore = 100;

        healthScore -= machineAgeMonths;
        healthScore -= hoursSinceService / 50;
        healthScore -= Integer.valueOf(temperature);
        healthScore -= Integer.valueOf(vibration * 2);

        if(healthScore < 0){
            healthScore = 0;
        }

        // Failure Probability from Asset
        Decimal failureProbability = assetRec.Latest_Failure_Probability__c != null
            ? assetRec.Latest_Failure_Probability__c
            : 0;

        // Risk Detection
        String riskLevel;

        if(failureProbability >= 90){
            riskLevel = 'Critical';
        }
        else if(failureProbability >= 70){
            riskLevel = 'High';
        }
        else if(failureProbability >= 40){
            riskLevel = 'Medium';
        }
        else{
            riskLevel = 'Low';
        }

        // Cost Calculation
        Decimal reactiveCost = hoursSinceService * 500;
        Decimal predictiveCost = hoursSinceService * 200;
        Decimal costSavings = reactiveCost - predictiveCost;

        // Return Data to LWC
        return new AssetHealthWrapper(
            healthScore,
            riskLevel,
            machineAgeMonths,
            hoursSinceService,
            reactiveCost,
            predictiveCost,
            costSavings
        );
    }

    // Wrapper Class
    public class AssetHealthWrapper {

        @AuraEnabled public Integer healthScore;
        @AuraEnabled public String riskLevel;
        @AuraEnabled public Integer machineAgeMonths;
        @AuraEnabled public Integer hoursSinceService;
        @AuraEnabled public Decimal reactiveCost;
        @AuraEnabled public Decimal predictiveCost;
        @AuraEnabled public Decimal costSavings;

        public AssetHealthWrapper(
            Integer h,
            String r,
            Integer m,
            Integer hrs,
            Decimal rc,
            Decimal pc,
            Decimal cs
        ){
            this.healthScore = h;
            this.riskLevel = r;
            this.machineAgeMonths = m;
            this.hoursSinceService = hrs;
            this.reactiveCost = rc;
            this.predictiveCost = pc;
            this.costSavings = cs;
        }
    }
}
