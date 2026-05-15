public with sharing class sparePartsRequestController {

    @AuraEnabled(cacheable=true)
    public static List<Product2> getRecommendedProducts(Id workOrderId) {
        // Fixed: workOrderId is now used to filter products relevant to the Work Order's asset
        List<WorkOrder> woList = [
            SELECT Id, Asset.Product2Id
            FROM WorkOrder
            WHERE Id = :workOrderId
            LIMIT 1
        ];

        if (woList.isEmpty() || woList[0].Asset == null || woList[0].Asset.Product2Id == null) {
            // Fallback: return generic active products if no asset/product link found
            return [
                SELECT Id, Name, IsActive
                FROM Product2
                WHERE IsActive = true
                LIMIT 10
            ];
        }

        // Return products in the same product family as the asset's product
        Id assetProductId = woList[0].Asset.Product2Id;
        List<Product2> assetProduct = [SELECT Id, Family FROM Product2 WHERE Id = :assetProductId LIMIT 1];
        String family = assetProduct.isEmpty() ? null : assetProduct[0].Family;

        if (String.isNotBlank(family)) {
            return [
                SELECT Id, Name, IsActive
                FROM Product2
                WHERE IsActive = true AND Family = :family
                LIMIT 10
            ];
        }

        return [
            SELECT Id, Name, IsActive
            FROM Product2
            WHERE IsActive = true
            LIMIT 10
        ];
    }

    @AuraEnabled
    public static Id requestSparePart(Id workOrderId, Id productId, Integer quantity) {

        // 1. Get Work Order 
        List<WorkOrder> woList = [
            SELECT Id, AssetId
            FROM WorkOrder
            WHERE Id = :workOrderId
            LIMIT 1
        ];

        if (woList.isEmpty()) {
            throw new AuraHandledException('Work Order not found.');
        }

        WorkOrder wo = woList[0];

        if (wo.AssetId == null) {
            throw new AuraHandledException('Work Order has no linked Asset.');
        }

        // 2. Get Asset + Territory 
        List<Asset> assetList = [
            SELECT Id, Service_Territory__r.Name
            FROM Asset
            WHERE Id = :wo.AssetId
            LIMIT 1
        ];

        if (assetList.isEmpty()) {
            throw new AuraHandledException('Asset not found.');
        }

        Asset assetRec = assetList[0];

        // Fixed: null check happens BEFORE accessing .Name (was reversed before)
        if (assetRec.Service_Territory__r == null) {
            throw new AuraHandledException('No Service Territory found on Asset.');
        }

        String territoryName = assetRec.Service_Territory__r.Name;

        // 3. Get Location from Custom Metadata — guard against missing mapping
        List<Territory_Location_Map__mdt> mappings = [
            SELECT Location__c
            FROM Territory_Location_Map__mdt
            WHERE Service_Territory__c = :territoryName
            LIMIT 1
        ];

        if (mappings.isEmpty()) {
            throw new AuraHandledException('No territory-to-location mapping found for: ' + territoryName);
        }

        String locationName = mappings[0].Location__c;

        // 4. Get Location Record — guard against missing location
        List<Schema.Location> locList = [
            SELECT Id
            FROM Location
            WHERE Name = :locationName
            LIMIT 1
        ];

        if (locList.isEmpty()) {
            throw new AuraHandledException('Location not found: ' + locationName);
        }

        Schema.Location loc = locList[0];

        // 5. Check Inventory at Primary Location
        ProductItem item;

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
            // 6. Fallback to Central Warehouse — guard against missing warehouse
            List<Schema.Location> warehouseList = [
                SELECT Id
                FROM Location
                WHERE Name = 'Central Warehouse'
                LIMIT 1
            ];

            if (warehouseList.isEmpty()) {
                throw new AuraHandledException('Central Warehouse location not found.');
            }

            List<ProductItem> fallbackItems = [
                SELECT Id, QuantityOnHand, LocationId
                FROM ProductItem
                WHERE Product2Id = :productId
                AND LocationId = :warehouseList[0].Id
                AND QuantityOnHand > 0
                LIMIT 1
            ];

            if (fallbackItems.isEmpty()) {
                throw new AuraHandledException('No stock available in any location.');
            }

            item = fallbackItems[0];
        }

        // 7 & 8. Create Product Request and Line Item in a single try/catch
        // Fixed: both DML operations wrapped together so a failure rolls back cleanly
        ProductRequest pr = new ProductRequest(
            WorkOrderId = workOrderId,
            Status = 'Submitted',
            NeedByDate = Date.today()
        );

        ProductRequestLineItem prli;

        try {
            insert pr;

            // Fixed: SourceLocationId is now set from the resolved inventory item
            prli = new ProductRequestLineItem(
                ParentId = pr.Id,
                Product2Id = productId,
                QuantityRequested = quantity,
                NeedByDate = Date.today(),
                WorkOrderId = workOrderId,
                SourceLocationId = item.LocationId
            );

            insert prli;

        } catch (DmlException e) {
            throw new AuraHandledException('Failed to create Product Request: ' + e.getMessage());
        }

        return pr.Id;
    }
}
``