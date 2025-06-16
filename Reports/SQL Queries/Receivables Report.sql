/*
 
 29-08-2024 - Receivables report
 One Invoice One Line
 Does Not include CIA
 
 Ticket : Payables and Receivables - Line items
 
 --Added Port Nomination logic
 24-10-2024 --Base currency
 
 
 Updated By : Sidharth A
 Updated On : 24-10-2024 11:30 IST
 
 Uploaded On PROD : 07-11-2024 06:32 IST
 
 --14-01-2025 - Changes Made - Overdue days set to 0 when invoice status is received
 --04-08-2025 - Changes Made - Accounted for Merged Customers
 
 Updated ON UAT: 04-03-2025 10:58 IST
 Receivables and Payables report - Invoice date
 
 */
WITH BookedAndPartlyBookedCTE AS(
    Select
        Id,
        InquirySellerDetailId,
        InquiryDetailId,
        BuyerCreditTerms,
        QuantityMax,
        BuyerPaymentTerm
    from
        AppInquiryNominations
    where
        InquirySellerDetailId IN (
            Select
                Id
            from
                AppInquirySellerDetails
            where
                InquiryFuelDetailId IN (
                    Select
                        Id
                    from
                        AppInquiryFuelDetails
                    where
                        IsDelivered = 0
                        and IsDeleted = 0
                        and IsCancelled = 0
                )
                and IsDeleted = 0
        )
        and IsNominated = 1
        and IsDeleted = 0
        and isBooked = 1
),
FirstRecordPerCustomer AS (
    SELECT
        accc.Id,
        accc.CustomerId,
        aff.Name AS 'Financing Facility',
        ROW_NUMBER() OVER (
            PARTITION BY accc.CustomerId
            ORDER BY
                accc.CreationTime ASC
        ) AS RowNum
    FROM
        AppCustomerCreditCompliances accc
        LEFT JOIN AppFinancingFacilites aff ON aff.Id = accc.FinancingFacilityId
        and aff.IsDeleted = 0
    WHERE
        accc.IsDeleted = 0
),
BuyerMiscCost AS (
    SELECT
        InquiryDetailId,
        SUM(AmountUsd) AS BuyerMiscCost
    FROM
        AppInquiryMiscCosts
    WHERE
        FromBuyer = 1
    GROUP BY
        InquiryDetailId
),
CustomerInvoiceModified AS (
    SELECT
        aid.Code,
        aifd.[Description],
        ROW_NUMBER() OVER (
            PARTITION BY aic.InvoiceCode,
            aid.code
            ORDER BY
                aifd.Description
        ) AS [Rank],
        aic.*
    FROM
        AppInvoiceCustomers aic
        JOIN AppInquiryFuelDetails aifd ON aifd.Id = aic.InquiryFuelDetailId
        and aifd.IsDeleted = 0
        and aifd.IsLosted = 0
        JOIN AppInquiryDetails aid ON aid.Id = aic.InquiryDetailId
        and aid.IsDeleted = 0
    WHERE
        MergeCode IS NOT NULL
),
Query1 AS (
    Select
        ac.Name as 'Customer Name',
        acg.Name as 'Customer Group',
        frpc.[Financing Facility],
        aid.Code AS 'Job Number',
        --CASE 
        --	WHEN bpb.BuyerPaymentTerm = 2 THEN apc.InvoiceNumber
        --	WHEN bpb.BuyerPaymentTerm <> 2 THEN NULL
        --      END AS 'Invoice Number',
        NULL AS 'Invoice Number',
        --CASE 
        --	WHEN bpb.BuyerPaymentTerm = 2 THEN CONVERT(DATE, apc.PaymentDueDate)
        --	WHEN bpb.BuyerPaymentTerm <> 2 THEN CONVERT(DATE, DATEADD(DAY, bpb.BuyerCreditTerms, aid.DeliveryStartDateNomination))
        --      END AS 'Payment Due Date',
        CONVERT(
            DATE,
            DATEADD(
                DAY,
                bpb.BuyerCreditTerms,
                aid.DeliveryStartDateNomination
            )
        ) AS 'Payment Due Date',
        NULL AS 'Invoice Date',
        --DATEDIFF(DAY, CONVERT(DATE, DATEADD(DAY, bpb.BuyerCreditTerms, aid.DeliveryStartDateNomination)), GETDATE()) as 'Overdue days',
        --CASE 
        --	WHEN bpb.BuyerPaymentTerm = 2 THEN DATEDIFF(DAY, CONVERT(DATE,apc.PaymentDueDate), GETDATE())
        --	WHEN bpb.BuyerPaymentTerm <> 2 THEN DATEDIFF(DAY, CONVERT(DATE, DATEADD(DAY, bpb.BuyerCreditTerms,aid.DeliveryStartDateNomination)), GETDATE())
        --      END AS 'Overdue days',
        NULL AS 'Overdue days',
        CASE
            --WHEN bpb.BuyerPaymentTerm = 2 THEN ROUND(apc.BalanceDue,2)
            WHEN bmc.BuyerMiscCost IS NULL THEN ROUND(bpb.QuantityMax * aim.SellPrice, 2)
            WHEN bmc.BuyerMiscCost IS NOT NULL THEN ROUND(
                bpb.QuantityMax * aim.SellPrice + bmc.BuyerMiscCost,
                2
            )
        END AS 'Outstanding Amount',
        CASE
            -- WHEN bpb.BuyerPaymentTerm = 2 THEN ROUND(apc.BalanceDue, 2)
            WHEN bmc.BuyerMiscCost IS NULL THEN CASE
                WHEN acur.Code = 'AED' THEN ROUND(bpb.QuantityMax * aim.SellPrice / 3.6725, 2)
                ELSE ROUND(bpb.QuantityMax * aim.SellPriceUsd, 2)
            END
            WHEN bmc.BuyerMiscCost IS NOT NULL THEN CASE
                WHEN acur.Code = 'AED' THEN ROUND(
                    (
                        bpb.QuantityMax * aim.SellPrice + bmc.BuyerMiscCost
                    ) / 3.6725,
                    2
                )
                ELSE ROUND(
                    bpb.QuantityMax * aim.SellPriceUsd + bmc.BuyerMiscCost,
                    2
                )
            END
        END AS 'Outstanding Amount(USD)',
        CASE
            --WHEN bpb.BuyerPaymentTerm = 2 THEN ROUND(apc.TotalAmount,2)
            WHEN bmc.BuyerMiscCost IS NULL THEN ROUND(bpb.QuantityMax * aim.SellPrice, 2)
            WHEN bmc.BuyerMiscCost IS NOT NULL THEN ROUND(
                bpb.QuantityMax * aim.SellPrice + bmc.BuyerMiscCost,
                2
            )
        END AS 'Invoice Amount',
        CASE
            -- WHEN bpb.BuyerPaymentTerm = 2 THEN ROUND(apc.TotalAmount, 2)
            WHEN bmc.BuyerMiscCost IS NULL THEN CASE
                WHEN acur.Code = 'AED' THEN ROUND(bpb.QuantityMax * aim.SellPrice / 3.6725, 2)
                ELSE ROUND(bpb.QuantityMax * aim.SellPriceUsd, 2)
            END
            WHEN bmc.BuyerMiscCost IS NOT NULL THEN CASE
                WHEN acur.Code = 'AED' THEN ROUND(
                    (
                        bpb.QuantityMax * aim.SellPrice + bmc.BuyerMiscCost
                    ) / 3.6725,
                    2
                )
                ELSE ROUND(
                    bpb.QuantityMax * aim.SellPriceUsd + bmc.BuyerMiscCost,
                    2
                )
            END
        END AS 'Invoice Amount(USD)',
        --CASE 
        --	WHEN bpb.BuyerPaymentTerm = 2 THEN ROUND(apc.AmountReceived,2)
        --	WHEN bpb.BuyerPaymentTerm <> 2 THEN NULL
        --      END AS 'Amount Received So Far',
        NULL AS 'Amount Received So Far',
        NULL AS 'Amount Received So Far(USD)',
        av.Name as 'Vessel',
        ap.Name as 'Port Name',
        aup.Name as 'Assignee',
        CONVERT(DATE, aid.DeliveryStartDateNomination) AS 'Delivery Date',
        NULL AS 'Expected Payment Received Date',
        CASE
            WHEN aim.CurrencyId IS NOT NULL THEN acur.Code
        END AS 'Currency',
        'Uninvoiced' AS 'Invoice Status',
        NULL AS 'Cancellation Status',
        CASE
            --WHEN bpb.BuyerPaymentTerm = 2 THEN 'Booked (CIA)'
            WHEN aid.InquiryStatus = 0 THEN 'Draft'
            WHEN aid.InquiryStatus = 100 THEN 'Raised By Client'
            WHEN aid.InquiryStatus = 200 THEN 'Sent For Approval'
            WHEN aid.InquiryStatus = 300 THEN 'Rejected'
            WHEN aid.InquiryStatus = 400 THEN 'Approved'
            WHEN aid.InquiryStatus = 500 THEN 'PreApproved'
            WHEN aid.InquiryStatus = 600 THEN 'Auction'
            WHEN aid.InquiryStatus = 700 THEN 'Partly Booked'
            WHEN aid.InquiryStatus = 800 THEN 'Booked'
            WHEN aid.InquiryStatus = 900 THEN 'Partly Delivered'
            WHEN aid.InquiryStatus = 1000 THEN 'Delivered'
            WHEN aid.InquiryStatus = 1500 THEN 'LostStem' --WHEN aifd.IsCancelled = 1 THEN 'Cancelled'
            WHEN aid.InquiryStatus = 9000 THEN 'Cancelled'
            WHEN aid.InquiryStatus = 10000 THEN 'Invoiced'
            WHEN aid.InquiryStatus = 15000 THEN 'Closed'
        END AS 'Job Status'
    from
        BookedAndPartlyBookedCTE bpb
        JOIN AppInquiryMargins aim ON aim.InquirySellerDetailId = bpb.InquirySellerDetailId
        and aim.IsDeleted = 0 --LEFT JOIN AppInquiryFuelDetails aifd ON aifd.Id = aim.InquiryDetailId
        LEFT JOIN AppProformaCustomers apc ON apc.InquiryNominationId = bpb.Id
        AND apc.IsDeleted = 0
        JOIN AppInquiryDetails aid ON aid.Id = bpb.InquiryDetailId
        LEFT JOIN BuyerMiscCost bmc ON bmc.InquiryDetailId = aid.Id
        JOIN AppCustomers ac ON ac.Id = aid.CustomerNominationId
        LEFT JOIN AppCustomerGroups acg ON acg.Id = ac.CustomerGroupId
        LEFT JOIN FirstRecordPerCustomer frpc ON frpc.CustomerId = ac.Id
        and frpc.RowNum = 1
        JOIN AppVessel av ON av.Id = aid.VesselNominationId
        JOIN AppPorts ap ON ap.Id = aid.PortNominationId
        JOIN AppUserProfiles aup ON aup.Id = aid.UserProfileId
        JOIN AppCurrencies acur ON aim.CurrencyId = acur.Id
    where
        aid.InquiryStatus = 700
        or aid.InquiryStatus = 800
        or aid.InquiryStatus = 900
        or aid.InquiryStatus = 1000
),
Query2 AS (
    SELECT
        DISTINCT acus.Name AS CustomerName,
        acg.Name AS CustomerGroup,
        frpc.[Financing Facility],
        aid.Code AS JobNumber,
        aic.InvoiceCode AS InvoiceNumber,
        CONVERT(DATE, aic.PaymentDueDate) AS PaymentDueDate,
        CONVERT(DATE, aic.ApprovedOn) AS InvoiceDate,
        DATEDIFF(day, aic.PaymentDueDate, GETDATE()) AS OverdueDays,
        ROUND(aic.BalanceDue, 2) AS OutstandingAmount,
        CASE
            WHEN acur.Code = 'AED' THEN ROUND(aic.BalanceDue / 3.6725, 2)
            WHEN acur.code <> 'AED' THEN ROUND(aic.BalanceDue * aim.ExchangeRate, 2)
        END AS 'OutstandingAmount(USD)',
        ROUND(aic.TotalAmount, 2) AS InvoiceAmount,
        CASE
            WHEN acur.Code = 'AED' THEN ROUND(aic.TotalAmount / 3.6725, 2)
            WHEN acur.Code <> 'AED' THEN ROUND(aic.TotalAmount * aim.ExchangeRate, 2)
        END AS 'InvoiceAmount(USD)',
        CASE
            WHEN aic.AmountReceivedSoFar IS NULL THEN CASE
                WHEN apc.AmountReceived IS NULL THEN aic.TotalAmount - aic.BalanceDue
                WHEN apc.AmountReceived IS NOT NULL THEN aic.TotalAmount - (aic.BalanceDue + apc.AmountReceived)
            END
            ELSE aic.AmountReceivedSoFar
        END AS 'Amount Received So Far',
        CASE
            WHEN acur.Code = 'AED' THEN CASE
                WHEN aic.AmountReceivedSoFar IS NULL THEN CASE
                    WHEN apc.AmountReceived IS NULL THEN ROUND((aic.TotalAmount - (aic.BalanceDue)) / 3.6725, 2)
                    WHEN apc.AmountReceived IS NOT NULL THEN ROUND(
                        (
                            aic.TotalAmount - (aic.BalanceDue + apc.AmountReceived)
                        ) / 3.6725,
                        2
                    )
                END
                ELSE ROUND(aic.AmountReceivedSoFar / 3.6725, 2)
            END
            WHEN acur.Code <> 'AED' THEN CASE
                WHEN aic.AmountReceivedSoFar IS NULL THEN CASE
                    WHEN apc.AmountReceived IS NULL THEN ROUND(
                        (aic.TotalAmount - (aic.BalanceDue)) * aim.ExchangeRate,
                        2
                    )
                    WHEN apc.AmountReceived IS NOT NULL THEN ROUND(
                        (
                            aic.TotalAmount - (aic.BalanceDue + apc.AmountReceived)
                        ) * aim.ExchangeRate,
                        2
                    )
                END
                ELSE ROUND(aic.AmountReceivedSoFar * aim.ExchangeRate, 2)
            END
        END AS 'Amount Received So Far(USD)',
        av.Name AS Vessel,
        ap.Name AS PortName,
        aup.Name AS Assignee,
        CONVERT(DATE, ad.DeliveryDate) AS DeliveryDate,
        CONVERT(DATE, aic.ExpectedDueDate) AS ExpectedPaymentReceivedDate,
        CASE
            WHEN aim.CurrencyId IS NOT NULL THEN acur.Code
        END AS Currency,
        CASE
            WHEN aic.InvoiceType IS NULL THEN 'Uninvoiced'
            WHEN aic.InvoiceStatus = 0 THEN 'Uninvoiced'
            WHEN aic.InvoiceStatus = 10 THEN 'Invoice Created'
            WHEN aic.InvoiceStatus = 20 THEN 'Pending Approval'
            WHEN aic.InvoiceStatus = 30 THEN 'Invoice Approved'
            WHEN aic.InvoiceStatus = 40 THEN 'Invoice Sent'
            WHEN aic.InvoiceStatus = 50 THEN 'Partly Received'
            WHEN aic.InvoiceStatus = 60 THEN 'Received'
        END AS InvoiceStatus,
        CASE
            WHEN aics.CancelTypes = 0 THEN 'With Penalty'
            WHEN aics.CancelTypes = 1 THEN 'Without Penalty'
        END AS 'Cancellation Status',
        CASE
            WHEN aid.InquiryStatus = 0 THEN 'Draft'
            WHEN aid.InquiryStatus = 100 THEN 'Raised By Client'
            WHEN aid.InquiryStatus = 200 THEN 'Sent For Approval'
            WHEN aid.InquiryStatus = 300 THEN 'Rejected'
            WHEN aid.InquiryStatus = 400 THEN 'Approved'
            WHEN aid.InquiryStatus = 500 THEN 'PreApproved'
            WHEN aid.InquiryStatus = 600 THEN 'Auction'
            WHEN aid.InquiryStatus = 700 THEN 'Partly Booked'
            WHEN aid.InquiryStatus = 800 THEN 'Booked'
            WHEN aid.InquiryStatus = 900 THEN 'Partly Delivered'
            WHEN aid.InquiryStatus = 1000 THEN 'Delivered'
            WHEN aid.InquiryStatus = 1500 THEN 'LostStem'
            WHEN aid.InquiryStatus = 9000 THEN 'Cancelled'
            WHEN aid.InquiryStatus = 10000 THEN 'Invoiced'
            WHEN aid.InquiryStatus = 15000 THEN 'Closed'
        END AS 'Job Status'
    FROM
        AppInquiryDetails aid
        JOIN AppInquiryFuelDetails aifd ON aifd.InquiryDetailId = aid.Id
        LEFT JOIN AppInquiryCancelStems aics ON aifd.Id = aics.InquiryFuelDetailId
        and aics.CancelTypes = 0
        JOIN AppCustomers acus ON acus.Id = aid.CustomerNominationId
        LEFT JOIN AppCustomerGroups acg ON acg.id = acus.CustomerGroupId
        LEFT JOIN FirstRecordPerCustomer frpc ON frpc.CustomerId = acus.Id
        and frpc.RowNum = 1
        LEFT JOIN AppCustomerCreditCompliances accc ON acus.Id = accc.CustomerId
        and accc.IsDeleted = 0
        LEFT JOIN CustomerInvoiceModified aic ON aic.InquiryFuelDetailId = aifd.Id
        and aic.IsDeleted = 0
        and aic.Rank = 1
        LEFT JOIN AppProformaCustomers apc ON apc.inquiryfueldetailid = aic.InquiryFuelDetailId
        and aic.IsDeleted = 0 --test
        JOIN AppVessel av ON av.Id = aid.VesselNominationId
        JOIN AppPorts ap ON ap.Id = aid.PortNominationId
        JOIN AppUserProfiles aup ON aid.UserProfileId = aup.Id
        LEFT JOIN AppDeliveries ad ON ad.InquiryFuelDetailId = aic.InquiryFuelDetailId
        LEFT JOIN AppInquiryMargins aim ON aim.InquiryDetailId = aifd.InquiryDetailId
        JOIN AppCurrencies acur ON aim.CurrencyId = acur.Id
        and aim.Id = aic.InquiryMarginId
    where
        aid.InquiryStatus = 700
        or aid.InquiryStatus = 800
        or aid.InquiryStatus = 900
        or aid.InquiryStatus = 1000
        or aid.InquiryStatus = 9000
        and aics.CancelTypes = 0
        and aics.IsDeleted = 0
),
Query3 AS (
    SELECT
        DISTINCT acus.Name AS CustomerName,
        acg.Name AS CustomerGroup,
        frpc.[Financing Facility],
        aid.Code AS JobNumber,
        aic.InvoiceCode AS InvoiceNumber,
        CONVERT(DATE, aic.PaymentDueDate) AS PaymentDueDate,
        CONVERT(DATE, aic.ApprovedOn) AS InvoiceDate,
        DATEDIFF(day, aic.PaymentDueDate, GETDATE()) AS OverdueDays,
        ROUND(aic.BalanceDue, 2) AS OutstandingAmount,
        CASE
            WHEN acur.Code = 'AED' THEN ROUND(aic.BalanceDue / 3.6725, 2)
            WHEN acur.code <> 'AED' THEN ROUND(aic.BalanceDue * aim.ExchangeRate, 2)
        END AS 'OutstandingAmount(USD)',
        ROUND(aic.TotalAmount, 2) AS InvoiceAmount,
        CASE
            WHEN acur.Code = 'AED' THEN ROUND(aic.TotalAmount / 3.6725, 2)
            WHEN acur.Code <> 'AED' THEN ROUND(aic.TotalAmount * aim.ExchangeRate, 2)
        END AS 'InvoiceAmount(USD)',
        CASE
            WHEN aic.AmountReceivedSoFar IS NULL THEN CASE
                WHEN apc.AmountReceived IS NULL THEN aic.TotalAmount - aic.BalanceDue
                WHEN apc.AmountReceived IS NOT NULL THEN aic.TotalAmount - (aic.BalanceDue + apc.AmountReceived)
            END
            ELSE aic.AmountReceivedSoFar
        END AS 'Amount Received So Far',
        CASE
            WHEN acur.Code = 'AED' THEN CASE
                WHEN aic.AmountReceivedSoFar IS NULL THEN CASE
                    WHEN apc.AmountReceived IS NULL THEN ROUND((aic.TotalAmount - (aic.BalanceDue)) / 3.6725, 2)
                    WHEN apc.AmountReceived IS NOT NULL THEN ROUND(
                        (
                            aic.TotalAmount - (aic.BalanceDue + apc.AmountReceived)
                        ) / 3.6725,
                        2
                    )
                END
                ELSE ROUND(aic.AmountReceivedSoFar / 3.6725, 2)
            END
            WHEN acur.Code <> 'AED' THEN CASE
                WHEN aic.AmountReceivedSoFar IS NULL THEN CASE
                    WHEN apc.AmountReceived IS NULL THEN ROUND(
                        (aic.TotalAmount - (aic.BalanceDue)) * aim.ExchangeRate,
                        2
                    )
                    WHEN apc.AmountReceived IS NOT NULL THEN ROUND(
                        (
                            aic.TotalAmount - (aic.BalanceDue + apc.AmountReceived)
                        ) * aim.ExchangeRate,
                        2
                    )
                END
                ELSE ROUND(aic.AmountReceivedSoFar * aim.ExchangeRate, 2)
            END
        END AS 'Amount Received So Far(USD)',
        av.Name AS Vessel,
        ap.Name AS PortName,
        aup.Name AS Assignee,
        CONVERT(DATE, ad.DeliveryDate) AS DeliveryDate,
        CONVERT(DATE, aic.ExpectedDueDate) AS ExpectedPaymentReceivedDate,
        CASE
            WHEN aim.CurrencyId IS NOT NULL THEN acur.Code
        END AS Currency,
        CASE
            WHEN aic.InvoiceType IS NULL THEN 'Uninvoiced'
            WHEN aic.InvoiceStatus = 0 THEN 'Uninvoiced'
            WHEN aic.InvoiceStatus = 10 THEN 'Invoice Created'
            WHEN aic.InvoiceStatus = 20 THEN 'Pending Approval'
            WHEN aic.InvoiceStatus = 30 THEN 'Invoice Approved'
            WHEN aic.InvoiceStatus = 40 THEN 'Invoice Sent'
            WHEN aic.InvoiceStatus = 50 THEN 'Partly Received'
            WHEN aic.InvoiceStatus = 60 THEN 'Received'
        END AS InvoiceStatus,
        CASE
            WHEN aics.CancelTypes = 0 THEN 'With Penalty'
            WHEN aics.CancelTypes = 1 THEN 'Without Penalty'
        END AS 'Cancellation Status',
        CASE
            WHEN aid.InquiryStatus = 0 THEN 'Draft'
            WHEN aid.InquiryStatus = 100 THEN 'Raised By Client'
            WHEN aid.InquiryStatus = 200 THEN 'Sent For Approval'
            WHEN aid.InquiryStatus = 300 THEN 'Rejected'
            WHEN aid.InquiryStatus = 400 THEN 'Approved'
            WHEN aid.InquiryStatus = 500 THEN 'PreApproved'
            WHEN aid.InquiryStatus = 600 THEN 'Auction'
            WHEN aid.InquiryStatus = 700 THEN 'Partly Booked'
            WHEN aid.InquiryStatus = 800 THEN 'Booked'
            WHEN aid.InquiryStatus = 900 THEN 'Partly Delivered'
            WHEN aid.InquiryStatus = 1000 THEN 'Delivered'
            WHEN aid.InquiryStatus = 1500 THEN 'LostStem'
            WHEN aid.InquiryStatus = 9000 THEN 'Cancelled'
            WHEN aid.InquiryStatus = 10000 THEN 'Invoiced'
            WHEN aid.InquiryStatus = 15000 THEN 'Closed'
        END AS 'Job Status'
    FROM
        AppInquiryDetails aid
        JOIN AppInquiryFuelDetails aifd ON aifd.InquiryDetailId = aid.Id
        LEFT JOIN AppInquiryCancelStems aics ON aifd.Id = aics.InquiryFuelDetailId
        and aics.CancelTypes = 0
        JOIN AppCustomers acus ON acus.Id = aid.CustomerNominationId
        LEFT JOIN AppCustomerGroups acg ON acg.id = acus.CustomerGroupId
        LEFT JOIN FirstRecordPerCustomer frpc ON frpc.CustomerId = acus.Id
        and frpc.RowNum = 1
        LEFT JOIN AppCustomerCreditCompliances accc ON acus.Id = accc.CustomerId
        and accc.IsDeleted = 0
        LEFT JOIN AppInvoiceCustomers aic ON aic.InquiryFuelDetailId = aifd.Id
        and aic.IsDeleted = 0
        and aic.MergeCode IS NULL
        LEFT JOIN AppProformaCustomers apc ON apc.inquiryfueldetailid = aic.InquiryFuelDetailId
        and aic.IsDeleted = 0 --test
        JOIN AppVessel av ON av.Id = aid.VesselNominationId
        JOIN AppPorts ap ON ap.Id = aid.PortNominationId
        JOIN AppUserProfiles aup ON aid.UserProfileId = aup.Id
        LEFT JOIN AppDeliveries ad ON ad.InquiryFuelDetailId = aic.InquiryFuelDetailId
        LEFT JOIN AppInquiryMargins aim ON aim.InquiryDetailId = aifd.InquiryDetailId
        JOIN AppCurrencies acur ON aim.CurrencyId = acur.Id
        and aim.Id = aic.InquiryMarginId
    where
        aid.InquiryStatus = 700
        or aid.InquiryStatus = 800
        or aid.InquiryStatus = 900
        or aid.InquiryStatus = 1000
        or aid.InquiryStatus = 9000
        and aics.CancelTypes = 0
        and aics.IsDeleted = 0
),
unionquery AS (
    SELECT
        *
    FROM
        Query1
    UNION
    Select
        *
    FROM
        Query2
    UNION
    Select
        *
    FROM
        Query3
),
--Select 
--	* 
--from unionquery
--ORDER BY CAST(SUBSTRING([Job Number], 2, LEN([Job Number]) - 1) AS INT) DESC
CombinedDateRanked AS (
    SELECT
        *,
        -- Payment Due Date rankings
        ROW_NUMBER() OVER (
            PARTITION BY COALESCE([Invoice Number], [Job Number]) -- Use Job Number when Invoice Number is NULL
            ORDER BY
                [Payment Due Date] ASC
        ) AS PaymentDueDateRank,
        MIN([Payment Due Date]) OVER (
            PARTITION BY COALESCE([Invoice Number], [Job Number]) -- Use Job Number when Invoice Number is NULL
        ) AS MinPaymentDueDate,
        -- Invoice Date rankings
        ROW_NUMBER() OVER (
            PARTITION BY COALESCE([Invoice Number], [Job Number]) -- Use Job Number when Invoice Number is NULL
            ORDER BY
                [Invoice Date] ASC
        ) AS InvoiceDateRank,
        MIN([Invoice Date]) OVER (
            PARTITION BY COALESCE([Invoice Number], [Job Number]) -- Use Job Number when Invoice Number is NULL
        ) AS MinInvoiceDate
    FROM
        unionquery
),
AggregatedData AS (
    SELECT
        [Customer Name],
        [Customer Group],
        [Financing Facility],
        [Job Number],
        [Invoice Number],
        -- Use MinPaymentDueDate directly for grouping purposes
        MinPaymentDueDate AS [Payment Due Date],
        MinInvoiceDate AS [Invoice Date],
        DATEDIFF(day, MinPaymentDueDate, GETDATE()) AS [Overdue days],
        -- Calculate Overdue days based on MinPaymentDueDate
        SUM([Outstanding Amount]) AS [Outstanding Amount],
        -- Sum Outstanding Amount
        SUM([Outstanding Amount(USD)]) AS [Outstanding Amount(USD)],
        -- Sum Outstanding Amount(USD)
        SUM([Invoice Amount]) AS [Invoice Amount],
        -- Sum Invoice Amount
        SUM([Invoice Amount(USD)]) AS [Invoice Amount(USD)],
        -- Sum Invoice Amount(USD)
        SUM([Amount Received So Far]) AS [Amount Received So Far],
        -- Sum Amount Received So Far
        SUM([Amount Received So Far(USD)]) AS [Amount Received So Far(USD)],
        -- Sum Amount Received So Far
        -- For Delivery Date, pick the value corresponding to the MinPaymentDueDate
        MAX(
            CASE
                WHEN [Payment Due Date] = MinPaymentDueDate THEN [Delivery Date]
                WHEN [Payment Due Date] <> MinPaymentDueDate THEN [Delivery Date]
            END
        ) AS [Delivery Date],
        --MAX(CASE WHEN [Payment Due Date] = MinPaymentDueDate THEN [Expected Payment Received Date] END) AS [Expected Payment Received Date], 
        [Expected Payment Received Date],
        [Currency],
        [Invoice Status],
        [Cancellation Status],
        [Job Status],
        [Vessel],
        [Port Name],
        [Assignee]
    FROM
        CombinedDateRanked
    GROUP BY
        [Customer Name],
        [Financing Facility],
        [Customer Group],
        [Job Number],
        [Invoice Number],
        MinPaymentDueDate,
        -- Include MinPaymentDueDate in the GROUP BY clause
        MinInvoiceDate,
        [Expected Payment Received Date],
        [Currency],
        [Invoice Status],
        [Cancellation Status],
        [Job Status],
        [Vessel],
        [Port Name],
        [Assignee]
)
SELECT
    [Customer Name],
    [Customer Group],
    [Financing Facility],
    [Job Number],
    [Invoice Number],
    [Payment Due Date],
    [Invoice Date],
    CASE
        WHEN [Job Status] = 'Booked'
        OR [Job Status] = 'Partly Booked' THEN NULL
        WHEN [Invoice Status] = 'Received' THEN 0
        ELSE [Overdue days]
    END AS 'Overdue days',
    [Outstanding Amount],
    [Outstanding Amount(USD)],
    [Invoice Amount],
    [Invoice Amount(USD)],
    [Amount Received So Far],
    [Amount Received So Far(USD)],
    [Delivery Date],
    [Expected Payment Received Date],
    [Currency],
    [Vessel],
    [Port Name],
    [Assignee],
    [Invoice Status],
    [Cancellation Status],
    [Job Status],
    COALESCE(
        [Expected Payment Received Date],
        [Payment Due Date]
    ) AS 'Filter Date'
FROM
    AggregatedData
ORDER BY
    CAST(
        SUBSTRING([Job Number], 2, LEN([Job Number]) - 1) AS INT
    ) DESC