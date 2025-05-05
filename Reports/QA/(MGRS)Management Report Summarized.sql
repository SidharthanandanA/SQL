WITH QtyCTE AS (
Select 
	aifd.Id,
	CASE
		WHEN agg.Name = 'GO'
		THEN
			CASE 
				WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 0 THEN COALESCE(aic.BdnBillingQuantity, ad.BDNQty)	--MT
				WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 1 THEN ROUND(COALESCE(aic.BdnBillingQuantity, ad.BDNQty) * 0.001, 4) --KG
				WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 2 THEN ROUND(COALESCE(aic.BdnBillingQuantity, ad.BDNQty) * 0.00085, 4) --Litres
				WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 3 THEN ROUND(COALESCE(aic.BdnBillingQuantity, ad.BDNQty) * 0.0038641765, 4) --IG
				WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 4 THEN ROUND(COALESCE(aic.BdnBillingQuantity, ad.BDNQty) * 0.85, 4) --CBM
				WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 5 THEN ROUND(COALESCE(aic.BdnBillingQuantity, ad.BDNQty) * 0.0032, 4) --US Gallons
				WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 6 THEN ROUND(COALESCE(aic.BdnBillingQuantity, ad.BDNQty) * 0.134, 4) --Barrels
				WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 7 THEN ROUND(COALESCE(aic.BdnBillingQuantity, ad.BDNQty) * 0.85, 4) --KL
			END
		WHEN agg.Name = 'FO'
		THEN
			CASE
				WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 0 THEN COALESCE(aic.BdnBillingQuantity, ad.BDNQty)	--MT
				WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 1 THEN ROUND(COALESCE(aic.BdnBillingQuantity, ad.BDNQty) * 0.001, 4) --KG
				WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 2 THEN ROUND(COALESCE(aic.BdnBillingQuantity, ad.BDNQty) * 0.00094, 4) --Litres
				WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 3 THEN ROUND(COALESCE(aic.BdnBillingQuantity, ad.BDNQty) * 0.0042733246, 4)--IG
				WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 4 THEN ROUND(COALESCE(aic.BdnBillingQuantity, ad.BDNQty) * 0.94, 4) --CBM
				WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 5 THEN ROUND(COALESCE(aic.BdnBillingQuantity, ad.BDNQty) * 0.0037, 4) --US Gallons
				WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 6 THEN ROUND(COALESCE(aic.BdnBillingQuantity, ad.BDNQty) * 0.157, 4) --Barrels
				WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 7 THEN ROUND(COALESCE(aic.BdnBillingQuantity, ad.BDNQty) * 0.94, 4) --KL
			END
		ELSE COALESCE(aic.BdnBillingQuantity, ad.BDNQty)
	end as QtyCte
from AppInquiryFuelDetails aifd
LEFT JOIN AppInvoiceCustomers aic ON aic.InquiryFuelDetailId = aifd.Id and aic.IsDeleted = 0
LEFT JOIN AppDeliveries ad ON ad.InquiryFuelDetailId = aifd.Id and aifd.IsLosted = 0
LEFT JOIN AppFuels af ON af.id = aifd.FuelId and af.IsDeleted = 0
LEFT JOIN AppGradeGroups agg ON agg.Id = af.GradeGroupId and agg.IsDeleted = 0
Where aifd.IsDeleted = 0 and aifd.IsLosted = 0
),
InvoiceCustomerCTE AS (
Select 
	inv.InquiryDetailId,
	InquiryFuelDetailId,
	inv.Id AS 'InvoiceCustomerId',
	SellPrice * inv.ExchangeRate AS SellPrice, 
	aimc.AmountUsd AS MiscCostGradeUSD,
	BdnBillingQuantity,
	inv.SubTotal as InvoiceSubTotal,
	inv.TotalAmount as InvoiceTotalAmount,
	inv.ReceivableType,
	inv.CurrencyId,
	aic.TotalBDN,
	inv.InvoiceCode,
	inv.MergeCode,
	CASE 
		WHEN AdditionalCost is not null THEN AdditionalCost * inv.ExchangeRate
		ELSE (
			SELECT TOP 1 ISNULL(AdditionalCost * ExchangeRate, 0)
			FROM AppInvoiceCustomers sub
			JOIN (Select id as 'FuelDetailId', Description from AppInquiryFuelDetails where IsLosted = 0 and IsDeleted = 0) fc ON fc.FuelDetailId = sub.InquiryFuelDetailId
			WHERE sub.IsDeleted = 0 AND
			sub.InvoiceType = 0 AND
			sub.MergeCode = inv.MergeCode AND
			sub.InquiryDetailId = inv.InquiryDetailId
			ORDER BY fc.Description)
	END AS AdditionalCostFilled,
	CASE 
		WHEN Discount is not null THEN Discount * inv.ExchangeRate
		ELSE (
			SELECT TOP 1 ISNULL(Discount * ExchangeRate, 0)
			FROM AppInvoiceCustomers sub
			JOIN (Select id as 'FuelDetailId', Description from AppInquiryFuelDetails where IsLosted = 0 and IsDeleted = 0) fc ON fc.FuelDetailId = sub.InquiryFuelDetailId
			WHERE sub.IsDeleted = 0 AND
			sub.InvoiceType = 0 AND
			sub.MergeCode = inv.MergeCode AND
			sub.InquiryDetailId = inv.InquiryDetailId
			ORDER BY fc.Description)
	END AS Discount,
	CASE 
		WHEN VatAmount != 0 AND VatAmount is not null THEN VatAmount * inv.ExchangeRate
		ELSE (
			SELECT TOP 1 ISNULL(VatAmount * ExchangeRate, 0)
			FROM AppInvoiceCustomers sub
			JOIN (Select id as 'FuelDetailId', Description from AppInquiryFuelDetails where IsLosted = 0 and IsDeleted = 0) fc ON fc.FuelDetailId = sub.InquiryFuelDetailId
			WHERE sub.IsDeleted = 0 AND
			sub.InvoiceType = 0 AND
			sub.HasVat = 1 AND
			sub.MergeCode = inv.MergeCode AND
			sub.InquiryDetailId = inv.InquiryDetailId
			ORDER BY fc.Description)
	END AS VatAmountFilled,
	CASE 
		WHEN AmountReceivedSoFar != 0 AND AmountReceivedSoFar is not null THEN AmountReceivedSoFar * inv.ExchangeRate
		ELSE (
			SELECT TOP 1 ISNULL(AmountReceivedSoFar * ExchangeRate, 0)
			FROM AppInvoiceCustomers sub
			JOIN (Select id as 'FuelDetailId', Description from AppInquiryFuelDetails where IsLosted = 0 and IsDeleted = 0) fc ON fc.FuelDetailId = sub.InquiryFuelDetailId
			WHERE sub.IsDeleted = 0 AND
			sub.InvoiceType = 0 AND
			sub.MergeCode = inv.MergeCode AND
			sub.InquiryDetailId = inv.InquiryDetailId
			ORDER BY fc.Description)
	END AS AmountReceivedSoFarFilled
from APpInvoiceCustomers inv
LEFT JOIN (Select 
		Id AS 'InvoiceCustomerId', 
		InquiryDetailId, 
		SUM(ISNULL(BdnBillingQuantity, 0)) OVER (PARTITION BY InquiryDetailId) AS TotalBDN 
	from AppInvoiceCustomers
	where InvoiceType = 0 and MergeCode is not null) aic ON aic.InvoiceCustomerId = inv.Id
LEFT JOIN AppInvoiceMiscCosts aimc ON aimc.InvoiceCustomerId = inv.Id and aimc.IsDeleted = 0

where InvoiceType = 0 and inv.IsDeleted = 0 and inv.InvoiceStatus NOT IN (0,10,20)--and inv.InquiryDetailId = '46B4E5F9-4190-69AF-455C-3A18838DA01F'
)
, InvoiceAmountsCTE AS (
Select 
	InvoiceCustomerId,
	InquiryDetailId,
	InquiryFuelDetailId,
	AmountReceivedSoFarFilled,
	VatAmountFilled,
	BdnBillingQuantity,
	MergeCode,
	TotalBDN,
	InvoiceCode,
	ReceivableType,
	SellPrice,
	CurrencyId,
	MiscCostGradeUSD,
	InvoiceSubTotal,
	InvoiceTotalAmount,
	((VatAmountFilled * BdnBillingQuantity) / SUM(BdnBillingQuantity) OVER (PARTITION BY InquiryDetailId, MergeCode)) AS VATAmount,
	((Discount * BdnBillingQuantity) / SUM(BdnBillingQuantity) OVER (PARTITION BY InquiryDetailId, MergeCode)) AS Discount,
	((AdditionalCostFilled * BdnBillingQuantity) / SUM(BdnBillingQuantity) OVER (PARTITION BY InquiryDetailId, MergeCode)) AS AdditionalCost

from InvoiceCustomerCTE
WHERE BdnBillingQuantity is not null
)
, InvoiceAdjustedCTE AS (
Select 
	InvoiceCustomerId,
	InquiryDetailId,
	InquiryFuelDetailId,
	AmountReceivedSoFarFilled,
	BdnBillingQuantity,
	MergeCode,
	TotalBDN,
	InvoiceCode,
	ReceivableType,
	SellPrice,
	CurrencyId,
	CASE
		WHEN MergeCode IS NULL THEN InvoiceSubTotal
		ELSE (SellPrice * ISNULL(BdnBillingQuantity, 0)) + ((ISNULL(AdditionalCost, 0) * ISNULL(BdnBillingQuantity, 0))/COALESCE(BDNBillingQuantity, TotalBDN)) + ISNULL(MiscCostGradeUSD, 0) - ((ISNULL(Discount, 0) * ISNULL(BdnBillingQuantity, 0))/COALESCE(BDNBillingQuantity, TotalBDN)) 
	END AS 'SubTotal',
	CASE
		WHEN MergeCode IS NULL THEN InvoiceTotalAmount
		ELSE (SellPrice * ISNULL(BdnBillingQuantity, 0)) + ((ISNULL(AdditionalCost, 0) * ISNULL(BdnBillingQuantity, 0))/COALESCE(BDNBillingQuantity, TotalBDN)) + ISNULL(MiscCostGradeUSD, 0) + ((ISNULL(VATAmount, 0) * ISNULL(BdnBillingQuantity, 0))/COALESCE(BDNBillingQuantity, TotalBDN)) - ((ISNULL(Discount, 0) * ISNULL(BdnBillingQuantity, 0))/COALESCE(BDNBillingQuantity, TotalBDN)) 
	END AS 'TotalAmount'
	
from InvoiceAmountsCTE
WHERE BdnBillingQuantity is not null
) --Select * from InvoiceCustomerCTE WHERE InquiryDetailId = 'CACFBAE3-48FA-48D3-B523-3A1890EDDF90'
, CustomerAmountsCTE AS (
Select 
	InvoiceCustomerId,
	InquiryDetailId,
	InquiryFuelDetailId,
	MergeCode,
	InvoiceCode,
	ReceivableType,
	BdnBillingQuantity,
	SellPrice,
	CurrencyId,
	SubTotal,
	TotalAmount,
	CASE 
		WHEN MergeCode IS NULL THEN AmountReceivedSoFarFilled - ((AmountReceivedSoFarFilled * (TotalAmount - SubTotal)) / TotalAmount)
		ELSE (AmountReceivedSoFarFilled - ((AmountReceivedSoFarFilled * (SUM(TotalAmount) OVER (PARTITION BY InquiryDetailId, MergeCode) - SUM(SubTotal) OVER (PARTITION BY InquiryDetailId, MergeCode))) / SUM(TotalAmount) OVER (PARTITION BY InquiryDetailId, MergeCode))) * SubTotal / (SUM(SubTotal) OVER (PARTITION BY InquiryDetailId, MergeCode)) 
	END AS 'AmountReceivedReal',
	SubTotal / (SUM(SubTotal) OVER (PARTITION BY InquiryDetailId)) AS 'Weight'
from InvoiceAdjustedCTE
)
--Select * from CustomerAmountsCTE --WHERE InquiryDetailId = 'CACFBAE3-48FA-48D3-B523-3A1890EDDF90'
,ExcessDaysCalc AS (
    SELECT 
        aid.CustomerNominationId,
        aic.InvoiceCode AS 'Invoice Number',
        COALESCE(aic.AmountReceivedDate, aic.acknowledgementsenton) AS 'DateReceived',
        aic.PaymentDueDate,
        CAST(DATEDIFF(DAY, aic.PaymentDueDate, COALESCE(aic.AmountReceivedDate, aic.acknowledgementsenton)) AS FLOAT) AS 'Excess Days'
    FROM AppInvoiceCustomers aic
    JOIN AppInquiryDetails aid ON aid.Id = aic.Inquirydetailid AND aid.isdeleted = 0
    WHERE aic.isdeleted = 0 AND InvoiceStatus IN (50, 60)
),
PaymentPerformance AS (
SELECT
    CustomerNominationId,
    ROUND(AVG([Excess Days]),2) AS 'Payment Performance'
FROM ExcessDaysCalc
GROUP BY CustomerNominationId
),
MainAndBookedInvoices AS (
Select DISTINCT
	aid.Code AS [Job Code],
	aifd.Id AS InquiryFuelDetailId,
	aifd.Description AS Fuel,
	CASE
		WHEN aifd.TradeType = 0 THEN 'Spot'
		WHEN aifd.TradeType = 1 THEN 'Contract'
	END AS 'Trade Type',
	asel.Name AS Seller,
	asup.Name AS Supplier,
	CASE 
		WHEN aid.InquiryStatus NOT IN (900,1000) THEN NULL
		ELSE 'Invoice'
	END AS 'Invoice Type',
	av.Name AS Vessel,
	ap.Name AS [Port],
	aup.Name AS Trader,
	aup.UserId AS UserId,
	aup.Email AS UserEmail,
	ac.Name AS Buyer,
	pp.[Payment performance],
	CASE 
		WHEN acg.Name = 'Scorpio' THEN 'Scorpio'
		WHEN (acg.Name = 'Cargo deals' OR acg.Name = 'Cargo Deals' OR acg.Name = 'Cargo deal' OR acg.Name = 'Cargo Deal') THEN 'Cargo Deals'
		ELSE '3rd Party'
	END AS 'Customer In Out',
	CASE 
		WHEN aid.InquiryStatus = 0 THEN 'Draft'
		WHEN aid.InquiryStatus = 100 THEN 'Raised By Client'
		WHEN aid.InquiryStatus = 200 THEN 'Pending Credit Approval'
		WHEN aid.InquiryStatus = 300 THEN 'Credit Rejected'
		WHEN aid.InquiryStatus = 400 THEN 'Credit Approved'
		WHEN aid.InquiryStatus = 500 THEN 'PreApproved'
		WHEN aid.InquiryStatus = 600 THEN 'Auction'
		WHEN aid.InquiryStatus = 650 THEN 'Partly Booked'
		WHEN aid.InquiryStatus = 700 THEN 'Partly Booked'
		WHEN aid.InquiryStatus = 800 THEN 'Booked'
		WHEN aid.InquiryStatus = 900 THEN 'Partly Delivered'
		WHEN aid.InquiryStatus = 1000 THEN 'Delivered'
		WHEN aid.InquiryStatus = 1500 THEN 'Lost Stem'
		WHEN aid.InquiryStatus = 9000 THEN 'Cancelled Stem'
		WHEN aid.InquiryStatus = 10000 THEN 'Invoiced'
		WHEN aid.InquiryStatus = 15000 THEN 'Closed'
	END AS 'Job Status',
	CONVERT(DATE, COALESCE(ain.StemDate, ain.BookedOn)) AS 'Stem Date',
	CONVERT(DATE, ad.DeliveryDate) AS 'Delivery Date',
	ROUND(aim.Margin, 2) AS 'Margin per MT',
	CASE WHEN aifd.IsCancelled = 0
	THEN
	CASE
		WHEN agg.Name = 'GO'
		THEN
			CASE 
				WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 0 THEN COALESCE(ca.BdnBillingQuantity, ad.BDNQty, ain.QuantityMax)	--MT
				WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 1 THEN ROUND(COALESCE(ca.BdnBillingQuantity, ad.BDNQty, ain.QuantityMax) * 0.001, 4) --KG
				WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 2 THEN ROUND(COALESCE(ca.BdnBillingQuantity, ad.BDNQty, ain.QuantityMax) * 0.00085, 4) --Litres
				WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 3 THEN ROUND(COALESCE(ca.BdnBillingQuantity, ad.BDNQty, ain.QuantityMax) * 0.0038641765, 4) --IG
				WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 4 THEN ROUND(COALESCE(ca.BdnBillingQuantity, ad.BDNQty, ain.QuantityMax) * 0.85, 4) --CBM
				WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 5 THEN ROUND(COALESCE(ca.BdnBillingQuantity, ad.BDNQty, ain.QuantityMax) * 0.0032, 4) --US Gallons
				WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 6 THEN ROUND(COALESCE(ca.BdnBillingQuantity, ad.BDNQty, ain.QuantityMax) * 0.134, 4) --Barrels
				WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 7 THEN ROUND(COALESCE(ca.BdnBillingQuantity, ad.BDNQty, ain.QuantityMax) * 0.85, 4) --KL
			END
		WHEN agg.Name = 'FO'
		THEN
			CASE
				WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 0 THEN COALESCE(ca.BdnBillingQuantity, ad.BDNQty, ain.QuantityMax)	--MT
				WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 1 THEN ROUND(COALESCE(ca.BdnBillingQuantity, ad.BDNQty, ain.QuantityMax) * 0.001, 4) --KG
				WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 2 THEN ROUND(COALESCE(ca.BdnBillingQuantity, ad.BDNQty, ain.QuantityMax) * 0.00094, 4) --Litres
				WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 3 THEN ROUND(COALESCE(ca.BdnBillingQuantity, ad.BDNQty, ain.QuantityMax) * 0.0042733246, 4)--IG
				WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 4 THEN ROUND(COALESCE(ca.BdnBillingQuantity, ad.BDNQty, ain.QuantityMax) * 0.94, 4) --CBM
				WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 5 THEN ROUND(COALESCE(ca.BdnBillingQuantity, ad.BDNQty, ain.QuantityMax) * 0.0037, 4) --US Gallons
				WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 6 THEN ROUND(COALESCE(ca.BdnBillingQuantity, ad.BDNQty, ain.QuantityMax) * 0.157, 4) --Barrels
				WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 7 THEN ROUND(COALESCE(ca.BdnBillingQuantity, ad.BDNQty, ain.QuantityMax) * 0.94, 4) --KL
			END
		ELSE COALESCE(ca.BdnBillingQuantity, ad.BDNQty, ain.QuantityMax)
	END
	ELSE NULL
	END AS 'Qty',
	aic.InvoiceCode AS 'Customer Invoice Number',
	CASE 
		WHEN aifd.IsDelivered = 0 THEN (aim.SellPriceUsd * ain.QuantityMax) + ISNULL(aimb.TotalMiscCostBuyer, 0)
		ELSE ca.SubTotal
	END AS 'Customer Invoice Amount',
	ais.InvoiceNumber AS 'Seller Invoice Number',
	CASE 
		WHEN aifd.IsDelivered = 0 THEN (aim.BuyPriceUsd * ain.QuantityMax) + ISNULL(aims.TotalMiscCostSeller, 0)
		ELSE ais.SubTotal
	END AS 'Seller Invoice Amount',
	ca.AmountReceivedReal AS 'Amount Received',
	ais.AmountPaidSoFar AS 'Amount Paid',
	CASE
		WHEN aid.InquiryStatus IN (700,800) THEN 'Not paid'
		WHEN aid.InquiryStatus NOT IN (700,800) 
		THEN 
			CASE 
				WHEN ais.InvoiceType IS NULL THEN 'Not paid'
				WHEN ais.PayableType = 0 THEN 'Not paid'
				WHEN ais.PayableType = 1 THEN 'Partly paid'
				WHEN ais.PayableType = 2 THEN 'Paid'
			END
	END AS 'Payment Status',
	CASE
		WHEN aid.InquiryStatus IN (700,800) THEN 'Not received'
		WHEN aid.InquiryStatus NOT IN (700,800) 
		THEN 
			CASE 
				WHEN aic.ReceivableType = 0 THEN 'Not received'
				WHEN aic.ReceivableType = 1 THEN 'Partly received'
				WHEN aic.ReceivableType = 2 THEN 'Received'
				ELSE 'Not received'
			END
	END AS 'Receipt Status',
	ROUND(aim.BuyPriceUsd, 2) AS 'Buying Price',
	buy.Code AS 'Buying Currency',
	ROUND(aim.SellPriceUsd, 2) AS 'Selling Price',
	sel.Code AS 'Selling Currency'


from AppInquiryNominations ain
JOIN AppInquiryDetails aid ON aid.Id = ain.InquiryDetailId and aid.isdeleted = 0 and aid.InquiryStatus IN (700,800,900,1000,9000)
JOIN AppInquiryFuelDetails aifd ON aifd.InquiryDetailId = ain.InquiryDetailId and aifd.InquiryDetailId = aid.Id and aifd.IsDeleted = 0 and aifd.IsLosted = 0
JOIN AppInquirySellerDetails aisd ON aisd.InquiryFuelDetailId = aifd.Id and aisd.SellerId = aifd.SellerId and aisd.IsDeleted = 0 and aisd.id = ain.InquirySellerDetailId
LEFT JOIN AppSellers asel ON asel.Id = aifd.sellerId and asel.isdeleted = 0
LEFT JOIN AppSuppliers asup ON asup.Id = aisd.SupplierId and asup.isdeleted = 0
LEFT JOIN AppVessel av ON av.id = aid.VesselNominationId and av.Isdeleted = 0
LEFT JOIN AppPorts ap ON ap.id = aid.PortNominationId and av.Isdeleted = 0
LEFT JOIN AppUserProfiles aup ON aup.Id = aid.UserProfileId and aup.Isdeleted = 0
LEFT JOIN AppCustomers ac ON ac.Id = aid.CustomerNominationId and ac.Isdeleted = 0
LEFT JOIN AppCustomerGroups acg ON acg.Id = ac.CustomerGroupId and acg.Isdeleted = 0
LEFT JOIN AppDeliveries ad ON ad.InquiryFuelDetailId = aifd.id and ad.isdeleted = 0
JOIN AppInquiryMargins aim ON aim.InquiryDetailId = aid.id and aim.InquirySellerDetailId = aisd.Id and aim.isdeleted = 0
LEFT JOIN AppInvoiceCustomers aic ON aic.InquiryFueldetailid = aifd.id and aic.InvoiceType = 0 and aic.IsDeleted = 0
LEFT JOIN CustomerAmountsCTE ca ON ca.InquiryFuelDetailId = aifd.id
LEFT JOIN AppFuels af ON af.Id = aifd.FuelId and af.Isdeleted = 0
LEFT JOIN AppGradeGroups agg ON agg.Id = af.GradeGroupId and agg.isdeleted = 0
LEFT JOIN AppInvoiceSellers ais ON ais.InquiryFuelDetailId = aifd.Id and ais.IsDeleted = 0 and ais.InvoiceType = 0
LEFT JOIN (Select 
				InquirySellerDetailId, 
				InquiryDetailId, 
				(SUM(AmountUsd)) AS TotalMiscCostSeller 
		   from AppInquiryMiscCosts where ToSeller = 1 and IsDeleted = 0 GROUP BY InquirySellerDetailId, InquiryDetailId) aims ON aims.InquirySellerDetailId = aisd.Id and aifd.InquiryDetailId = aims.InquiryDetailId
LEFT JOIN (Select 
				InquirySellerDetailId, 
				InquiryDetailId, 
				(SUM(AmountUsd)) AS TotalMiscCostBuyer
		   from AppInquiryMiscCosts where FromBuyer = 1 and IsDeleted = 0 GROUP BY InquirySellerDetailId, InquiryDetailId) aimb ON aimb.InquirySellerDetailId = aisd.Id and aifd.InquiryDetailId = aimb.InquiryDetailId
LEFT JOIN AppInquiryOffers aio ON aio.InquiryDetailId = aifd.InquiryDetailId and aio.SellerId = aifd.SellerId and aio.IsDeleted = 0
LEFT JOIN AppCurrencies sel ON sel.Id = aim.CurrencyId and sel.IsDeleted = 0
LEFT JOIN AppCurrencies buy ON buy.Id = aio.CurrencyId and buy.IsDeleted = 0
LEFT JOIN PaymentPerformance pp ON pp.CustomerNominationId = aid.CustomerNominationId

WHERE aid.InquiryStatus IN (700,800,900,1000,9000) AND (aic.InvoiceStatus NOT IN (0,10,20) OR ais.InvoiceStatus NOT IN (0,10,20) OR (aic.InvoiceStatus IS NULL OR ais.InvoiceStatus is null))
),
CustomerInvoices AS (
    SELECT 
		aid.Code AS 'Job Code',
        aifd.Id,
        aifd.Description,
        aic.InvoiceCode AS CustomerInvoiceNumber,
		CASE 
			WHEN aic.InvoiceType = 0 THEN 'Invoice'
			WHEN aic.InvoiceType = 1 THEN 'Credit Note'
			WHEN aic.InvoiceType = 2 THEN 'Debit Note'
        END AS 'InvoiceType',
		CASE
		WHEN aifd.TradeType = 0 THEN 'Spot'
		WHEN aifd.TradeType = 1 THEN 'Contract'
		END AS 'Trade Type',
		CASE 
			WHEN aic.InvoiceType = 1 THEN ROUND(-ABS(aic.SubTotal * aim.ExchangeRate),2)
			WHEN aic.InvoiceType = 2 THEN ROUND(aic.SubTotal * aim.ExchangeRate, 2)
		END AS 'Customer Invoice Amount',
		CASE 
			WHEN aic.InvoiceType = 1 THEN ROUND(-ABS(aic.AmountReceivedSoFar * aim.ExchangeRate),2)
			WHEN aic.InvoiceType = 2 THEN ROUND(aic.AmountReceivedSoFar * aim.ExchangeRate, 2)
		END AS 'Amount Received',
		CASE
			WHEN aid.InquiryStatus IN (700,800) THEN 'Not received'
			WHEN aid.InquiryStatus NOT IN (700,800)
			THEN 
			CASE 
				WHEN aic.InvoiceType IS NULL THEN 'Not received'
				WHEN aic.ReceivableType = 0 THEN 'Not received'
				WHEN aic.ReceivableType = 1 THEN 'Partly received'
				WHEN aic.ReceivableType = 2 THEN 'Received'
			END
		END AS 'Receipt Status',
		CASE
			WHEN aic.SellPrice IS NOT NULL THEN aic.SellPrice * aim.ExchangeRate
			WHEN aic.SubTotal IS NOT NULL AND COALESCE(ad.BdnQtyUnit, aifd.Unit) IS NOT NULL AND aic.InvoiceType = 1 THEN ROUND((-ABS(aic.SubTotal) / COALESCE(aic.BdnBillingQuantity, ad.BDNQty, ain.QuantityMax))*aim.ExchangeRate, 2)
			WHEN aic.SubTotal IS NOT NULL AND COALESCE(ad.BdnQtyUnit, aifd.Unit) IS NOT NULL AND aic.InvoiceType = 2 THEN ROUND((aic.SubTotal / COALESCE(aic.BdnBillingQuantity, ad.BDNQty, ain.QuantityMax))*aim.ExchangeRate, 2)
		END AS 'Selling Price',
		CASE
		WHEN agg.Name = 'GO'
		THEN
			CASE 
				WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 0 THEN COALESCE(aic.BdnBillingQuantity, ad.BDNQty, ain.QuantityMax)	--MT
				WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 1 THEN ROUND(COALESCE(aic.BdnBillingQuantity, ad.BDNQty, ain.QuantityMax) * 0.001, 4) --KG
				WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 2 THEN ROUND(COALESCE(aic.BdnBillingQuantity, ad.BDNQty, ain.QuantityMax) * 0.00085, 4) --Litres
				WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 3 THEN ROUND(COALESCE(aic.BdnBillingQuantity, ad.BDNQty, ain.QuantityMax) * 0.0038641765, 4) --IG
				WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 4 THEN ROUND(COALESCE(aic.BdnBillingQuantity, ad.BDNQty, ain.QuantityMax) * 0.85, 4) --CBM
				WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 5 THEN ROUND(COALESCE(aic.BdnBillingQuantity, ad.BDNQty, ain.QuantityMax) * 0.0032, 4) --US Gallons
				WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 6 THEN ROUND(COALESCE(aic.BdnBillingQuantity, ad.BDNQty, ain.QuantityMax) * 0.134, 4) --Barrels
				WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 7 THEN ROUND(COALESCE(aic.BdnBillingQuantity, ad.BDNQty, ain.QuantityMax) * 0.85, 4) --KL
			END
		WHEN agg.Name = 'FO'
		THEN
			CASE
				WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 0 THEN COALESCE(aic.BdnBillingQuantity, ad.BDNQty, ain.QuantityMax)	--MT
				WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 1 THEN ROUND(COALESCE(aic.BdnBillingQuantity, ad.BDNQty, ain.QuantityMax) * 0.001, 4) --KG
				WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 2 THEN ROUND(COALESCE(aic.BdnBillingQuantity, ad.BDNQty, ain.QuantityMax) * 0.00094, 4) --Litres
				WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 3 THEN ROUND(COALESCE(aic.BdnBillingQuantity, ad.BDNQty, ain.QuantityMax) * 0.0042733246, 4)--IG
				WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 4 THEN ROUND(COALESCE(aic.BdnBillingQuantity, ad.BDNQty, ain.QuantityMax) * 0.94, 4) --CBM
				WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 5 THEN ROUND(COALESCE(aic.BdnBillingQuantity, ad.BDNQty, ain.QuantityMax) * 0.0037, 4) --US Gallons
				WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 6 THEN ROUND(COALESCE(aic.BdnBillingQuantity, ad.BDNQty, ain.QuantityMax) * 0.157, 4) --Barrels
				WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 7 THEN ROUND(COALESCE(aic.BdnBillingQuantity, ad.BDNQty, ain.QuantityMax) * 0.94, 4) --KL
			END
		ELSE COALESCE(aic.BdnBillingQuantity, ad.BDNQty, ain.QuantityMax)
	END AS 'Qty in MT',
	asel.Name AS 'Seller',
	asup.Name AS 'Supplier',
	av.Name AS 'Vessel',
	ap.Name AS 'Port',
	aup.Name AS 'Trader',
	aup.UserId AS 'UserId',
	aup.Email AS 'UserEmail',
	ac.Name AS 'Buyer',
	pp.[Payment performance],
	CASE 
		WHEN acg.Name = 'Scorpio' THEN 'Scorpio'
		WHEN (acg.Name = 'Cargo deals' OR acg.Name = 'Cargo Deals' OR acg.Name = 'Cargo deal' OR acg.Name = 'Cargo Deal') THEN 'Cargo Deals'
		ELSE '3rd Party'
		END AS 'Customer In Out',
	CASE 
		WHEN aid.InquiryStatus = 0 THEN 'Draft'
		WHEN aid.InquiryStatus = 100 THEN 'Raised By Client'
		WHEN aid.InquiryStatus = 200 THEN 'Pending Credit Approval'
		WHEN aid.InquiryStatus = 300 THEN 'Credit Rejected'
		WHEN aid.InquiryStatus = 400 THEN 'Credit Approved'
		WHEN aid.InquiryStatus = 500 THEN 'PreApproved'
		WHEN aid.InquiryStatus = 600 THEN 'Auction'
		WHEN aid.InquiryStatus = 650 THEN 'Partly Booked'
		WHEN aid.InquiryStatus = 700 THEN 'Partly Booked'
		WHEN aid.InquiryStatus = 800 THEN 'Booked'
		WHEN aid.InquiryStatus = 900 THEN 'Partly Delivered'
		WHEN aid.InquiryStatus = 1000 THEN 'Delivered'
		WHEN aid.InquiryStatus = 1500 THEN 'Lost Stem'
		WHEN aid.InquiryStatus = 9000 THEN 'Cancelled Stem'
		WHEN aid.InquiryStatus = 10000 THEN 'Invoiced'
		WHEN aid.InquiryStatus = 15000 THEN 'Closed'
	END AS 'Job Status',
	CONVERT(DATE, COALESCE(ain.StemDate, ain.BookedOn)) AS 'Stem Date',
	CONVERT(DATE, ad.DeliveryDate) AS 'Delivery Date',
	CASE WHEN aifd.IsCancelled = 1 THEN NULL
	ELSE aim.Margin 
	END AS 'Margin per MT',
	acur.Code AS 'Selling Currency',
        ROW_NUMBER() OVER (PARTITION BY aifd.Id, aifd.Description, aic.InvoiceType ORDER BY aic.InvoiceCode) AS RowNum
    FROM 
        AppInquiryFuelDetails aifd
    JOIN 
        AppInvoiceCustomers aic 
        ON aic.InquiryFuelDetailId = aifd.Id 
        AND aic.IsDeleted = 0 
        AND aic.InvoiceType <> 0
		AND aic.InvoiceStatus NOT IN (0,10,20)
	LEFT JOIN AppDeliveries ad ON ad.InquiryFuelDetailId = aifd.id and ad.IsDeleted = 0
	JOIN AppInquirySellerDetails aisd ON aisd.InquiryFuelDetailId = aifd.id and aisd.SellerId = aifd.SellerId and aisd.IsDeleted = 0
	JOIN AppInquiryNominations ain ON ain.InquirySellerDetailId = aisd.Id and ain.InquiryDetailId = aifd.InquiryDetailId and ain.IsDeleted = 0
	JOIN AppInquiryDetails aid ON aid.Id = aifd.InquiryDetailId and aid.isdeleted = 0
	LEFT JOIN AppFuels af ON af.id = aifd.FuelId and af.IsDeleted = 0
	LEFT JOIN AppGradeGroups agg ON agg.Id = af.GradeGroupId and agg.IsDeleted = 0
	LEFT JOIN AppSellers asel ON asel.Id = aifd.SellerId and asel.IsDeleted = 0
	LEFT JOIN AppSuppliers asup ON asup.Id = aisd.SupplierId and asup.IsDeleted = 0
	LEFT JOIN AppVessel av ON av.Id = aid.VesselNominationId and av.IsDeleted = 0
	LEFT JOIN AppPorts ap ON ap.Id = aid.PortNominationId and ap.IsDeleted = 0
	LEFT JOIN AppUserProfiles aup ON aup.Id = aid.UserProfileId and aup.IsDeleted = 0
	LEFT JOIN AppCustomers ac ON ac.Id = aid.CustomerNominationId and ac.IsDeleted = 0
	LEFT JOIN AppCustomerGroups acg ON acg.id = ac.CustomerGroupId and acg.IsDeleted = 0
	LEFT JOIN AppInquiryMargins aim On aim.InquiryDetailId = aifd.InquiryDetailId and aim.InquirySellerDetailId = aisd.Id and aim.IsDeleted = 0
	LEFT JOIN AppCurrencies acur ON acur.Id = aim.CurrencyId and acur.IsDeleted = 0
	LEFT JOIN PaymentPerformance pp ON pp.CustomerNominationId = aid.CustomerNominationId
    WHERE 
        aifd.IsDeleted = 0 
        AND aifd.isLosted = 0
),
SellerInvoices AS (
    SELECT 
		aid.Code AS 'Job Code',
        aifd.Id,
        aifd.Description,
        ais.InvoiceNumber AS SellerInvoiceNumber,
        CASE 
			WHEN ais.InvoiceType = 0 THEN 'Invoice'
			WHEN ais.InvoiceType = 1 THEN 'Credit Note'
			WHEN ais.InvoiceType = 2 THEN 'Debit Note'
        END AS 'InvoiceType',
		CASE
		WHEN aifd.TradeType = 0 THEN 'Spot'
		WHEN aifd.TradeType = 1 THEN 'Contract'
		END AS 'Trade Type',
		CASE 
			WHEN ais.InvoiceType = 1 THEN ROUND(-ABS(ais.SubTotal * aio.ExchangeRate),2)
			WHEN ais.InvoiceType = 2 THEN ROUND(ais.SubTotal * aio.ExchangeRate, 2)
		END AS 'Seller Invoice Amount',
		CASE 
			WHEN ais.InvoiceType = 1 THEN ROUND(-ABS(ais.AmountPaidSoFar * aio.ExchangeRate),2)
			WHEN ais.InvoiceType = 2 THEN ROUND(ais.AmountPaidSoFar * aio.ExchangeRate, 2)
		END AS 'Amount Paid',
		CASE
			WHEN aid.InquiryStatus IN (700,800) THEN 'Not paid'
			WHEN aid.InquiryStatus NOT IN (700,800)
				THEN 
				CASE 
					WHEN ais.InvoiceType IS NULL THEN 'Not paid'
					WHEN ais.PayableType = 0 THEN 'Not paid'
					WHEN ais.PayableType = 1 THEN 'Partly paid'
					WHEN ais.PayableType = 2 THEN 'Paid'
				END
		END AS 'Payment Status',
		CASE
			WHEN ais.BuyPrice IS NOT NULL THEN ais.BuyPrice * aio.ExchangeRate
			WHEN ais.SubTotal IS NOT NULL AND COALESCE(ad.BdnQtyUnit, aifd.Unit) IS NOT NULL AND ais.InvoiceType = 1 THEN ROUND((-ABS(ais.SubTotal) / COALESCE(ais.BdnBillingQuantity, ad.BDNQty, ain.QuantityMax))*aio.ExchangeRate, 2)
			WHEN ais.SubTotal IS NOT NULL AND COALESCE(ad.BdnQtyUnit, aifd.Unit) IS NOT NULL AND ais.InvoiceType = 2 THEN ROUND((ais.SubTotal / COALESCE(ais.BdnBillingQuantity, ad.BDNQty, ain.QuantityMax))*aio.ExchangeRate, 2)
		END AS 'Buying Price',
		CASE
		WHEN agg.Name = 'GO'
		THEN
			CASE 
				WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 0 THEN COALESCE(ais.BdnBillingQuantity, ad.BDNQty, ain.QuantityMax)	--MT
				WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 1 THEN ROUND(COALESCE(ais.BdnBillingQuantity, ad.BDNQty, ain.QuantityMax) * 0.001, 4) --KG
				WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 2 THEN ROUND(COALESCE(ais.BdnBillingQuantity, ad.BDNQty, ain.QuantityMax) * 0.00085, 4) --Litres
				WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 3 THEN ROUND(COALESCE(ais.BdnBillingQuantity, ad.BDNQty, ain.QuantityMax) * 0.0038641765, 4) --IG
				WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 4 THEN ROUND(COALESCE(ais.BdnBillingQuantity, ad.BDNQty, ain.QuantityMax) * 0.85, 4) --CBM
				WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 5 THEN ROUND(COALESCE(ais.BdnBillingQuantity, ad.BDNQty, ain.QuantityMax) * 0.0032, 4) --US Gallons
				WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 6 THEN ROUND(COALESCE(ais.BdnBillingQuantity, ad.BDNQty, ain.QuantityMax) * 0.134, 4) --Barrels
				WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 7 THEN ROUND(COALESCE(ais.BdnBillingQuantity, ad.BDNQty, ain.QuantityMax) * 0.85, 4) --KL
			END
		WHEN agg.Name = 'FO'
		THEN
			CASE
				WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 0 THEN COALESCE(ais.BdnBillingQuantity, ad.BDNQty, ain.QuantityMax)	--MT
				WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 1 THEN ROUND(COALESCE(ais.BdnBillingQuantity, ad.BDNQty, ain.QuantityMax) * 0.001, 4) --KG
				WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 2 THEN ROUND(COALESCE(ais.BdnBillingQuantity, ad.BDNQty, ain.QuantityMax) * 0.00094, 4) --Litres
				WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 3 THEN ROUND(COALESCE(ais.BdnBillingQuantity, ad.BDNQty, ain.QuantityMax) * 0.0042733246, 4)--IG
				WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 4 THEN ROUND(COALESCE(ais.BdnBillingQuantity, ad.BDNQty, ain.QuantityMax) * 0.94, 4) --CBM
				WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 5 THEN ROUND(COALESCE(ais.BdnBillingQuantity, ad.BDNQty, ain.QuantityMax) * 0.0037, 4) --US Gallons
				WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 6 THEN ROUND(COALESCE(ais.BdnBillingQuantity, ad.BDNQty, ain.QuantityMax) * 0.157, 4) --Barrels
				WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 7 THEN ROUND(COALESCE(ais.BdnBillingQuantity, ad.BDNQty, ain.QuantityMax) * 0.94, 4) --KL
			END
		ELSE COALESCE(ais.BdnBillingQuantity, ad.BDNQty, ain.QuantityMax)
	END AS 'Qty in MT',
		COALESCE(asur.Name, agen.Name, asup.Name, abro.Name, aselll.Name, asell.Name, asel.Name) AS Seller,
		COALESCE(asupp.Name, asuppp.Name) AS 'Supplier',
		av.Name AS 'Vessel',
		ap.Name AS 'Port',
		aup.Name AS 'Trader',
		aup.UserId AS 'UserId',
		aup.Email AS 'UserEmail',
		ac.Name AS 'Buyer',
		pp.[Payment performance],
		CASE 
		WHEN acg.Name = 'Scorpio' THEN 'Scorpio'
		WHEN (acg.Name = 'Cargo deals' OR acg.Name = 'Cargo Deals' OR acg.Name = 'Cargo deal' OR acg.Name = 'Cargo Deal') THEN 'Cargo Deals'
		ELSE '3rd Party'
		END AS 'Customer In Out',
		CASE 
		WHEN aid.InquiryStatus = 0 THEN 'Draft'
		WHEN aid.InquiryStatus = 100 THEN 'Raised By Client'
		WHEN aid.InquiryStatus = 200 THEN 'Pending Credit Approval'
		WHEN aid.InquiryStatus = 300 THEN 'Credit Rejected'
		WHEN aid.InquiryStatus = 400 THEN 'Credit Approved'
		WHEN aid.InquiryStatus = 500 THEN 'PreApproved'
		WHEN aid.InquiryStatus = 600 THEN 'Auction'
		WHEN aid.InquiryStatus = 650 THEN 'Partly Booked'
		WHEN aid.InquiryStatus = 700 THEN 'Partly Booked'
		WHEN aid.InquiryStatus = 800 THEN 'Booked'
		WHEN aid.InquiryStatus = 900 THEN 'Partly Delivered'
		WHEN aid.InquiryStatus = 1000 THEN 'Delivered'
		WHEN aid.InquiryStatus = 1500 THEN 'Lost Stem'
		WHEN aid.InquiryStatus = 9000 THEN 'Cancelled Stem'
		WHEN aid.InquiryStatus = 10000 THEN 'Invoiced'
		WHEN aid.InquiryStatus = 15000 THEN 'Closed'
	END AS 'Job Status',
	CONVERT(DATE, COALESCE(ain.StemDate, ain.BookedOn)) AS 'Stem Date',
	CONVERT(DATE, ad.DeliveryDate) AS 'Delivery Date',
	CASE WHEN aifd.IsCancelled = 1 THEN NULL
	ELSE aim.Margin 
	END AS 'Margin per MT',
	acur.Code AS 'Buying Currency',
        ROW_NUMBER() OVER (PARTITION BY aifd.Id, aifd.Description, ais.InvoiceType ORDER BY ais.InvoiceNumber) AS RowNum
    FROM 
        AppInquiryFuelDetails aifd
    JOIN 
        AppInvoiceSellers ais 
        ON ais.InquiryFuelDetailId = aifd.Id 
        AND ais.IsDeleted = 0 
        AND ais.InvoiceType <> 0
		and ais.InvoiceStatus NOT IN (0,10,20)
	LEFT JOIN AppDeliveries ad ON ad.InquiryFuelDetailId = aifd.id and ad.IsDeleted = 0
	JOIN AppInquirySellerDetails aisd ON aisd.InquiryFuelDetailId = aifd.id and aisd.SellerId = aifd.SellerId and aisd.IsDeleted = 0
	JOIN AppInquiryNominations ain ON ain.InquirySellerDetailId = aisd.Id and ain.InquiryDetailId = aifd.InquiryDetailId and ain.IsDeleted = 0
	JOIN AppInquiryDetails aid ON aid.Id = aifd.InquiryDetailId and aid.isDeleted = 0
	LEFT JOIN AppFuels af ON af.id = aifd.FuelId and af.IsDeleted = 0
	LEFT JOIN AppGradeGroups agg ON agg.Id = af.GradeGroupId and agg.IsDeleted = 0
	LEFT JOIN AppSellers asel ON asel.Id = aifd.SellerId and asel.IsDeleted = 0
	LEFT JOIN AppSellers asell ON asell.Id = ais.SellerId and asell.IsDeleted = 0
	LEFT JOIN AppSellers aselll ON aselll.Id = ais.CounterpartyName and aselll.IsDeleted = 0
	LEFT JOIN AppBrokers abro ON abro.Id = ais.CounterpartyName and abro.IsDeleted = 0
	LEFT JOIN AppSurveyors asur ON asur.Id = ais.CounterpartyName and asur.IsDeleted = 0
	LEFT JOIN AppAgents agen ON agen.Id = ais.CounterpartyName and agen.IsDeleted = 0
	LEFT JOIN AppSuppliers asup ON asup.Id = ais.CounterpartyName and asup.IsDeleted = 0
	LEFT JOIN AppSuppliers asupp ON asupp.Id = ais.SupplierId and asupp.IsDeleted = 0
	LEFT JOIN AppSuppliers asuppp ON asuppp.Id = aisd.SupplierId and asuppp.IsDeleted = 0
	LEFT JOIN AppVessel av ON av.Id = aid.VesselNominationId and av.IsDeleted = 0
	LEFT JOIN AppPorts ap ON ap.Id = aid.PortNominationId and ap.IsDeleted = 0
	LEFT JOIN AppUserProfiles aup ON aup.Id = aid.UserProfileId and aup.IsDeleted = 0
	LEFT JOIN AppCustomers ac ON ac.Id = aid.CustomerNominationId and ac.IsDeleted = 0
	LEFT JOIN AppCustomerGroups acg ON acg.id = ac.CustomerGroupId and acg.IsDeleted = 0
	LEFT JOIN AppInquiryMargins aim On aim.InquiryDetailId = aifd.InquiryDetailId and aim.InquirySellerDetailId = aisd.Id and aim.IsDeleted = 0
	LEFT JOIN AppInquiryOffers aio ON aio.InquiryDetailId = aifd.InquiryDetailId and aio.SellerId = aifd.SellerId and aio.IsDeleted = 0
	LEFT JOIN AppCurrencies acur ON acur.Id = aio.CurrencyId and acur.IsDeleted = 0
	LEFT JOIN PaymentPerformance pp ON pp.CustomerNominationId = aid.CustomerNominationId
    WHERE 
        aifd.IsDeleted = 0 
        AND aifd.isLosted = 0
), CnAndDnInvoices AS (
SELECT 
    ci.[Job Code] AS 'Job Code',
    ci.Id AS InquiryFuelDetailId,
    ci.Description AS Fuel,
	ci.[Trade Type],
	ci.Seller,
	ci.Supplier,
	ci.InvoiceType,
	ci.Vessel,
	ci.Port,
	ci.Trader,
	ci.UserId,
	ci.UserEmail,
	ci.Buyer,
	ci.[Payment performance],
	ci.[Customer In Out],
	ci.[Job Status],
	ci.[Stem Date],
	ci.[Delivery Date],
	ci.[Margin per MT],
    ci.[Qty in MT] AS Qty,
    ci.CustomerInvoiceNumber AS 'Customer Invoice Number',
    ci.[Customer Invoice Amount],
	NULL AS 'Seller Invoice Number',
    NULL AS [Seller Invoice Amount],
    ci.[Amount Received],
	NULL AS [Amount Paid],
	NULL AS [Payment Status],
    ci.[Receipt Status],
	NULL AS [Buying Price],
	NULL AS [Buying Currency],
    ci.[Selling Price],
	ci.[Selling Currency]
    
FROM 
    CustomerInvoices ci

UNION ALL

SELECT 
    si.[Job Code] AS 'Job Code',
    si.Id AS InquiryFuelDetailId,
    si.Description AS Fuel,
	si.[Trade Type],
	si.Seller,
	si.Supplier,
	si.InvoiceType,
	si.Vessel,
	si.Port,
	si.Trader,
	si.UserId,
	si.UserEmail,
	si.Buyer,
	si.[Payment performance],
	si.[Customer In Out],
	si.[Job Status],
	si.[Stem Date],
	si.[Delivery Date],
	si.[Margin per MT],
    si.[Qty in MT] AS Qty,
    NULL AS 'Customer Invoice Number',
    NULL AS [Customer Invoice Amount],
	si.SellerInvoiceNumber AS 'Seller Invoice Number',
    si.[Seller Invoice Amount],
    NULL AS [Amount Received],
	si.[Amount Paid],
	si.[Payment Status],
    NULL AS [Receipt Status],
    si.[Buying Price],
	si.[Buying Currency],
    NULL AS [Selling Price],
	NULL AS [Selling Currency]
   
FROM 
    SellerInvoices si
),UNIONALL AS (
Select * from MainAndBookedInvoices
UNION ALL
Select * from CnAndDnInvoices
)
,
SellingCurrencyCTE AS (
Select 
	uq.[Job Code],
	STRING_AGG(uq.[Selling Currency], ',') AS 'Selling Currency'
from (
Select DISTINCT
[Job Code],
[Selling Currency]
from UNIONALL) uq
GROUP BY uq.[Job Code]
)
,
BuyingCurrencyCTE AS (
Select 
	uq.[Job Code],
	STRING_AGG(uq.[Buying Currency], ',') AS 'Buying Currency'
from (
Select DISTINCT
[Job Code],
[Buying Currency]
from UNIONALL
) uq
GROUP BY uq.[Job Code]
),
ExampleCTE AS (
Select 
	uq.[Job Code],
	Vessel,
	Port,
	Trader,
	UserId,
	UserEmail,
	Buyer,
	[Payment performance],
	[Customer In Out],
	[Job Status],
	ROUND(SUM([Margin per MT] * (CASE WHEN [Invoice Type] = 'Invoice' OR [Job Status] IN ('Booked', 'Partly Booked', 'Cancelled Stem') THEN Qty ELSE NULL END)) / SUM(CASE WHEN [Invoice Type] = 'Invoice' OR [Job Status] IN ('Booked', 'Partly Booked', 'Cancelled Stem') THEN Qty ELSE NULL END),2) AS 'Margin per MT',
	ROUND(SUM([Buying Price] * Qty) / SUM(CASE WHEN [Invoice Type] = 'Invoice' OR [Job Status] IN ('Booked', 'Partly Booked', 'Cancelled Stem') THEN Qty ELSE NULL END),2) AS 'Buying Price',
	ROUND(SUM([Selling Price] * Qty) / SUM(CASE WHEN [Invoice Type] = 'Invoice' OR [Job Status] IN ('Booked', 'Partly Booked', 'Cancelled Stem') THEN Qty ELSE NULL END),2) AS 'Selling Price',
	SUM(CASE WHEN [Invoice Type] = 'Invoice' OR [Job Status] IN ('Booked', 'Partly Booked', 'Cancelled Stem') THEN Qty ELSE NULL END) AS 'Qty',
	MIN([Stem Date]) AS 'Stem Date',
	MIN([Delivery Date]) AS 'Delivery Date',
	SUM([Customer Invoice Amount]) AS CustomerAmount,
	--CASE 
	--	WHEN [Job Status] IN ('Booked', 'Partly Booked')  THEN ROUND( ROUND(SUM([Selling Price] * Qty) / SUM(CASE WHEN [Invoice Type] = 'Invoice' OR [Job Status] IN ('Booked', 'Partly Booked', 'Cancelled Stem') THEN Qty ELSE NULL END),2) * SUM(CASE WHEN [Invoice Type] = 'Invoice' OR [Job Status] IN ('Booked', 'Partly Booked', 'Cancelled Stem') THEN Qty ELSE NULL END), 2)
	--	ELSE ROUND(SUM([Customer Invoice Amount]),2)
	--END AS 'Customer Invoice Amount',
	ROUND(SUM([Customer Invoice Amount]),2) AS 'Customer Invoice Amount',
	--CASE 
	--	WHEN [Job Status] IN ('Booked', 'Partly Booked')  THEN ROUND( ROUND(SUM([Buying Price] * Qty) / SUM(CASE WHEN [Invoice Type] = 'Invoice' OR [Job Status] IN ('Booked', 'Partly Booked', 'Cancelled Stem') THEN Qty ELSE NULL END),2) * SUM(CASE WHEN [Invoice Type] = 'Invoice' OR [Job Status] IN ('Booked', 'Partly Booked', 'Cancelled Stem') THEN Qty ELSE NULL END), 2)
	--	ELSE ROUND(SUM([Seller Invoice Amount]),2)
	--END AS 'Seller Invoice Amount',
	ROUND(SUM([Seller Invoice Amount]),2) AS 'Seller Invoice Amount',
	ROUND(SUM([Amount Received]), 2) AS 'Amount Received',
	ROUND(SUM([Amount Paid]), 2) AS 'Amount Paid',
	CASE 
		WHEN (SUM([Amount Received]) = SUM([Customer Invoice Amount]) OR SUM([Amount Received]) > SUM([Customer Invoice Amount])) THEN 'Received'
		WHEN SUM([Amount Received]) > 0 THEN 'Partly Received'
		ELSE 'Not Received'
	END AS 'Receipt Status',
	CASE 
		WHEN (SUM([Amount Paid]) = SUM([Seller Invoice Amount]) OR SUM([Amount Paid]) > SUM([Seller Invoice Amount])) THEN 'Paid'
		WHEN SUM([Amount Paid]) > 0 THEN 'Partly Paid'
		ELSE 'Not Paid'
	END AS 'Payment Status',
	--CASE
 --       WHEN COUNT(DISTINCT [Buying Currency]) = 1 THEN MAX([Buying Currency])
 --       ELSE STUFF((
 --           SELECT DISTINCT ', ' + [Buying Currency]
 --           FROM UNIONALL AS t2
 --           WHERE t2.[Job Code] = UNIONALL.[Job Code]
 --           FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 2, '')
 --   END AS 'Buying Currency',
	--CASE
 --       WHEN COUNT(DISTINCT [Selling Currency]) = 1 THEN MAX([Selling Currency])
 --       ELSE STUFF((
 --           SELECT DISTINCT ', ' + [Selling Currency]
 --           FROM UNIONALL AS t2
 --           WHERE t2.[Job Code] = UNIONALL.[Job Code]
 --           FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 2, '')
 --   END AS 'Selling Currency',
	sc.[Selling Currency],
	bc.[Buying Currency],
	CASE
        WHEN COUNT(DISTINCT [Trade Type]) = 1 THEN MAX([Trade Type])
        ELSE STRING_AGG([Trade Type], ', ') WITHIN GROUP (ORDER BY [Trade Type])
    END AS 'Trade Type'
	
from UNIONALL uq
LEFT JOIN SellingCurrencyCTE sc ON sc.[Job Code] = uq.[Job Code]
LEFT JOIN BuyingCurrencyCTE bc ON bc.[Job Code] = uq.[Job Code]


--where [Job Code] = 'G2952'
GROUP BY uq.[Job Code],
	Vessel,
	Port,
	Trader,
	UserId,
	UserEmail,
	Buyer,
	[Payment performance],
	[Customer In Out],
	[Job Status],
	sc.[Selling Currency],
	bc.[Buying Currency]
)
Select 
	[Job Code],
	Vessel,
	Port,
	Trader,
	UserId,
	UserEmail,
	Buyer,
	[Payment performance],
	[Customer In Out],
	[Job Status],
	CASE 
		WHEN [Job Status] = 'Cancelled Stem' THEN NULL 
		ELSE [Margin per MT] 
	END AS 'Margin per MT',
	CASE 
		WHEN [Job Status] = 'Cancelled Stem' THEN NULL 
		ELSE ROUND([Customer Invoice Amount] / Qty, 2) 
	END AS 'Selling Price',
	CASE 
		WHEN [Job Status] = 'Cancelled Stem' THEN NULL 
		ELSE ROUND([Seller Invoice Amount] / Qty, 2) 
	END AS 'Buying Price',
	CASE WHEN [Job Status] = 'Cancelled Stem' THEN NULL 
	ELSE Qty END AS 'Qty',
	[Stem Date],
	[Delivery Date],
	[Customer Invoice Amount],
	[Seller Invoice Amount],
	[Amount Received],
	[Amount Paid],
	[Receipt Status],
	[Payment Status],
	[Buying Currency],
	[Selling Currency],
	[Trade Type]


from ExampleCTE --where [Job Code] = 'G5835'