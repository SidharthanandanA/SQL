/*
 
 29-08-2024 - Payables report
 One Invoice One Line
 Does Not include CIA
 
 Ticket : Payables and Receivables - Line items
 
 --Added Port Nomination logic
 24-10-2024 --Base currency
 
 Updated By : Sidharth A
 Updated On : 09-04-2024 05:30 IST
 
 Uploaded On UAT: 29-10-2024 14:45 IST
 --14-01-2025 - Changes Made - Overdue days set to 0 when invoice status is Paid
 --09-04-2024 - Changes Made - Broker Name added
 
 Updated ON UAT: 14-02-2025 12:19 IST
 Receivables and Payables report - Invoice date
 
 05-05-2025 - Added CustomerGroupName to this
 18-06-2025 - Updated logics for Amount Paid So Far and Outstanding Amounts
 19-06-2025 - For cancelled stems, update delivery date as the approved on date
 
 */
WITH BookedAndPartlyBookedCTE AS(
    Select
        Id,
        InquirySellerDetailId,
        InquiryDetailId,
        SellerCreditTerms,
        QuantityMax,
        SellerPaymentTerm
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
        and IsBooked = 1
),
SellerMiscCost AS (
    SELECT
        InquiryDetailId,
        SUM(AmountUsd) AS SellerMiscCost
    FROM
        AppInquiryMiscCosts
    WHERE
        ToSeller = 1
    GROUP BY
        InquiryDetailId
),
SellerInvoiceModifed AS (
    SELECT
        aifd.[Description],
        ROW_NUMBER() OVER (
            PARTITION BY aic.InvoiceNumber,
            aid.code
            ORDER BY
                aifd.Description
        ) AS [Rank],
        aic.*
    FROM
        AppInvoiceSellers aic
        JOIN AppInquiryFuelDetails aifd ON aifd.Id = aic.InquiryFuelDetailId
        and aifd.IsDeleted = 0
        and aifd.IsLosted = 0
        JOIN AppInquiryDetails aid ON aid.Id = aic.InquiryDetailId
        and aid.IsDeleted = 0
),
BookedInvoices AS (
    SELECT
        DISTINCT asel.Name as 'Seller Name',
        acg.Name as 'Customer Group Name',
        ab.Name AS 'Broker Name',
        asg.Name as 'Seller Group',
        aid.Code AS 'Job Number',
        NULL AS 'Seller Invoice Number',
        CASE
            WHEN aps.PaymentDueDate IS NULL THEN CONVERT(
                DATE,
                DATEADD(
                    DAY,
                    bpb.SellerCreditTerms,
                    aid.DeliveryStartDateNomination
                )
            )
            ELSE CONVERT(DATE, aps.PaymentDueDate)
        END AS 'Payment Due Date',
        NULL AS 'Invoice Date',
        NULL AS 'Overdue days',
        CASE
            WHEN aps.BalanceDue IS NOT NULL
            AND (
                aifd.IsDelivered = 0
                OR aifd.IsCancelled = 1
            ) THEN ROUND(aps.BalanceDue, 2)
            WHEN smc.SellerMiscCost IS NULL
            AND (
                aifd.IsDelivered = 0
                OR aifd.IsCancelled = 1
            ) THEN bpb.QuantityMax * aim.BuyPrice
            WHEN smc.SellerMiscCost IS NOT NULL
            AND (
                aifd.IsDelivered = 0
                OR aifd.IsCancelled = 1
            ) THEN bpb.QuantityMax * aim.BuyPrice + smc.SellerMiscCost
            ELSE 0
        END AS 'Outstanding Amount',
        CASE
            WHEN aps.BalanceDue IS NOT NULL
            AND (
                aifd.IsDelivered = 0
                OR aifd.IsCancelled = 1
            ) THEN CASE
                WHEN acur.Code = 'AED' THEN ROUND(aps.BalanceDue / 3.6725, 2)
                ELSE ROUND(aps.BalanceDue * aio.ExchangeRate, 2)
            END
            WHEN smc.SellerMiscCost IS NULL
            AND (
                aifd.IsDelivered = 0
                OR aifd.IsCancelled = 1
            )
            AND acur.Code = 'AED' THEN (bpb.QuantityMax * aim.BuyPrice) / 3.6725
            WHEN smc.SellerMiscCost IS NULL
            AND (
                aifd.IsDelivered = 0
                OR aifd.IsCancelled = 1
            )
            AND acur.Code <> 'AED' THEN bpb.QuantityMax * aim.BuyPriceUsd
            WHEN smc.SellerMiscCost IS NOT NULL
            AND (
                aifd.IsDelivered = 0
                OR aifd.IsCancelled = 1
            )
            AND acur.Code = 'AED' THEN (
                bpb.QuantityMax * aim.BuyPrice + smc.SellerMiscCost
            ) / 3.6725
            WHEN smc.SellerMiscCost IS NOT NULL
            AND (
                aifd.IsDelivered = 0
                OR aifd.IsCancelled = 1
            )
            AND acur.Code <> 'AED' THEN bpb.QuantityMax * aim.BuyPriceUsd + smc.SellerMiscCost
            ELSE 0
        END AS 'Outstanding Amount(USD)',
        CASE
            WHEN aps.TotalAmount IS NOT NULL
            AND (
                aifd.IsDelivered = 0
                OR aifd.IsCancelled = 1
            ) THEN ROUND(aps.TotalAmount, 2)
            WHEN smc.SellerMiscCost IS NULL
            AND (
                aifd.IsDelivered = 0
                OR aifd.IsCancelled = 1
            ) THEN bpb.QuantityMax * aim.BuyPrice
            WHEN smc.SellerMiscCost IS NOT NULL
            AND (
                aifd.IsDelivered = 0
                OR aifd.IsCancelled = 1
            ) THEN bpb.QuantityMax * aim.BuyPrice + smc.SellerMiscCost
            ELSE 0
        END AS 'Invoice Amount',
        CASE
            WHEN aps.TotalAmount IS NOT NULL
            AND (
                aifd.IsDelivered = 0
                OR aifd.IsCancelled = 1
            ) THEN CASE
                WHEN acur.Code = 'AED' THEN ROUND(aps.TotalAmount / 3.6725, 2)
                ELSE ROUND(aps.TotalAmount * aio.ExchangeRate, 2)
            END
            WHEN smc.SellerMiscCost IS NULL
            AND (
                aifd.IsDelivered = 0
                OR aifd.IsCancelled = 1
            )
            AND acur.Code = 'AED' THEN (bpb.QuantityMax * aim.BuyPrice) / 3.6725
            WHEN smc.SellerMiscCost IS NULL
            AND (
                aifd.IsDelivered = 0
                OR aifd.IsCancelled = 1
            )
            AND acur.Code <> 'AED' THEN bpb.QuantityMax * aim.BuyPriceUsd
            WHEN smc.SellerMiscCost IS NOT NULL
            AND (
                aifd.IsDelivered = 0
                OR aifd.IsCancelled = 1
            )
            AND acur.Code = 'AED' THEN (
                bpb.QuantityMax * aim.BuyPrice + smc.SellerMiscCost
            ) / 3.6725
            WHEN smc.SellerMiscCost IS NOT NULL
            AND (
                aifd.IsDelivered = 0
                OR aifd.IsCancelled = 1
            )
            AND acur.Code <> 'AED' THEN bpb.QuantityMax * aim.BuyPriceUsd + smc.SellerMiscCost
            ELSE 0
        END AS 'Invoice Amount(USD)',
        CASE
            WHEN aps.AmountPaid IS NOT NULL
            AND (
                aifd.IsDelivered = 0
                OR aifd.IsCancelled = 1
            ) THEN ROUND(aps.AmountPaid, 2)
            ELSE 0
        END AS 'Amount Paid So Far',
        CASE
            WHEN aps.AmountPaid IS NOT NULL
            AND (
                aifd.IsDelivered = 0
                OR aifd.IsCancelled = 1
            )
            AND acur.Code = 'AED' THEN ROUND(aps.AmountPaid / 3.6725, 2)
            WHEN aps.AmountPaid IS NOT NULL
            AND (
                aifd.IsDelivered = 0
                OR aifd.IsCancelled = 1
            )
            AND acur.Code <> 'AED' THEN ROUND(aps.AmountPaid * aio.ExchangeRate, 2)
            ELSE 0
        END AS 'Amount Paid So Far(USD)',
        av.Name AS 'Vessel',
        ap.Name AS 'Port Name',
        aup.Name AS 'Assignee',
        CONVERT(DATE, aid.DeliveryStartDateNomination) AS 'Delivery Date',
        NULL AS 'Expected Payment Date',
        acur.Code as 'Currency',
        'Uninvoiced' AS 'Invoice Status',
        NULL AS 'Cancellation Status',
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
            WHEN aid.InquiryStatus = 1500 THEN 'Lost Stem'
            WHEN aid.InquiryStatus = 9000 THEN 'Cancelled'
            WHEN aid.InquiryStatus = 10000 THEN 'Invoiced'
            WHEN aid.InquiryStatus = 15000 THEN 'Closed'
        END AS 'Job Status',
        NULL AS 'Payment Status'
    FROM
        BookedAndPartlyBookedCTE bpb
        JOIN AppInquiryDetails aid ON bpb.InquiryDetailId = aid.Id
        JOIN AppInquiryFuelDetails aifd ON aid.Id = aifd.InquiryDetailId
        LEFT JOIN AppSellers asel ON asel.Id = aifd.SellerId
        LEFT JOIN AppSellerGroups asg ON asg.Id = asel.SellerGroupId
        LEFT JOIN SellerMiscCost smc ON smc.InquiryDetailId = aid.Id
        JOIN AppInquiryMargins aim ON aim.InquirySellerDetailId = bpb.InquirySellerDetailId
        JOIN AppInquirySellerDetails aisd ON aid.Id = aisd.InquiryDetailId
        and aifd.SellerId = aisd.SellerId
        and bpb.InquirySellerDetailId = aisd.Id
        JOIN AppInquiryOffers aio On aio.SellerId = aisd.SellerId
        and aio.SellerId = aifd.SellerId
        JOIN AppCurrencies acur ON acur.Id = aio.CurrencyId
        and aisd.InquiryDetailId = aio.InquiryDetailId
        LEFT JOIN AppVessel av ON av.Id = aid.VesselNominationId
        LEFT JOIN AppPorts ap ON ap.Id = aid.PortNominationId
        LEFT JOIN AppUserProfiles aup ON aup.Id = aid.UserProfileId
        LEFT JOIN AppInquiryBrokerDetails aibd ON aibd.InquiryFuelDetailId = aifd.Id
        and aibd.IsDeleted = 0
        LEFT JOIN AppBrokers ab ON ab.Id = aibd.SellerBrokerId
        AND ab.IsDeleted = 0
        LEFT JOIN AppCustomers ac ON ac.Id = aid.CustomerNominationId
        AND ac.IsDeleted = 0
        LEFT JOIN AppCustomerGroups acg ON acg.Id = ac.CustomerGroupId
        AND acg.IsDeleted = 0
        LEFT JOIN AppProformaSellers aps ON aps.InquiryFuelDetailId = aifd.Id
        and aps.IsDeleted = 0
    where
        aid.InquiryStatus = 700
        or aid.InquiryStatus = 800
        or aid.InquiryStatus = 900
        or aid.InquiryStatus = 1000
        AND (aifd.IsDelivered = 0)
),
DeliveredInvoices AS (
    (
        Select
            DISTINCT asel.Name as 'Seller Name',
            acg.Name as 'Customer Group Name',
            ab.Name AS 'Broker Name',
            asg.Name as 'Seller Group',
            aid.Code as 'Job Number',
            ais.InvoiceNumber as 'Seller Invoice Number',
            CONVERT(DATE, ais.PaymentDueDate) as 'Payment Due Date',
            CONVERT(DATE, ais.InvoiceDate) as 'Invoice Date',
            DATEDIFF(DAY, ais.PaymentDueDate, GETDATE()) as 'Overdue days',
            ROUND(ais.BalanceDue, 2) as 'Outstanding Amount',
            CASE
                WHEN acur.Code = 'AED' THEN ROUND((ais.BalanceDue / 3.6725), 2)
                ELSE ROUND(ais.BalanceDue * aio.ExchangeRate, 2)
            END as 'Outstanding Amount(USD)',
            ROUND(ais.TotalAmount, 2) as 'Invoice Amount',
            CASE
                WHEN acur.Code = 'AED' THEN ROUND((ais.TotalAmount / 3.6725), 2)
                ELSE ROUND(ais.TotalAmount * aio.ExchangeRate, 2)
            END as 'Invoice Amount(USD)',
            CASE
                WHEN aps.AmountPaid IS NOT NULL THEN ROUND(
                    aps.AmountPaid + ISNULL(
                        NULLIF(ais.TotalAmount, NULL) - NULLIF(ais.BalanceDue, NULL),
                        0
                    ),
                    2
                )
                WHEN aps.AmountPaid IS NULL THEN ROUND(
                    ISNULL(
                        NULLIF(ais.TotalAmount, NULL) - NULLIF(ais.BalanceDue, NULL),
                        0
                    ),
                    2
                )
            END AS 'Amount Paid So Far',
            CASE
                WHEN aps.AmountPaid IS NOT NULL
                AND acur.Code = 'AED' THEN ROUND(
                    (
                        aps.AmountPaid + ISNULL(
                            NULLIF(ais.TotalAmount, NULL) - NULLIF(ais.BalanceDue, NULL),
                            0
                        )
                    ) / 3.6725,
                    2
                )
                WHEN aps.AmountPaid IS NOT NULL
                AND acur.Code <> 'AED' THEN ROUND(
                    (
                        aps.AmountPaid + ISNULL(
                            NULLIF(ais.TotalAmount, NULL) - NULLIF(ais.BalanceDue, NULL),
                            0
                        )
                    ) * aio.ExchangeRate,
                    2
                )
                WHEN aps.AmountPaid IS NULL
                AND acur.Code = 'AED' THEN ROUND(
                    ISNULL(
                        NULLIF(ais.TotalAmount, NULL) - NULLIF(ais.BalanceDue, NULL),
                        0
                    ) / 3.6725,
                    2
                )
                WHEN aps.AmountPaid IS NULL
                AND acur.Code <> 'AED' THEN ROUND(
                    ISNULL(
                        NULLIF(ais.TotalAmount, NULL) - NULLIF(ais.BalanceDue, NULL),
                        0
                    ) * aio.ExchangeRate,
                    2
                )
            END AS 'Amount Paid So Far(USD)',
            av.Name as 'Vessel',
            ap.Name as 'Port Name',
            aup.Name AS 'Assignee',
            CONVERT(
                DATE,
                CASE
                    WHEN (
                        aics.CancelTypes = 0
                        AND aifd.IsCancelled = 1
                    ) THEN ais.ApprovedOn
                    ELSE ad.DeliveryDate
                END
            ) AS 'Delivery Date',
            CONVERT(DATE, ais.ExpectedDueDate) AS 'Expected Payment Date',
            acur.Code as 'Currency',
            CASE
                WHEN ais.InvoiceStatus IS NULL THEN 'Uninvoiced'
                WHEN ais.InvoiceStatus = 0 THEN 'Uninvoiced'
                WHEN ais.InvoiceStatus = 10 THEN 'Invoice Received'
                WHEN ais.InvoiceStatus = 20 THEN 'Pending Approval'
                WHEN ais.InvoiceStatus = 30 THEN 'Invoice Approved'
                WHEN ais.InvoiceStatus = 40 THEN 'Partly Paid'
                WHEN ais.InvoiceStatus = 50 THEN 'Paid'
            END AS 'Invoice Status',
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
                WHEN aid.InquiryStatus = 1500 THEN 'Lost Stem'
                WHEN aid.InquiryStatus = 9000 THEN 'Cancelled'
                WHEN aid.InquiryStatus = 10000 THEN 'Invoiced'
                WHEN aid.InquiryStatus = 15000 THEN 'Closed'
            END AS 'Job Status',
            CASE
                WHEN ais.PayableType IS NULL THEN 'Not Paid'
                WHEN ais.PayableType = 0 THEN 'Not Paid'
                WHEN ais.PayableType = 1 THEN 'Partly Paid'
                WHEN ais.PayableType = 2 THEN 'Paid'
            END AS 'Payment Status'
        from
            AppInquiryDetails aid
            JOIN AppInquiryFuelDetails aifd ON aid.Id = aifd.InquiryDetailId
            LEFT JOIN AppInquiryCancelStems aics ON aifd.Id = aics.InquiryFuelDetailId
            and aics.CancelTypes = 0
            and aics.IsDeleted = 0
            JOIN AppInquirySellerDetails aisd ON aid.Id = aisd.InquiryDetailId
            and aifd.SellerId = aisd.SellerId
            JOIN AppInquiryOffers aio On aio.SellerId = aisd.SellerId
            and aio.SellerId = aifd.SellerId
            JOIN AppCurrencies acur ON acur.Id = aio.CurrencyId
            and aisd.InquiryDetailId = aio.InquiryDetailId
            LEFT JOIN SellerInvoiceModifed ais ON ais.InquiryFuelDetailId = aifd.Id
            and ais.IsDeleted = 0
            and (
                ais.TotalAmount != 0
                AND ais.SubTotal != 0
            )
            LEFT JOIN AppProformaSellers aps ON aps.inquiryfueldetailid = ais.InquiryFuelDetailId
            and aps.IsDeleted = 0 --test
            LEFT JOIN AppSellers asel ON ais.sellerid = asel.id
            LEFT JOIN AppSellerGroups asg ON asg.Id = asel.SellerGroupId
            LEFT JOIN AppDeliveries ad ON ad.InquiryFuelDetailId = ais.InquiryFuelDetailId
            JOIN AppVessel av ON av.Id = aid.VesselNominationId
            JOIN AppPorts ap ON ap.Id = aid.PortNominationId
            JOIN AppUserProfiles aup ON aup.Id = aid.UserProfileId
            LEFT JOIN AppBrokers ab ON ab.Id = ais.CounterpartyName
            and ab.IsDeleted = 0
            LEFT JOIN AppCustomers ac ON ac.Id = aid.CustomerNominationId
            AND ac.IsDeleted = 0
            LEFT JOIN AppCustomerGroups acg ON acg.Id = ac.CustomerGroupId
            AND acg.IsDeleted = 0
        where
            aid.InquiryStatus = 700
            or aid.InquiryStatus = 800
            or aid.InquiryStatus = 900
            or aid.InquiryStatus = 1000
            or aid.InquiryStatus = 9000
            and aics.CancelTypes = 0
            and aics.IsDeleted = 0
    )
),
unionquery AS (
    SELECT
        *
    FROM
        BookedInvoices
    UNION
    ALL
    SELECT
        *
    FROM
        DeliveredInvoices
),
GroupedInvoices AS (
    SELECT
        [Seller Invoice Number],
        [Seller Name],
        [Customer Group Name],
        [Broker Name],
        [Seller Group],
        [Job Number],
        [Payment Due Date],
        [Invoice Date],
        [Overdue days],
        [Vessel],
        [Port Name],
        [Assignee],
        [Delivery Date],
        [Expected Payment Date],
        Currency,
        [Invoice Status],
        [Cancellation Status],
        [Job Status],
        [Payment Status],
        SUM([Outstanding Amount]) AS [Outstanding Amount],
        SUM([Outstanding Amount(USD)]) AS [Outstanding Amount(USD)],
        SUM([Invoice Amount]) AS [Invoice Amount],
        SUM([Invoice Amount(USD)]) AS [Invoice Amount(USD)],
        SUM([Amount Paid So Far]) AS [Amount Paid So Far],
        SUM([Amount Paid So Far(USD)]) AS [Amount Paid So Far(USD)]
    FROM
        unionquery
    GROUP BY
        [Seller Invoice Number],
        [Seller Name],
        [Customer Group Name],
        [Broker Name],
        [Seller Group],
        [Job Number],
        [Payment Due Date],
        [Invoice Date],
        [Overdue days],
        [Vessel],
        [Port Name],
        [Assignee],
        [Delivery Date],
        [Expected Payment Date],
        Currency,
        [Invoice Status],
        [Cancellation Status],
        [Job Status],
        [Payment Status]
),
UnionQueryCTE AS (
    SELECT
        [Seller Name],
        [Customer Group Name],
        [Broker Name],
        [Seller Group],
        [Job Number],
        [Seller Invoice Number],
        [Payment Due Date],
        [Invoice Date],
        CASE
            WHEN [Job Status] = 'Booked'
            OR [Job Status] = 'Partly Booked' THEN NULL
            WHEN [Invoice Status] = 'Paid' THEN 0
            ELSE [Overdue days]
        END AS 'Overdue days',
        [Outstanding Amount],
        [Outstanding Amount(USD)],
        [Invoice Amount],
        [Invoice Amount(USD)],
        [Amount Paid So Far],
        [Amount Paid So Far(USD)],
        Vessel,
        [Port Name],
        Assignee,
        [Delivery Date],
        [Expected Payment Date],
        Currency,
        [Invoice Status],
        [Cancellation Status],
        [Job Status],
        [Payment Status],
        COALESCE([Expected Payment Date], [Payment Due Date]) AS 'Filter Date'
    FROM
        GroupedInvoices
    WHERE
        [Seller Name] IS NOT NULL --and [Job Number] = 'G3489' --AND [Invoice Status] <> 'Paid'
)
SELECT
    *
FROM
    UnionQueryCTE
ORDER BY
    CAST(
        SUBSTRING([Job Number], 2, LEN([Job Number]) - 1) AS INT
    ) DESC