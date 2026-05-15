public with sharing class sparePartAgentforce {

    // wrapper class 
    public class SparePartRequestInput {

        @InvocableVariable(required=true)
        public Id workOrderId;

        @InvocableVariable(required=true)
        public Id productId;

        @InvocableVariable(required=true)
        public Integer quantity;
    }

    @InvocableMethod(label='Request Spare Part')
    public static List<Id> requestSparePart(List<SparePartRequestInput> inputs) {

        List<Id> requestIds = new List<Id>();

        for (SparePartRequestInput input : inputs) {

            Id workOrderId = input.workOrderId;
            Id productId = input.productId;
            Integer quantity = input.quantity;

            // 1. Get Work Order
            WorkOrder wo = [
                SELECT Id, AssetId
                FROM WorkOrder
                WHERE Id = :workOrderId
                LIMIT 1
            ];

            // 2. Get Asset + Territory
            Asset assetRec = [
                SELECT Id, Service_Territory__r.Name
                FROM Asset
                WHERE Id = :wo.AssetId
                LIMIT 1
            ];

            String territoryName = assetRec.Service_Territory__r.Name;

            // 3. Get Location from Custom Metadata
            Territory_Location_Map__mdt mapping = [
                SELECT Location__c
                FROM Territory_Location_Map__mdt
                WHERE Service_Territory__c = :territoryName
                LIMIT 1
            ];

            String locationName = mapping.Location__c;

            // 4. Get Location Record
             Schema.Location loc = [
                SELECT Id
                FROM Location
                WHERE Name = :locationName
                LIMIT 1
            ];

            ProductItem item;

            // 5. Check Inventory (Primary Location)
            List<ProductItem> items = [
                SELECT Id, QuantityOnHand, LocationId
                FROM ProductItem
                WHERE Product2Id = :productId
                AND LocationId = :loc.Id
                AND QuantityOnHand > 0
                LIMIT 1
            ];

            if (!items.isEmpty()) {
                item = items[0];
            } else {

                // 6. Fallback to Central Warehouse
                 Schema.Location warehouse = [
                    SELECT Id
                    FROM Location
                    WHERE Name = 'Central Warehouse'
                    LIMIT 1
                ];

                List<ProductItem> fallbackItems = [
                    SELECT Id, QuantityOnHand, LocationId
                    FROM ProductItem
                    WHERE Product2Id = :productId
                    AND LocationId = :warehouse.Id
                    AND QuantityOnHand > 0
                    LIMIT 1
                ];

                if (fallbackItems.isEmpty()) {
                    throw new AuraHandledException('No stock available in any location');
                }

                item = fallbackItems[0];
            }

            // 7. Create Product Request
            ProductRequest pr = new ProductRequest(
                WorkOrderId = workOrderId,
                Status = 'Submitted',
                NeedByDate = Date.today()
            );
            insert pr;

            // 8. Create Product Request Line Item
            ProductRequestLineItem prli = new ProductRequestLineItem(
                ParentId = pr.Id,
                Product2Id = productId,
                QuantityRequested = quantity
            );
            insert prli;

            // Add to response list
            requestIds.add(pr.Id);
        }

        return requestIds;
    }
}
