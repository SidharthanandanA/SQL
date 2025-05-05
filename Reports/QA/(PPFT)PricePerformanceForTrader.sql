/* PricePerformanceReport.v3 */

WITH FuelCTE AS (
	SELECT DISTINCT
		aid.Id AS 'InquiryDetailId', 
		aifd.Id AS 'InquiryFuelDetailId', 
		aifd.FuelId, 
		aid.PortNominationId AS 'PortId',
		COALESCE(ain.StemDate, ain.BookedOn) AS 'StemDate'
	FROM AppInquiryFuelDetails aifd
	JOIN AppInquiryDetails aid ON aifd.InquiryDetailId = aid.Id
	JOIN AppInquirySellerDetails aisd On aisd.InquiryFuelDetailId = aifd.Id AND aisd.IsDeleted = 0 AND aisd.SellerId = aifd.SellerId
	LEFT JOIN AppFuels af ON aifd.FuelId = af.Id
	LEFT JOIN AppPorts ap ON aid.PortId = ap.Id
	LEFT JOIN AppVessel av ON aid.VesselId = av.Id
	JOIN AppInquiryNominations ain ON ain.InquirySellerDetailId = aisd.Id AND ain.IsDeleted = 0 AND aifd.InquiryDetailId = ain.InquiryDetailId 
    WHERE aifd.IsDeleted = 0 AND aifd.IsLosted = 0
    ),

