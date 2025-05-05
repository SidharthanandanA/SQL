/*
Management Seperated
1. Updated to have 3.6725 as the exchange rate when currency is AED
2. Total Brokerage added.
3. Cargo Deals Updated


Last Modified On : 09-04-2025 02:00AM
Last Modifier : Sidharth A
*/
WITH AdditionalCostCustomerCTE AS (
SELECT 
    SUM(AmountUsd * BdnBillingQuantity) AS AmtxBDN,
	SUM(Amount * BdnBillingQuantity) AS AmtNonxBDN,
    SUM(BdnBillingQuantity) AS TotalBDN,
	(SUM(AmountUsd * BdnBillingQuantity) / 
     SUM(SUM(BdnBillingQuantity)) OVER (PARTITION BY aic.InquiryDetailId)) AS AdditionalCost,
	 (SUM(Amount * BdnBillingQuantity) / 
     SUM(SUM(BdnBillingQuantity)) OVER (PARTITION BY aic.InquiryDetailId)) AS AdditionalNonCost,
    aic.InquiryDetailId,
    aic.InquiryFuelDetailId
FROM AppInvoiceCustomers aic
LEFT JOIN AppInvoiceAdditionalCosts aiac 
    ON aic.InquiryDetailId = aiac.InquiryDetailId AND aiac.IsDeleted = 0

	WHERE InvoiceCustomerId IS NOT NULL AND InvoiceCustomerId IN (Select id from Appinvoicecustomers where InvoiceType = 0)
GROUP BY aic.InquiryDetailId, aic.InquiryFuelDetailId
),
TestCustomerCTE AS (
SELECT 
    Id,
    InquiryDetailId,
    InquiryFuelDetailId,
    ISNULL(Discount, 
        (SELECT TOP 1 ISNULL(Discount, 0)
         FROM AppInvoiceCustomers AS sub
         WHERE sub.InquiryDetailId = aic.InquiryDetailId 
           AND sub.IsDeleted = 0 
           AND sub.InvoiceType = 0 
           AND sub.Discount IS NOT NULL
         ORDER BY sub.Id)) AS Discount
FROM AppInvoiceCustomers aic
WHERE IsDeleted = 0 AND InvoiceType = 0
),
PrepaymentDiscountCustomer AS (
SELECT 
    SUM(tcte.Discount * BdnBillingQuantity) AS DisxBDN,
    SUM(BdnBillingQuantity) AS TotalBDN,
	 (SUM(tcte.Discount * BdnBillingQuantity) / 
     SUM(SUM(BdnBillingQuantity)) OVER (PARTITION BY aic.InquiryDetailId)) AS PrepaymentDiscount,
    aic.InquiryDetailId,
    aic.InquiryFuelDetailId
FROM AppInvoiceCustomers aic
LEFT JOIN TestCustomerCTE tcte ON tcte.Id = aic.Id
WHERE aic.InvoiceType = 0 and aic.IsDeleted = 0 --and aic.InquiryDetailId IN (Select id from AppInquiryDetails where code = 'G2969')
GROUP BY aic.InquiryDetailId, aic.InquiryFuelDetailId
),
AdditionalCostSellerCTE AS (
SELECT 
    SUM(AmountUsd * BdnBillingQuantity) AS AmtxBDN,
	SUM(Amount * BdnBillingQuantity) AS AmtNonxBDN,
    SUM(BdnBillingQuantity) AS TotalBDN,
	(SUM(AmountUsd * BdnBillingQuantity) / 
     SUM(SUM(BdnBillingQuantity)) OVER (PARTITION BY ais.InquiryDetailId)) AS AdditionalCost,
	 (SUM(Amount * BdnBillingQuantity) / 
     SUM(SUM(BdnBillingQuantity)) OVER (PARTITION BY ais.InquiryDetailId)) AS AdditionalNonCost,
    ais.InquiryDetailId,
    ais.InquiryFuelDetailId
FROM AppInvoiceSellers ais
LEFT JOIN AppInvoiceAdditionalCosts aiac 
    ON ais.InquiryDetailId = aiac.InquiryDetailId AND aiac.IsDeleted = 0

	WHERE InvoiceSellerId IS NOT NULL AND InvoiceSellerId IN (Select id from AppInvoiceSellers where InvoiceType = 0)
GROUP BY ais.InquiryDetailId, ais.InquiryFuelDetailId
),
MiscCostSeller AS (
Select 
	
	InquiryDetailId,
	InquirySellerDetailId,
	SUM(AmountUsd) AS TotalMiscCost,
	SUM(Amount) AS TotalNonMiscCost

from AppInquiryMiscCosts
WHERE ToSeller = 1 and IsDeleted = 0
GROUP BY InquiryDetailId, InquirySellerDetailId
),
MiscCostCustomer AS (
Select 
	
	InquiryDetailId,
	InquirySellerDetailId,
	SUM(AmountUsd) AS TotalMiscCost,
	SUM(Amount) AS TotalNonMiscCost 

from AppInquiryMiscCosts
WHERE FromBuyer = 1 and IsDeleted = 0
GROUP BY InquiryDetailId, InquirySellerDetailId
),
VatCustomer AS (
SELECT 
    Id,
    InquiryDetailId,
    InquiryFuelDetailId,
	CASE 
		WHEN VatAmount is not null and VatAmount != 0 THEN VatAmount
		ELSE
        (SELECT TOP 1 ISNULL(VatAmount, 0)
         FROM AppInvoiceCustomers AS sub
         WHERE sub.InquiryDetailId = aic.InquiryDetailId 
           AND sub.IsDeleted = 0 
           AND sub.InvoiceType = 0 
           AND sub.VatAmount IS NOT NULL
		   AND sub.HasVat = 1
         ORDER BY sub.Id)
	end AS VatAmount
FROM AppInvoiceCustomers aic
WHERE IsDeleted = 0 AND InvoiceType = 0 and MergeCode is not null AND HasVat = 1--and InquiryDetailId = '4A7DCC8D-F4AB-0876-32F4-3A185D35E261'
),
VATAmountCustomer AS (
SELECT 
    SUM(tcte.VatAmount * BdnBillingQuantity) AS VatxBDN,
    SUM(BdnBillingQuantity) AS TotalBDN,
	 (SUM(tcte.VatAmount * BdnBillingQuantity) / 
     SUM(SUM(BdnBillingQuantity)) OVER (PARTITION BY aic.InquiryDetailId)) AS VatAmount,
    aic.InquiryDetailId,
    aic.InquiryFuelDetailId
FROM AppInvoiceCustomers aic
LEFT JOIN VatCustomer tcte ON tcte.Id = aic.Id
WHERE aic.InvoiceType = 0 and aic.IsDeleted = 0 and aic.MergeCode is not null--and aic.InquiryDetailId = '4A7DCC8D-F4AB-0876-32F4-3A185D35E261'
GROUP BY aic.InquiryDetailId, aic.InquiryFuelDetailId
),
TestCustomer3CTE AS (
SELECT DISTINCT
	aid.Id,
	aifd.Id AS 'InquiryFuelDetailId',
	aic.InvoiceCode AS 'Customer Invoice Number',
	--ROUND(aic.SubTotal * aim.ExchangeRate, 2) AS 'Customer Invoice Amount',
	CASE 
		WHEN aid.InquiryStatus IN (700,800) THEN ROUND((ain.QuantityMax * aim.SellPrice) + ISNULL(mcc.TotalNonMiscCost, 0), 2)
		ELSE ROUND(ISNULL(((aic.SellPrice) * aic.BdnBillingQuantity),0) + ISNULL(aic.BuyerGradeMiscCost, 0) + ISNULL(acc.AdditionalNonCost, 0) - ISNULL(pdc.PrepaymentDiscount, 0), 2)
	END AS 'Customer Invoice Amount',
	CASE 
		WHEN aid.InquiryStatus IN (700,800) THEN ROUND((ain.QuantityMax * aim.SellPrice) + ISNULL(mcc.TotalNonMiscCost, 0), 2)
		ELSE ROUND(ISNULL(((aic.SellPrice) * aic.BdnBillingQuantity),0) + ISNULL(aic.BuyerGradeMiscCost, 0) + ISNULL(acc.AdditionalNonCost, 0) - ISNULL(pdc.PrepaymentDiscount, 0) + ISNULL(vc.VatAmount, 0), 2)
	END AS 'Customer Invoice Total Amount',
	ROUND(aic.AmountReceivedSoFar, 2) AS 'Amount Received',
	ROUND(COALESCE(aic.SellPrice, aim.SellPrice),2) AS 'Selling Price',
	sc.Code AS 'Selling Currency',
	aic.MergeCode,
	aic.VatAmount


FROM AppInquiryDetails aid
JOIN AppInquiryFuelDetails aifd On aifd.InquiryDetailId = aid.id and aifd.IsDeleted = 0 and aifd.isLosted = 0
LEFT JOIN AppSellers asel ON asel.Id = aifd.SellerId and asel.IsDeleted = 0
LEFT JOIN AppInquirySellerDetails aisd ON aisd.InquiryFuelDetailId = aifd.Id and aisd.SellerId = aifd.SellerId and aisd.IsDeleted = 0
LEFT JOIN AppSuppliers asup ON asup.Id = aisd.SupplierId and asup.IsDeleted = 0
LEFT JOIN AppVessel av ON av.Id = aid.VesselNominationId and av.IsDeleted = 0
LEFT JOIN AppPorts ap ON ap.Id = aid.PortNominationId and ap.IsDeleted = 0
LEFT JOIN AppUserProfiles aup ON aup.Id = aid.UserProfileId and aup.IsDeleted = 0
LEFT JOIN AppCustomers acus ON acus.Id = aid.CustomerNominationId and acus.IsDeleted = 0
LEFT JOIN AppCustomerGroups acg ON acg.id = acus.CustomerGroupId and acg.IsDeleted = 0
LEFT JOIN AppInquiryNominations ain ON ain.InquirySellerDetailId = aisd.Id and ain.IsDeleted = 0 and ain.InquiryDetailId = aifd.InquiryDetailId
LEFT JOIN AppDeliveries ad ON ad.InquiryFuelDetailId = aifd.Id and ad.IsDeleted = 0
LEFT JOIN AppInquiryMargins aim ON aim.InquirySellerDetailId = aisd.Id and aim.InquiryDetailId = aifd.InquiryDetailId and aim.IsDeleted = 0
LEFT JOIN AppInquiryOffers aio ON aio.InquiryDetailId = aifd.InquiryDetailId and aio.SellerId = aifd.SellerId and aio.IsDeleted = 0
LEFT JOIN AppFuels af ON af.id = aifd.FuelId and af.IsDeleted = 0
LEFT JOIN AppGradeGroups agg ON agg.Id = af.GradeGroupId and agg.IsDeleted = 0
LEFT JOIN AppInvoiceCustomers aic ON aic.InquiryFuelDetailId = aifd.Id and aic.IsDeleted = 0 and aic.InvoiceType = 0
LEFT JOIN AppCurrencies sc ON sc.Id = aim.CurrencyId and sc.IsDeleted = 0
LEFT JOIN AppInvoiceSellers ais ON ais.InquiryFuelDetailId = aifd.Id and ais.IsDeleted = 0 and ais.InvoiceType = 0
LEFT JOIN AppCurrencies bc ON bc.Id = aio.CurrencyId and bc.IsDeleted = 0
LEFT JOIN AppInvoiceAdditionalCosts aiac ON aiac.InvoiceCustomerId = aic.Id and aiac.IsDeleted = 0
LEFT JOIN AdditionalCostCustomerCTE acc ON acc.InquiryFuelDetailId = aic.InquiryFuelDetailId
LEFT JOIN AdditionalCostSellerCTE acs ON acs.InquiryFuelDetailId = ais.InquiryFuelDetailId
LEFT JOIN AppInquiryCancelStems aics ON aics.InquiryFuelDetailId = aifd.Id and aics.IsDeleted = 0
LEFT JOIN MiscCostSeller mcs ON mcs.InquirySellerDetailId = aisd.Id 
LEFT JOIN MiscCostCustomer mcc ON mcc.InquirySellerDetailId = aisd.Id 
LEFT JOIN PrepaymentDiscountCustomer pdc ON pdc.InquiryFuelDetailId = aic.InquiryFuelDetailId
LEFT JOIN VATAmountCustomer vc ON vc.InquiryFuelDetailId = aic.InquiryFuelDetailId

WHERE aid.InquiryStatus IN (650,700,800,900,1000,9000) and aic.MergeCode is not null and sc.Name is not null
)
,
AmountRecivedSoFar1CTE AS (
SELECT 
    tcte.Id,
    tcte.Id AS 'InquiryDetailId',
    tcte.InquiryFuelDetailId,
	tcte.[Customer Invoice Total Amount],
	tcte.[Customer Invoice Amount],
	BdnBillingQuantity,
	tcte.MergeCode,
	AmountReceivedSoFar
	--CASE 
	--	WHEN AmountReceivedSoFar is not null and AmountReceivedSoFar != 0 THEN AmountReceivedSoFar
	--	ELSE
 --       (SELECT TOP 1 ISNULL(AmountReceivedSoFar, 0)
 --        FROM AppInvoiceCustomers AS sub
 --        WHERE sub.InquiryDetailId = aic.InquiryDetailId 
 --          AND sub.IsDeleted = 0 
 --          AND sub.InvoiceType = 0 
 --          AND sub.AmountReceivedSoFar IS NOT NULL
 --        ORDER BY sub.Id)
	--end AS AmountReceivedSoFar
FROM AppInvoiceCustomers aic
JOIN TestCustomer3CTE tcte ON tcte.InquiryFuelDetailId = aic.InquiryFuelDetailId
WHERE IsDeleted = 0 AND InvoiceType = 0 and aic.MergeCode is not null--and InquiryDetailId = '4A7DCC8D-F4AB-0876-32F4-3A185D35E261'
)
,
TotalAmountCTE AS (
Select 
	InquiryDetailId,
	SUM(TotalAmount) as 'TotalAmountAdjusted',
	SUM(SubTotal) as 'SubTotalAdjusted'
from AppInvoiceCustomers aic
WHERE aic.IsDeleted = 0 and aic.InvoiceType = 0 and TotalAmount != 0 AND MergeCode is not null  --AND InquiryDetailId = '4A7DCC8D-F4AB-0876-32F4-3A185D35E261'
GROUP BY aic.InquiryDetailId
),
WeightsCTE AS (
Select 
	Id,
	InquiryFuelDetailId,
	[Customer Invoice Amount] / tcte.SubTotalAdjusted AS 'Weight'
from TestCustomer3CTE tc
JOIN TotalAmountCTE tcte ON tcte.InquiryDetailId = tc.Id
)
,
AdjustedAmountReceivedSoFarCTE AS (
Select 
	InquiryDetailId,
	SUM(AmountReceivedSoFar) * (ISNULL(SUM([Customer Invoice Total Amount]),0) - ISNULL(SUM([Customer Invoice Amount]),0)) / SUM([Customer Invoice Total Amount]) AS 'AdjustedAmountReceived'
	
from AmountRecivedSoFar1CTE
where MergeCode is not null
GROUP BY InquiryDetailId 
)
,
AmountRecivedSoFar2CTE AS (
SELECT 
    tcte.Id,
    tcte.Id AS 'InquiryDetailId',
    tcte.InquiryFuelDetailId,
	tcte.[Customer Invoice Total Amount],
	tcte.[Customer Invoice Amount],
	BdnBillingQuantity,
	tcte.MergeCode,
	aar.AdjustedAmountReceived
FROM AppInvoiceCustomers aic
JOIN TestCustomer3CTE tcte ON tcte.InquiryFuelDetailId = aic.InquiryFuelDetailId and tcte.MergeCode is not null
LEFT JOIN AdjustedAmountReceivedSoFarCTE aar ON aar.InquiryDetailId = aic.InquiryDetailId
WHERE IsDeleted = 0 AND InvoiceType = 0 --and InquiryDetailId = '4A7DCC8D-F4AB-0876-32F4-3A185D35E261'
), 
AmountRecivedSoFar3CTE AS (
SELECT 
    tcte.Id,
    tcte.Id AS 'InquiryDetailId',
    tcte.InquiryFuelDetailId,
	tcte.[Customer Invoice Total Amount],
	tcte.[Customer Invoice Amount],
	BdnBillingQuantity,
	CASE 
		WHEN AmountReceivedSoFar is not null and AmountReceivedSoFar != 0 THEN AmountReceivedSoFar
		ELSE
        (SELECT TOP 1 ISNULL(AmountReceivedSoFar, 0)
         FROM AppInvoiceCustomers AS sub
         WHERE sub.InquiryDetailId = aic.InquiryDetailId 
           AND sub.IsDeleted = 0 
           AND sub.InvoiceType = 0 
		   AND sub.Mergecode = aic.MergeCode
           AND sub.AmountReceivedSoFar IS NOT NULL
         ORDER BY sub.Id)
	end AS AmountReceivedSoFar
FROM AppInvoiceCustomers aic
JOIN TestCustomer3CTE tcte ON tcte.InquiryFuelDetailId = aic.InquiryFuelDetailId
WHERE IsDeleted = 0 AND InvoiceType = 0 and aic.MergeCode is not null--and InquiryDetailId = '4A7DCC8D-F4AB-0876-32F4-3A185D35E261'
) --select * from AmountRecivedSoFar3CTE
,
AmountReceivedSoFARCTE AS (
Select 
	a2.InquiryFuelDetailId,
	(ISNULL(ar3.AmountReceivedSoFar,0) * wc.Weight) - (AdjustedAmountReceived * wc.[Weight]) AS 'AmountReceivedReal'
from AmountRecivedSoFar2CTE a2
LEFT JOIN WeightsCTE wc ON wc.InquiryFuelDetailId = a2.InquiryFuelDetailId
LEFT JOIN AmountRecivedSoFar3CTE ar3 ON ar3.InquiryFuelDetailId = a2.InquiryFuelDetailId
WHERE a2.MergeCode is not null
),
VatCustomer2 AS (
SELECT 
    Id,
    InquiryDetailId,
    InquiryFuelDetailId,
	CASE 
		WHEN VatAmount is not null and VatAmount != 0 THEN VatAmount
		ELSE
        (SELECT TOP 1 ISNULL(VatAmount, 0)
         FROM AppInvoiceCustomers AS sub
         WHERE sub.InquiryDetailId = aic.InquiryDetailId 
           AND sub.IsDeleted = 0 
           AND sub.InvoiceType = 0 
           AND sub.VatAmount IS NOT NULL
         ORDER BY sub.Id)
	end AS VatAmount
FROM AppInvoiceCustomers aic
WHERE IsDeleted = 0 AND InvoiceType = 0 and MergeCode is null--and InquiryDetailId = '4A7DCC8D-F4AB-0876-32F4-3A185D35E261'
) --Select * from VatCustomer where InquiryDetailId IN (Select id from AppInquiryDetails where Code = 'G3000')
,
VATAmountCustomer2 AS (
SELECT 
    SUM(tcte.VatAmount * BdnBillingQuantity) AS VatxBDN,
    SUM(BdnBillingQuantity) AS TotalBDN,
	 (SUM(tcte.VatAmount * BdnBillingQuantity) / 
     SUM(SUM(BdnBillingQuantity)) OVER (PARTITION BY aic.InquiryDetailId)) AS VatAmount,
    aic.InquiryDetailId,
    aic.InquiryFuelDetailId
FROM AppInvoiceCustomers aic
LEFT JOIN VatCustomer2 tcte ON tcte.Id = aic.Id
WHERE aic.InvoiceType = 0 and aic.IsDeleted = 0 and aic.MergeCode is null  --and aic.InquiryDetailId = '4A7DCC8D-F4AB-0876-32F4-3A185D35E261'
GROUP BY aic.InquiryDetailId, aic.InquiryFuelDetailId
)
,
TestCustomer4CTE AS (
SELECT DISTINCT
	aid.Id,
	aifd.Id AS 'InquiryFuelDetailId',
	aic.InvoiceCode AS 'Customer Invoice Number',
	--ROUND(aic.SubTotal * aim.ExchangeRate, 2) AS 'Customer Invoice Amount',
	CASE 
		WHEN aid.InquiryStatus IN (700,800) THEN ROUND((ain.QuantityMax * aim.SellPrice) + ISNULL(mcc.TotalNonMiscCost, 0), 2)
		ELSE ROUND(ISNULL(((aic.SellPrice) * aic.BdnBillingQuantity),0) + ISNULL(aic.BuyerGradeMiscCost, 0) + ISNULL(acc.AdditionalNonCost, 0) - ISNULL(pdc.PrepaymentDiscount, 0), 2)
	END AS 'Customer Invoice Amount',
	CASE 
		WHEN aid.InquiryStatus IN (700,800) THEN ROUND((ain.QuantityMax * aim.SellPrice) + ISNULL(mcc.TotalNonMiscCost, 0), 2)
		ELSE ROUND(ISNULL(((aic.SellPrice) * aic.BdnBillingQuantity),0) + ISNULL(aic.BuyerGradeMiscCost, 0) + ISNULL(acc.AdditionalNonCost, 0) - ISNULL(pdc.PrepaymentDiscount, 0) + ISNULL(COALESCE(vc.VatAmount, vc.VatAmount), 0), 2)
	END AS 'Customer Invoice Total Amount',
	ROUND(COALESCE(aic.SellPrice, aim.SellPrice),2) AS 'Selling Price',
	sc.Code AS 'Selling Currency',
	aic.MergeCode,
	aic.VatAmount,
	aic.VatPercentage,
	aic.TotalAmount,
	vc.VatAmount AS 'Real Vat'


FROM AppInquiryDetails aid
JOIN AppInquiryFuelDetails aifd On aifd.InquiryDetailId = aid.id and aifd.IsDeleted = 0 and aifd.isLosted = 0
LEFT JOIN AppSellers asel ON asel.Id = aifd.SellerId and asel.IsDeleted = 0
LEFT JOIN AppInquirySellerDetails aisd ON aisd.InquiryFuelDetailId = aifd.Id and aisd.SellerId = aifd.SellerId and aisd.IsDeleted = 0
LEFT JOIN AppSuppliers asup ON asup.Id = aisd.SupplierId and asup.IsDeleted = 0
LEFT JOIN AppVessel av ON av.Id = aid.VesselNominationId and av.IsDeleted = 0
LEFT JOIN AppPorts ap ON ap.Id = aid.PortNominationId and ap.IsDeleted = 0
LEFT JOIN AppUserProfiles aup ON aup.Id = aid.UserProfileId and aup.IsDeleted = 0
LEFT JOIN AppCustomers acus ON acus.Id = aid.CustomerNominationId and acus.IsDeleted = 0
LEFT JOIN AppCustomerGroups acg ON acg.id = acus.CustomerGroupId and acg.IsDeleted = 0
LEFT JOIN AppInquiryNominations ain ON ain.InquirySellerDetailId = aisd.Id and ain.IsDeleted = 0 and ain.InquiryDetailId = aifd.InquiryDetailId
LEFT JOIN AppDeliveries ad ON ad.InquiryFuelDetailId = aifd.Id and ad.IsDeleted = 0
LEFT JOIN AppInquiryMargins aim ON aim.InquirySellerDetailId = aisd.Id and aim.InquiryDetailId = aifd.InquiryDetailId and aim.IsDeleted = 0
LEFT JOIN AppInquiryOffers aio ON aio.InquiryDetailId = aifd.InquiryDetailId and aio.SellerId = aifd.SellerId and aio.IsDeleted = 0
LEFT JOIN AppFuels af ON af.id = aifd.FuelId and af.IsDeleted = 0
LEFT JOIN AppGradeGroups agg ON agg.Id = af.GradeGroupId and agg.IsDeleted = 0
LEFT JOIN AppInvoiceCustomers aic ON aic.InquiryFuelDetailId = aifd.Id and aic.IsDeleted = 0 and aic.InvoiceType = 0
LEFT JOIN AppCurrencies sc ON sc.Id = aim.CurrencyId and sc.IsDeleted = 0
LEFT JOIN AppInvoiceSellers ais ON ais.InquiryFuelDetailId = aifd.Id and ais.IsDeleted = 0 and ais.InvoiceType = 0
LEFT JOIN AppCurrencies bc ON bc.Id = aio.CurrencyId and bc.IsDeleted = 0
LEFT JOIN AppInvoiceAdditionalCosts aiac ON aiac.InvoiceCustomerId = aic.Id and aiac.IsDeleted = 0
LEFT JOIN AdditionalCostCustomerCTE acc ON acc.InquiryFuelDetailId = aic.InquiryFuelDetailId
LEFT JOIN AdditionalCostSellerCTE acs ON acs.InquiryFuelDetailId = ais.InquiryFuelDetailId
LEFT JOIN AppInquiryCancelStems aics ON aics.InquiryFuelDetailId = aifd.Id and aics.IsDeleted = 0
LEFT JOIN MiscCostSeller mcs ON mcs.InquirySellerDetailId = aisd.Id 
LEFT JOIN MiscCostCustomer mcc ON mcc.InquirySellerDetailId = aisd.Id 
LEFT JOIN PrepaymentDiscountCustomer pdc ON pdc.InquiryFuelDetailId = aic.InquiryFuelDetailId
LEFT JOIN VATAmountCustomer2 vc ON vc.InquiryFuelDetailId = aic.InquiryFuelDetailId
WHERE aid.InquiryStatus IN (650,700,800,900,1000,9000) and aic.MergeCode is null and sc.Code is not null
) --Select * from TestCustomer4CTE where id in (Select id from AppInquiryDetails where Code = 'G3001')
,
AmountRecivedSoFar11CTE AS (
SELECT 
    tcte.Id,
    tcte.Id AS 'InquiryDetailId',
    tcte.InquiryFuelDetailId,
	tcte.[Customer Invoice Total Amount],
	tcte.[Customer Invoice Amount],
	tcte.MergeCode,
	BdnBillingQuantity,
	AmountReceivedSoFar
FROM AppInvoiceCustomers aic
JOIN TestCustomer4CTE tcte ON tcte.InquiryFuelDetailId = aic.InquiryFuelDetailId
WHERE IsDeleted = 0 AND InvoiceType = 0 and aic.MergeCode is null--and InquiryDetailId = '4A7DCC8D-F4AB-0876-32F4-3A185D35E261'
) --Select * from AmountRecivedSoFar1CTE where InquiryDetailid in (Select id from AppInquiryDetails where Code = 'G3000')
,
AmountRecivedSoFar33CTE AS (
SELECT 
    tcte.Id,
    tcte.Id AS 'InquiryDetailId',
    tcte.InquiryFuelDetailId,
	tcte.[Customer Invoice Total Amount],
	tcte.[Customer Invoice Amount],
	BdnBillingQuantity,
	CASE 
		WHEN AmountReceivedSoFar is not null and AmountReceivedSoFar != 0 THEN AmountReceivedSoFar
		ELSE
        (SELECT TOP 1 ISNULL(AmountReceivedSoFar, 0)
         FROM AppInvoiceCustomers AS sub
         WHERE sub.InquiryDetailId = aic.InquiryDetailId 
           AND sub.IsDeleted = 0 
           AND sub.InvoiceType = 0 
		   AND sub.Mergecode = aic.MergeCode
           AND sub.AmountReceivedSoFar IS NOT NULL
         ORDER BY sub.Id)
	end AS AmountReceivedSoFar
FROM AppInvoiceCustomers aic
JOIN TestCustomer4CTE tcte ON tcte.InquiryFuelDetailId = aic.InquiryFuelDetailId and tcte.MergeCode is null
WHERE IsDeleted = 0 AND InvoiceType = 0 and aic.MergeCode is null--and InquiryDetailId = '4A7DCC8D-F4AB-0876-32F4-3A185D35E261'
) --Select * from AmountRecivedSoFar3CTE where InquiryDetailid in (Select id from AppInquiryDetails where Code = 'G3000')
,
TotalAmountCTE1 AS (
Select 
	InquiryDetailId,
	SUM(TotalAmount) as 'TotalAmountAdjusted',
	SUM(SubTotal) as 'SubTotalAdjusted'
from AppInvoiceCustomers aic
WHERE aic.IsDeleted = 0 and aic.InvoiceType = 0 and TotalAmount != 0 AND MergeCode is null --AND InquiryDetailId = '4A7DCC8D-F4AB-0876-32F4-3A185D35E261'
GROUP BY aic.InquiryDetailId
) --Select * from TotalAmountCTE where InquiryDetailid in (Select id from AppInquiryDetails where Code = 'G3000')
,
WeightsCTE1 AS (
Select 
	Id,
	InquiryFuelDetailId,
	[Customer Invoice Amount] / tcte.SubTotalAdjusted AS 'Weight'
from TestCustomer4CTE tc
LEFT JOIN TotalAmountCTE1 tcte ON tcte.InquiryDetailId = tc.Id and MergeCode is null
) --Select * from WeightsCTE where Id in (Select id from AppInquiryDetails where Code = 'G3000')
,
AdjustedAmountReceivedSoFarCTE1 AS (
Select 
	InquiryDetailId,
	SUM(AmountReceivedSoFar) AS AmountReceived,
	SUM([Customer Invoice Amount]) AS CustomerInvoiceAmount,
	SUM([Customer Invoice Total Amount]) AS CustomerInvoiceTotalAmount,
	SUM(AmountReceivedSoFar) * (ISNULL(SUM([Customer Invoice Total Amount]),0) - ISNULL(SUM([Customer Invoice Amount]),0)) / SUM([Customer Invoice Total Amount]) AS 'AdjustedAmountReceived'
	
from AmountRecivedSoFar11CTE
where MergeCode is null
GROUP BY InquiryDetailId
) --Select * from TestCustomer3CTE where Id in (Select id from AppInquiryDetails where Code = 'G3000')
,
AmountRecivedSoFar22CTE AS (
SELECT 
    tcte.Id,
    tcte.Id AS 'InquiryDetailId',
    tcte.InquiryFuelDetailId,
	tcte.[Customer Invoice Total Amount],
	tcte.[Customer Invoice Amount],
	BdnBillingQuantity,
	tcte.MergeCode,
	aar.AdjustedAmountReceived
FROM AppInvoiceCustomers aic
LEFT JOIN TestCustomer4CTE tcte ON tcte.InquiryFuelDetailId = aic.InquiryFuelDetailId and tcte.MergeCode is null
LEFT JOIN AdjustedAmountReceivedSoFarCTE1 aar ON aar.InquiryDetailId = aic.InquiryDetailId
WHERE IsDeleted = 0 AND InvoiceType = 0 --and InquiryDetailId = '4A7DCC8D-F4AB-0876-32F4-3A185D35E261'
), 
AmountReceivedSoFARCTE1 AS (
Select 
	a2.InquiryDetailId,
	a2.InquiryFuelDetailId,
	a2.mergeCode,
	ar3.AmountReceivedSoFar,
	AdjustedAmountReceived,
	Weight,
	(ISNULL(ar3.AmountReceivedSoFar,0) * wc.Weight) - (AdjustedAmountReceived * wc.[Weight]) AS 'AmountReceivedReal'
from AmountRecivedSoFar22CTE a2
LEFT JOIN WeightsCTE1 wc ON wc.InquiryFuelDetailId = a2.InquiryFuelDetailId
LEFT JOIN AmountRecivedSoFar33CTE ar3 ON ar3.InquiryFuelDetailId = a2.InquiryFuelDetailId

WHERE a2.MergeCode is null
),
MainAndBookedInvoices AS (
SELECT DISTINCT
	aid.Code AS 'Job Code',
	aifd.Id AS 'InquiryFuelDetailId',
	aifd.Description AS 'Fuel',
	CASE
		WHEN aifd.TradeType = 0 THEN 'Spot'
		WHEN aifd.TradeType = 1 THEN 'Contract'
	END AS 'Trade Type',
	asel.Name AS 'Seller',
	asup.Name AS 'Supplier',
	CASE 
		WHEN aid.InquiryStatus NOT IN (900,1000) THEN NULL
		ELSE 'Invoice'
	END AS 'Invoice Type',
	av.Name AS 'Vessel',
	ap.Name AS 'Port',
	aup.Name AS 'Trader',
	aup.UserId AS 'UserId',
	aup.Email AS 'UserEmail',
	acus.Name AS 'Buyer',
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
	CASE 
		WHEN aics.CancelTypes = 0 THEN 'With Penalty'
		WHEN aics.CancelTypes = 1 THEN 'Without Penalty'
	END AS 'Cancellation Status',
	CONVERT(DATE, COALESCE(ain.StemDate, ain.BookedOn)) AS 'Stem Date',
	CASE 
		WHEN aid.InquiryStatus NOT IN (700,800,9000) THEN CONVERT(DATE, ad.DeliveryDate) 
		WHEN aid.InquiryStatus IN (700,800) THEN CONVERT(DATE, aid.DeliveryStartDateNomination) 
	END AS 'Delivery Date',
	ROUND(aim.Margin, 2) AS 'Margin per MT',
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
	END AS 'Qty',
	aic.InvoiceCode AS 'Customer Invoice Number',
	--ROUND(aic.SubTotal * aim.ExchangeRate, 2) AS 'Customer Invoice Amount',
	CASE 
		WHEN aid.InquiryStatus IN (700,800) THEN ROUND((ain.QuantityMax * aim.SellPrice) + ISNULL(mcc.TotalNonMiscCost, 0), 2)
		--ELSE ROUND(ISNULL(((aic.SellPrice) * aic.BdnBillingQuantity),0) + ISNULL(aic.BuyerGradeMiscCost, 0) + ISNULL(acc.AdditionalNonCost, 0) - ISNULL(pdc.PrepaymentDiscount, 0), 2)
		ELSE ROUND(aic.SubTotal, 2)
	END AS 'Customer Invoice Amount',
	CASE 
		WHEN aid.InquiryStatus IN (700,800) AND sc.Code = 'AED' THEN ROUND((ain.QuantityMax * (aim.SellPrice / 3.6725)) + ISNULL(mcc.TotalMiscCost, 0), 2)
		WHEN aid.InquiryStatus IN (700,800) AND sc.Code <> 'AED' THEN ROUND((ain.QuantityMax * aim.SellPriceUSD) + ISNULL(mcc.TotalMiscCost, 0), 2)
		--ELSE ROUND(ISNULL(((aic.SellPrice) * aic.BdnBillingQuantity),0) + ISNULL(aic.BuyerGradeMiscCost, 0) + ISNULL(acc.AdditionalNonCost, 0) - ISNULL(pdc.PrepaymentDiscount, 0), 2)
		WHEN aid.InquiryStatus NOT IN (700,800) AND sc.Code = 'AED' THEN ROUND(aic.SubTotal / 3.6725, 2)
		ELSE ROUND(aic.SubTotal * aim.ExchangeRate, 2)
	END AS 'Customer Invoice Amount USD',
	ais.InvoiceNumber AS 'Seller Invoice Number',
	--CASE 
	--	WHEN aid.InquiryStatus IN (700,800) THEN (ain.QuantityMax * aim.BuyPriceUsd)
	--	ELSE ROUND(ISNULL(((ais.BuyPrice * aio.ExchangeRate) * ais.BdnBillingQuantity),0) + ISNULL(ais.BuyerGradeMiscCost, 0) + ISNULL(acs.AdditionalCost, 0), 2) 
	--END AS 'Seller Invoice Amount',
	CASE 
		WHEN aid.InquiryStatus IN (700,800) THEN ROUND((aim.BuyPrice * ain.QuantityMax)  + ISNULL(mcs.TotalNonMiscCost, 0),2)
		ELSE ROUND(ais.SubTotal, 2) 
	END AS 'Seller Invoice Amount',
	CASE 
		WHEN aid.InquiryStatus IN (700,800) AND bc.Code = 'AED' THEN ROUND(((aim.BuyPrice / 3.6725) * ain.QuantityMax)  + ISNULL(mcs.TotalMiscCost, 0),2)
		WHEN aid.InquiryStatus IN (700,800) AND bc.Code <> 'AED' THEN ROUND((aim.BuyPriceUsd * ain.QuantityMax)  + ISNULL(mcs.TotalMiscCost, 0),2)
		WHEN aid.InquiryStatus NOT IN (700,800) AND bc.Code = 'AED' THEN ROUND(ais.SubTotal / 3.6725, 2)
		ELSE ROUND(ais.SubTotal * aio.ExchangeRate, 2) 
	END AS 'Seller Invoice Amount USD',
	--ROUND(ISNULL(((ais.BuyPrice * aio.ExchangeRate) * ais.BdnBillingQuantity),0) + ISNULL(ais.SellerGradeMiscCost, 0) + ISNULL(acs.AdditionalCost, 0), 2) AS 'Seller Invoice Amount',
	--ROUND(COALESCE(ars.AmountReceivedReal, arss.AmountReceivedReal, aic.AmountReceivedSoFar),2) AS 'Amount Received',
	ROUND(aic.AmountReceivedSoFar, 2) AS 'Amount Received',
	ROUND(ais.AmountPaidSoFar, 2) AS 'Amount Paid',
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
				WHEN aic.InvoiceType IS NULL THEN 'Not received'
				WHEN aic.ReceivableType = 0 THEN 'Not received'
				WHEN aic.ReceivableType = 1 THEN 'Partly received'
				WHEN aic.ReceivableType = 2 THEN 'Received'
			END
	END AS 'Receipt Status',
	ROUND(COALESCE(ais.BuyPrice, aim.BuyPrice),2) AS 'Buying Price',
	bc.Code AS 'Buying Currency',
	ROUND(COALESCE(aic.SellPrice, aim.SellPrice),2) AS 'Selling Price',
	sc.Code AS 'Selling Currency',
	ISNULL(
    CASE 
        WHEN aibd.SellerUnitLumpsum = 0 AND bc.code = 'AED' THEN ((aibd.SellerBrokerage / 3.6725) * ain.QuantityMax)
		WHEN aibd.SellerUnitLumpsum = 0 AND bc.code <> 'AED' THEN (aibd.SellerBrokerage * aibd.SellerExchangeRate * ain.QuantityMax)
        WHEN aibd.SellerUnitLumpsum = 1 AND bc.code = 'AED' THEN (aibd.SellerBrokerage / 3.6725)
		WHEN aibd.SellerUnitLumpsum = 1 AND bc.code <> 'AED' THEN (aibd.SellerBrokerage * aibd.SellerExchangeRate)
        ELSE 0
    END
	,0) +
	ISNULL(
    CASE 
        WHEN aibd.CustomerUnitLumpsum = 0 AND sc.Code = 'AED' THEN ((aibd.CustomerBrokerage / 3.6725) * ain.QuantityMax)
		WHEN aibd.CustomerUnitLumpsum = 0 AND sc.Code <> 'AED' THEN (aibd.CustomerBrokerage * aibd.CustomerExchangeRate * ain.QuantityMax)
        WHEN aibd.CustomerUnitLumpsum = 1 AND sc.Code = 'AED' THEN (aibd.CustomerBrokerage / 3.6725)
		WHEN aibd.CustomerUnitLumpsum = 1 AND sc.Code <> 'AED' THEN (aibd.CustomerBrokerage * aibd.CustomerExchangeRate)
        ELSE 0
    END
	,0) AS 'Total Brokerage',
	CASE
		WHEN aid.InquiryStatus IN (700,800) THEN CONVERT(DATE, DATEADD(DAY, ain.BuyerCreditTerms, aid.DeliveryStartDateNomination))
		ELSE CONVERT(DATE, aic.PaymentDueDate)
	END AS 'PaymentDueDate',
	CASE
		WHEN aid.InquiryStatus IN (700,800) THEN NULL
		ELSE CONVERT(DATE, COALESCE(aic.AmountReceivedDate, aic.AcknowledgementSentOn))
	END AS 'DateReceived',
	CONVERT(DATE, aic.ApprovedOn) AS 'InvoiceDate'


FROM AppInquiryDetails aid
JOIN AppInquiryFuelDetails aifd On aifd.InquiryDetailId = aid.id and aifd.IsDeleted = 0 and aifd.isLosted = 0
LEFT JOIN AppSellers asel ON asel.Id = aifd.SellerId and asel.IsDeleted = 0
LEFT JOIN AppInquirySellerDetails aisd ON aisd.InquiryFuelDetailId = aifd.Id and aisd.SellerId = aifd.SellerId and aisd.IsDeleted = 0
LEFT JOIN AppSuppliers asup ON asup.Id = aisd.SupplierId and asup.IsDeleted = 0
LEFT JOIN AppVessel av ON av.Id = aid.VesselNominationId and av.IsDeleted = 0
LEFT JOIN AppPorts ap ON ap.Id = aid.PortNominationId and ap.IsDeleted = 0
LEFT JOIN AppUserProfiles aup ON aup.Id = aid.UserProfileId and aup.IsDeleted = 0
LEFT JOIN AppCustomers acus ON acus.Id = aid.CustomerNominationId and acus.IsDeleted = 0
LEFT JOIN AppCustomerGroups acg ON acg.id = acus.CustomerGroupId and acg.IsDeleted = 0
LEFT JOIN AppInquiryNominations ain ON ain.InquirySellerDetailId = aisd.Id and ain.IsDeleted = 0 and ain.InquiryDetailId = aifd.InquiryDetailId
LEFT JOIN AppDeliveries ad ON ad.InquiryFuelDetailId = aifd.Id and ad.IsDeleted = 0
LEFT JOIN AppInquiryMargins aim ON aim.InquirySellerDetailId = aisd.Id and aim.InquiryDetailId = aifd.InquiryDetailId and aim.IsDeleted = 0
LEFT JOIN AppInquiryOffers aio ON aio.InquiryDetailId = aifd.InquiryDetailId and aio.SellerId = aifd.SellerId and aio.IsDeleted = 0
LEFT JOIN AppFuels af ON af.id = aifd.FuelId and af.IsDeleted = 0
LEFT JOIN AppGradeGroups agg ON agg.Id = af.GradeGroupId and agg.IsDeleted = 0
LEFT JOIN AppInvoiceCustomers aic ON aic.InquiryFuelDetailId = aifd.Id and aic.IsDeleted = 0 and aic.InvoiceType = 0
LEFT JOIN AppCurrencies sc ON sc.Id = aim.CurrencyId and sc.IsDeleted = 0
LEFT JOIN AppInvoiceSellers ais ON ais.InquiryFuelDetailId = aifd.Id and ais.IsDeleted = 0 and ais.InvoiceType = 0
LEFT JOIN AppCurrencies bc ON bc.Id = aio.CurrencyId and bc.IsDeleted = 0
LEFT JOIN AppInvoiceAdditionalCosts aiac ON aiac.InvoiceCustomerId = aic.Id and aiac.IsDeleted = 0
LEFT JOIN AdditionalCostCustomerCTE acc ON acc.InquiryFuelDetailId = aic.InquiryFuelDetailId
LEFT JOIN AdditionalCostSellerCTE acs ON acs.InquiryFuelDetailId = ais.InquiryFuelDetailId
LEFT JOIN AppInquiryCancelStems aics ON aics.InquiryFuelDetailId = aifd.Id and aics.IsDeleted = 0
LEFT JOIN MiscCostSeller mcs ON mcs.InquirySellerDetailId = aisd.Id 
LEFT JOIN MiscCostCustomer mcc ON mcc.InquirySellerDetailId = aisd.Id 
LEFT JOIN PrepaymentDiscountCustomer pdc ON pdc.InquiryFuelDetailId = aic.InquiryFuelDetailId
LEFT JOIN AmountReceivedSoFARCTE ars ON ars.InquiryFuelDetailId = aic.InquiryFuelDetailId
LEFT JOIN AmountReceivedSoFARCTE1 arss ON arss.InquiryFuelDetailId = aic.InquiryFuelDetailId
LEFT JOIN AppInquiryBrokerDetails aibd ON aibd.InquiryFuelDetailId = aifd.Id and aibd.IsDeleted = 0 and (aibd.CustomerBrokerage is not null OR aibd.SellerBrokerage Is NOT NULL)

WHERE aid.InquiryStatus IN (650,700,800,900,1000,9000) and sc.Code is not null
)
,
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
			WHEN aic.InvoiceType = 1 THEN ROUND(-ABS(aic.SubTotal),2)
			WHEN aic.InvoiceType = 2 THEN ROUND(aic.SubTotal, 2)
		END AS 'Customer Invoice Amount',
		CASE 
			WHEN aic.InvoiceType = 1 AND acur.Code = 'AED' THEN ROUND(-ABS(aic.SubTotal / 3.6725),2)
			WHEN aic.InvoiceType = 1 AND acur.Code <> 'AED' THEN ROUND(-ABS(aic.SubTotal * aim.ExchangeRate),2)
			WHEN aic.InvoiceType = 2 AND acur.Code = 'AED' THEN ROUND(aic.SubTotal / 3.6725, 2)
			WHEN aic.InvoiceType = 2 AND acur.Code <> 'AED' THEN ROUND(aic.SubTotal * aim.ExchangeRate, 2)
		END AS 'Customer Invoice Amount USD',
		CASE 
			WHEN aic.InvoiceType = 1 THEN ROUND(-ABS(aic.AmountReceivedSoFar),2)
			WHEN aic.InvoiceType = 2 THEN ROUND(aic.AmountReceivedSoFar, 2)
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
			WHEN aic.SellPrice IS NOT NULL THEN aic.SellPrice
			WHEN aic.SubTotal IS NOT NULL AND COALESCE(ad.BdnQtyUnit, aifd.Unit) IS NOT NULL AND aic.InvoiceType = 1 THEN ROUND((-ABS(aic.SubTotal) / COALESCE(aic.BdnBillingQuantity, ad.BDNQty, ain.QuantityMax)), 2)
			WHEN aic.SubTotal IS NOT NULL AND COALESCE(ad.BdnQtyUnit, aifd.Unit) IS NOT NULL AND aic.InvoiceType = 2 THEN ROUND((aic.SubTotal / COALESCE(aic.BdnBillingQuantity, ad.BDNQty, ain.QuantityMax)), 2)
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
	CASE 
		WHEN aics.CancelTypes = 0 THEN 'With Penalty'
		WHEN aics.CancelTypes = 1 THEN 'Without Penalty'
	END AS 'Cancellation Status',
	CONVERT(DATE, COALESCE(ain.StemDate, ain.BookedOn)) AS 'Stem Date',
	CONVERT(DATE, ad.DeliveryDate) AS 'Delivery Date',
	aim.Margin AS 'Margin per MT',
	acur.Code AS 'Selling Currency',
        ROW_NUMBER() OVER (PARTITION BY aifd.Id, aifd.Description, aic.InvoiceType ORDER BY aic.InvoiceCode) AS RowNum,
		NULL AS 'Total Brokerage',
		CASE
		WHEN aid.InquiryStatus IN (700,800) THEN CONVERT(DATE, DATEADD(DAY, ain.BuyerCreditTerms, aid.DeliveryStartDateNomination))
		ELSE CONVERT(DATE, aic.PaymentDueDate)
	END AS 'PaymentDueDate',
	CASE
		WHEN aid.InquiryStatus IN (700,800) THEN NULL
		ELSE CONVERT(DATE, COALESCE(aic.AmountReceivedDate, aic.AcknowledgementSentOn))
	END AS 'DateReceived',
	CONVERT(DATE, aic.ApprovedOn) AS 'InvoiceDate'
    FROM 
        AppInquiryFuelDetails aifd
    JOIN 
        AppInvoiceCustomers aic 
        ON aic.InquiryFuelDetailId = aifd.Id 
        AND aic.IsDeleted = 0 
        AND aic.InvoiceType <> 0
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
	LEFT JOIN AppInquiryCancelStems aics ON aics.InquiryFuelDetailId = aifd.Id and aics.IsDeleted = 0
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
			WHEN ais.InvoiceType = 1 THEN ROUND(-ABS(ais.SubTotal),2)
			WHEN ais.InvoiceType = 2 THEN ROUND(ais.SubTotal, 2)
		END AS 'Seller Invoice Amount',
		CASE 
			WHEN ais.InvoiceType = 1 AND acur.Code = 'AED' THEN ROUND(-ABS(ais.SubTotal / 3.6725),2)
			WHEN ais.InvoiceType = 1 AND acur.Code <> 'AED' THEN ROUND(-ABS(ais.SubTotal * aio.ExchangeRate),2)
			WHEN ais.InvoiceType = 2 AND acur.Code = 'AED' THEN ROUND(ais.SubTotal / 3.6725, 2)
			WHEN ais.InvoiceType = 2 AND acur.Code <> 'AED' THEN ROUND(ais.SubTotal * aio.ExchangeRate, 2)
		END AS 'Seller Invoice Amount USD',
		CASE 
			WHEN ais.InvoiceType = 1 THEN ROUND(-ABS(ais.AmountPaidSoFar),2)
			WHEN ais.InvoiceType = 2 THEN ROUND(ais.AmountPaidSoFar, 2)
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
			WHEN ais.SubTotal IS NOT NULL AND COALESCE(ad.BdnQtyUnit, aifd.Unit) IS NOT NULL AND ais.InvoiceType = 1 THEN ROUND((-ABS(ais.SubTotal) / COALESCE(ais.BdnBillingQuantity, ad.BDNQty, ain.QuantityMax)), 2)
			WHEN ais.SubTotal IS NOT NULL AND COALESCE(ad.BdnQtyUnit, aifd.Unit) IS NOT NULL AND ais.InvoiceType = 2 THEN ROUND((ais.SubTotal / COALESCE(ais.BdnBillingQuantity, ad.BDNQty, ain.QuantityMax)), 2)
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
	CASE 
		WHEN aics.CancelTypes = 0 THEN 'With Penalty'
		WHEN aics.CancelTypes = 1 THEN 'Without Penalty'
	END AS 'Cancellation Status',
	CONVERT(DATE, COALESCE(ain.StemDate, ain.BookedOn)) AS 'Stem Date',
	CONVERT(DATE, ad.DeliveryDate) AS 'Delivery Date',
	aim.Margin AS 'Margin per MT',
	acur.Code AS 'Buying Currency',
        ROW_NUMBER() OVER (PARTITION BY aifd.Id, aifd.Description, ais.InvoiceType ORDER BY ais.InvoiceNumber) AS RowNum,
		NULL AS 'Total Brokerage',
		NULL AS 'PaymentDueDate',
		NULL AS 'DateReceived',
		NULL AS 'InvoiceDate'
    FROM 
        AppInquiryFuelDetails aifd
    JOIN 
        AppInvoiceSellers ais 
        ON ais.InquiryFuelDetailId = aifd.Id 
        AND ais.IsDeleted = 0 
        AND ais.InvoiceType <> 0
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
	LEFT JOIN AppInquiryCancelStems aics ON aics.InquiryFuelDetailId = aifd.Id and aics.IsDeleted = 0
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
	ci.[Customer In Out],
	ci.[Job Status],
	ci.[Cancellation Status],
	ci.[Stem Date],
	ci.[Delivery Date],
	ci.[Margin per MT],
    ci.[Qty in MT] AS Qty,
    ci.CustomerInvoiceNumber AS 'Customer Invoice Number',
    ci.[Customer Invoice Amount],
	ci.[Customer Invoice Amount USD],
	NULL AS 'Seller Invoice Number',
    NULL AS [Seller Invoice Amount],
	NULL AS [Seller Invoice Amount USD],
    ci.[Amount Received],
	NULL AS [Amount Paid],
	NULL AS [Payment Status],
    ci.[Receipt Status],
	NULL AS [Buying Price],
	NULL AS [Buying Currency],
    ci.[Selling Price],
	ci.[Selling Currency],
	NULL AS 'Total Brokerage',
	ci.PaymentDueDate,
	ci.DateReceived,
	ci.InvoiceDate
    
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
	si.[Customer In Out],
	si.[Job Status],
	si.[Cancellation Status],
	si.[Stem Date],
	si.[Delivery Date],
	si.[Margin per MT],
    si.[Qty in MT] AS Qty,
    NULL AS 'Customer Invoice Number',
    NULL AS [Customer Invoice Amount],
	NULL AS [Customer Invoice Amount USD],
	si.SellerInvoiceNumber AS 'Seller Invoice Number',
    si.[Seller Invoice Amount],
	si.[Seller Invoice Amount USD],
    NULL AS [Amount Received],
	si.[Amount Paid],
	si.[Payment Status],
    NULL AS [Receipt Status],
    si.[Buying Price],
	si.[Buying Currency],
    NULL AS [Selling Price],
	NULL AS [Selling Currency],
	NULL AS 'Total Brokerage',
	si.PaymentDueDate,
	si.DateReceived,
	si.InvoiceDate
   
FROM 
    SellerInvoices si
),UNIONALL AS (
Select * from MainAndBookedInvoices
UNION ALL
Select * from CnAndDnInvoices
)
Select * from UNIONALL --where [Job Code] = 'G2854'