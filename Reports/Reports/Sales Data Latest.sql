/*
 Sales Data Latest
 04-03-2025
 Updated in Prod
 
 Old Updates
 16-07-2024 --Added Expected Payment Received Date
 27-07-2024 --Added Query to production
 23-08-2024 --Added new column called Customer Group
 28-08-2024 --Added new column called BDN Unit and Payment Status
 28-08-2024 --Added logic for Payment Status, when uninvoiced, sent for approval and rejected this would be null
 08-09-2024 --Modified query
 23-09-2024 --Optimized
 24-09-2024 --Grade Spec updated from Nomination
 27-09-2024 --Sub total and Amount Received added
 04-10-2024 --Port Nomination added
 07-10-2024 --Added Date Received
 08-10-2024 --Added 3 columns QuantityMin(MT), QuantityMax(MT), BDNBillingQty(MT)
 24-10-2024 --Added 4 columns Selling Price(USD), Buying Price(USD), Seller invoice sub total/total amount, Customer invoice total/subtotal amount
 10-12-2024 --Updated misc cost
 20-12-2024 --Added Cancellation Status
 21-03-2024 - Replaced Ack date to Amount Received date
 21-03-2024 - Misc Cost Added for Booked stems
 05-05-2024 :
 1. Seller Broker Name
 2. Customer Broker Name
 3. Seller UNIT/LUMPSUM
 4. Seller UNIT
 5. Customer UNIT/LUMPSUM
 6. Customer UNIT
 7. Seller Brokerage
 8. Seller Brokerage(USD)
 9. Customer Brokerage
 10. Customer Brokerage(USD)
 Added the above columns
 07-07-2025 - Order by clause modified
 */