QtyCTE AS (

	SELECT DISTINCT
	aifd.Id AS InquiryFuelDetailId,
	CASE
		WHEN agg.Name = 'GO'
			THEN
			CASE 
				WHEN ad.BdnQtyUnit = 0 THEN ad.BdnQty	--MT
				WHEN ad.BdnQtyUnit = 1 THEN ROUND(ad.BdnQty * 0.001, 4) --KG
				WHEN ad.BdnQtyUnit = 2 THEN ROUND(ad.BdnQty * 0.00085, 4) --Litres
				WHEN ad.BdnQtyUnit = 3 THEN ROUND(ad.BdnQty * 0.0038641765, 4) --IG
				WHEN ad.BdnQtyUnit = 4 THEN ROUND(ad.BdnQty * 0.85, 4) --CBM
				WHEN ad.BdnQtyUnit = 5 THEN ROUND(ad.BdnQty * 0.0032, 4) --US Gallons
				WHEN ad.BdnQtyUnit = 6 THEN ROUND(ad.BdnQty * 0.134, 4) --Barrels
				WHEN ad.BdnQtyUnit = 7 THEN ROUND(ad.BdnQty * 0.85, 4) --KL
        END
        WHEN agg.Name = 'FO'
            THEN
            CASE
            WHEN ad.BdnQtyUnit = 0 THEN ad.BdnQty	--MT
            WHEN ad.BdnQtyUnit = 1 THEN ROUND(ad.BdnQty * 0.001, 4) --KG
            WHEN ad.BdnQtyUnit = 2 THEN ROUND(ad.BdnQty * 0.00094, 4) --Litres
            WHEN ad.BdnQtyUnit = 3 THEN ROUND(ad.BdnQty * 0.0042733246, 4)--IG
            WHEN ad.BdnQtyUnit = 4 THEN ROUND(ad.BdnQty * 0.94, 4) --CBM
            WHEN ad.BdnQtyUnit = 5 THEN ROUND(ad.BdnQty * 0.0037, 4) --US Gallons
            WHEN ad.BdnQtyUnit = 6 THEN ROUND(ad.BdnQty * 0.157, 4) --Barrels
            WHEN ad.BdnQtyUnit = 7 THEN ROUND(ad.BdnQty * 0.94, 4) --KL
            END
            ELSE ad.BdnQty
            END AS 'Qty'
	FROM AppInquiryFuelDetails as aifd
	JOIN  AppInquiryDetails aid ON aid.Id = aifd.InquiryDetailId
	LEFT JOIN AppFuels af ON af.id = aifd.FuelId AND af.IsDeleted=0
	LEFT JOIN AppGradeGroups agg ON agg.id = af.GradeGroupId AND agg.IsDeleted=0
	LEFT JOIN AppDeliveries ad ON ad.InquiryFuelDetailId = aifd.Id AND ad.IsDeleted=0
	WHERE aifd.IsDeleted = 0 and aifd.IsLosted = 0
),
InquiryFuelCTE AS (
    SELECT DISTINCT
        aid.Code AS 'ID',
        av.Name AS 'Vessel',
        ap.Name AS 'Port',
        aup.Name AS 'Trader',
		CASE
			WHEN api.PortId = aid.PortNominationId and api.FuelId = aifd.FuelId THEN 'Platt'
			WHEN api.SubPortId = aid.PortNominationId and api.FuelId = aifd.FuelId THEN 'Non-Platt'
			ELSE '-'
		END AS 'Platt/NonPlatt',
        CONVERT(DATE, COALESCE(ain.StemDate, ain.BookedOn)) AS 'Stem Date',
        CONVERT(DATE, aid.DeliveryStartDateNomination) AS 'ETA',
        CONVERT(DATE, ad.DeliveryDate) AS 'Delivery Date',
        CASE 
            WHEN acg.Name = 'Scorpio' THEN acg.Name
            ELSE 'Third Party'
        END AS 'INT VS EXT',
        ac.Name AS 'Buyer',
        ase.Name AS 'Seller',
        asup.Name AS 'Physical Supplier',
        CASE 
            WHEN ase.Name = asup.Name THEN '1'
            ELSE '0'
        END  AS 'Trader Type',
        aifd.Description AS 'Grade',
        CASE 
            WHEN ad.BdnQtyUnit = 0 THEN 'MT' 
            WHEN ad.BdnQtyUnit = 1 THEN 'KG'
            WHEN ad.BdnQtyUnit = 2 THEN 'Litres'
            WHEN ad.BdnQtyUnit = 3 THEN 'IG'
            WHEN ad.BdnQtyUnit = 4 THEN 'CBM'
            WHEN ad.BdnQtyUnit = 5 THEN 'USGallons'
            WHEN ad.BdnQtyUnit = 6 THEN 'Barrels'
            WHEN ad.BdnQtyUnit = 7 THEN 'KL'
        END AS 'Units',
        af.Name AS 'GRADES',
        COALESCE(ad.bdnqty, ain.quantitymax) AS 'Grade MT',
        aimg.SellPrice AS 'Sell Price',
        ROUND(aimg.SellPriceUsd,2) AS 'Sell Price USD',
        aimg.BuyPrice AS 'Buy Price',
        ROUND(aimg.BuyPriceUsd,2) AS 'Buy Price USD',
        ROUND(aimg.Margin,2) AS 'Margin',
        CASE
		WHEN api.PriceSymbol = apd.Symbol AND CONVERT(DATE, COALESCE(ain.StemDate, ain.BookedOn)) = CONVERT(DATE,apd.Date) THEN apd.[Close]
		WHEN api.PriceSymbol = apd.Symbol AND CONVERT(DATE, COALESCE(ain.StemDate, ain.BookedOn)) <> CONVERT(DATE, apd.Date) THEN (
            SELECT TOP 1 [Close] 
            FROM AppPriceDefinitions 
			WHERE Symbol = api.PriceSymbol AND CONVERT(DATE, Date) < CONVERT(DATE, COALESCE(ain.StemDate, ain.BookedOn)) AND [Close] is not null
            ORDER BY Date DESC
        )
        ELSE NULL
		END AS 'Index Price',
		CASE
		WHEN apisp.PaymentType =1 THEN FORMAT(ROUND((apd.[Close] + apisp.Amount) - aimg.BuyPrice, 2), 'N2')
		WHEN apisp.PaymentType =0 THEN FORMAT(ROUND((apd.[Close] - apisp.Amount) - aimg.BuyPrice, 2), 'N2')
		ELSE FORMAT(ROUND(apd.[Close] - aimg.BuyPrice, 2), 'N2')
        END AS 'Avg.Below(Above)index',
        CASE  
			WHEN apd.Comments IS NULL OR apd.Comments = '' THEN '-' 
			ELSE apd.Comments
		END AS 'Remarks',
        QtyCTE.Qty AS 'BDN Qty in MT',
        CASE
		WHEN apisp.PaymentType =1 THEN FORMAT(ROUND(((apd.[Close] + apisp.Amount) - aimg.BuyPrice) * QtyCTE.Qty , 2), 'N2')
		WHEN apisp.PaymentType =0 THEN FORMAT(ROUND(((apd.[Close] - apisp.Amount) - aimg.BuyPrice) * QtyCTE.Qty , 2), 'N2')
		ELSE FORMAT(ROUND((apd.[Close] - aimg.BuyPrice) * QtyCTE.Qty, 2) , 'N2')
        END  AS 'Total Avg Savings',
        ROUND(aimg.Margin * QtyCTE.Qty,2) AS 'Total Avg Earning /Per mt'
    FROM AppInquiryFuelDetails as aifd
    JOIN AppInquiryDetails aid ON aid.Id = aifd.InquiryDetailId AND aid.InquiryStatus IN (700,800,900,1000,9000)
	LEFT JOIN FuelCTE fct ON fct.InquiryFuelDetailId = aifd.Id
	LEFT JOIN AppPriceIndexes api ON (api.PortId = fct.PortId OR api.SubPortId = fct.PortId) AND aifd.FuelId = api.FuelId AND api.IsDeleted=0
    LEFT JOIN AppPriceDefinitions apd ON api.PriceSymbol = apd.Symbol AND apd.IsDeleted=0
	LEFT JOIN AppPriceIndexSelectedSubPorts apisp ON apisp.PriceIndexId = api.Id AND apisp.IsDeleted=0
    LEFT JOIN QtyCTE ON QtyCTE.InquiryFuelDetailId = aifd.Id
    LEFT JOIN AppInquirySellerDetails aisd ON aisd.InquiryFuelDetailId = aifd.Id AND aisd.IsDeleted=0 AND aisd.SellerId = aifd.SellerId
    LEFT JOIN AppInquiryMargins aimg ON aimg.InquirySellerDetailId = aisd.Id AND aimg.IsDeleted=0
    LEFT JOIN AppVessel AS av ON av.id = aid.VesselId AND av.IsDeleted=0
    LEFT JOIN AppPorts AS ap ON ap.Id = aid.PortId AND ap.IsDeleted=0
    LEFT JOIN AppUserProfiles aup ON aup.Id = aid.UserProfileId AND aup.IsDeleted=0
    LEFT JOIN AppDeliveries ad ON ad.InquiryFuelDetailId = aifd.Id AND ad.IsDeleted=0
    LEFT JOIN AppCustomers ac ON ac.id = aid.CustomerNominationId AND ac.IsDeleted=0
    LEFT JOIN AppCustomerGroups acg ON acg.id = ac.CustomerGroupId AND ac.IsDeleted=0
    LEFT JOIN AppSellers ase ON ase.id = aifd.SellerId
    LEFT JOIN AppFuels af ON af.id = aifd.FuelId
    LEFT JOIN AppGradeGroups agg ON agg.id = af.GradeGroupId AND agg.IsDeleted=0
    LEFT JOIN AppInquiryNominations ain ON ain.InquirySellerDetailId = aisd.id AND ain.IsDeleted=0
    LEFT JOIN AppSuppliers asup ON asup.id = aisd.SupplierId AND asup.IsDeleted=0
    WHERE aid.IsDeleted = 0 and aifd.IsDeleted = 0 and aifd.IsLosted = 0
)

	SELECT 	* 
	FROM InquiryFuelCTE
	ORDER BY CAST(SUBSTRING(ID, 2, LEN(ID) - 1) AS INT) DESC
 