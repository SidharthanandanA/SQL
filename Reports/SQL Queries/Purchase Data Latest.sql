/*
 Purchase Data Latest (PJD)
 04-03-2025
 
 Old Updates
 24-07-2024 - added supplier name
 23-08-2024 - New order by clause
 
 28-08-2024 - Added new columns BDN Unit, and Payment Status
 
 08-09-2024 --Modified query
 23-09-2024 --Optimized
 24-09-2024 --Grade Spec updated from Nomination
 27-09-2024 --Sub total and Amount paid added
 04-10-2024 --Sub total added for customer
 04-10-2024 --Port Nomination added
 08-10-2024 --Added 3 columns QuantityMin(MT), QuantityMax(MT), BDNBillingQty(MT)
 24-10-2024 --Added 4 columns Selling Price(USD), Buying Price(USD), Seller invoice sub total/total amount, Customer invoice total/subtotal amount
 11-12-2024 --Added Cancellation Status
 13-02-2025 --Modified AED values to be divided by 3.6725
 17-03-2025 --Duplicate values removed
 21-03-2025 --Amount Paid Date modified
 09-06-2025 - SellerNomination and CustomerNomination Sent On Date added
 
 Last Modifiied By - Sidharth A
 Last Modifiied On : 17-03-2025 12:20 IST
 
 Uploaded On PROD : 17-03-2025 12:25 IST
 
 */
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
StemDate AS (
    Select
        ain.InquiryDetailId,
        ain.BookedOn,
        ain.NominatedOn,
        ain.StemDate,
        ain.Id,
        ain.QuantityMax,
        ain.QuantityMin,
        ain.BuyerCreditTerms,
        ain.SellerCreditTerms,
        ain.InquirySellerDetailId,
        ain.isdeleted,
        ain.InquiryOfferId,
        ain.BuyerCreditTerms AS 'Customer Payment Terms',
        ain.SellerCreditTerms AS 'Seller Payment Terms',
        ain.GradeSpecId
    from
        AppInquiryDetails aid
        LEFT JOIN AppInquiryNominations ain ON ain.InquiryDetailId = aid.Id
    Where
        ain.IsBooked = 1
        and ain.IsNominated = 1
        and ain.IsDeleted = 0
        and ain.BookedOn is not null
),
GSData AS (
    SELECT
        'GS' AS 'Data source',
        aid.Code AS 'Job code',
        av.Name AS 'Vessel name',
        ap.Name AS 'Port name',
        CONVERT(DATE, COALESCE(ain.StemDate, ain.BookedOn)) AS 'Stem date',
        CONVERT(DATE, ain.BookedOn) AS 'Seller Nomination Sent On',
        CONVERT(DATE, ain.NominatedOn) AS 'Customer Nomination Sent On',
        CONVERT(DATE, aid.DeliveryStartDateNomination) AS 'Delivery start date',
        CONVERT(DATE, ad.DeliveryDate) AS 'Delivery date',
        COALESCE(
            asur.Name,
            agen.Name,
            asup.Name,
            abro.Name,
            aselll.Name,
            asell.Name,
            asel.Name
        ) AS 'Seller name',
        COALESCE(asuppp.Name, asupp.Name) AS 'Supplier name',
        ibc.[Seller Broker Name],
        ibc.[Customer Broker Name],
        ibc.SellerUnitLumpsum,
        ibc.SellerUnit as 'SellerBrokerUnit',
        ibc.CustomerUnitLumpsum,
        ibc.CustomerUnit as 'CustomerBrokerUnit',
        ais.InvoiceNumber AS 'Invoice number',
        CONVERT(DATE, ais.Invoicedate) AS 'Invoice date',
        CASE
            WHEN ais.InvoiceType = 0 THEN 'Invoice'
            WHEN ais.InvoiceType = 1 THEN 'Credit Note'
            WHEN ais.InvoiceType = 2 THEN 'Debit Note'
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
        CONVERT(DATE, ais.PaymentDueDate) AS 'Payment due date',
        CONVERT(DATE, ais.ExpectedDueDate) AS 'Expected Payment Date',
        CONVERT(
            DATE,
            COALESCE(ais.AmountPaidDate, ais.AcknowledgementSentOn)
        ) AS 'DatePaid',
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
        COALESCE(ais.BdnBillingQuantity, ad.BdnQty) AS 'BdnBillingQuantity',
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
                WHEN ad.BdnQtyUnit = 0 THEN COALESCE(ais.BdnBillingQuantity, ad.BdnQty) --MT
                WHEN ad.BdnQtyUnit = 1 THEN ROUND(
                    COALESCE(ais.BdnBillingQuantity, ad.BdnQty) * 0.001,
                    4
                ) --KG
                WHEN ad.BdnQtyUnit = 2 THEN ROUND(
                    COALESCE(ais.BdnBillingQuantity, ad.BdnQty) * 0.00085,
                    4
                ) --Litres
                WHEN ad.BdnQtyUnit = 3 THEN ROUND(
                    COALESCE(ais.BdnBillingQuantity, ad.BdnQty) * 0.0038641765,
                    4
                ) --IG
                WHEN ad.BdnQtyUnit = 4 THEN ROUND(
                    COALESCE(ais.BdnBillingQuantity, ad.BdnQty) * 0.85,
                    4
                ) --CBM
                WHEN ad.BdnQtyUnit = 5 THEN ROUND(
                    COALESCE(ais.BdnBillingQuantity, ad.BdnQty) * 0.0032,
                    4
                ) --US Gallons
                WHEN ad.BdnQtyUnit = 6 THEN ROUND(
                    COALESCE(ais.BdnBillingQuantity, ad.BdnQty) * 0.134,
                    4
                ) --Barrels
                WHEN ad.BdnQtyUnit = 7 THEN ROUND(
                    COALESCE(ais.BdnBillingQuantity, ad.BdnQty) * 0.85,
                    4
                ) --KL
            END
            WHEN agg.Name = 'FO' THEN CASE
                WHEN ad.BdnQtyUnit = 0 THEN COALESCE(ais.BdnBillingQuantity, ad.BdnQty) --MT
                WHEN ad.BdnQtyUnit = 1 THEN ROUND(
                    COALESCE(ais.BdnBillingQuantity, ad.BdnQty) * 0.001,
                    4
                ) --KG
                WHEN ad.BdnQtyUnit = 2 THEN ROUND(
                    COALESCE(ais.BdnBillingQuantity, ad.BdnQty) * 0.00094,
                    4
                ) --Litres
                WHEN ad.BdnQtyUnit = 3 THEN ROUND(
                    COALESCE(ais.BdnBillingQuantity, ad.BdnQty) * 0.0042733246,
                    4
                ) --IG
                WHEN ad.BdnQtyUnit = 4 THEN ROUND(
                    COALESCE(ais.BdnBillingQuantity, ad.BdnQty) * 0.94,
                    4
                ) --CBM
                WHEN ad.BdnQtyUnit = 5 THEN ROUND(
                    COALESCE(ais.BdnBillingQuantity, ad.BdnQty) * 0.0037,
                    4
                ) --US Gallons
                WHEN ad.BdnQtyUnit = 6 THEN ROUND(
                    COALESCE(ais.BdnBillingQuantity, ad.BdnQty) * 0.157,
                    4
                ) --Barrels
                WHEN ad.BdnQtyUnit = 7 THEN ROUND(
                    COALESCE(ais.BdnBillingQuantity, ad.BdnQty) * 0.94,
                    4
                ) --KL
            END
            ELSE COALESCE(ais.BdnBillingQuantity, ad.BdnQty)
        end as 'BDNQty(MT)',
        aifd.Description AS 'Fuel name',
        COALESCE(ags.Name, agss.Name) AS 'Grade spec name',
        aim.SellPrice AS 'Selling price',
        sc.Code AS 'Selling Price Currency type',
        CASE
            WHEN sc.Code = 'AED' THEN ROUND(aim.SellPrice / 3.6725, 2)
            WHEN sc.Code <> 'AED' THEN ROUND(aim.SellPriceUsd, 2)
        END AS 'Selling Price(USD)',
        COALESCE(ais.BuyPrice, aim.BuyPrice) AS 'Buying price',
        bc.Code AS 'Buying Price Currency type',
        CASE
            WHEN bc.Code = 'AED' THEN ROUND(
                COALESCE(ais.BuyPrice / 3.6725, aim.buyprice / 3.6725),
                2
            )
            WHEN bc.Code <> 'AED' THEN ROUND(
                COALESCE(ais.BuyPrice * aio.ExchangeRate, aim.buypriceusd),
                2
            )
        END AS 'Buying price(USD)',
        ibc.SellerBrokerage,
        ibc.[Seller Currency],
        ibc.[Seller Brokerage(USD)],
        ibc.[CustomerBrokerage],
        ibc.[Customer Currency],
        ibc.[Customer Brokerage(USD)],
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
        CASE
            WHEN ais.InvoiceType = 0 THEN aic.TotalAmount
            ELSE NULL
        END AS 'Customer invoice total amount',
        CASE
            WHEN ais.InvoiceType = 0
            and sc.Code = 'AED' THEN ROUND(aic.TotalAmount / 3.6725, 2)
            WHEN ais.InvoiceType = 0
            and sc.Code <> 'AED' THEN ROUND(aic.TotalAmount * aim.ExchangeRate, 2)
            ELSE NULL
        END AS 'Customer invoice total amount(USD)',
        CASE
            WHEN ais.InvoiceType = 0 THEN aic.SubTotal
            ELSE NULL
        END AS 'Customer invoice sub total',
        CASE
            WHEN ais.InvoiceType = 0
            and sc.Code = 'AED' THEN ROUND(aic.SubTotal / 3.6725, 2)
            WHEN ais.InvoiceType = 0
            and sc.Code <> 'AED' THEN ROUND(aic.SubTotal * aim.ExchangeRate, 2)
            ELSE NULL
        END AS 'Customer invoice sub total(USD)',
        CASE
            WHEN ais.InvoiceType is null THEN imc.Amount
            WHEN ais.InvoiceType = 0 THEN aic.BuyerGradeMiscCost
            ELSE NULL
        END AS 'Customer Grade Misc Cost',
        CASE
            WHEN ais.InvoiceType = 0 THEN aic.AdditionalCost
            ELSE NULL
        END AS 'CustomerInvAddlCost',
        sc.Code AS 'Customer Currency Type',
        ais.TotalAmount AS 'Seller invoice total amount',
        CASE
            WHEN bc.Code = 'AED' THEN ROUND(ais.TotalAmount / 3.6725, 2)
            WHEN bc.Code <> 'AED' THEN ROUND(ais.TotalAmount * aio.ExchangeRate, 2)
        END AS 'Seller invoice total amount(USD)',
        ais.SubTotal AS 'Seller invoice sub total',
        CASE
            WHEN bc.Code = 'AED' THEN ROUND(ais.SubTotal / 3.6725, 2)
            WHEN bc.Code <> 'AED' THEN ROUND(ais.SubTotal * aio.ExchangeRate, 2)
        END AS 'Seller invoice sub total(USD)',
        CASE
            WHEN aps.AmountPaid IS NOT NULL
            AND aps.AmountPaid <> 0 THEN ais.AmountPaidSoFar + aps.AmountPaid
            ELSE ais.AmountPaidSoFar
        END AS 'Amount paid',
        CASE
            WHEN aps.AmountPaid IS NOT NULL
            AND aps.AmountPaid <> 0 THEN CASE
                WHEN bc.Code = 'AED' THEN ROUND(ais.AmountPaidSoFar / 3.6725, 2) + ROUND(aps.AmountPaid / 3.6725, 2)
                WHEN bc.Code <> 'AED' THEN ROUND(ais.AmountPaidSoFar * aio.ExchangeRate, 2) + ROUND(aps.AmountPaid * aio.ExchangeRate, 2)
            END
            ELSE CASE
                WHEN bc.Code = 'AED' THEN ROUND(ais.AmountPaidSoFar / 3.6725, 2)
                WHEN bc.Code <> 'AED' THEN ROUND(ais.AmountPaidSoFar * aio.ExchangeRate, 2)
            END
        END AS 'Amount paid(USD)',
        COALESCE(ais.SellerGradeMiscCost, ims.Amount) AS 'Seller Grade Misc Cost',
        ais.AdditionalCost AS 'SellerInvAddlCost',
        bc.Code AS 'Seller Currency Type',
        aup.name AS 'Assignee',
        aup.UserId AS 'UserId',
        aup.Email AS 'UserEmail',
        CASE
            WHEN aifd.TradeType = 0 THEN 'spot'
            WHEN aifd.TradeType = 1 THEN 'Contract'
        END AS 'TradeType',
        COALESCE(ais.SellerPaymentTerm, ain.SellerCreditTerms) AS 'SellerPaymentTerms',
        CASE
            WHEN ais.PayableType = 0 THEN 'Not paid'
            WHEN ais.PayableType = 1 THEN 'Partly paid'
            WHEN ais.PayableType = 2 THEN 'Paid'
            ELSE 'Not paid'
        END AS 'Payment Status',
        CONVERT(date, ais.CreationTime) AS 'CreationTime',
        CONVERT(date, ais.LastModificationTime) AS 'LastModificationTime'
    FROM
        AppInquiryDetails aid
        LEFT JOIN AppVessel av ON av.id = aid.VesselNominationId
        and av.isdeleted = 0
        LEFT JOIN AppPorts ap ON ap.id = aid.portNominationId
        and ap.isdeleted = 0
        JOIN AppInquiryFuelDetails aifd ON aifd.inquirydetailid = aid.id
        and aifd.isdeleted = 0
        and aifd.islosted = 0
        JOIN AppInquirySellerDetails aisd ON aisd.InquiryFuelDetailId = aifd.id
        and aifd.sellerid = aisd.sellerid
        and aisd.isdeleted = 0
        JOIN StemDate ain ON ain.InquiryDetailId = aifd.InquiryDetailId
        and ain.IsDeleted = 0
        and ain.InquirySellerDetailId = aisd.Id
        LEFT JOIN AppDeliveries ad ON ad.InquiryFuelDetailId = aifd.Id
        and ad.isdeleted = 0
        LEFT JOIN AppSellers asel ON asel.id = aifd.SellerId
        and asel.isdeleted = 0
        LEFT JOIN AppSuppliers asup ON asup.id = aisd.SupplierId
        and asup.isdeleted = 0
        LEFT JOIN AppInquiryCancelStems aics ON aics.InquiryFuelDetailId = aifd.Id
        and aics.IsDeleted = 0
        LEFT JOIN AppFuels af ON af.id = aifd.FuelId
        and af.IsDeleted = 0
        LEFT JOIN AppGradeGroups agg ON agg.id = af.GradeGroupId
        and agg.IsDeleted = 0
        LEFT JOIN AppGradeSpecs ags ON ags.id = aifd.GradeSpecId
        and ags.IsDeleted = 0
        LEFT JOIN AppGradeSpecs agss ON agss.id = ain.GradeSpecId
        and agss.IsDeleted = 0
        LEFT JOIN AppInvoiceSellers ais ON ais.InquiryFuelDetailId = aifd.Id
        and ais.IsDeleted = 0
        LEFT JOIN AppProformaSellers aps ON aps.InquiryFuelDetailId = aifd.Id
        and aps.IsDeleted = 0
        LEFT JOIN AppSellers asell ON asell.Id = ais.SellerId
        and asell.IsDeleted = 0
        LEFT JOIN AppSellers aselll ON aselll.Id = ais.CounterpartyName
        and aselll.IsDeleted = 0
        LEFT JOIN AppBrokers abro ON abro.Id = ais.CounterpartyName
        and abro.IsDeleted = 0
        LEFT JOIN AppSurveyors asur ON asur.Id = ais.CounterpartyName
        and asur.IsDeleted = 0
        LEFT JOIN AppAgents agen ON agen.Id = ais.CounterpartyName
        and agen.IsDeleted = 0
        LEFT JOIN AppSuppliers asupp ON asupp.Id = ais.CounterpartyName
        and asupp.IsDeleted = 0
        LEFT JOIN AppSuppliers asuppp ON asuppp.Id = ais.SupplierId
        and asuppp.IsDeleted = 0
        LEFT JOIN AppInquiryMargins aim ON aim.InquirySellerDetailId = aisd.Id
        and aim.isdeleted = 0
        LEFT JOIN AppInquiryOffers aio ON aio.InquiryDetailId = aifd.InquiryDetailId
        and aio.SellerId = aifd.SellerId
        and aio.IsDeleted = 0
        LEFT JOIN AppCurrencies sc ON sc.Id = aim.CurrencyId
        and sc.isdeleted = 0
        LEFT JOIN AppCurrencies bc ON bc.Id = aio.CurrencyId
        and bc.isdeleted = 0
        LEFT JOIN AppInvoiceCustomers aic ON aic.InquiryFuelDetailId = aifd.Id
        and aic.IsDeleted = 0
        and aic.InvoiceType = 0
        LEFT JOIN AppUserProfiles aup ON aup.id = aid.UserProfileId
        and aup.isdeleted = 0
        LEFT JOIN InquiryMiscCostSeller ims ON ims.InquirySellerDetailId = aisd.Id
        and ims.InquiryDetailId = aisd.InquiryDetailId
        LEFT JOIN InquiryMiscCostCustomer imc ON imc.InquirySellerDetailId = aisd.Id
        and imc.InquiryDetailId = aisd.InquiryDetailId
        LEFT JOIN InquiryBrokerDetailsCTE ibc ON ibc.InquiryFuelDetailId = aifd.Id
        and ibc.InquiryDetailId = aid.Id
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
        NULL AS 'Seller Nomination Sent On',
        NULL AS 'Customer Nomination Sent On',
        CONVERT(date, DeliveryStartDate) AS 'Delivery start date',
        CONVERT(date, DeliveryDate) AS 'Delivery date',
        SellerName AS 'Seller name',
        SupplierName AS 'Supplier name',
        NULL AS [Seller Broker Name],
        NULL AS [Customer Broker Name],
        NULL AS SellerUnitLumpsum,
        NULL AS SellerBrokerUnit,
        NULL AS CustomerUnitLumpsum,
        NULL AS CustomerBrokerUnit,
        InvoiceNumber AS 'Invoice number',
        CONVERT(date, InvoiceDate) AS 'Invoice date',
        NULL AS 'InvoiceType',
        JobStatus AS 'Job status',
        NULL AS 'Cancellation Status',
        CONVERT(date, InquiryReceivedDate) AS 'Inquiry recieved date',
        CONVERT(date, PaymentDueDate) AS 'Payment due date',
        NULL AS 'Expected Payment Date',
        --CONVERT(date, DatePaid) AS 'Date paid',
        CASE
            WHEN DatePaid = 'N\A' THEN NULL
            ELSE DatePaid
        END AS DatePaid,
        --Converted the 'N\A' values into NULL so that the union would be satisfied.
        QuantityMin AS 'Quantity min',
        NULL AS 'Quantity min(MT)',
        QuantityMax AS 'Quantity max',
        NULL AS 'Quantity max(MT)',
        BdnBillingQuantity,
        NULL AS 'BDN Unit',
        NULL AS 'BDNQty(MT)',
        FuelName AS 'Fuel name',
        GradeSpecName AS 'Grade spec name',
        SellingPrice AS 'Selling price',
        NULL as 'Selling Price Currency type',
        NULL AS 'Selling Price(USD)',
        BuyingPrice AS 'Buying price',
        NULL as 'Buying Price Currency type',
        NULL AS 'Buying price(USD)',
        NULL AS SellerBrokerage,
        NULL AS [Seller Currency],
        NULL AS [Seller Brokerage(USD)],
        NULL AS [CustomerBrokerage],
        NULL AS [Customer Currency],
        NULL AS [Customer Brokerage(USD)],
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
        NULL AS 'Amount paid',
        NULL AS 'Amount paid(USD)',
        (
            MiscCostItemOneAmount + MiscCostItemTwoAmount + MiscCostItemThreeAmount + MiscCostItemFourAmount + MiscCostItemFiveAmount
        ) as 'Seller Grade Misc Cost',
        --new
        NULL as 'SellerInvAddlCost',
        --new
        NULL as 'Seller Currency Type',
        Assignee,
        NULL AS 'UserId',
        NULL AS 'UserEmail',
        TradeType,
        CASE
            WHEN TRY_CAST(sellerpaymentterms AS INT) IS NOT NULL THEN CAST(sellerpaymentterms AS INT)
            ELSE NULL
        END AS 'SellerPaymentTerms',
        NULL AS 'Payment Status',
        CONVERT(date, CreationTime) AS 'CreationTime',
        CONVERT(date, LastModificationTime) AS 'LastModificationTime' --IsDeleted,
        --CONVERT(date, DeletionTime) AS 'DeletionTime'
    FROM
        AppHistoricalPurchaseData
),
UNIONALLCTE AS (
    Select
        *
    from
        HistoricalData
    UNION
    ALL
    Select
        *
    from
        GSData
)
Select
    *
from
    UNIONALLCTE --where [Data source] = 'GS' and DatePaid is null and [Payment Status] = 'Paid'