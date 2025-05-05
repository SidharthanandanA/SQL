/*ClaimsReportdashboard_v2*/
WITH DeliveryQualitiesCTE AS (
    SELECT 
    aid.code AS 'JobID',
	av.Name AS 'Vessel',
	acg.Name AS 'Pool/Customer Group',
	ase.Name AS 'Seller',
	asup.Name AS 'Physical Supplier',
	ap.Name AS 'Port',
	CONVERT(DATE, ad.DeliveryDate) AS 'BDN Delivery Date',
	'Quality' AS 'Claim Type',
	'Quality' AS 'Claim Subtype',
	CASE 
		WHEN ad.DeliveryPointType = 0 THEN 'Barge'
		WHEN ad.DeliveryPointType = 1 THEN 'Terminal'
		END AS 'Delivery Method',
	abr.Name AS 'Barge/Truck Name',
	af.Name AS 'Grade',
	ad.BdnQty AS 'BDN Quantity Lifted',
	CASE 
	WHEN adq.SellerSettlementStatus = 0 THEN 'Consumed With Difficulty'
	WHEN adq.SellerSettlementStatus = 1 THEN 'Consumed Without Difficulty'
	WHEN adq.SellerSettlementStatus = 2 THEN 'Re-tested To Be On-Spec'
	WHEN adq.SellerSettlementStatus = 3 THEN 'De-Bunkered'
	END  AS 'Claim Status',
	NULL AS 'Claim Amount Raised (USD)',
	ROUND(adq.BuyerSettlementAmount,4) AS 'Claim Amount Recovered (USD)',
	NULL AS 'Claim Qty Raised (MT)',
	NULL AS 'Claim Qty Recovered (MT)',
	aid.OperationalNotesClaims AS 'Remarks',
	aup.Name AS 'Trader'
    FROM AppDeliveryQualities adq
    JOIN AppInquiryFuelDetails aifd ON adq.InquiryFuelDetailId = aifd.Id AND aifd.IsDeleted=0
	LEFT JOIN AppInquiryDetails aid ON aid.id = adq.InquiryDetailId AND aid.IsDeleted =0
	LEFT JOIN AppDeliveries ad ON ad.InquiryFuelDetailId =aifd.Id AND ad.IsDeleted = 0
	LEFT JOIN AppVessel av ON av.id = aid.VesselId AND av.IsDeleted=0
	LEFT JOIN AppCustomers ac ON ac.id = aid.CustomerNominationId AND ac.IsDeleted=0
    LEFT JOIN AppCustomerGroups acg ON acg.id = ac.CustomerGroupId AND ac.IsDeleted=0
	LEFT JOIN AppSellers ase ON ase.id = aifd.SellerId AND ase.IsDeleted=0
	LEFT JOIN AppInquirySellerDetails aisd ON aisd.InquiryFuelDetailId = aifd.Id AND aisd.IsDeleted=0 AND aisd.SellerId = aifd.SellerId
	LEFT JOIN AppSuppliers asup ON asup.id = aisd.SupplierId AND asup.IsDeleted=0
	LEFT JOIN AppPorts ap ON aid.PortNominationId = ap.Id
	LEFT JOIN AppBarges abr ON abr.id = ad.BargeId AND abr.IsDeleted=0
	LEFT JOIN AppFuels af ON af.id = aifd.FuelId
	LEFT JOIN AppUserProfiles aup ON aup.Id = aid.UserProfileId AND aup.IsDeleted=0
),
 DeliveryQuantityShortSuppliesCTE AS (
    SELECT 
    aid.code AS 'JobID',
	av.Name AS 'Vessel',
	acg.Name AS 'Pool/Customer Group',
	ase.Name AS 'Seller',
	asup.Name AS 'Physical Supplier',
	ap.Name AS 'Port',
	CONVERT(DATE, ad.DeliveryDate) AS 'BDN Delivery Date',
	'Quantity' AS 'Claim Type',
	'Short Supply' AS 'Claim Subtype',
	CASE 
		WHEN ad.DeliveryPointType = 0 THEN 'Barge'
		WHEN ad.DeliveryPointType = 1 THEN 'Terminal'
		END AS 'Delivery Method',
	abr.Name AS 'Barge/Truck Name',
	af.Name AS 'Grade',
	ad.BdnQty AS 'BDN Quantity Lifted',
	CASE
	WHEN adqss.ShortSupplyStatus = 0 THEN 'Commercial Settlement'
	WHEN adqss.ShortSupplyStatus = 1 THEN 'No Recovery'
    END AS 'Claim Status',
	NULL AS 'Claim Amount Raised (USD)',
	ROUND(adqss.BuyerSettlementAmount,4) AS 'Claim Amount Recovered (USD)',
	NULL AS 'Claim Qty Raised (MT)',
	NULL AS 'Claim Qty Recovered (MT)',
	aid.OperationalNotesClaims AS 'Remarks',
	aup.Name AS 'Trader'
    FROM AppDeliveryQuantityShortSupplies adqss
    JOIN AppInquiryFuelDetails aifd ON adqss.InquiryFuelDetailId = aifd.Id AND aifd.IsDeleted=0
	LEFT JOIN AppInquiryDetails aid ON aid.id = adqss.InquiryDetailId AND aid.IsDeleted =0
	LEFT JOIN AppDeliveries ad ON ad.InquiryFuelDetailId =aifd.Id AND ad.IsDeleted = 0
	LEFT JOIN AppVessel av ON av.id = aid.VesselId AND av.IsDeleted=0
	LEFT JOIN AppCustomers ac ON ac.id = aid.CustomerNominationId AND ac.IsDeleted=0
    LEFT JOIN AppCustomerGroups acg ON acg.id = ac.CustomerGroupId AND ac.IsDeleted=0
	LEFT JOIN AppSellers ase ON ase.id = aifd.SellerId AND ase.IsDeleted=0
	LEFT JOIN AppInquirySellerDetails aisd ON aisd.InquiryFuelDetailId = aifd.Id AND aisd.IsDeleted=0 AND aisd.SellerId = aifd.SellerId
	LEFT JOIN AppSuppliers asup ON asup.id = aisd.SupplierId AND asup.IsDeleted=0
	LEFT JOIN AppPorts ap ON aid.PortNominationId = ap.Id
	LEFT JOIN AppBarges abr ON abr.id = ad.BargeId AND abr.IsDeleted=0
	LEFT JOIN AppFuels af ON af.id = aifd.FuelId
	LEFT JOIN AppUserProfiles aup ON aup.Id = aid.UserProfileId AND aup.IsDeleted=0
),
DeliveryQuantityDensitiesCTE AS (
    SELECT 
    aid.code AS 'JobID',
	av.Name AS 'Vessel',
	acg.Name AS 'Pool/Customer Group',
	ase.Name AS 'Seller',
	asup.Name AS 'Physical Supplier',
	ap.Name AS 'Port',
	CONVERT(DATE, ad.DeliveryDate) AS 'BDN Delivery Date',
	'Quantity' AS 'Claim Type',
	'Density' AS 'Claim Subtype',
	CASE 
		WHEN ad.DeliveryPointType = 0 THEN 'Barge'
		WHEN ad.DeliveryPointType = 1 THEN 'Terminal'
		END AS 'Delivery Method',
	abr.Name AS 'Barge/Truck Name',
	af.Name AS 'Grade',
	ad.BdnQty AS 'BDN Quantity Lifted',
	CASE
	WHEN adqd.DensitySettlementStatus = 0 THEN 'Commercial Settlement'
	WHEN adqd.DensitySettlementStatus = 1 THEN 'Re-tested'
	WHEN adqd.DensitySettlementStatus = 2 THEN 'No Recovery'
	END AS 'Claim Status',
	ROUND(adqd.ClaimQty *  aisd.BuyPrice,4) AS 'Claim Amount Raised (USD)',
	ROUND(adqd.BuyerSettlementAmount,4) AS 'Claim Amount Recovered (USD)',
	ROUND(adqd.ClaimQty,4) AS 'Claim Qty Raised (MT)',
	ROUND(adqd.ClaimQty,4) AS 'Claim Qty Recovered (MT)',
	aid.OperationalNotesClaims AS 'Remarks',
	aup.Name AS 'Trader'
    FROM AppDeliveryQuantityDensities adqd
    JOIN AppInquiryFuelDetails aifd ON adqd.InquiryFuelDetailId = aifd.Id AND aifd.IsDeleted=0
	LEFT JOIN AppInquiryDetails aid ON aid.id = adqd.InquiryDetailId AND aid.IsDeleted =0
	LEFT JOIN AppDeliveries ad ON ad.InquiryFuelDetailId =aifd.Id AND ad.IsDeleted = 0
	LEFT JOIN AppVessel av ON av.id = aid.VesselId AND av.IsDeleted=0
	LEFT JOIN AppCustomers ac ON ac.id = aid.CustomerNominationId AND ac.IsDeleted=0
    LEFT JOIN AppCustomerGroups acg ON acg.id = ac.CustomerGroupId AND ac.IsDeleted=0
	LEFT JOIN AppSellers ase ON ase.id = aifd.SellerId AND ase.IsDeleted=0
	LEFT JOIN AppInquirySellerDetails aisd ON aisd.InquiryFuelDetailId = aifd.Id AND aisd.IsDeleted=0 AND aisd.SellerId = aifd.SellerId
	LEFT JOIN AppSuppliers asup ON asup.id = aisd.SupplierId AND asup.IsDeleted=0
	LEFT JOIN AppPorts ap ON aid.PortNominationId = ap.Id
	LEFT JOIN AppBarges abr ON abr.id = ad.BargeId AND abr.IsDeleted=0
	LEFT JOIN AppFuels af ON af.id = aifd.FuelId
	LEFT JOIN AppUserProfiles aup ON aup.Id = aid.UserProfileId AND aup.IsDeleted=0
),
DeliveryQualityWatersCTE AS (
    SELECT 
    aid.code AS 'JobID',
	av.Name AS 'Vessel',
	acg.Name AS 'Pool/Customer Group',
	ase.Name AS 'Seller',
	asup.Name AS 'Physical Supplier',
	ap.Name AS 'Port',
	CONVERT(DATE, ad.DeliveryDate) AS 'BDN Delivery Date',
	'Quality' AS 'Claim Type',
	'Water' AS 'Claim Subtype',
	CASE 
		WHEN ad.DeliveryPointType = 0 THEN 'Barge'
		WHEN ad.DeliveryPointType = 1 THEN 'Terminal'
		END AS 'Delivery Method',
	abr.Name AS 'Barge/Truck Name',
	af.Name AS 'Grade',
	ad.BdnQty AS 'BDN Quantity Lifted',
	CASE
	WHEN adqw.WaterSettlementStatus = 0 THEN 'Consumed With Difficulty'
	WHEN adqw.WaterSettlementStatus = 1 THEN 'Consumed Without Difficulty'
	WHEN adqw.WaterSettlementStatus = 2 THEN 'Re-tested To Be On-Spec'
	WHEN adqw.WaterSettlementStatus = 3 THEN 'De-Bunkered'
    END AS 'Claim Status',
	ROUND(adqw.ClaimQty *  aisd.BuyPrice,4) AS 'Claim Amount Raised (USD)',
	ROUND(adqw.BuyerSettlementAmount,4) AS 'Claim Amount Recovered (USD)',
	ROUND(adqw.ClaimQty,4) AS 'Claim Qty Raised (MT)',
	ROUND(adqw.ClaimQty,4) AS 'Claim Qty Recovered (MT)',
	aid.OperationalNotesClaims AS 'Remarks',
	aup.Name AS 'Trader'
    FROM AppDeliveryQualityWaters adqw
    JOIN AppInquiryFuelDetails aifd ON adqw.InquiryFuelDetailId = aifd.Id AND aifd.IsDeleted=0
	LEFT JOIN AppInquiryDetails aid ON aid.id = adqw.InquiryDetailId AND aid.IsDeleted =0
	LEFT JOIN AppDeliveries ad ON ad.InquiryFuelDetailId =aifd.Id AND ad.IsDeleted = 0
	LEFT JOIN AppVessel av ON av.id = aid.VesselId AND av.IsDeleted=0
	LEFT JOIN AppCustomers ac ON ac.id = aid.CustomerNominationId AND ac.IsDeleted=0
    LEFT JOIN AppCustomerGroups acg ON acg.id = ac.CustomerGroupId AND ac.IsDeleted=0
	LEFT JOIN AppSellers ase ON ase.id = aifd.SellerId AND ase.IsDeleted=0
	LEFT JOIN AppInquirySellerDetails aisd ON aisd.InquiryFuelDetailId = aifd.Id AND aisd.IsDeleted=0 AND aisd.SellerId = aifd.SellerId
	LEFT JOIN AppSuppliers asup ON asup.id = aisd.SupplierId AND asup.IsDeleted=0
	LEFT JOIN AppPorts ap ON aid.PortNominationId = ap.Id
	LEFT JOIN AppBarges abr ON abr.id = ad.BargeId AND abr.IsDeleted=0
	LEFT JOIN AppFuels af ON af.id = aifd.FuelId
	LEFT JOIN AppUserProfiles aup ON aup.Id = aid.UserProfileId AND aup.IsDeleted=0
),
DeliveryQualityDelaysCTE AS (
    SELECT 
    aid.code AS 'JobID',
	av.Name AS 'Vessel',
	acg.Name AS 'Pool/Customer Group',
	ase.Name AS 'Seller',
	asup.Name AS 'Physical Supplier',
	ap.Name AS 'Port',
	CONVERT(DATE, ad.DeliveryDate) AS 'BDN Delivery Date',
	'Operational' AS 'Claim Type',
	'Operational' AS 'Claim Subtype',
	CASE 
		WHEN ad.DeliveryPointType = 0 THEN 'Barge'
		WHEN ad.DeliveryPointType = 1 THEN 'Terminal'
		END AS 'Delivery Method',
	abr.Name AS 'Barge/Truck Name',
	af.Name AS 'Grade',
	ad.BdnQty AS 'BDN Quantity Lifted',
	CASE
	WHEN adqt.DelaySettlementStatus = 0 THEN 'Commercial Settlement'
	WHEN adqt.DelaySettlementStatus = 1 THEN 'No Recovery'
	END AS 'Claim Status',
	NULL AS 'Claim Amount Raised (USD)',
	ROUND(adqt.BuyerSettlementAmount,4) AS 'Claim Amount Recovered (USD)',
	NULL AS 'Claim Qty Raised (MT)',
	NULL AS 'Claim Qty Recovered (MT)',
	aid.OperationalNotesClaims AS 'Remarks',
	aup.Name AS 'Trader'
    FROM AppDeliveryDelays adqt
    JOIN AppInquiryFuelDetails aifd ON adqt.InquiryFuelDetailId = aifd.Id AND aifd.IsDeleted=0
	LEFT JOIN AppInquiryDetails aid ON aid.id = adqt.InquiryDetailId AND aid.IsDeleted =0
	LEFT JOIN AppDeliveries ad ON ad.InquiryFuelDetailId =aifd.Id AND ad.IsDeleted = 0
	LEFT JOIN AppVessel av ON av.id = aid.VesselId AND av.IsDeleted=0
	LEFT JOIN AppCustomers ac ON ac.id = aid.CustomerNominationId AND ac.IsDeleted=0
    LEFT JOIN AppCustomerGroups acg ON acg.id = ac.CustomerGroupId AND ac.IsDeleted=0
	LEFT JOIN AppSellers ase ON ase.id = aifd.SellerId AND ase.IsDeleted=0
	LEFT JOIN AppInquirySellerDetails aisd ON aisd.InquiryFuelDetailId = aifd.Id AND aisd.IsDeleted=0 AND aisd.SellerId = aifd.SellerId
	LEFT JOIN AppSuppliers asup ON asup.id = aisd.SupplierId AND asup.IsDeleted=0
	LEFT JOIN AppPorts ap ON aid.PortNominationId = ap.Id
	LEFT JOIN AppBarges abr ON abr.id = ad.BargeId AND abr.IsDeleted=0
	LEFT JOIN AppFuels af ON af.id = aifd.FuelId
	LEFT JOIN AppUserProfiles aup ON aup.Id = aid.UserProfileId AND aup.IsDeleted=0
),UNIONCTE AS (

        SELECT * FROM DeliveryQualitiesCTE
        UNION 
        SELECT * FROM DeliveryQuantityShortSuppliesCTE
        UNION 
        SELECT * FROM DeliveryQuantityDensitiesCTE
        UNION 
        SELECT * FROM DeliveryQualityWatersCTE
        UNION 
        SELECT * FROM DeliveryQualityDelaysCTE
)
SELECT * FROM UNIONCTE

    ORDER BY CAST(SUBSTRING(JobID, 2, LEN(JobID) - 1) AS INT) DESC