DROP TABLE IF EXISTS #SalesDataLatestUnionTable;
WITH InquiryMiscCostCustomer AS (
    Select
        aimc.InquiryDetailId,
        aimc.InquirySellerDetailId,
        SUM(AmountUsd) AS 'Amount'
    from
        AppInquiryMiscCosts aimc
    WHERE
        IsDeleted = 0
        and FromBuyer = 1
    GROUP BY
        aimc.InquiryDetailId,
        aimc.InquirySellerDetailId
),
InquiryBrokerDetailsCTE AS (
    SELECT
        aibd.Id,
        aibd.InquiryDetailId,
        aibd.InquiryFuelDetailId,
        aibd.SellerBrokerage,
        sel.Code AS 'Seller Currency',
        CASE
            WHEN sel.Code = 'AED' THEN ROUND(aibd.SellerBrokerage / 3.6725, 2)
            ELSE ROUND(
                aibd.SellerBrokerage * aibd.SellerExchangeRate,
                2
            )
        END AS 'Seller Brokerage(USD)',
        sb.Name AS 'Seller Broker Name',
        CASE
            WHEN aibd.SellerUnitLumpsum = 0 THEN 'Unit'
            ELSE 'Lumpsum'
        END AS SellerUnitLumpsum,
        CASE
            WHEN aibd.SellerUnitLumpsum = 1 THEN NULL
            ELSE CASE
                WHEN aibd.SellerUnit = 0 THEN 'MT'
                WHEN aibd.SellerUnit = 1 THEN 'KG'
                WHEN aibd.SellerUnit = 2 THEN 'Litres'
                WHEN aibd.SellerUnit = 3 THEN 'IG'
                WHEN aibd.SellerUnit = 4 THEN 'CBM'
                WHEN aibd.SellerUnit = 5 THEN 'US Gallons'
                WHEN aibd.SellerUnit = 6 THEN 'Barrels'
                WHEN aibd.SellerUnit = 7 THEN 'KL'
            END
        END AS SellerUnit,
        aibd.CustomerBrokerage,
        cust.Code AS 'Customer Currency',
        CASE
            WHEN cust.Code = 'AED' THEN ROUND(aibd.CustomerBrokerage / 3.6725, 2)
            ELSE ROUND(
                aibd.CustomerBrokerage * aibd.CustomerExchangeRate,
                2
            )
        END AS 'Customer Brokerage(USD)',
        cb.Name AS 'Customer Broker Name',
        CASE
            WHEN aibd.CustomerUnitLumpsum = 0 THEN 'Unit'
            ELSE 'Lumpsum'
        END AS CustomerUnitLumpsum,
        CASE
            WHEN aibd.CustomerUnitLumpsum = 1 THEN NULL
            ELSE CASE
                WHEN aibd.CustomerUnit = 0 THEN 'MT'
                WHEN aibd.CustomerUnit = 1 THEN 'KG'
                WHEN aibd.CustomerUnit = 2 THEN 'Litres'
                WHEN aibd.CustomerUnit = 3 THEN 'IG'
                WHEN aibd.CustomerUnit = 4 THEN 'CBM'
                WHEN aibd.CustomerUnit = 5 THEN 'US Gallons'
                WHEN aibd.CustomerUnit = 6 THEN 'Barrels'
                WHEN aibd.CustomerUnit = 7 THEN 'KL'
            END
        END AS CustomerUnit
    FROM
        AppInquiryBrokerDetails aibd
        LEFT JOIN AppCurrencies sel ON sel.Id = aibd.SellerCurrencyId
        AND sel.IsDeleted = 0
        LEFT JOIN AppCurrencies cust ON cust.Id = aibd.CustomerCurrencyId
        AND cust.IsDeleted = 0
        LEFT JOIN AppBrokers sb ON sb.Id = aibd.SellerBrokerId
        AND sb.IsDeleted = 0
        LEFT JOIN AppBrokers cb ON cb.Id = aibd.CustomerBrokerId
        AND cb.IsDeleted = 0
    WHERE
        (
            CustomerBrokerage IS NOT NULL
            OR SellerBrokerage IS NOT NULL
        )
        AND aibd.IsDeleted = 0
),
InquiryMiscCostSeller AS (
    Select
        aimc.InquiryDetailId,
        aimc.InquirySellerDetailId,
        SUM(AmountUsd) AS 'Amount'
    from
        AppInquiryMiscCosts aimc
    WHERE
        IsDeleted = 0
        and ToSeller = 1
    GROUP BY
        aimc.InquiryDetailId,
        aimc.InquirySellerDetailId
),
ExpCTE AS (
    SELECT
        'GS' AS 'Data source',
        aid.Code AS 'Job code',
        av.Name AS 'Vessel name',
        ap.Name AS 'Port name',
        CONVERT(DATE, COALESCE(ain.StemDate, ain.BookedOn)) AS 'Stem date',
        CONVERT(DATE, aid.DeliveryStartDateNomination) AS 'Delivery start date',
        CONVERT(DATE, ad.DeliveryDate) AS 'Delivery date',
        ac.Name AS 'Customer name',
        acg.Name AS 'Customer group',
        aco.Name AS 'Incorporation Jurisdiction',
        asup.Name AS 'Supplier name',
        aibd.[Seller Broker Name],
        aibd.[Customer Broker Name],
        aibd.SellerUnitLumpsum,
        aibd.SellerUnit,
        aibd.CustomerUnitLumpsum,
        aibd.CustomerUnit,
        aic.InvoiceCode AS 'Invoice number',
        CONVERT(DATE, aic.ApprovedOn) AS 'Invoice date',
        CASE
            WHEN aic.InvoiceType = 0 THEN 'Invoice'
            WHEN aic.InvoiceType = 1 THEN 'Credit Note'
            WHEN aic.InvoiceType = 2 THEN 'Debit Note'
            ELSE NULL
        END AS 'Invoice Type',
        CASE
            WHEN aid.InquiryStatus = 0 THEN 'Draft'
            WHEN aid.InquiryStatus = 100 THEN 'RaisedByClient'
            WHEN aid.InquiryStatus = 200 THEN 'Pending Credit Approval'
            WHEN aid.InquiryStatus = 300 THEN 'Rejected'
            WHEN aid.InquiryStatus = 400 THEN 'Credit Approved'
            WHEN aid.InquiryStatus = 500 THEN 'PreApproved'
            WHEN aid.InquiryStatus = 600 THEN 'Auction'
            WHEN aid.InquiryStatus = 650 THEN 'PartlyBooked'
            WHEN aid.InquiryStatus = 700 THEN 'PartlyBooked'
            WHEN aid.InquiryStatus = 800 THEN 'Booked'
            WHEN aid.InquiryStatus = 900 THEN 'PartlyDelivered'
            WHEN aid.InquiryStatus = 1000 THEN 'Delivered'
            WHEN aid.InquiryStatus = 1500 THEN 'LostStem'
            WHEN aid.InquiryStatus = 9000 THEN 'Cancelled'
            WHEN aid.InquiryStatus = 10000 THEN 'Invoiced'
            WHEN aid.InquiryStatus = 15000 THEN 'Closed'
        END AS 'Job Status',
        CASE
            WHEN aics.CancelTypes = 0 THEN 'With Penalty'
            WHEN aics.CancelTypes = 1 THEN 'Without Penalty'
        END AS 'Cancellation Status',
        CONVERT(DATE, aid.DateCreated) AS 'Inquiry Received Date',
        CONVERT(DATE, aic.PaymentDueDate) AS 'Payment due date',
        CONVERT(DATE, aic.ExpectedDueDate) AS 'Expected Payment Received Date',
        CONVERT(DATE, aic.AmountReceivedDate) AS 'Date Received',
        COALESCE(ain.QuantityMin, aifd.QuantityMin) AS 'Quantity min',
        CASE
            WHEN agg.Name = 'GO' THEN CASE
                WHEN aifd.Unit = 0 THEN COALESCE(ain.QuantityMin, aifd.QuantityMin) --MT
                WHEN aifd.Unit = 1 THEN ROUND(
                    COALESCE(ain.QuantityMin, aifd.QuantityMin) * 0.001,
                    4
                ) --KG
                WHEN aifd.Unit = 2 THEN ROUND(
                    COALESCE(ain.QuantityMin, aifd.QuantityMin) * 0.00085,
                    4
                ) --Litres
                WHEN aifd.Unit = 3 THEN ROUND(
                    COALESCE(ain.QuantityMin, aifd.QuantityMin) * 0.0038641765,
                    4
                ) --IG
                WHEN aifd.Unit = 4 THEN ROUND(
                    COALESCE(ain.QuantityMin, aifd.QuantityMin) * 0.85,
                    4
                ) --CBM
                WHEN aifd.Unit = 5 THEN ROUND(
                    COALESCE(ain.QuantityMin, aifd.QuantityMin) * 0.0032,
                    4
                ) --US Gallons
                WHEN aifd.Unit = 6 THEN ROUND(
                    COALESCE(ain.QuantityMin, aifd.QuantityMin) * 0.134,
                    4
                ) --Barrels
                WHEN aifd.Unit = 7 THEN ROUND(
                    COALESCE(ain.QuantityMin, aifd.QuantityMin) * 0.85,
                    4
                ) --KL
            END
            WHEN agg.Name = 'FO' THEN CASE
                WHEN aifd.Unit = 0 THEN COALESCE(ain.QuantityMin, aifd.QuantityMin) --MT
                WHEN aifd.Unit = 1 THEN ROUND(
                    COALESCE(ain.QuantityMin, aifd.QuantityMin) * 0.001,
                    4
                ) --KG
                WHEN aifd.Unit = 2 THEN ROUND(
                    COALESCE(ain.QuantityMin, aifd.QuantityMin) * 0.00094,
                    4
                ) --Litres
                WHEN aifd.Unit = 3 THEN ROUND(
                    COALESCE(ain.QuantityMin, aifd.QuantityMin) * 0.0042733246,
                    4
                ) --IG
                WHEN aifd.Unit = 4 THEN ROUND(
                    COALESCE(ain.QuantityMin, aifd.QuantityMin) * 0.94,
                    4
                ) --CBM
                WHEN aifd.Unit = 5 THEN ROUND(
                    COALESCE(ain.QuantityMin, aifd.QuantityMin) * 0.0037,
                    4
                ) --US Gallons
                WHEN aifd.Unit = 6 THEN ROUND(
                    COALESCE(ain.QuantityMin, aifd.QuantityMin) * 0.157,
                    4
                ) --Barrels
                WHEN aifd.Unit = 7 THEN ROUND(
                    COALESCE(ain.QuantityMin, aifd.QuantityMin) * 0.94,
                    4
                ) --KL
            END
            ELSE COALESCE(ain.QuantityMin, aifd.QuantityMin)
        end as 'Quantity Min(MT)',
        COALESCE(ain.QuantityMax, aifd.QuantityMax) AS 'Quantity max',
        CASE
            WHEN agg.Name = 'GO' THEN CASE
                WHEN aifd.Unit = 0 THEN COALESCE(ain.QuantityMax, aifd.QuantityMax) --MT
                WHEN aifd.Unit = 1 THEN ROUND(
                    COALESCE(ain.QuantityMax, aifd.QuantityMax) * 0.001,
                    4
                ) --KG
                WHEN aifd.Unit = 2 THEN ROUND(
                    COALESCE(ain.QuantityMax, aifd.QuantityMax) * 0.00085,
                    4
                ) --Litres
                WHEN aifd.Unit = 3 THEN ROUND(
                    COALESCE(ain.QuantityMax, aifd.QuantityMax) * 0.0038641765,
                    4
                ) --IG
                WHEN aifd.Unit = 4 THEN ROUND(
                    COALESCE(ain.QuantityMax, aifd.QuantityMax) * 0.85,
                    4
                ) --CBM
                WHEN aifd.Unit = 5 THEN ROUND(
                    COALESCE(ain.QuantityMax, aifd.QuantityMax) * 0.0032,
                    4
                ) --US Gallons
                WHEN aifd.Unit = 6 THEN ROUND(
                    COALESCE(ain.QuantityMax, aifd.QuantityMax) * 0.134,
                    4
                ) --Barrels
                WHEN aifd.Unit = 7 THEN ROUND(
                    COALESCE(ain.QuantityMax, aifd.QuantityMax) * 0.85,
                    4
                ) --KL
            END
            WHEN agg.Name = 'FO' THEN CASE
                WHEN aifd.Unit = 0 THEN COALESCE(ain.QuantityMax, aifd.QuantityMax) --MT
                WHEN aifd.Unit = 1 THEN ROUND(
                    COALESCE(ain.QuantityMax, aifd.QuantityMax) * 0.001,
                    4
                ) --KG
                WHEN aifd.Unit = 2 THEN ROUND(
                    COALESCE(ain.QuantityMax, aifd.QuantityMax) * 0.00094,
                    4
                ) --Litres
                WHEN aifd.Unit = 3 THEN ROUND(
                    COALESCE(ain.QuantityMax, aifd.QuantityMax) * 0.0042733246,
                    4
                ) --IG
                WHEN aifd.Unit = 4 THEN ROUND(
                    COALESCE(ain.QuantityMax, aifd.QuantityMax) * 0.94,
                    4
                ) --CBM
                WHEN aifd.Unit = 5 THEN ROUND(
                    COALESCE(ain.QuantityMax, aifd.QuantityMax) * 0.0037,
                    4
                ) --US Gallons
                WHEN aifd.Unit = 6 THEN ROUND(
                    COALESCE(ain.QuantityMax, aifd.QuantityMax) * 0.157,
                    4
                ) --Barrels
                WHEN aifd.Unit = 7 THEN ROUND(
                    COALESCE(ain.QuantityMax, aifd.QuantityMax) * 0.94,
                    4
                ) --KL
            END
            ELSE COALESCE(ain.QuantityMax, aifd.QuantityMax)
        end as 'Quantity Max(MT)',
        COALESCE(aic.BdnBillingQuantity, ad.BdnQty) AS 'BdnBillingQuantity',
        CASE
            WHEN ad.BdnQtyUnit = 0 THEN 'MT'
            WHEN ad.BdnQtyUnit = 1 THEN 'KG'
            WHEN ad.BdnQtyUnit = 2 THEN 'Litres'
            WHEN ad.BdnQtyUnit = 3 THEN 'IG'
            WHEN ad.BdnQtyUnit = 4 THEN 'CBM'
            WHEN ad.BdnQtyUnit = 5 THEN 'US Gallons'
            WHEN ad.BdnQtyUnit = 6 THEN 'Barrels'
            WHEN ad.BdnQtyUnit = 7 THEN 'KL'
        END AS 'BDN Unit',
        CASE
            WHEN agg.Name = 'GO' THEN CASE
                WHEN ad.BdnQtyUnit = 0 THEN COALESCE(aic.BdnBillingQuantity, ad.BdnQty) --MT
                WHEN ad.BdnQtyUnit = 1 THEN ROUND(
                    COALESCE(aic.BdnBillingQuantity, ad.BdnQty) * 0.001,
                    4
                ) --KG
                WHEN ad.BdnQtyUnit = 2 THEN ROUND(
                    COALESCE(aic.BdnBillingQuantity, ad.BdnQty) * 0.00085,
                    4
                ) --Litres
                WHEN ad.BdnQtyUnit = 3 THEN ROUND(
                    COALESCE(aic.BdnBillingQuantity, ad.BdnQty) * 0.0038641765,
                    4
                ) --IG
                WHEN ad.BdnQtyUnit = 4 THEN ROUND(
                    COALESCE(aic.BdnBillingQuantity, ad.BdnQty) * 0.85,
                    4
                ) --CBM
                WHEN ad.BdnQtyUnit = 5 THEN ROUND(
                    COALESCE(aic.BdnBillingQuantity, ad.BdnQty) * 0.0032,
                    4
                ) --US Gallons
                WHEN ad.BdnQtyUnit = 6 THEN ROUND(
                    COALESCE(aic.BdnBillingQuantity, ad.BdnQty) * 0.134,
                    4
                ) --Barrels
                WHEN ad.BdnQtyUnit = 7 THEN ROUND(
                    COALESCE(aic.BdnBillingQuantity, ad.BdnQty) * 0.85,
                    4
                ) --KL
            END
            WHEN agg.Name = 'FO' THEN CASE
                WHEN ad.BdnQtyUnit = 0 THEN COALESCE(aic.BdnBillingQuantity, ad.BdnQty) --MT
                WHEN ad.BdnQtyUnit = 1 THEN ROUND(
                    COALESCE(aic.BdnBillingQuantity, ad.BdnQty) * 0.001,
                    4
                ) --KG
                WHEN ad.BdnQtyUnit = 2 THEN ROUND(
                    COALESCE(aic.BdnBillingQuantity, ad.BdnQty) * 0.00094,
                    4
                ) --Litres
                WHEN ad.BdnQtyUnit = 3 THEN ROUND(
                    COALESCE(aic.BdnBillingQuantity, ad.BdnQty) * 0.0042733246,
                    4
                ) --IG
                WHEN ad.BdnQtyUnit = 4 THEN ROUND(
                    COALESCE(aic.BdnBillingQuantity, ad.BdnQty) * 0.94,
                    4
                ) --CBM
                WHEN ad.BdnQtyUnit = 5 THEN ROUND(
                    COALESCE(aic.BdnBillingQuantity, ad.BdnQty) * 0.0037,
                    4
                ) --US Gallons
                WHEN ad.BdnQtyUnit = 6 THEN ROUND(
                    COALESCE(aic.BdnBillingQuantity, ad.BdnQty) * 0.157,
                    4
                ) --Barrels
                WHEN ad.BdnQtyUnit = 7 THEN ROUND(
                    COALESCE(aic.BdnBillingQuantity, ad.BdnQty) * 0.94,
                    4
                ) --KL
            END
            ELSE COALESCE(aic.BdnBillingQuantity, ad.BdnQty)
        end as 'BDNQty(MT)',
        aifd.Description AS 'Fuel name',
        COALESCE(ags.Name, agss.Name) AS 'Grade spec name',
        COALESCE(aic.SellPrice, aim.SellPrice) AS 'Selling price',
        sel.Code AS 'Selling Price Currency type',
        CASE
            WHEN sel.Code = 'AED' THEN ROUND(
                COALESCE(aic.SellPrice / 3.6725, aim.SellPrice / 3.6725),
                2
            )
            WHEN sel.Code <> 'AED' THEN ROUND(
                COALESCE(
                    aic.SellPrice * aim.ExchangeRate,
                    aim.SellPriceUsd
                ),
                2
            )
        END AS 'Selling Price(USD)',
        ROUND(COALESCE(ais.BuyPrice, aim.BuyPrice), 2) AS 'Buying price',
        buy.Code AS 'Buying Price Currency type',
        CASE
            WHEN buy.Code = 'AED' THEN ROUND(
                COALESCE(ais.BuyPrice / 3.6725, aim.Buyprice / 3.6725),
                2
            )
            WHEN buy.Code <> 'AED' THEN ROUND(
                COALESCE(ais.BuyPrice * aio.ExchangeRate, aim.Buypriceusd),
                2
            )
        END AS 'Buying Price(USD)',
        aibd.CustomerBrokerage,
        aibd.[Customer Currency],
        aibd.[Customer Brokerage(USD)],
        aibd.SellerBrokerage,
        aibd.[Seller Currency],
        aibd.[Seller Brokerage(USD)],
        ROUND(aim.Margin, 2) AS 'Margin',
        NULL AS MiscCostItemOneName,
        NULL AS MiscCostItemOneAmount,
        NULL AS MiscCostItemTwoName,
        NULL AS MiscCostItemTwoAmount,
        NULL AS MiscCostItemThreeName,
        NULL AS MiscCostItemThreeAmount,
        NULL AS MiscCostItemFourName,
        NULL AS MiscCostItemFourAmount,
        NULL AS MiscCostItemFiveName,
        NULL AS MiscCostItemFiveAmount,
        aic.TotalAmount AS 'Customer invoice total amount',
        CASE
            WHEN sel.Code = 'AED' THEN ROUND(aic.TotalAmount / 3.6725, 2)
            WHEN sel.Code <> 'AED' THEN ROUND(aic.TotalAmount * aim.ExchangeRate, 2)
        END AS 'Customer invoice total amount(USD)',
        aic.SubTotal AS 'Customer invoice sub total',
        CASE
            WHEN sel.Code = 'AED' THEN ROUND(aic.SubTotal / 3.6725, 2)
            WHEN sel.Code <> 'AED' THEN ROUND(aic.SubTotal * aim.ExchangeRate, 2)
        END AS 'Customer invoice sub total(USD)',
        ROUND(aic.AmountReceivedSoFar, 2) AS 'Amount received',
        CASE
            WHEN sel.Code = 'AED' THEN ROUND(aic.AmountReceivedSoFar / 3.6725, 2)
            WHEN sel.Code = 'AED' THEN ROUND(aic.AmountReceivedSoFar * aim.ExchangeRate, 2)
        END AS 'Amount received(USD)',
        COALESCE(aic.BuyerGradeMiscCost, imc.Amount) AS 'Customer Grade Misc Cost',
        aic.AdditionalCost AS 'CustomerInvAddlCost',
        sel.Code AS 'Customer Currency Type',
        CASE
            WHEN aic.InvoiceType = 0 THEN ais.TotalAmount
            ELSE NULL
        END AS 'Seller invoice total amount',
        CASE
            WHEN aic.InvoiceType = 0
            and buy.Code = 'AED' THEN ROUND(ais.TotalAmount / 3.6725, 2)
            WHEN aic.InvoiceType = 0
            and buy.Code <> 'AED' THEN ROUND(ais.TotalAmount * aio.ExchangeRate, 2)
            ELSE NULL
        END AS 'Seller invoice total amount(USD)',
        CASE
            WHEN aic.InvoiceType = 0 THEN ais.SubTotal
            ELSE NULL
        END AS 'Seller invoice sub total',
        CASE
            WHEN aic.InvoiceType = 0
            and buy.Code = 'AED' THEN ROUND(ais.SubTotal / 3.6725, 2)
            WHEN aic.InvoiceType = 0
            and buy.Code <> 'AED' THEN ROUND(ais.SubTotal * aio.ExchangeRate, 2)
            ELSE NULL
        END AS 'Seller invoice sub total(USD)',
        CASE
            WHEN aic.InvoiceType is null THEN ims.Amount
            WHEN aic.InvoiceType = 0 THEN ais.SellerGradeMiscCost
            ELSE NULL
        END AS 'Seller Grade Misc Cost',
        CASE
            WHEN aic.InvoiceType = 0 THEN ais.AdditionalCost
            ELSE NULL
        END AS 'SellerInvAddlCost',
        CASE
            WHEN aic.InvoiceType = 0 THEN buy.Code
            ELSE NULL
        END AS 'Seller Currency Type',
        aup.Name AS 'Assignee',
        CASE
            WHEN aifd.TradeType = 0 THEN 'spot'
            WHEN aifd.TradeType = 1 THEN 'Contract'
        END AS 'Trade type',
        COALESCE(aic.BuyerCreditTerms, ain.BuyerCreditTerms) AS 'CustomerPaymentTerms',
        CASE
            WHEN aic.ReceivableType = 0 THEN 'Not received'
            WHEN aic.ReceivableType = 1 THEN 'Partly received'
            WHEN aic.ReceivableType = 2 THEN 'Received'
            ELSE 'Not Received'
        END AS 'Payment Status',
        CONVERT(date, aic.CreationTime) AS 'CreationTime',
        CONVERT(date, aic.LastModificationTime) AS 'LastModificationTime'
    FROM
        AppInquiryDetails aid
        LEFT JOIN AppVessel av ON av.id = aid.VesselNominationId
        and av.isdeleted = 0
        LEFT JOIN AppPorts ap ON ap.id = aid.portNominationId
        and ap.isdeleted = 0
        LEFT JOIN AppInquiryFuelDetails aifd ON aifd.inquirydetailid = aid.id
        and aifd.isdeleted = 0
        and aifd.islosted = 0
        LEFT JOIN AppInquirySellerDetails aisd ON aisd.InquiryFuelDetailId = aifd.id
        and aifd.sellerid = aisd.sellerid
        and aisd.isdeleted = 0
        LEFT JOIN AppInquiryNominations ain ON ain.InquirySellerDetailId = aisd.id
        and ain.InquiryDetailId = aifd.InquiryDetailId
        and ain.IsDeleted = 0
        LEFT JOIN AppDeliveries ad ON ad.InquiryFuelDetailId = aifd.Id
        and ad.isdeleted = 0
        LEFT JOIN AppCustomers ac ON ac.Id = aid.CustomerNominationId
        and ac.isdeleted = 0
        LEFT JOIN AppCustomerGroups acg ON acg.Id = ac.CustomerGroupId
        and acg.isdeleted = 0
        LEFT JOIN AppSuppliers asup ON asup.id = aisd.SupplierId
        and asup.IsDeleted = 0
        LEFT JOIN AppFuels af ON af.id = aifd.FuelId
        and af.IsDeleted = 0
        LEFT JOIN AppGradeGroups agg ON agg.id = af.GradeGroupId
        and agg.IsDeleted = 0
        LEFT JOIN AppGradeSpecs ags ON ags.id = aifd.GradeSpecId
        and ags.IsDeleted = 0
        LEFT JOIN AppGradeSpecs agss ON agss.id = ain.GradeSpecId
        and agss.IsDeleted = 0
        LEFT JOIN AppInquiryMargins aim ON aim.InquirySellerDetailId = aisd.Id
        and aim.InquiryDetailId = aisd.InquiryDetailId
        and aim.IsDeleted = 0
        LEFT JOIN AppUserProfiles aup ON aup.Id = aid.UserProfileId
        and aup.IsDeleted = 0
        LEFT JOIN AppInvoiceCustomers aic ON aic.InquiryFuelDetailId = aifd.Id
        and aic.IsDeleted = 0
        LEFT JOIN AppInvoiceSellers ais ON ais.InquiryFuelDetailId = aifd.Id
        and ais.IsDeleted = 0
        and ais.InvoiceType = 0
        LEFT JOIN AppInquiryCancelStems aics ON aics.InquiryFuelDetailId = aifd.Id
        and aics.IsDeleted = 0
        LEFT JOIN AppInquiryOffers aio ON aio.InquiryDetailId = aifd.InquiryDetailId
        and aio.SellerId = aifd.SellerId
        and aio.IsDeleted = 0
        LEFT JOIN AppCurrencies sel ON sel.Id = aim.CurrencyId
        and sel.IsDeleted = 0
        LEFT JOIN AppCurrencies buy ON buy.Id = aio.CurrencyId
        and buy.IsDeleted = 0
        LEFT JOIN AppCountries aco ON aco.Id = ac.JurisdictionId
        and aco.IsDeleted = 0
        LEFT JOIN InquiryMiscCostSeller ims ON ims.InquirySellerDetailId = aisd.Id
        and ims.InquiryDetailId = aisd.InquiryDetailId
        LEFT JOIN InquiryMiscCostCustomer imc ON imc.InquirySellerDetailId = aisd.Id
        and imc.InquiryDetailId = aisd.InquiryDetailId
        LEFT JOIN InquiryBrokerDetailsCTE aibd ON aibd.InquiryFuelDetailId = aifd.Id
        and aibd.InquiryDetailId = aid.Id
    WHERE
        aid.InquiryStatus IN (650, 700, 800, 900, 1000, 9000)
),
HistoricalData AS (
    SELECT
        DataSource as [Data source],
        JobCode AS 'Job code',
        VesselName AS 'Vessel name',
        PortName AS 'Port name',
        CONVERT(date, StemDate) AS 'Stem date',
        CONVERT(date, DeliveryStartDate) AS 'Delivery start date',
        --FORMAT(DeliveryStartDate, 'dd-MMM-yyyy') AS 'Delivery start date',
        --FORMAT(DeliveryDate, 'yyyy-MM-dd') AS 'Delivery date',
        CONVERT(date, DeliveryDate) AS 'Delivery date',
        CustomerName AS 'Customer name',
        NULL AS 'Customer group',
        NULL AS 'Incorporation Jurisdiction',
        SupplierName AS 'Supplier name',
        NULL AS 'Seller Broker Name',
        NULL AS 'Customer Broker Name',
        NULL AS 'Seller Broker Unit/Lumpsum',
        NULL AS 'Seller Broker Unit',
        NULL AS 'Customer Broker Unit/Lumpsum',
        NULL AS 'Customer Broker Unit',
        InvoiceNumber AS 'Invoice number',
        CONVERT(date, InvoiceDate) AS 'Invoice date',
        NULL AS 'Invoice Type',
        JobStatus AS 'Job status',
        NULL AS 'Cancellation Status',
        CONVERT(date, InquiryReceivedDate) AS 'Inquiry recieved date',
        CONVERT(date, PaymentDueDate) AS 'Payment due date',
        NULL AS 'Expected Payment Received Date',
        NULL AS 'Date Received',
        QuantityMin AS 'Quantity min',
        NULL AS 'Quantity min(MT)',
        QuantityMax AS 'Quantity max',
        NULL AS 'Quantity max(MT)',
        BdnBillingQuantity,
        NULL as 'BDN Unit',
        NULL AS 'BDNQty(MT)',
        FuelName AS 'Fuel name',
        GradeSpecName AS 'Grade spec name',
        SellingPrice AS 'Selling price',
        NULL as 'Selling Price Currency type',
        NULL AS 'Selling Price(USD)',
        BuyingPrice AS 'Buying price',
        NULL as 'Buying Price Currency type',
        NULL AS 'Buying Price(USD)',
        NULL AS CustomerBrokerage,
        NULL AS [Customer Currency],
        NULL AS [Customer Brokerage(USD)],
        NULL AS SellerBrokerage,
        NULL AS [Seller Currency],
        NULL AS [Seller Brokerage(USD)],
        ROUND(Margin, 2) AS 'Margin',
        MiscCostItemOneName,
        MiscCostItemOneAmount,
        MiscCostItemTwoName,
        MiscCostItemTwoAmount,
        MiscCostItemThreeName,
        MiscCostItemThreeAmount,
        MiscCostItemFourName,
        MiscCostItemFourAmount,
        MiscCostItemFiveName,
        MiscCostItemFiveAmount,
        ROUND(CustomerInvoiceTotalAmount, 2) AS 'Customer invoice total amount',
        NULL AS 'Customer invoice total amount(USD)',
        NULL AS 'Customer invoice sub total',
        NULL AS 'Customer invoice sub total(USD)',
        NULL AS 'Amount received',
        NULL AS 'Amount received(USD)',
        (
            MiscCostItemOneAmount + MiscCostItemTwoAmount + MiscCostItemThreeAmount + MiscCostItemFourAmount + MiscCostItemFiveAmount
        ) as 'Customer Grade Misc Cost',
        --new
        NULL as 'CustomerInvAddlCost',
        --new
        NULL as 'Customer Currency Type',
        ROUND(SellerInvoiceTotalAmount, 2) AS 'Seller invoice total amount',
        NULL AS 'Seller invoice total amount(USD)',
        NULL AS 'Seller invoice sub total',
        NULL AS 'Seller invoice sub total(USD)',
        (
            MiscCostItemOneAmount + MiscCostItemTwoAmount + MiscCostItemThreeAmount + MiscCostItemFourAmount + MiscCostItemFiveAmount
        ) as 'Seller Grade Misc Cost',
        --new
        NULL as 'SellerInvAddlCost',
        --new
        NULL as 'Seller Currency Type',
        Assignee,
        TradeType,
        CASE
            WHEN TRY_CAST(customerpaymentterms AS INT) IS NOT NULL THEN CAST(customerpaymentterms AS INT)
            ELSE NULL
        END AS 'CustomerPaymentTerms',
        NULL as 'Payment Status',
        CONVERT(date, CreationTime) AS 'CreationTime',
        CONVERT(date, LastModificationTime) AS 'LastModificationTime'
    FROM
        AppHistoricalSalesData
),
UnionCTE AS (
    Select
        *
    from
        HistoricalData
    UNION
    ALL
    Select
        *
    from
        ExpCTE
)
SELECT
    *,
    CASE
        WHEN [Data Source] = 'GS' THEN 0
        ELSE 1
    END AS SortIsGS,
    CASE
        WHEN [Stem date] IS NULL THEN 0
        ELSE 1
    END AS SortHasStemDate,
    CASE
        WHEN LEN([Job code]) > 1 THEN TRY_CAST(
            SUBSTRING([Job code], 2, LEN([Job code]) - 1) AS INT
        )
        ELSE 0
    END AS SortJobCodeNum INTO #SalesDataLatestUnionTable
FROM
    UnionCTE
SELECT
    *
FROM
    #SalesDataLatestUnionTable
ORDER BY
    SortIsGS,
    SortHasStemDate,
    [Stem date] DESC,
    SortJobCodeNum DESC