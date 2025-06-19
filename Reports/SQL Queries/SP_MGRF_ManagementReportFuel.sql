-- ===================================================
-- Procedure Name: SP_MGRF_ManagementReportFuel
-- Created By: Sidharth A
-- Created On: 2025-06-07
-- Version: 1.0
-- Description: Report for Management report, separated for Fuel
-- Change Log:
-- 1.0 - Initial creation (2025-06-07)
-- 1.1 - Proforma amounts added to Amount Received (2025-06-09)
-- 1.2 - Logic Updated to work for 3 fuel scenarios (2025-06-11)
-- 1.3 - Fuel wise calculations updated (2025-06-18)
-- 1.4 - For cancelled stems, update delivery date as the approved on date(2025-06-19)
-- ===================================================
WITH MISubProformaTable AS (
    SELECT
        aic.Id,
        aic.InquiryDetailId,
        aic.InquiryFuelDetailId,
        aic.InquirySellerDetailId,
        aifd.Description,
        aic.MergeCode,
        aic.OrderedQuantity,
        aic.SubTotal,
        aic.InvoiceNumber,
        aio.CurrencyId,
        aim.BuyPrice,
        (aimc.AmountUsd / aio.ExchangeRate) AS 'MiscCostGradeLC',
        CASE
            WHEN (aic.AdditionalCost / aio.ExchangeRate) != 0
            AND (aic.AdditionalCost / aio.ExchangeRate) IS NOT NULL THEN (aic.AdditionalCost / aio.ExchangeRate) * (
                aic.OrderedQuantity * 1.0 / NULLIF(
                    SUM(aic.OrderedQuantity) OVER (PARTITION BY aic.InquiryDetailId, aic.MergeCode),
                    0
                )
            )
            ELSE (
                MAX(
                    CASE
                        WHEN (aic.AdditionalCost / aio.ExchangeRate) IS NOT NULL THEN (aic.AdditionalCost / aio.ExchangeRate)
                        ELSE NULL
                    END
                ) OVER (
                    PARTITION BY aic.InquiryDetailId,
                    aic.MergeCode
                    ORDER BY
                        aifd.Description ROWS BETWEEN UNBOUNDED PRECEDING
                        AND CURRENT ROW
                )
            ) * (
                aic.OrderedQuantity * 1.0 / NULLIF(
                    SUM(aic.OrderedQuantity) OVER (PARTITION BY aic.InquiryDetailId, aic.MergeCode),
                    0
                )
            )
        END AS 'AdditionalCost',
        CASE
            WHEN aic.AdditionalCost != 0
            AND aic.AdditionalCost IS NOT NULL THEN aic.AdditionalCost * (
                aic.OrderedQuantity * 1.0 / NULLIF(
                    SUM(aic.OrderedQuantity) OVER (PARTITION BY aic.InquiryDetailId, aic.MergeCode),
                    0
                )
            )
            ELSE (
                MAX(
                    CASE
                        WHEN aic.AdditionalCost IS NOT NULL THEN aic.AdditionalCost
                        ELSE NULL
                    END
                ) OVER (
                    PARTITION BY aic.InquiryDetailId,
                    aic.MergeCode
                    ORDER BY
                        aifd.Description ROWS BETWEEN UNBOUNDED PRECEDING
                        AND CURRENT ROW
                )
            ) * (
                aic.OrderedQuantity * 1.0 / NULLIF(
                    SUM(aic.OrderedQuantity) OVER (PARTITION BY aic.InquiryDetailId, aic.MergeCode),
                    0
                )
            )
        END AS 'AdditionalCostUSD',
        CASE
            WHEN aic.VatAmount != 0
            AND aic.VatAmount IS NOT NULL THEN aic.VatAmount * (
                aic.OrderedQuantity * 1.0 / NULLIF(
                    SUM(aic.OrderedQuantity) OVER (PARTITION BY aic.InquiryDetailId, aic.MergeCode),
                    0
                )
            )
            ELSE (
                MAX(
                    CASE
                        WHEN aic.VatAmount IS NOT NULL THEN aic.VatAmount
                        ELSE NULL
                    END
                ) OVER (
                    PARTITION BY aic.InquiryDetailId,
                    aic.MergeCode
                    ORDER BY
                        aifd.Description ROWS BETWEEN UNBOUNDED PRECEDING
                        AND CURRENT ROW
                )
            ) * (
                aic.OrderedQuantity * 1.0 / NULLIF(
                    SUM(aic.OrderedQuantity) OVER (PARTITION BY aic.InquiryDetailId, aic.MergeCode),
                    0
                )
            )
        END AS 'VatAmount',
        aic.OrderedQuantity * 1.0 / NULLIF(
            SUM(aic.OrderedQuantity) OVER (PARTITION BY aic.InquiryDetailId, aic.MergeCode),
            0
        ) AS 'Weights'
    FROM
        AppProformaSellers aic
        JOIN (
            SELECT
                id,
                Description,
                SellerId
            FROM
                AppInquiryFuelDetails
            WHERE
                IsDeleted = 0
                AND IsLosted = 0
        ) aifd ON aifd.Id = aic.InquiryFuelDetailId
        LEFT JOIN (
            SELECT
                ProformaSellerId,
                SUM(Amount) AS Amount,
                SUM(AmountUsd) AS AmountUsd
            FROM
                AppProformaMiscCosts
            WHERE
                IsDeleted = 0
            GROUP BY
                ProformaSellerId
        ) aimc ON aimc.ProformaSellerId = aic.Id
        LEFT JOIN AppInquiryOffers aio ON aio.InquiryDetailId = aic.InquiryDetailId
        and aio.SellerId = aifd.SellerId
        and aio.isdeleted = 0
        LEFT JOIN AppInquiryMargins aim ON aim.InquiryDetailId = aic.InquiryDetailId
        and aim.InquirySellerDetailId = aic.InquirySellerDetailId
        and aim.isdeleted = 0
    WHERE
        aic.IsDeleted = 0
        AND MergeCode IS NOT NULL
),
ProformaSellerTable AS (
    SELECT
        aic.Id,
        aic.InquiryDetailId,
        aic.MergeCode,
        aic.InquiryFuelDetailId,
        aic.InvoiceNumber,
        aio.CurrencyId,
        aio.ExchangeRate,
        aim.BuyPrice,
        sct.AdditionalCost,
        sct.Description,
        sct.Weights,
        sct.VatAmount,
        sct.MiscCostGradeLC,
        (
            ISNULL(aim.BuyPrice, 0) * ISNULL(aic.OrderedQuantity, 0)
        ) + ISNULL(sct.AdditionalCost, 0) + ISNULL(sct.MiscCostGradeLC, 0) AS 'SubTotal',
        (
            ISNULL(aim.BuyPrice, 0) * ISNULL(aic.OrderedQuantity, 0)
        ) + ISNULL(sct.AdditionalCost, 0) + ISNULL(sct.MiscCostGradeLC, 0) + ISNULL(sct.VatAmount, 0) AS 'TotalAmount',
        aic.AmountPaid,
        aic.OrderedQuantity
    FROM
        AppProformaSellers aic
        JOIN (
            SELECT
                id,
                Description,
                SellerId
            FROM
                AppInquiryFuelDetails
            WHERE
                IsDeleted = 0
                AND IsLosted = 0
        ) aifd ON aifd.Id = aic.InquiryFuelDetailId
        JOIN MISubProformaTable sct ON sct.Id = aic.Id
        LEFT JOIN AppInquiryOffers aio ON aio.InquiryDetailId = aic.InquiryDetailId
        and aio.SellerId = aifd.SellerId
        and aio.isdeleted = 0
        LEFT JOIN AppInquiryMargins aim ON aim.InquiryDetailId = aic.InquiryDetailId
        and aim.InquirySellerDetailId = aic.InquirySellerDetailId
        and aim.isdeleted = 0
),
WeightsSubTotalPS AS (
    SELECT
        Id,
        InquiryDetailId,
        InquiryFuelDetailId,
        MergeCode,
        CASE
            WHEN SubTotal = 0 THEN 0
            ELSE SubTotal / SUM(SubTotal) OVER (PARTITION BY InquiryDetailId, MergeCode)
        END AS Weights
    FROM
        ProformaSellerTable
),
ProformaSellersTest AS (
    SELECT
        it.Id,
        it.InquiryDetailId,
        it.InquiryFuelDetailId,
        it.InvoiceNumber,
        it.CurrencyId,
        it.ExchangeRate,
        it.BuyPrice,
        it.Description,
        it.MergeCode,
        it.OrderedQuantity,
        wc.Weights,
        it.SubTotal,
        it.VatAmount,
        it.AdditionalCost,
        it.TotalAmount,
        CASE
            WHEN AmountPaid != 0
            AND AmountPaid IS NOT NULL THEN AmountPaid
            ELSE (
                MAX(
                    CASE
                        WHEN AmountPaid IS NOT NULL THEN AmountPaid
                        ELSE NULL
                    END
                ) OVER (
                    PARTITION BY it.InquiryDetailId,
                    it.MergeCode
                    ORDER BY
                        Description ROWS BETWEEN UNBOUNDED PRECEDING
                        AND CURRENT ROW
                )
            )
        END AS 'AmountReceivedSoFars'
    FROM
        ProformaSellerTable it
        LEFT JOIN WeightsSubTotalPS wc ON wc.Id = it.Id
),
ProformaSellerTables AS (
    SELECT
        Id,
        InquiryDetailId,
        InquiryFuelDetailId,
        InvoiceNumber,
        CurrencyId,
        ExchangeRate,
        BuyPrice,
        Description,
        MergeCode,
        OrderedQuantity,
        SubTotal,
        VatAmount,
        AdditionalCost,
        TotalAmount,
        CASE
            WHEN TotalAmount = 0 THEN 0
            ELSE (
                AmountReceivedSoFars - (
                    AmountReceivedSoFars * (
                        (
                            SUM(TotalAmount) OVER (PARTITION BY InquiryDetailId, MergeCode) - SUM(SubTotal) OVER (PARTITION BY InquiryDetailId, MergeCode)
                        ) / SUM(TotalAmount) OVER (PARTITION BY InquiryDetailId, MergeCode)
                    )
                )
            ) * Weights
        END AS 'AmountPaidSoFar'
    FROM
        ProformaSellersTest
),
SubSellerProformaTable AS (
    SELECT
        aic.Id,
        aic.InquiryDetailId,
        aic.InquiryFuelDetailId,
        aic.InvoiceNumber,
        aio.CurrencyId,
        aio.ExchangeRate,
        aim.BuyPrice,
        aifd.Description,
        aic.MergeCode,
        aic.OrderedQuantity,
        aic.SubTotal,
        aic.VatAmount,
        aic.AdditionalCost,
        aic.TotalAmount,
        CASE
            WHEN aic.TotalAmount = 0 THEN 0
            ELSE aic.AmountPaid - (
                aic.AmountPaid * (
                    (aic.TotalAmount - aic.SubTotal) / aic.TotalAmount
                )
            )
        END AS AmountPaidSoFarWO
    FROM
        AppProformaSellers aic
        JOIN (
            SELECT
                id,
                Description,
                SellerId
            FROM
                AppInquiryFuelDetails
            WHERE
                IsDeleted = 0
                AND IsLosted = 0
        ) aifd ON aifd.Id = aic.InquiryFuelDetailId
        LEFT JOIN (
            SELECT
                ProformaSellerId,
                SUM(Amount) AS Amount,
                SUM(AmountUsd) AS AmountUsd
            FROM
                AppProformaMiscCosts
            WHERE
                IsDeleted = 0
            GROUP BY
                ProformaSellerId
        ) aimc ON aimc.ProformaSellerId = aic.Id
        LEFT JOIN AppInquiryOffers aio ON aio.InquiryDetailId = aic.InquiryDetailId
        and aio.SellerId = aifd.SellerId
        and aio.isdeleted = 0
        LEFT JOIN AppInquiryMargins aim ON aim.InquiryDetailId = aic.InquiryDetailId
        and aim.InquirySellerDetailId = aic.InquirySellerDetailId
        and aim.isdeleted = 0
    WHERE
        aic.IsDeleted = 0
        AND MergeCode IS NULL
),
ProformaSellerTableNew AS (
    SELECT
        *
    FROM
        ProformaSellerTables
    UNION
    ALL
    SELECT
        *
    FROM
        SubSellerProformaTable
),
MISubInvoiceTable AS (
    SELECT
        aic.Id,
        aic.InquiryDetailId,
        aic.InquiryFuelDetailId,
        aic.InquirySellerDetailId,
        aifd.Description,
        aic.MergeCode,
        aic.BdnBillingQuantity,
        aic.SubTotal,
        aic.InvoiceNumber,
        aic.CurrencyId,
        aic.PayableType,
        aic.BuyPrice,
        (aimc.AmountUsd / aic.ExchangeRate) AS 'MiscCostGradeLC',
        CASE
            WHEN (aic.AdditionalCost / aic.ExchangeRate) != 0
            AND (aic.AdditionalCost / aic.ExchangeRate) IS NOT NULL THEN (aic.AdditionalCost / aic.ExchangeRate) * (
                aic.BdnBillingQuantity * 1.0 / SUM(aic.BdnBillingQuantity) OVER (PARTITION BY aic.InquiryDetailId, aic.MergeCode)
            )
            ELSE (
                MAX(
                    CASE
                        WHEN (aic.AdditionalCost / aic.ExchangeRate) IS NOT NULL THEN (aic.AdditionalCost / aic.ExchangeRate)
                        ELSE NULL
                    END
                ) OVER (
                    PARTITION BY aic.InquiryDetailId,
                    aic.MergeCode
                    ORDER BY
                        aifd.Description ROWS BETWEEN UNBOUNDED PRECEDING
                        AND CURRENT ROW
                )
            ) * (
                aic.BdnBillingQuantity * 1.0 / SUM(aic.BdnBillingQuantity) OVER (PARTITION BY aic.InquiryDetailId, aic.MergeCode)
            )
        END AS 'AdditionalCost',
        CASE
            WHEN aic.AdditionalCost != 0
            AND aic.AdditionalCost IS NOT NULL THEN aic.AdditionalCost * (
                aic.BdnBillingQuantity * 1.0 / SUM(aic.BdnBillingQuantity) OVER (PARTITION BY aic.InquiryDetailId, aic.MergeCode)
            )
            ELSE (
                MAX(
                    CASE
                        WHEN aic.AdditionalCost IS NOT NULL THEN aic.AdditionalCost
                        ELSE NULL
                    END
                ) OVER (
                    PARTITION BY aic.InquiryDetailId,
                    aic.MergeCode
                    ORDER BY
                        aifd.Description ROWS BETWEEN UNBOUNDED PRECEDING
                        AND CURRENT ROW
                )
            ) * (
                aic.BdnBillingQuantity * 1.0 / SUM(aic.BdnBillingQuantity) OVER (PARTITION BY aic.InquiryDetailId, aic.MergeCode)
            )
        END AS 'AdditionalCostUSD',
        CASE
            WHEN aic.Discount != 0
            AND aic.Discount IS NOT NULL THEN aic.Discount * (
                aic.BdnBillingQuantity * 1.0 / SUM(aic.BdnBillingQuantity) OVER (PARTITION BY aic.InquiryDetailId, aic.MergeCode)
            )
            ELSE (
                MAX(
                    CASE
                        WHEN aic.Discount IS NOT NULL THEN aic.Discount
                        ELSE NULL
                    END
                ) OVER (
                    PARTITION BY aic.InquiryDetailId,
                    aic.MergeCode
                    ORDER BY
                        aifd.Description ROWS BETWEEN UNBOUNDED PRECEDING
                        AND CURRENT ROW
                )
            ) * (
                aic.BdnBillingQuantity * 1.0 / SUM(aic.BdnBillingQuantity) OVER (PARTITION BY aic.InquiryDetailId, aic.MergeCode)
            )
        END AS 'Discount',
        CASE
            WHEN aic.VatAmount != 0
            AND aic.VatAmount IS NOT NULL THEN aic.VatAmount * (
                aic.BdnBillingQuantity * 1.0 / SUM(aic.BdnBillingQuantity) OVER (PARTITION BY aic.InquiryDetailId, aic.MergeCode)
            )
            ELSE (
                MAX(
                    CASE
                        WHEN aic.VatAmount IS NOT NULL THEN aic.VatAmount
                        ELSE NULL
                    END
                ) OVER (
                    PARTITION BY aic.InquiryDetailId,
                    aic.MergeCode
                    ORDER BY
                        aifd.Description ROWS BETWEEN UNBOUNDED PRECEDING
                        AND CURRENT ROW
                )
            ) * (
                aic.BdnBillingQuantity * 1.0 / SUM(aic.BdnBillingQuantity) OVER (PARTITION BY aic.InquiryDetailId, aic.MergeCode)
            )
        END AS 'VatAmount',
        aic.BdnBillingQuantity * 1.0 / SUM(aic.BdnBillingQuantity) OVER (PARTITION BY aic.InquiryDetailId, aic.MergeCode) AS 'Weights'
    FROM
        AppInvoiceSellers aic
        JOIN (
            SELECT
                id,
                Description
            FROM
                AppInquiryFuelDetails
            WHERE
                IsDeleted = 0
                AND IsLosted = 0
        ) aifd ON aifd.Id = aic.InquiryFuelDetailId
        LEFT JOIN (
            SELECT
                InvoiceSellerId,
                SUM(Amount) AS Amount,
                SUM(AmountUsd) AS AmountUsd
            FROM
                AppInvoiceMiscCosts
            WHERE
                IsDeleted = 0
            GROUP BY
                InvoiceSellerId
        ) aimc ON aimc.InvoiceSellerId = aic.Id
    WHERE
        IsDeleted = 0
        AND InvoiceType = 0
        AND MergeCode IS NOT NULL
),
InvoiceSellerTable AS (
    SELECT
        aic.Id,
        aic.InquiryDetailId,
        aic.MergeCode,
        aic.InquiryFuelDetailId,
        aic.InvoiceNumber,
        aic.CurrencyId,
        aic.ExchangeRate,
        aic.PayableType,
        aic.BuyPrice,
        sct.AdditionalCost,
        sct.Description,
        sct.Weights,
        sct.VatAmount,
        sct.MiscCostGradeLC,
        sct.Discount,
        (
            ISNULL(aic.BuyPrice, 0) * ISNULL(aic.BdnBillingQuantity, 0)
        ) + ISNULL(sct.AdditionalCost, 0) + ISNULL(sct.MiscCostGradeLC, 0) - ISNULL(sct.Discount, 0) AS 'SubTotal',
        (
            ISNULL(aic.BuyPrice, 0) * ISNULL(aic.BdnBillingQuantity, 0)
        ) + ISNULL(sct.AdditionalCost, 0) + ISNULL(sct.MiscCostGradeLC, 0) + ISNULL(sct.VatAmount, 0) - ISNULL(sct.Discount, 0) AS 'TotalAmount',
        aic.AmountPaidSoFar,
        aic.BdnBillingQuantity
    FROM
        AppInvoiceSellers aic
        JOIN MISubInvoiceTable sct ON sct.Id = aic.Id
),
WeightsSubTotal AS (
    SELECT
        Id,
        InquiryDetailId,
        InquiryFuelDetailId,
        MergeCode,
        CASE
            WHEN SubTotal = 0 THEN 0
            ELSE SubTotal / SUM(SubTotal) OVER (PARTITION BY InquiryDetailId, MergeCode)
        END AS Weights
    FROM
        InvoiceSellerTable
),
InvoiceSellersTest AS (
    SELECT
        it.Id,
        it.InquiryDetailId,
        it.InquiryFuelDetailId,
        it.InvoiceNumber,
        it.CurrencyId,
        it.ExchangeRate,
        it.PayableType,
        it.BuyPrice,
        it.Description,
        it.MergeCode,
        it.BdnBillingQuantity,
        wc.Weights,
        it.SubTotal,
        it.VatAmount,
        it.Discount,
        it.AdditionalCost,
        it.TotalAmount,
        CASE
            WHEN AmountPaidSoFar != 0
            AND AmountPaidSoFar IS NOT NULL THEN AmountPaidSoFar
            ELSE (
                MAX(
                    CASE
                        WHEN AmountPaidSoFar IS NOT NULL THEN AmountPaidSoFar
                        ELSE NULL
                    END
                ) OVER (
                    PARTITION BY it.InquiryDetailId,
                    it.MergeCode
                    ORDER BY
                        Description ROWS BETWEEN UNBOUNDED PRECEDING
                        AND CURRENT ROW
                )
            )
        END AS 'AmountReceivedSoFars'
    FROM
        InvoiceSellerTable it
        LEFT JOIN WeightsSubTotal wc ON wc.Id = it.Id
),
InvoiceSellerTables AS (
    SELECT
        ast.Id,
        ast.InquiryDetailId,
        ast.InquiryFuelDetailId,
        ast.InvoiceNumber,
        ast.CurrencyId,
        ast.ExchangeRate,
        ast.PayableType,
        ast.BuyPrice,
        ast.Description,
        ast.MergeCode,
        ast.BdnBillingQuantity,
        ast.SubTotal,
        ast.VatAmount,
        ast.Discount,
        ast.AdditionalCost,
        ast.TotalAmount,
        CASE
            WHEN ast.TotalAmount = 0 THEN 0
            ELSE ISNULL(
                (
                    (
                        ast.AmountReceivedSoFars - (
                            ast.AmountReceivedSoFars * (
                                (
                                    SUM(ast.TotalAmount) OVER (PARTITION BY ast.InquiryDetailId, ast.MergeCode) - SUM(ast.SubTotal) OVER (PARTITION BY ast.InquiryDetailId, ast.MergeCode)
                                ) / SUM(ast.TotalAmount) OVER (PARTITION BY ast.InquiryDetailId, ast.MergeCode)
                            )
                        )
                    ) * Weights
                ),
                0
            ) + ISNULL(
                SUM(pst.AmountPaidSoFar) OVER (PARTITION BY ast.InquiryDetailId, ast.MergeCode) * Weights,
                0
            )
        END AS 'AmountPaidSoFar'
    FROM
        InvoiceSellersTest ast
        LEFT JOIN ProformaSellerTableNew pst ON pst.Inquirydetailid = ast.InquiryFuelDetailId
),
SubSellerTable AS (
    SELECT
        aic.Id,
        aic.InquiryDetailId,
        aic.InquiryFuelDetailId,
        aic.InvoiceNumber,
        aic.CurrencyId,
        aic.ExchangeRate,
        aic.PayableType,
        aic.BuyPrice,
        aifd.Description,
        aic.MergeCode,
        aic.BdnBillingQuantity,
        aic.SubTotal,
        aic.VatAmount,
        aic.Discount,
        aic.AdditionalCost,
        aic.TotalAmount,
        CASE
            WHEN aic.TotalAmount = 0 THEN 0
            ELSE ISNULL(
                aic.AmountPaidSoFar - (
                    aic.AmountPaidSoFar * (
                        (aic.TotalAmount - aic.SubTotal) / aic.TotalAmount
                    )
                ),
                0
            ) + ISNULL(pst.AmountPaidSoFar, 0)
        END AS AmountPaidSoFarWO
    FROM
        AppInvoiceSellers aic
        JOIN (
            SELECT
                id,
                Description
            FROM
                AppInquiryFuelDetails
            WHERE
                IsDeleted = 0
                AND IsLosted = 0
        ) aifd ON aifd.Id = aic.InquiryFuelDetailId
        LEFT JOIN (
            SELECT
                InvoiceSellerId,
                SUM(Amount) AS Amount,
                SUM(AmountUsd) AS AmountUsd
            FROM
                AppInvoiceMiscCosts
            WHERE
                IsDeleted = 0
            GROUP BY
                InvoiceSellerId
        ) aimc ON aimc.InvoiceSellerId = aic.Id
        LEFT JOIN ProformaSellerTableNew pst ON pst.Inquirydetailid = aic.InquiryFuelDetailId
    WHERE
        IsDeleted = 0
        AND InvoiceType = 0
        AND aic.MergeCode IS NULL
),
InvoiceSellerTableNew AS (
    SELECT
        *
    FROM
        InvoiceSellerTables
    UNION
    ALL
    SELECT
        *
    FROM
        SubSellerTable
),
MISubProformaCusTable AS (
    SELECT
        aic.Id,
        aic.InquiryDetailId,
        aic.InquiryFuelDetailId,
        aic.InquirySellerDetailId,
        aifd.Description,
        aic.MergeCode,
        aic.OrderedQuantity,
        aic.SubTotal,
        aic.ProformaCode,
        aim.CurrencyId,
        aim.SellPrice,
        (aimc.AmountUsd / aim.ExchangeRate) AS 'MiscCostGradeLC',
        CASE
            WHEN (aic.AdditionalCost / aim.ExchangeRate) != 0
            AND (aic.AdditionalCost / aim.ExchangeRate) IS NOT NULL THEN (aic.AdditionalCost / aim.ExchangeRate) * (
                aic.OrderedQuantity * 1.0 / NULLIF(
                    SUM(aic.OrderedQuantity) OVER (PARTITION BY aic.InquiryDetailId, aic.MergeCode),
                    0
                )
            )
            ELSE (
                MAX(
                    CASE
                        WHEN (aic.AdditionalCost / aim.ExchangeRate) IS NOT NULL THEN (aic.AdditionalCost / aim.ExchangeRate)
                        ELSE NULL
                    END
                ) OVER (
                    PARTITION BY aic.InquiryDetailId,
                    aic.MergeCode
                    ORDER BY
                        aifd.Description ROWS BETWEEN UNBOUNDED PRECEDING
                        AND CURRENT ROW
                )
            ) * (
                aic.OrderedQuantity * 1.0 / NULLIF(
                    SUM(aic.OrderedQuantity) OVER (PARTITION BY aic.InquiryDetailId, aic.MergeCode),
                    0
                )
            )
        END AS 'AdditionalCost',
        CASE
            WHEN aic.AdditionalCost != 0
            AND aic.AdditionalCost IS NOT NULL THEN aic.AdditionalCost * (
                aic.OrderedQuantity * 1.0 / NULLIF(
                    SUM(aic.OrderedQuantity) OVER (PARTITION BY aic.InquiryDetailId, aic.MergeCode),
                    0
                )
            )
            ELSE (
                MAX(
                    CASE
                        WHEN aic.AdditionalCost IS NOT NULL THEN aic.AdditionalCost
                        ELSE NULL
                    END
                ) OVER (
                    PARTITION BY aic.InquiryDetailId,
                    aic.MergeCode
                    ORDER BY
                        aifd.Description ROWS BETWEEN UNBOUNDED PRECEDING
                        AND CURRENT ROW
                )
            ) * (
                aic.OrderedQuantity * 1.0 / NULLIF(
                    SUM(aic.OrderedQuantity) OVER (PARTITION BY aic.InquiryDetailId, aic.MergeCode),
                    0
                )
            )
        END AS 'AdditionalCostUSD',
        CASE
            WHEN aic.VatAmount != 0
            AND aic.VatAmount IS NOT NULL THEN aic.VatAmount * (
                aic.OrderedQuantity * 1.0 / NULLIF(
                    SUM(aic.OrderedQuantity) OVER (PARTITION BY aic.InquiryDetailId, aic.MergeCode),
                    0
                )
            )
            ELSE (
                MAX(
                    CASE
                        WHEN aic.VatAmount IS NOT NULL THEN aic.VatAmount
                        ELSE NULL
                    END
                ) OVER (
                    PARTITION BY aic.InquiryDetailId,
                    aic.MergeCode
                    ORDER BY
                        aifd.Description ROWS BETWEEN UNBOUNDED PRECEDING
                        AND CURRENT ROW
                )
            ) * (
                aic.OrderedQuantity * 1.0 / NULLIF(
                    SUM(aic.OrderedQuantity) OVER (PARTITION BY aic.InquiryDetailId, aic.MergeCode),
                    0
                )
            )
        END AS 'VatAmount',
        aic.OrderedQuantity * 1.0 / NULLIF(
            SUM(aic.OrderedQuantity) OVER (PARTITION BY aic.InquiryDetailId, aic.MergeCode),
            0
        ) AS 'Weights'
    FROM
        AppProformaCustomers aic
        JOIN (
            SELECT
                id,
                Description,
                SellerId
            FROM
                AppInquiryFuelDetails
            WHERE
                IsDeleted = 0
                AND IsLosted = 0
        ) aifd ON aifd.Id = aic.InquiryFuelDetailId
        LEFT JOIN (
            SELECT
                ProformaCustomerId,
                SUM(Amount) AS Amount,
                SUM(AmountUsd) AS AmountUsd
            FROM
                AppProformaMiscCosts
            WHERE
                IsDeleted = 0
            GROUP BY
                ProformaCustomerId
        ) aimc ON aimc.ProformaCustomerId = aic.Id
        LEFT JOIN AppInquiryOffers aio ON aio.InquiryDetailId = aic.InquiryDetailId
        and aio.SellerId = aifd.SellerId
        and aio.isdeleted = 0
        LEFT JOIN AppInquiryMargins aim ON aim.InquiryDetailId = aic.InquiryDetailId
        and aim.InquirySellerDetailId = aic.InquirySellerDetailId
        and aim.isdeleted = 0
    WHERE
        aic.IsDeleted = 0
        AND MergeCode IS NOT NULL
),
ProformaCustomerTable AS (
    SELECT
        aic.Id,
        aic.InquiryDetailId,
        aic.MergeCode,
        aic.InquiryFuelDetailId,
        aic.ProformaCode,
        aim.CurrencyId,
        aim.ExchangeRate,
        aim.SellPrice,
        sct.AdditionalCost,
        sct.Description,
        sct.Weights,
        sct.VatAmount,
        sct.MiscCostGradeLC,
        (
            ISNULL(aim.SellPrice, 0) * ISNULL(aic.OrderedQuantity, 0)
        ) + ISNULL(sct.AdditionalCost, 0) + ISNULL(sct.MiscCostGradeLC, 0) AS 'SubTotal',
        (
            ISNULL(aim.SellPrice, 0) * ISNULL(aic.OrderedQuantity, 0)
        ) + ISNULL(sct.AdditionalCost, 0) + ISNULL(sct.MiscCostGradeLC, 0) + ISNULL(sct.VatAmount, 0) AS 'TotalAmount',
        aic.AmountReceived,
        aic.OrderedQuantity
    FROM
        AppProformaCustomers aic
        JOIN (
            SELECT
                id,
                Description,
                SellerId
            FROM
                AppInquiryFuelDetails
            WHERE
                IsDeleted = 0
                AND IsLosted = 0
        ) aifd ON aifd.Id = aic.InquiryFuelDetailId
        JOIN MISubProformaCusTable sct ON sct.Id = aic.Id
        LEFT JOIN AppInquiryOffers aio ON aio.InquiryDetailId = aic.InquiryDetailId
        and aio.SellerId = aifd.SellerId
        and aio.isdeleted = 0
        LEFT JOIN AppInquiryMargins aim ON aim.InquiryDetailId = aic.InquiryDetailId
        and aim.InquirySellerDetailId = aic.InquirySellerDetailId
        and aim.isdeleted = 0
),
WeightsSubTotalPC AS (
    SELECT
        Id,
        InquiryDetailId,
        InquiryFuelDetailId,
        MergeCode,
        CASE
            WHEN SubTotal = 0 THEN 0
            ELSE SubTotal / SUM(SubTotal) OVER (PARTITION BY InquiryDetailId, MergeCode)
        END AS Weights
    FROM
        ProformaCustomerTable
),
ProformaCustomersTest AS (
    SELECT
        it.Id,
        it.InquiryDetailId,
        it.InquiryFuelDetailId,
        it.ProformaCode,
        it.CurrencyId,
        it.ExchangeRate,
        it.SellPrice,
        it.Description,
        it.MergeCode,
        it.OrderedQuantity,
        wc.Weights,
        it.SubTotal,
        it.VatAmount,
        it.AdditionalCost,
        it.TotalAmount,
        CASE
            WHEN AmountReceived != 0
            AND AmountReceived IS NOT NULL THEN AmountReceived
            ELSE (
                MAX(
                    CASE
                        WHEN AmountReceived IS NOT NULL THEN AmountReceived
                        ELSE NULL
                    END
                ) OVER (
                    PARTITION BY it.InquiryDetailId,
                    it.MergeCode
                    ORDER BY
                        Description ROWS BETWEEN UNBOUNDED PRECEDING
                        AND CURRENT ROW
                )
            )
        END AS 'AmountReceivedSoFars'
    FROM
        ProformaCustomerTable it
        LEFT JOIN WeightsSubTotalPC wc ON wc.Id = it.Id
),
ProformaCustomerTables AS (
    SELECT
        Id,
        InquiryDetailId,
        InquiryFuelDetailId,
        ProformaCode,
        CurrencyId,
        ExchangeRate,
        SellPrice,
        Description,
        MergeCode,
        OrderedQuantity,
        SubTotal,
        VatAmount,
        AdditionalCost,
        TotalAmount,
        CASE
            WHEN TotalAmount = 0 THEN 0
            ELSE (
                AmountReceivedSoFars - (
                    AmountReceivedSoFars * (
                        (
                            SUM(TotalAmount) OVER (PARTITION BY InquiryDetailId, MergeCode) - SUM(SubTotal) OVER (PARTITION BY InquiryDetailId, MergeCode)
                        ) / SUM(TotalAmount) OVER (PARTITION BY InquiryDetailId, MergeCode)
                    )
                )
            ) * Weights
        END AS 'AmountReceivedSoFar'
    FROM
        ProformaCustomersTest
),
SubCustomerProformaTable AS (
    SELECT
        aic.Id,
        aic.InquiryDetailId,
        aic.InquiryFuelDetailId,
        aic.ProformaCode,
        aim.CurrencyId,
        aim.ExchangeRate,
        aim.SellPrice,
        aifd.Description,
        aic.MergeCode,
        aic.OrderedQuantity,
        aic.SubTotal,
        aic.VatAmount,
        aic.AdditionalCost,
        aic.TotalAmount,
        CASE
            WHEN aic.TotalAmount = 0 THEN 0
            ELSE aic.AmountReceived - (
                aic.AmountReceived * (
                    (aic.TotalAmount - aic.SubTotal) / aic.TotalAmount
                )
            )
        END AS AmountPaidSoFarWO
    FROM
        AppProformaCustomers aic
        JOIN (
            SELECT
                id,
                Description,
                SellerId
            FROM
                AppInquiryFuelDetails
            WHERE
                IsDeleted = 0
                AND IsLosted = 0
        ) aifd ON aifd.Id = aic.InquiryFuelDetailId
        LEFT JOIN (
            SELECT
                ProformaCustomerId,
                SUM(Amount) AS Amount,
                SUM(AmountUsd) AS AmountUsd
            FROM
                AppProformaMiscCosts
            WHERE
                IsDeleted = 0
            GROUP BY
                ProformaCustomerId
        ) aimc ON aimc.ProformaCustomerId = aic.Id
        LEFT JOIN AppInquiryOffers aio ON aio.InquiryDetailId = aic.InquiryDetailId
        and aio.SellerId = aifd.SellerId
        and aio.isdeleted = 0
        LEFT JOIN AppInquiryMargins aim ON aim.InquiryDetailId = aic.InquiryDetailId
        and aim.InquirySellerDetailId = aic.InquirySellerDetailId
        and aim.isdeleted = 0
    WHERE
        aic.IsDeleted = 0
        AND MergeCode IS NULL
),
ProformaCustomerTableNew AS (
    SELECT
        *
    FROM
        ProformaCustomerTables
    UNION
    ALL
    SELECT
        *
    FROM
        SubCustomerProformaTable
),
MICSubInvoiceTable AS (
    SELECT
        aic.Id,
        aic.InquiryDetailId,
        aic.InquiryFuelDetailId,
        aic.InvoiceCode,
        aic.ReceivableType,
        aic.PaymentDueDate,
        aic.AmountReceivedDate,
        aic.ApprovedOn,
        aic.AcknowledgementSentOn,
        aic.InquirySellerDetailId,
        aifd.Description,
        aic.MergeCode,
        aic.BdnBillingQuantity,
        aic.SubTotal,
        (aimc.AmountUsd / aic.ExchangeRate) AS 'MiscCostGradeLC',
        CASE
            WHEN (aic.AdditionalCost / aic.ExchangeRate) != 0
            AND (aic.AdditionalCost / aic.ExchangeRate) IS NOT NULL THEN (aic.AdditionalCost / aic.ExchangeRate) * (
                aic.BdnBillingQuantity * 1.0 / SUM(aic.BdnBillingQuantity) OVER (PARTITION BY aic.InquiryDetailId, aic.MergeCode)
            )
            ELSE (
                MAX(
                    CASE
                        WHEN (aic.AdditionalCost / aic.ExchangeRate) IS NOT NULL THEN (aic.AdditionalCost / aic.ExchangeRate)
                        ELSE NULL
                    END
                ) OVER (
                    PARTITION BY aic.InquiryDetailId,
                    aic.MergeCode
                    ORDER BY
                        aifd.Description ROWS BETWEEN UNBOUNDED PRECEDING
                        AND CURRENT ROW
                )
            ) * (
                aic.BdnBillingQuantity * 1.0 / SUM(aic.BdnBillingQuantity) OVER (PARTITION BY aic.InquiryDetailId, aic.MergeCode)
            )
        END AS 'AdditionalCost',
        CASE
            WHEN aic.AdditionalCost != 0
            AND aic.AdditionalCost IS NOT NULL THEN aic.AdditionalCost * (
                aic.BdnBillingQuantity * 1.0 / SUM(aic.BdnBillingQuantity) OVER (PARTITION BY aic.InquiryDetailId, aic.MergeCode)
            )
            ELSE (
                MAX(
                    CASE
                        WHEN aic.AdditionalCost IS NOT NULL THEN aic.AdditionalCost
                        ELSE NULL
                    END
                ) OVER (
                    PARTITION BY aic.InquiryDetailId,
                    aic.MergeCode
                    ORDER BY
                        aifd.Description ROWS BETWEEN UNBOUNDED PRECEDING
                        AND CURRENT ROW
                )
            ) * (
                aic.BdnBillingQuantity * 1.0 / SUM(aic.BdnBillingQuantity) OVER (PARTITION BY aic.InquiryDetailId, aic.MergeCode)
            )
        END AS 'AdditionalCostUSD',
        CASE
            WHEN aic.Discount != 0
            AND aic.Discount IS NOT NULL THEN aic.Discount * (
                aic.BdnBillingQuantity * 1.0 / SUM(aic.BdnBillingQuantity) OVER (PARTITION BY aic.InquiryDetailId, aic.MergeCode)
            )
            ELSE (
                MAX(
                    CASE
                        WHEN aic.Discount IS NOT NULL THEN aic.Discount
                        ELSE NULL
                    END
                ) OVER (
                    PARTITION BY aic.InquiryDetailId,
                    aic.MergeCode
                    ORDER BY
                        aifd.Description ROWS BETWEEN UNBOUNDED PRECEDING
                        AND CURRENT ROW
                )
            ) * (
                aic.BdnBillingQuantity * 1.0 / SUM(aic.BdnBillingQuantity) OVER (PARTITION BY aic.InquiryDetailId, aic.MergeCode)
            )
        END AS 'Discount',
        CASE
            WHEN aic.VatAmount != 0
            AND aic.VatAmount IS NOT NULL THEN aic.VatAmount * (
                aic.BdnBillingQuantity * 1.0 / SUM(aic.BdnBillingQuantity) OVER (PARTITION BY aic.InquiryDetailId, aic.MergeCode)
            )
            ELSE (
                MAX(
                    CASE
                        WHEN aic.VatAmount IS NOT NULL THEN aic.VatAmount
                        ELSE NULL
                    END
                ) OVER (
                    PARTITION BY aic.InquiryDetailId,
                    aic.MergeCode
                    ORDER BY
                        aifd.Description ROWS BETWEEN UNBOUNDED PRECEDING
                        AND CURRENT ROW
                )
            ) * (
                aic.BdnBillingQuantity * 1.0 / SUM(aic.BdnBillingQuantity) OVER (PARTITION BY aic.InquiryDetailId, aic.MergeCode)
            )
        END AS 'VatAmount',
        aic.BdnBillingQuantity * 1.0 / SUM(aic.BdnBillingQuantity) OVER (PARTITION BY aic.InquiryDetailId, aic.MergeCode) AS 'Weights'
    FROM
        AppInvoiceCustomers aic
        JOIN (
            SELECT
                id,
                Description
            FROM
                AppInquiryFuelDetails
            WHERE
                IsDeleted = 0
                AND IsLosted = 0
        ) aifd ON aifd.Id = aic.InquiryFuelDetailId
        LEFT JOIN (
            SELECT
                InvoiceCustomerId,
                SUM(Amount) AS Amount,
                SUM(AmountUsd) AS AmountUsd
            FROM
                AppInvoiceMiscCosts
            WHERE
                IsDeleted = 0
            GROUP BY
                InvoiceCustomerId
        ) aimc ON aimc.InvoiceCustomerId = aic.Id
    WHERE
        IsDeleted = 0
        AND InvoiceType = 0
        AND MergeCode IS NOT NULL
),
InvoiceCustomerTable AS (
    SELECT
        aic.Id,
        aic.InquiryDetailId,
        aic.MergeCode,
        aic.InquiryFuelDetailId,
        aic.InvoiceCode,
        aic.CurrencyId,
        aic.ExchangeRate,
        aic.ReceivableType,
        aic.PaymentDueDate,
        aic.AmountReceivedDate,
        aic.ApprovedOn,
        aic.AcknowledgementSentOn,
        aic.SellPrice,
        sct.AdditionalCost,
        sct.Description,
        sct.Weights,
        sct.VatAmount,
        sct.MiscCostGradeLC,
        sct.Discount,
        (
            ISNULL(aic.SellPrice, 0) * ISNULL(aic.BdnBillingQuantity, 0)
        ) + ISNULL(sct.AdditionalCost, 0) + ISNULL(sct.MiscCostGradeLC, 0) - ISNULL(sct.Discount, 0) AS 'SubTotal',
        (
            ISNULL(aic.SellPrice, 0) * ISNULL(aic.BdnBillingQuantity, 0)
        ) + ISNULL(sct.AdditionalCost, 0) + ISNULL(sct.MiscCostGradeLC, 0) + ISNULL(sct.VatAmount, 0) - ISNULL(sct.Discount, 0) AS 'TotalAmount',
        aic.AmountReceivedSoFar,
        aic.BdnBillingQuantity
    FROM
        AppInvoiceCustomers aic
        JOIN MICSubInvoiceTable sct ON sct.Id = aic.Id
),
WeightsCSubTotal AS (
    SELECT
        Id,
        InquiryDetailId,
        InquiryFuelDetailId,
        MergeCode,
        CASE
            WHEN SubTotal = 0 THEN 0
            ELSE SubTotal / SUM(SubTotal) OVER (PARTITION BY InquiryDetailId, MergeCode)
        END AS Weights
    FROM
        InvoiceCustomerTable
),
InvoiceCustomersTest AS (
    SELECT
        it.Id,
        it.InquiryDetailId,
        it.InquiryFuelDetailId,
        it.InvoiceCode,
        it.ExchangeRate,
        it.CurrencyId,
        it.ReceivableType,
        it.PaymentDueDate,
        it.AmountReceivedDate,
        it.ApprovedOn,
        it.AcknowledgementSentOn,
        it.SellPrice,
        it.Description,
        it.MergeCode,
        it.BdnBillingQuantity,
        wc.Weights,
        it.SubTotal,
        it.VatAmount,
        it.Discount,
        it.AdditionalCost,
        it.TotalAmount,
        CASE
            WHEN AmountReceivedSoFar != 0
            AND AmountReceivedSoFar IS NOT NULL THEN AmountReceivedSoFar
            ELSE (
                MAX(
                    CASE
                        WHEN AmountReceivedSoFar IS NOT NULL THEN AmountReceivedSoFar
                        ELSE NULL
                    END
                ) OVER (
                    PARTITION BY it.InquiryDetailId,
                    it.MergeCode
                    ORDER BY
                        Description ROWS BETWEEN UNBOUNDED PRECEDING
                        AND CURRENT ROW
                )
            )
        END AS 'AmountReceivedSoFars'
    FROM
        InvoiceCustomerTable it
        LEFT JOIN WeightsCSubTotal wc ON wc.Id = it.Id
),
InvoiceCustomerTables AS (
    SELECT
        ict.Id,
        ict.InquiryDetailId,
        ict.InquiryFuelDetailId,
        ict.InvoiceCode,
        ict.CurrencyId,
        ict.ReceivableType,
        ict.PaymentDueDate,
        ict.AmountReceivedDate,
        ict.ApprovedOn,
        ict.AcknowledgementSentOn,
        ict.SellPrice,
        ict.ExchangeRate,
        ict.Description,
        ict.MergeCode,
        ict.BdnBillingQuantity,
        ict.SubTotal,
        ict.VatAmount,
        ict.Discount,
        ict.AdditionalCost,
        ict.TotalAmount,
        CASE
            WHEN ict.TotalAmount = 0 THEN 0
            ELSE ISNULL(
                (
                    (
                        ict.AmountReceivedSoFars - (
                            ict.AmountReceivedSoFars * (
                                (
                                    SUM(ict.TotalAmount) OVER (PARTITION BY ict.InquiryDetailId, ict.MergeCode) - SUM(ict.SubTotal) OVER (PARTITION BY ict.InquiryDetailId, ict.MergeCode)
                                ) / NULLIF(
                                    SUM(ict.TotalAmount) OVER (PARTITION BY ict.InquiryDetailId, ict.MergeCode),
                                    0
                                )
                            )
                        )
                    ) * Weights
                ),
                0
            ) + ISNULL(
                SUM(pst.AmountReceivedSoFar) OVER (PARTITION BY ict.InquiryDetailId, ict.MergeCode) * Weights,
                0
            )
        END AS 'AmountRecievedSoFar'
    FROM
        InvoiceCustomersTest ict
        LEFT JOIN ProformaCustomerTableNew pst ON pst.InquiryFuelDetailId = ict.InquiryFuelDetailId
),
SubCustomerTable AS (
    SELECT
        aic.Id,
        aic.InquiryDetailId,
        aic.InquiryFuelDetailId,
        aic.InvoiceCode,
        aic.CurrencyId,
        aic.ReceivableType,
        aic.PaymentDueDate,
        aic.AmountReceivedDate,
        aic.ApprovedOn,
        aic.AcknowledgementSentOn,
        aic.SellPrice,
        aic.ExchangeRate,
        aifd.Description,
        aic.MergeCode,
        aic.BdnBillingQuantity,
        aic.SubTotal,
        aic.VatAmount,
        aic.Discount,
        aic.AdditionalCost,
        aic.TotalAmount,
        CASE
            WHEN aic.TotalAmount = 0 THEN 0
            ELSE ISNULL(
                aic.AmountReceivedSoFar - (
                    aic.AmountReceivedSoFar * (
                        (aic.TotalAmount - aic.SubTotal) / aic.TotalAmount
                    )
                ),
                0
            ) + ISNULL(pst.AmountReceivedSoFar, 0)
        END AS AmountReceivedSoFarWO
    FROM
        AppInvoiceCustomers aic
        JOIN (
            SELECT
                id,
                Description
            FROM
                AppInquiryFuelDetails
            WHERE
                IsDeleted = 0
                AND IsLosted = 0
        ) aifd ON aifd.Id = aic.InquiryFuelDetailId
        LEFT JOIN (
            SELECT
                InvoiceCustomerId,
                SUM(Amount) AS Amount,
                SUM(AmountUsd) AS AmountUsd
            FROM
                AppInvoiceMiscCosts
            WHERE
                IsDeleted = 0
            GROUP BY
                InvoiceCustomerId
        ) aimc ON aimc.InvoiceCustomerId = aic.Id
        LEFT JOIN ProformaCustomerTableNew pst ON pst.Inquirydetailid = aic.InquiryFuelDetailId
    WHERE
        IsDeleted = 0
        AND InvoiceType = 0
        AND aic.MergeCode IS NULL
),
InvoiceCustomerTableNew AS (
    SELECT
        *
    FROM
        InvoiceCustomerTables
    UNION
    ALL
    SELECT
        *
    FROM
        SubCustomerTable
),
DateSelection AS (
    SELECT
        TOP 1 WITH TIES aic.MergeCode,
        aic.InquiryFuelDetailId AS FirstFuelDetailId
    FROM
        AppInvoiceCustomers aic
        JOIN AppInquiryFuelDetails aifd ON aifd.Id = aic.InquiryFuelDetailId
        AND aifd.IsDeleted = 0
        AND aifd.IsLosted = 0
    WHERE
        aic.MergeCode IS NOT NULL
        AND aic.IsDeleted = 0
    ORDER BY
        ROW_NUMBER() OVER (
            PARTITION BY aic.MergeCode
            ORDER BY
                aifd.Description
        )
),
DateReceivedLookup AS (
    SELECT
        d.MergeCode,
        COALESCE(
            aic.AmountReceivedDate,
            aic.acknowledgementsenton
        ) AS MergeDateReceived
    FROM
        DateSelection d
        JOIN AppInvoiceCustomers aic ON aic.InquiryFuelDetailId = d.FirstFuelDetailId
        AND aic.MergeCode = d.MergeCode
),
ExcessDaysCalc AS (
    SELECT
        aid.CustomerNominationId,
        aic.InvoiceCode,
        aic.MergeCode,
        aic.PaymentDueDate,
        CASE
            WHEN aic.MergeCode IS NULL THEN COALESCE(
                aic.AmountReceivedDate,
                aic.acknowledgementsenton
            )
            ELSE drl.MergeDateReceived
        END AS DateReceived,
        ROUND(
            CASE
                WHEN aic.MergeCode IS NULL THEN CAST(
                    DATEDIFF(
                        DAY,
                        aic.PaymentDueDate,
                        COALESCE(
                            aic.AmountReceivedDate,
                            aic.acknowledgementsenton
                        )
                    ) AS FLOAT
                )
                ELSE CAST(
                    DATEDIFF(DAY, aic.PaymentDueDate, drl.MergeDateReceived) AS FLOAT
                )
            END,
            2
        ) AS ExcessDays,
        CASE
            WHEN aic.MergeCode IS NULL THEN 1
            WHEN EXISTS (
                SELECT
                    1
                FROM
                    DateSelection ds
                WHERE
                    ds.MergeCode = aic.MergeCode
                    AND ds.FirstFuelDetailId = aic.InquiryFuelDetailId
            ) THEN 1
            ELSE 0
        END AS IncludeFlag
    FROM
        AppInvoiceCustomers aic
        JOIN AppInquiryDetails aid ON aid.Id = aic.Inquirydetailid
        AND aid.IsDeleted = 0
        LEFT JOIN DateReceivedLookup drl ON drl.MergeCode = aic.MergeCode
    WHERE
        aic.IsDeleted = 0
        AND InvoiceStatus IN (50, 60)
),
PaymentPerformance AS (
    SELECT
        CustomerNominationId,
        ROUND(AVG(ExcessDays), 2) AS [Payment performance]
    FROM
        ExcessDaysCalc
    WHERE
        IncludeFlag = 1
    GROUP BY
        CustomerNominationId
),
MainAndBookedInvoices AS (
    SELECT
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
            WHEN aid.InquiryStatus NOT IN (900, 1000) THEN NULL
            ELSE 'Invoice'
        END AS 'Invoice Type',
        av.Name AS 'Vessel',
        ap.Name AS 'Port',
        aup.Name AS 'Trader',
        aup.UserId AS 'UserId',
        aup.Email AS 'UserEmail',
        acus.Name AS 'Buyer',
        pp.[Payment performance],
        CASE
            WHEN acg.Name = 'Scorpio' THEN 'Scorpio'
            WHEN (
                acg.Name = 'Cargo deals'
                OR acg.Name = 'Cargo Deals'
                OR acg.Name = 'Cargo deal'
                OR acg.Name = 'Cargo Deal'
            ) THEN 'Cargo Deals'
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
            WHEN aid.InquiryStatus NOT IN (700, 800, 9000) THEN CONVERT(DATE, ad.DeliveryDate)
            WHEN (
                aifd.isBooked = 1
                AND aifd.IsNominated = 1
                AND aifd.IsDelivered = 0
            ) THEN CONVERT(DATE, aid.DeliveryStartDateNomination)
            WHEN (
                aifd.isBooked = 1
                AND aifd.IsNominated = 1
                AND aifd.IsCancelled = 1
                AND aics.CancelTypes = 0
            ) THEN CONVERT(DATE, aic.ApprovedOn)
        END AS 'Delivery Date',
        aim.Margin AS 'Margin per MT',
        CASE
            WHEN agg.Name = 'GO' THEN CASE
                WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 0 THEN COALESCE(
                    aic.BdnBillingQuantity,
                    ad.BDNQty,
                    ain.QuantityMax
                ) --MT
                WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 1 THEN COALESCE(
                    aic.BdnBillingQuantity,
                    ad.BDNQty,
                    ain.QuantityMax
                ) * 0.001 --KG
                WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 2 THEN COALESCE(
                    aic.BdnBillingQuantity,
                    ad.BDNQty,
                    ain.QuantityMax
                ) * 0.00085 --Litres
                WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 3 THEN COALESCE(
                    aic.BdnBillingQuantity,
                    ad.BDNQty,
                    ain.QuantityMax
                ) * 0.0038641765 --IG
                WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 4 THEN COALESCE(
                    aic.BdnBillingQuantity,
                    ad.BDNQty,
                    ain.QuantityMax
                ) * 0.85 --CBM
                WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 5 THEN COALESCE(
                    aic.BdnBillingQuantity,
                    ad.BDNQty,
                    ain.QuantityMax
                ) * 0.0032 --US Gallons
                WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 6 THEN COALESCE(
                    aic.BdnBillingQuantity,
                    ad.BDNQty,
                    ain.QuantityMax
                ) * 0.134 --Barrels
                WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 7 THEN COALESCE(
                    aic.BdnBillingQuantity,
                    ad.BDNQty,
                    ain.QuantityMax
                ) * 0.85 --KL
            END
            WHEN agg.Name = 'FO' THEN CASE
                WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 0 THEN COALESCE(
                    aic.BdnBillingQuantity,
                    ad.BDNQty,
                    ain.QuantityMax
                ) --MT
                WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 1 THEN COALESCE(
                    aic.BdnBillingQuantity,
                    ad.BDNQty,
                    ain.QuantityMax
                ) * 0.001 --KG
                WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 2 THEN COALESCE(
                    aic.BdnBillingQuantity,
                    ad.BDNQty,
                    ain.QuantityMax
                ) * 0.00094 --Litres
                WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 3 THEN COALESCE(
                    aic.BdnBillingQuantity,
                    ad.BDNQty,
                    ain.QuantityMax
                ) * 0.0042733246 --IG
                WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 4 THEN COALESCE(
                    aic.BdnBillingQuantity,
                    ad.BDNQty,
                    ain.QuantityMax
                ) * 0.94 --CBM
                WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 5 THEN COALESCE(
                    aic.BdnBillingQuantity,
                    ad.BDNQty,
                    ain.QuantityMax
                ) * 0.0037 --US Gallons
                WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 6 THEN COALESCE(
                    aic.BdnBillingQuantity,
                    ad.BDNQty,
                    ain.QuantityMax
                ) * 0.157 --Barrels
                WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 7 THEN COALESCE(
                    aic.BdnBillingQuantity,
                    ad.BDNQty,
                    ain.QuantityMax
                ) * 0.94 --KL
            END
            ELSE COALESCE(
                aic.BdnBillingQuantity,
                ad.BDNQty,
                ain.QuantityMax
            )
        END AS 'Qty',
        aic.InvoiceCode AS 'Customer Invoice Number',
        CASE
            WHEN (aifd.isBooked = 1 AND aifd.IsNominated = 1 AND aifd.IsDelivered = 0)
            AND COALESCE(cusCur1.Code, cusCur2.Code) = 'AED' THEN (
                (ain.QuantityMax * (aim.SellPrice / 3.6725)) + ISNULL(aimc.AmountUsd, 0)
            )
            WHEN (aifd.isBooked = 1 AND aifd.IsNominated = 1 AND aifd.IsDelivered = 0)
            AND COALESCE(cusCur1.Code, cusCur2.Code) <> 'AED' THEN (
                (ain.QuantityMax * aim.SellPriceUsd) + ISNULL(aimc.AmountUsd, 0)
            )
            WHEN (aifd.isBooked = 1 AND aifd.IsNominated = 1 AND (aifd.IsDelivered = 1 OR aifd.IsCancelled = 1))
            AND COALESCE(cusCur1.Code, cusCur2.Code) = 'AED' THEN (aic.SubTotal / 3.6725)
            ELSE (aic.SubTotal * aic.ExchangeRate)
        END AS 'Customer Invoice Amount',
        CASE
            WHEN (aifd.isBooked = 1 AND aifd.IsNominated = 1 AND aifd.IsDelivered = 0)
            AND COALESCE(cusCur1.Code, cusCur2.Code) = 'AED' THEN (
                (ain.QuantityMax * (aim.SellPrice / 3.6725)) + ISNULL(aimc.AmountUsd, 0)
            )
            WHEN (aifd.isBooked = 1 AND aifd.IsNominated = 1 AND aifd.IsDelivered = 0)
            AND COALESCE(cusCur1.Code, cusCur2.Code) <> 'AED' THEN (
                (ain.QuantityMax * aim.SellPriceUsd) + ISNULL(aimc.AmountUsd, 0)
            )
            WHEN (aifd.isBooked = 1 AND aifd.IsNominated = 1 AND (aifd.IsDelivered = 1 OR aifd.IsCancelled = 1))
            AND COALESCE(cusCur1.Code, cusCur2.Code) = 'AED' THEN (aic.TotalAmount / 3.6725)
            ELSE (aic.TotalAmount * aic.ExchangeRate)
        END AS 'Customer Invoice Total Amount',
        ais.InvoiceNumber AS 'Seller Invoice Number',
        CASE
            WHEN (aifd.isBooked = 1 AND aifd.IsNominated = 1 AND aifd.IsDelivered = 0)
            AND COALESCE(selCur1.Code, selCur2.Code) = 'AED' THEN (
                (ain.QuantityMax * (aim.BuyPrice / 3.6725)) + ISNULL(aims.AmountUsd, 0)
            )
            WHEN (aifd.isBooked = 1 AND aifd.IsNominated = 1 AND aifd.IsDelivered = 0)
            AND COALESCE(selCur1.Code, selCur2.Code) <> 'AED' THEN (
                (ain.QuantityMax * aim.BuyPriceUsd) + ISNULL(aims.AmountUsd, 0)
            )
            WHEN (aifd.isBooked = 1 AND aifd.IsNominated = 1 AND (aifd.IsDelivered = 1 OR aifd.IsCancelled = 1))
            AND COALESCE(selCur1.Code, selCur2.Code) = 'AED' THEN (ais.SubTotal / 3.6725)
            ELSE (ais.SubTotal * ais.ExchangeRate)
        END AS 'Seller Invoice Amount',
        CASE
            WHEN (aifd.isBooked = 1 AND aifd.IsNominated = 1 AND aifd.IsDelivered = 0)
            AND COALESCE(selCur1.Code, selCur2.Code) = 'AED' THEN (
                (ain.QuantityMax * (aim.BuyPrice / 3.6725)) + ISNULL(aims.AmountUsd, 0)
            )
            WHEN (aifd.isBooked = 1 AND aifd.IsNominated = 1 AND aifd.IsDelivered = 0)
            AND COALESCE(selCur1.Code, selCur2.Code) <> 'AED' THEN (
                (ain.QuantityMax * aim.BuyPriceUsd) + ISNULL(aims.AmountUsd, 0)
            )
            WHEN (aifd.isBooked = 1 AND aifd.IsNominated = 1 AND (aifd.IsDelivered = 1 OR aifd.IsCancelled = 1))
            AND COALESCE(selCur1.Code, selCur2.Code) = 'AED' THEN (ais.TotalAmount / 3.6725)
            ELSE (ais.TotalAmount * ais.ExchangeRate)
        END AS 'Seller Invoice Total Amount',
        CASE
            WHEN (aifd.isBooked = 1 AND aifd.IsNominated = 1 AND aifd.IsDelivered = 0) THEN NULL
            WHEN (aifd.isBooked = 1 AND aifd.IsNominated = 1 AND (aifd.IsDelivered = 1 OR aifd.IsCancelled = 1))
            AND COALESCE(cusCur1.Code, cusCur1.Code) = 'AED' THEN (aic.AmountRecievedSoFar / 3.6725)
            ELSE (aic.AmountRecievedSoFar * aic.ExchangeRate)
        END AS 'Amount Received',
        CASE
            WHEN (aifd.isBooked = 1 AND aifd.IsNominated = 1 AND aifd.IsDelivered = 0) THEN NULL
            WHEN (aifd.isBooked = 1 AND aifd.IsNominated = 1 AND (aifd.IsDelivered = 1 OR aifd.IsCancelled = 1))
            AND COALESCE(selCur1.Code, selCur2.Code) = 'AED' THEN (ais.AmountPaidSoFar / 3.6725)
            ELSE (ais.AmountPaidSoFar * ais.ExchangeRate)
        END AS 'Amount Paid',
        CASE
            WHEN (aifd.isBooked = 1 AND aifd.IsNominated = 1 AND aifd.IsDelivered = 0) THEN 'Not paid'
            WHEN (aifd.isBooked = 1 AND aifd.IsNominated = 1 AND (aifd.IsDelivered = 1 OR aifd.IsCancelled = 1)) THEN CASE
                WHEN ais.PayableType IS NULL THEN 'Not paid'
                WHEN ais.PayableType = 0 THEN 'Not paid'
                WHEN ais.PayableType = 1 THEN 'Partly paid'
                WHEN ais.PayableType = 2 THEN 'Paid'
            END
        END AS 'Payment Status',
        CASE
            WHEN (aifd.isBooked = 1 AND aifd.IsNominated = 1 AND aifd.IsDelivered = 0) THEN 'Not received'
            WHEN (aifd.isBooked = 1 AND aifd.IsNominated = 1 AND (aifd.IsDelivered = 1 OR aifd.IsCancelled = 1)) THEN CASE
                WHEN aic.ReceivableType IS NULL THEN 'Not received'
                WHEN aic.ReceivableType = 0 THEN 'Not received'
                WHEN aic.ReceivableType = 1 THEN 'Partly received'
                WHEN aic.ReceivableType = 2 THEN 'Received'
            END
        END AS 'Receipt Status',
        (
            COALESCE(
                (ais.BuyPrice * ais.ExchangeRate),
                aim.BuyPriceUsd
            )
        ) AS 'Buying Price',
        COALESCE(selCur1.Code, selCur2.Code) AS 'Buying Currency',
        (
            COALESCE(
                (aic.SellPrice * aic.ExchangeRate),
                aim.SellPrice
            )
        ) AS 'Selling Price',
        COALESCE(cusCur1.Code, cusCur2.Code) AS 'Selling Currency',
        ISNULL(
            CASE
                WHEN aibd.SellerUnitLumpsum = 0
                AND selCur2.code = 'AED' THEN (
                    (aibd.SellerBrokerage / 3.6725) * ain.QuantityMax
                )
                WHEN aibd.SellerUnitLumpsum = 0
                AND selCur2.code <> 'AED' THEN (
                    aibd.SellerBrokerage * aibd.SellerExchangeRate * ain.QuantityMax
                )
                WHEN aibd.SellerUnitLumpsum = 1
                AND selCur2.code = 'AED' THEN (aibd.SellerBrokerage / 3.6725)
                WHEN aibd.SellerUnitLumpsum = 1
                AND selCur2.code <> 'AED' THEN (aibd.SellerBrokerage * aibd.SellerExchangeRate)
                ELSE 0
            END,
            0
        ) + ISNULL(
            CASE
                WHEN aibd.CustomerUnitLumpsum = 0
                AND cusCur2.Code = 'AED' THEN (
                    (aibd.CustomerBrokerage / 3.6725) * ain.QuantityMax
                )
                WHEN aibd.CustomerUnitLumpsum = 0
                AND cusCur2.Code <> 'AED' THEN (
                    aibd.CustomerBrokerage * aibd.CustomerExchangeRate * ain.QuantityMax
                )
                WHEN aibd.CustomerUnitLumpsum = 1
                AND cusCur2.Code = 'AED' THEN (aibd.CustomerBrokerage / 3.6725)
                WHEN aibd.CustomerUnitLumpsum = 1
                AND cusCur2.Code <> 'AED' THEN (
                    aibd.CustomerBrokerage * aibd.CustomerExchangeRate
                )
                ELSE 0
            END,
            0
        ) AS 'Total Brokerage'
    FROM
        AppInquiryFuelDetails aifd
        JOIN AppInquiryDetails aid ON aid.Id = aifd.InquiryDetailId
        JOIN AppInquirySellerDetails aisd ON aisd.InquiryFuelDetailId = aifd.Id
        and aisd.SellerId = aifd.SellerId
        and aisd.IsDeleted = 0
        LEFT JOIN AppSellers asel ON asel.Id = aifd.SellerId
        and asel.IsDeleted = 0
        LEFT JOIN AppSuppliers asup ON asup.Id = aisd.SupplierId
        and asup.IsDeleted = 0
        LEFT JOIN AppVessel av ON av.Id = aid.VesselNominationId
        and av.IsDeleted = 0
        LEFT JOIN AppPorts ap ON ap.Id = aid.PortNominationId
        and ap.IsDeleted = 0
        LEFT JOIN AppUserProfiles aup ON aup.Id = aid.UserProfileId
        and aup.IsDeleted = 0
        LEFT JOIN AppCustomers acus ON acus.Id = aid.CustomerNominationId
        and acus.IsDeleted = 0
        LEFT JOIN AppCustomerGroups acg ON acg.id = acus.CustomerGroupId
        and acg.IsDeleted = 0
        LEFT JOIN AppInquiryNominations ain ON ain.InquirySellerDetailId = aisd.Id
        and ain.IsDeleted = 0
        and ain.InquiryDetailId = aifd.InquiryDetailId
        LEFT JOIN AppDeliveries ad ON ad.InquiryFuelDetailId = aifd.Id
        and ad.IsDeleted = 0
        LEFT JOIN InvoiceCustomerTableNew aic ON aic.InquiryFuelDetailId = aifd.Id
        LEFT JOIN InvoiceSellerTableNew ais ON ais.InquiryFuelDetailId = aifd.Id
        LEFT JOIN AppInquiryMargins aim ON aim.InquirySellerDetailId = aisd.Id
        and aim.InquiryDetailId = aifd.InquiryDetailId
        and aim.IsDeleted = 0
        LEFT JOIN AppFuels af ON af.id = aifd.FuelId
        and af.IsDeleted = 0
        LEFT JOIN AppGradeGroups agg ON agg.Id = af.GradeGroupId
        and agg.IsDeleted = 0
        LEFT JOIN AppInquiryCancelStems aics ON aics.InquiryFuelDetailId = aifd.Id
        and aics.IsDeleted = 0
        LEFT JOIN (
            SELECT
                InquirySellerDetailId,
                SUM(Amount) AS Amount,
                SUM(AmountUsd) AS AmountUsd
            FROM
                AppInquiryMiscCosts
            WHERE
                FromBuyer = 1
                AND IsDeleted = 0
            GROUP BY
                InquirySellerDetailId
        ) aimc ON aimc.InquirySellerDetailId = aisd.Id
        LEFT JOIN (
            SELECT
                InquirySellerDetailId,
                SUM(Amount) AS Amount,
                SUM(AmountUsd) AS AmountUsd
            FROM
                AppInquiryMiscCosts
            WHERE
                ToSeller = 1
                AND IsDeleted = 0
            GROUP BY
                InquirySellerDetailId
        ) aims ON aims.InquirySellerDetailId = aisd.Id
        LEFT JOIN AppInquiryOffers aio ON aio.InquiryDetailId = aifd.InquiryDetailId
        and aio.SellerId = aifd.SellerId
        and aio.IsDeleted = 0
        LEFT JOIN AppCurrencies cusCur1 ON cusCur1.Id = aic.CurrencyId
        and cusCur1.IsDeleted = 0
        LEFT JOIN AppCurrencies selCur1 ON selCur1.Id = ais.CurrencyId
        and selCur1.IsDeleted = 0
        LEFT JOIN AppCurrencies cusCur2 ON cusCur2.Id = aim.CurrencyId
        and cusCur2.IsDeleted = 0
        LEFT JOIN AppCurrencies selCur2 ON selCur2.Id = aio.CurrencyId
        and selCur2.IsDeleted = 0
        LEFT JOIN PaymentPerformance pp ON pp.CustomerNominationId = aid.CustomerNominationId
        LEFT JOIN AppInquiryBrokerDetails aibd ON aibd.InquiryFuelDetailId = aifd.Id
        and aibd.IsDeleted = 0
        and (
            aibd.CustomerBrokerage is not null
            OR aibd.SellerBrokerage Is NOT NULL
        )
    WHERE
        aifd.IsDeleted = 0
        AND aifd.IsLosted = 0
        AND aid.InquiryStatus IN (650, 700, 800, 900, 1000, 9000)
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
            WHEN aic.InvoiceType = 1
            AND COALESCE(acurr.Code, acur.Code) = 'AED' THEN (- ABS(aic.SubTotal / 3.6725))
            WHEN aic.InvoiceType = 1
            AND COALESCE(acurr.Code, acur.Code) <> 'AED' THEN (- ABS(aic.SubTotal * aim.ExchangeRate))
            WHEN aic.InvoiceType = 2
            AND COALESCE(acurr.Code, acur.Code) = 'AED' THEN (aic.SubTotal / 3.6725)
            WHEN aic.InvoiceType = 2
            AND COALESCE(acurr.Code, acur.Code) <> 'AED' THEN (aic.SubTotal * aim.ExchangeRate)
        END AS 'Customer Invoice Amount',
        CASE
            WHEN aic.InvoiceType = 1
            AND COALESCE(acurr.Code, acur.Code) = 'AED' THEN (- ABS(aic.TotalAmount / 3.6725))
            WHEN aic.InvoiceType = 1
            AND COALESCE(acurr.Code, acur.Code) <> 'AED' THEN (- ABS(aic.TotalAmount * aic.ExchangeRate))
            WHEN aic.InvoiceType = 2
            AND COALESCE(acurr.Code, acur.Code) = 'AED' THEN (aic.TotalAmount / 3.6725)
            WHEN aic.InvoiceType = 2
            AND COALESCE(acurr.Code, acur.Code) <> 'AED' THEN (aic.TotalAmount * aic.ExchangeRate)
        END AS 'Customer Invoice Total Amount',
        CASE
            WHEN aic.InvoiceType = 1
            AND acur.Code = 'AED' THEN (- ABS(aic.AmountReceivedSoFar / 3.6725))
            WHEN aic.InvoiceType = 1
            AND acur.Code <> 'AED' THEN (
                - ABS(aic.AmountReceivedSoFar * aic.ExchangeRate)
            )
            WHEN aic.InvoiceType = 2
            AND acur.Code = 'AED' THEN (aic.AmountReceivedSoFar / 3.6725)
            WHEN aic.InvoiceType = 2
            AND acur.Code <> 'AED' THEN (aic.AmountReceivedSoFar * aic.ExchangeRate)
        END AS 'Amount Received',
        CASE
            WHEN (aifd.isBooked = 1 AND aifd.IsNominated = 1 AND aifd.IsDelivered = 0) THEN 'Not received'
            WHEN (aifd.isBooked = 1 AND aifd.IsNominated = 1 AND (aifd.IsDelivered = 1 OR aifd.IsCancelled = 1)) THEN CASE
                WHEN aic.ReceivableType IS NULL THEN 'Not received'
                WHEN aic.ReceivableType = 0 THEN 'Not received'
                WHEN aic.ReceivableType = 1 THEN 'Partly received'
                WHEN aic.ReceivableType = 2 THEN 'Received'
            END
        END AS 'Receipt Status',
        CASE
            WHEN aic.SellPrice IS NOT NULL THEN aic.SellPrice * aic.ExchangeRate
            WHEN aic.SubTotal IS NOT NULL
            AND COALESCE(ad.BdnQtyUnit, aifd.Unit) IS NOT NULL
            AND aic.InvoiceType = 1 THEN (
                (
                    - ABS(aic.SubTotal) / NULLIF(
                        COALESCE(
                            aic.BdnBillingQuantity,
                            ad.BDNQty,
                            ain.QuantityMax
                        ),
                        0
                    )
                ) * aic.ExchangeRate
            )
            WHEN aic.SubTotal IS NOT NULL
            AND COALESCE(ad.BdnQtyUnit, aifd.Unit) IS NOT NULL
            AND aic.InvoiceType = 2 THEN (
                (
                    aic.SubTotal / NULLIF(
                        COALESCE(
                            aic.BdnBillingQuantity,
                            ad.BDNQty,
                            ain.QuantityMax
                        ),
                        0
                    )
                ) * aic.ExchangeRate
            )
        END AS 'Selling Price',
        CASE
            WHEN agg.Name = 'GO' THEN CASE
                WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 0 THEN COALESCE(
                    aic.BdnBillingQuantity,
                    ad.BDNQty,
                    ain.QuantityMax
                ) --MT
                WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 1 THEN (
                    COALESCE(
                        aic.BdnBillingQuantity,
                        ad.BDNQty,
                        ain.QuantityMax
                    ) * 0.001
                ) --KG
                WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 2 THEN (
                    COALESCE(
                        aic.BdnBillingQuantity,
                        ad.BDNQty,
                        ain.QuantityMax
                    ) * 0.00085
                ) --Litres
                WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 3 THEN (
                    COALESCE(
                        aic.BdnBillingQuantity,
                        ad.BDNQty,
                        ain.QuantityMax
                    ) * 0.0038641765
                ) --IG
                WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 4 THEN (
                    COALESCE(
                        aic.BdnBillingQuantity,
                        ad.BDNQty,
                        ain.QuantityMax
                    ) * 0.85
                ) --CBM
                WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 5 THEN (
                    COALESCE(
                        aic.BdnBillingQuantity,
                        ad.BDNQty,
                        ain.QuantityMax
                    ) * 0.0032
                ) --US Gallons
                WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 6 THEN (
                    COALESCE(
                        aic.BdnBillingQuantity,
                        ad.BDNQty,
                        ain.QuantityMax
                    ) * 0.134
                ) --Barrels
                WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 7 THEN (
                    COALESCE(
                        aic.BdnBillingQuantity,
                        ad.BDNQty,
                        ain.QuantityMax
                    ) * 0.85
                ) --KL
            END
            WHEN agg.Name = 'FO' THEN CASE
                WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 0 THEN COALESCE(
                    aic.BdnBillingQuantity,
                    ad.BDNQty,
                    ain.QuantityMax
                ) --MT
                WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 1 THEN (
                    COALESCE(
                        aic.BdnBillingQuantity,
                        ad.BDNQty,
                        ain.QuantityMax
                    ) * 0.001
                ) --KG
                WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 2 THEN (
                    COALESCE(
                        aic.BdnBillingQuantity,
                        ad.BDNQty,
                        ain.QuantityMax
                    ) * 0.00094
                ) --Litres
                WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 3 THEN (
                    COALESCE(
                        aic.BdnBillingQuantity,
                        ad.BDNQty,
                        ain.QuantityMax
                    ) * 0.0042733246
                ) --IG
                WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 4 THEN (
                    COALESCE(
                        aic.BdnBillingQuantity,
                        ad.BDNQty,
                        ain.QuantityMax
                    ) * 0.94
                ) --CBM
                WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 5 THEN (
                    COALESCE(
                        aic.BdnBillingQuantity,
                        ad.BDNQty,
                        ain.QuantityMax
                    ) * 0.0037
                ) --US Gallons
                WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 6 THEN (
                    COALESCE(
                        aic.BdnBillingQuantity,
                        ad.BDNQty,
                        ain.QuantityMax
                    ) * 0.157
                ) --Barrels
                WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 7 THEN (
                    COALESCE(
                        aic.BdnBillingQuantity,
                        ad.BDNQty,
                        ain.QuantityMax
                    ) * 0.94
                ) --KL
            END
            ELSE COALESCE(
                aic.BdnBillingQuantity,
                ad.BDNQty,
                ain.QuantityMax
            )
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
            WHEN (
                acg.Name = 'Cargo deals'
                OR acg.Name = 'Cargo Deals'
                OR acg.Name = 'Cargo deal'
                OR acg.Name = 'Cargo Deal'
            ) THEN 'Cargo Deals'
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
        CONVERT(
            DATE,
            CASE
                WHEN (
                    aics.CancelTypes = 0
                    AND aifd.IsCancelled = 1
                ) THEN aic.ApprovedOn
                ELSE ad.DeliveryDate
            END
        ) AS 'Delivery Date',
        aim.Margin AS 'Margin per MT',
        COALESCE(acurr.Code, acur.Code) AS 'Selling Currency',
        ROW_NUMBER() OVER (
            PARTITION BY aifd.Id,
            aifd.Description,
            aic.InvoiceType
            ORDER BY
                aic.InvoiceCode
        ) AS RowNum,
        NULL AS 'Total Brokerage'
    FROM
        AppInquiryFuelDetails aifd
        JOIN AppInvoiceCustomers aic ON aic.InquiryFuelDetailId = aifd.Id
        AND aic.IsDeleted = 0
        AND aic.InvoiceType <> 0
        LEFT JOIN AppDeliveries ad ON ad.InquiryFuelDetailId = aifd.id
        and ad.IsDeleted = 0
        JOIN AppInquirySellerDetails aisd ON aisd.InquiryFuelDetailId = aifd.id
        and aisd.SellerId = aifd.SellerId
        and aisd.IsDeleted = 0
        JOIN AppInquiryNominations ain ON ain.InquirySellerDetailId = aisd.Id
        and ain.InquiryDetailId = aifd.InquiryDetailId
        and ain.IsDeleted = 0
        JOIN AppInquiryDetails aid ON aid.Id = aifd.InquiryDetailId
        and aid.isdeleted = 0
        LEFT JOIN AppFuels af ON af.id = aifd.FuelId
        and af.IsDeleted = 0
        LEFT JOIN AppGradeGroups agg ON agg.Id = af.GradeGroupId
        and agg.IsDeleted = 0
        LEFT JOIN AppSellers asel ON asel.Id = aifd.SellerId
        and asel.IsDeleted = 0
        LEFT JOIN AppSuppliers asup ON asup.Id = aisd.SupplierId
        and asup.IsDeleted = 0
        LEFT JOIN AppVessel av ON av.Id = aid.VesselNominationId
        and av.IsDeleted = 0
        LEFT JOIN AppPorts ap ON ap.Id = aid.PortNominationId
        and ap.IsDeleted = 0
        LEFT JOIN AppUserProfiles aup ON aup.Id = aid.UserProfileId
        and aup.IsDeleted = 0
        LEFT JOIN AppCustomers ac ON ac.Id = aid.CustomerNominationId
        and ac.IsDeleted = 0
        LEFT JOIN AppCustomerGroups acg ON acg.id = ac.CustomerGroupId
        and acg.IsDeleted = 0
        LEFT JOIN AppInquiryMargins aim On aim.InquiryDetailId = aifd.InquiryDetailId
        and aim.InquirySellerDetailId = aisd.Id
        and aim.IsDeleted = 0
        LEFT JOIN AppCurrencies acur ON acur.Id = aim.CurrencyId
        and acur.IsDeleted = 0
        LEFT JOIN AppCurrencies acurr ON acurr.Id = aic.CurrencyId
        and acurr.IsDeleted = 0
        LEFT JOIN AppInquiryCancelStems aics ON aics.InquiryFuelDetailId = aifd.Id
        and aics.IsDeleted = 0
        LEFT JOIN PaymentPerformance pp ON pp.CustomerNominationId = aid.CustomerNominationId
    WHERE
        aifd.IsDeleted = 0
        AND aifd.isLosted = 0
        AND (
            aifd.IsDelivered = 1
            OR aifd.IsCancelled = 1
            OR aid.InquiryStatus = 9000
        )
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
            WHEN ais.InvoiceType = 1
            AND COALESCE(acurr.Code, acur.Code) = 'AED' THEN (- ABS(ais.SubTotal / 3.6725))
            WHEN ais.InvoiceType = 1
            AND COALESCE(acurr.Code, acur.Code) <> 'AED' THEN (- ABS(ais.SubTotal * ais.ExchangeRate))
            WHEN ais.InvoiceType = 2
            AND COALESCE(acurr.Code, acur.Code) = 'AED' THEN (ais.SubTotal / 3.6725)
            WHEN ais.InvoiceType = 2
            AND COALESCE(acurr.Code, acur.Code) <> 'AED' THEN (ais.SubTotal * ais.ExchangeRate)
        END AS 'Seller Invoice Amount',
        CASE
            WHEN ais.InvoiceType = 1
            AND COALESCE(acurr.Code, acur.Code) = 'AED' THEN (- ABS(ais.TotalAmount / 3.6725))
            WHEN ais.InvoiceType = 1
            AND COALESCE(acurr.Code, acur.Code) <> 'AED' THEN (- ABS(ais.TotalAmount * ais.ExchangeRate))
            WHEN ais.InvoiceType = 2
            AND COALESCE(acurr.Code, acur.Code) = 'AED' THEN (ais.SubTotal / 3.6725)
            WHEN ais.InvoiceType = 2
            AND COALESCE(acurr.Code, acur.Code) <> 'AED' THEN (ais.TotalAmount * ais.ExchangeRate)
        END AS 'Seller Invoice Total Amount',
        CASE
            WHEN ais.InvoiceType = 1
            AND acur.Code = 'AED' THEN (- ABS(ais.AmountPaidSoFar / 3.6725))
            WHEN ais.InvoiceType = 1
            AND acur.Code <> 'AED' THEN (- ABS(ais.AmountPaidSoFar * ais.ExchangeRate))
            WHEN ais.InvoiceType = 2
            AND acur.Code = 'AED' THEN (ais.AmountPaidSoFar / 3.6725)
            WHEN ais.InvoiceType = 2
            AND acur.Code <> 'AED' THEN (ais.AmountPaidSoFar * ais.ExchangeRate)
        END AS 'Amount Paid',
        CASE
            WHEN (aifd.isBooked = 1 AND aifd.IsNominated = 1 AND aifd.IsDelivered = 0) THEN 'Not paid'
            WHEN (aifd.isBooked = 1 AND aifd.IsNominated = 1 AND (aifd.IsDelivered = 1 OR aifd.IsCancelled = 1)) THEN CASE
                WHEN ais.InvoiceType IS NULL THEN 'Not paid'
                WHEN ais.PayableType = 0 THEN 'Not paid'
                WHEN ais.PayableType = 1 THEN 'Partly paid'
                WHEN ais.PayableType = 2 THEN 'Paid'
            END
        END AS 'Payment Status',
        CASE
            WHEN ais.BuyPrice IS NOT NULL THEN ais.BuyPrice * ais.ExchangeRate
            WHEN ais.SubTotal IS NOT NULL
            AND COALESCE(ad.BdnQtyUnit, aifd.Unit) IS NOT NULL
            AND ais.InvoiceType = 1 THEN (
                (
                    - ABS(ais.SubTotal) / NULLIF(
                        COALESCE(
                            ais.BdnBillingQuantity,
                            ad.BDNQty,
                            ain.QuantityMax
                        ),
                        0
                    )
                ) * aio.ExchangeRate
            )
            WHEN ais.SubTotal IS NOT NULL
            AND COALESCE(ad.BdnQtyUnit, aifd.Unit) IS NOT NULL
            AND ais.InvoiceType = 2 THEN (
                (
                    ais.SubTotal / NULLIF(
                        COALESCE(
                            ais.BdnBillingQuantity,
                            ad.BDNQty,
                            ain.QuantityMax
                        ),
                        0
                    )
                ) * aio.ExchangeRate
            )
        END AS 'Buying Price',
        CASE
            WHEN agg.Name = 'GO' THEN CASE
                WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 0 THEN COALESCE(
                    ais.BdnBillingQuantity,
                    ad.BDNQty,
                    ain.QuantityMax
                ) --MT
                WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 1 THEN (
                    COALESCE(
                        ais.BdnBillingQuantity,
                        ad.BDNQty,
                        ain.QuantityMax
                    ) * 0.001
                ) --KG
                WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 2 THEN (
                    COALESCE(
                        ais.BdnBillingQuantity,
                        ad.BDNQty,
                        ain.QuantityMax
                    ) * 0.00085
                ) --Litres
                WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 3 THEN (
                    COALESCE(
                        ais.BdnBillingQuantity,
                        ad.BDNQty,
                        ain.QuantityMax
                    ) * 0.0038641765
                ) --IG
                WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 4 THEN (
                    COALESCE(
                        ais.BdnBillingQuantity,
                        ad.BDNQty,
                        ain.QuantityMax
                    ) * 0.85
                ) --CBM
                WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 5 THEN (
                    COALESCE(
                        ais.BdnBillingQuantity,
                        ad.BDNQty,
                        ain.QuantityMax
                    ) * 0.0032
                ) --US Gallons
                WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 6 THEN (
                    COALESCE(
                        ais.BdnBillingQuantity,
                        ad.BDNQty,
                        ain.QuantityMax
                    ) * 0.134
                ) --Barrels
                WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 7 THEN (
                    COALESCE(
                        ais.BdnBillingQuantity,
                        ad.BDNQty,
                        ain.QuantityMax
                    ) * 0.85
                ) --KL
            END
            WHEN agg.Name = 'FO' THEN CASE
                WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 0 THEN COALESCE(
                    ais.BdnBillingQuantity,
                    ad.BDNQty,
                    ain.QuantityMax
                ) --MT
                WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 1 THEN (
                    COALESCE(
                        ais.BdnBillingQuantity,
                        ad.BDNQty,
                        ain.QuantityMax
                    ) * 0.001
                ) --KG
                WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 2 THEN (
                    COALESCE(
                        ais.BdnBillingQuantity,
                        ad.BDNQty,
                        ain.QuantityMax
                    ) * 0.00094
                ) --Litres
                WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 3 THEN (
                    COALESCE(
                        ais.BdnBillingQuantity,
                        ad.BDNQty,
                        ain.QuantityMax
                    ) * 0.0042733246
                ) --IG
                WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 4 THEN (
                    COALESCE(
                        ais.BdnBillingQuantity,
                        ad.BDNQty,
                        ain.QuantityMax
                    ) * 0.94
                ) --CBM
                WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 5 THEN (
                    COALESCE(
                        ais.BdnBillingQuantity,
                        ad.BDNQty,
                        ain.QuantityMax
                    ) * 0.0037
                ) --US Gallons
                WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 6 THEN (
                    COALESCE(
                        ais.BdnBillingQuantity,
                        ad.BDNQty,
                        ain.QuantityMax
                    ) * 0.157
                ) --Barrels
                WHEN COALESCE(ad.BdnQtyUnit, aifd.Unit) = 7 THEN (
                    COALESCE(
                        ais.BdnBillingQuantity,
                        ad.BDNQty,
                        ain.QuantityMax
                    ) * 0.94
                ) --KL
            END
            ELSE COALESCE(
                ais.BdnBillingQuantity,
                ad.BDNQty,
                ain.QuantityMax
            )
        END AS 'Qty in MT',
        asel.Name AS Seller,
        asuppp.Name AS 'Supplier',
        av.Name AS 'Vessel',
        ap.Name AS 'Port',
        aup.Name AS 'Trader',
        aup.UserId AS 'UserId',
        aup.Email AS 'UserEmail',
        ac.Name AS 'Buyer',
        pp.[Payment performance],
        CASE
            WHEN acg.Name = 'Scorpio' THEN 'Scorpio'
            WHEN (
                acg.Name = 'Cargo deals'
                OR acg.Name = 'Cargo Deals'
                OR acg.Name = 'Cargo deal'
                OR acg.Name = 'Cargo Deal'
            ) THEN 'Cargo Deals'
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
        aim.Margin AS 'Margin per MT',
        COALESCE(acurr.Code, acur.Code) AS 'Buying Currency',
        ROW_NUMBER() OVER (
            PARTITION BY aifd.Id,
            aifd.Description,
            ais.InvoiceType
            ORDER BY
                ais.InvoiceNumber
        ) AS RowNum,
        NULL AS 'Total Brokerage'
    FROM
        AppInquiryFuelDetails aifd
        JOIN AppInvoiceSellers ais ON ais.InquiryFuelDetailId = aifd.Id
        AND ais.IsDeleted = 0
        AND ais.InvoiceType <> 0
        LEFT JOIN AppDeliveries ad ON ad.InquiryFuelDetailId = aifd.id
        and ad.IsDeleted = 0
        JOIN AppInquirySellerDetails aisd ON aisd.InquiryFuelDetailId = aifd.id
        and aisd.SellerId = aifd.SellerId
        and aisd.IsDeleted = 0
        JOIN AppInquiryNominations ain ON ain.InquirySellerDetailId = aisd.Id
        and ain.InquiryDetailId = aifd.InquiryDetailId
        and ain.IsDeleted = 0
        JOIN AppInquiryDetails aid ON aid.Id = aifd.InquiryDetailId
        and aid.isDeleted = 0
        LEFT JOIN AppFuels af ON af.id = aifd.FuelId
        and af.IsDeleted = 0
        LEFT JOIN AppGradeGroups agg ON agg.Id = af.GradeGroupId
        and agg.IsDeleted = 0
        LEFT JOIN AppSellers asel ON asel.Id = aifd.SellerId
        and asel.IsDeleted = 0
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
        LEFT JOIN AppSuppliers asup ON asup.Id = ais.CounterpartyName
        and asup.IsDeleted = 0
        LEFT JOIN AppSuppliers asupp ON asupp.Id = ais.SupplierId
        and asupp.IsDeleted = 0
        LEFT JOIN AppSuppliers asuppp ON asuppp.Id = aisd.SupplierId
        and asuppp.IsDeleted = 0
        LEFT JOIN AppVessel av ON av.Id = aid.VesselNominationId
        and av.IsDeleted = 0
        LEFT JOIN AppPorts ap ON ap.Id = aid.PortNominationId
        and ap.IsDeleted = 0
        LEFT JOIN AppUserProfiles aup ON aup.Id = aid.UserProfileId
        and aup.IsDeleted = 0
        LEFT JOIN AppCustomers ac ON ac.Id = aid.CustomerNominationId
        and ac.IsDeleted = 0
        LEFT JOIN AppCustomerGroups acg ON acg.id = ac.CustomerGroupId
        and acg.IsDeleted = 0
        LEFT JOIN AppInquiryMargins aim On aim.InquiryDetailId = aifd.InquiryDetailId
        and aim.InquirySellerDetailId = aisd.Id
        and aim.IsDeleted = 0
        LEFT JOIN AppInquiryOffers aio ON aio.InquiryDetailId = aifd.InquiryDetailId
        and aio.SellerId = aifd.SellerId
        and aio.IsDeleted = 0
        LEFT JOIN AppCurrencies acur ON acur.Id = aio.CurrencyId
        and acur.IsDeleted = 0
        LEFT JOIN AppCurrencies acurr ON acurr.Id = ais.CurrencyId
        and acurr.IsDeleted = 0
        LEFT JOIN AppInquiryCancelStems aics ON aics.InquiryFuelDetailId = aifd.Id
        and aics.IsDeleted = 0
        LEFT JOIN PaymentPerformance pp ON pp.CustomerNominationId = aid.CustomerNominationId
    WHERE
        aifd.IsDeleted = 0
        AND aifd.isLosted = 0
        AND (
            aifd.IsDelivered = 1
            OR aifd.IsCancelled = 1
            OR aid.InquiryStatus = 9000
        )
) --SELECT * FROM SellerInvoices
,
CnAndDnInvoices AS (
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
        ci.[Cancellation Status],
        ci.[Stem Date],
        ci.[Delivery Date],
        ci.[Margin per MT],
        ci.[Qty in MT] AS Qty,
        ci.CustomerInvoiceNumber AS 'Customer Invoice Number',
        ci.[Customer Invoice Amount],
        ci.[Customer Invoice Total Amount],
        NULL AS 'Seller Invoice Number',
        NULL AS [Seller Invoice Amount],
        NULL AS [Seller Invoice Total Amount],
        ci.[Amount Received],
        NULL AS [Amount Paid],
        NULL AS [Payment Status],
        ci.[Receipt Status],
        NULL AS [Buying Price],
        NULL AS [Buying Currency],
        ci.[Selling Price],
        ci.[Selling Currency],
        ci.[Total Brokerage]
    FROM
        CustomerInvoices ci
    UNION
    ALL
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
        si.[Cancellation Status],
        si.[Stem Date],
        si.[Delivery Date],
        si.[Margin per MT],
        si.[Qty in MT] AS Qty,
        NULL AS 'Customer Invoice Number',
        NULL AS [Customer Invoice Amount],
        NULL AS [Customer Invoice Total Amount],
        si.SellerInvoiceNumber AS 'Seller Invoice Number',
        si.[Seller Invoice Amount],
        si.[Seller Invoice Total Amount],
        NULL AS [Amount Received],
        si.[Amount Paid],
        si.[Payment Status],
        NULL AS [Receipt Status],
        si.[Buying Price],
        si.[Buying Currency],
        NULL AS [Selling Price],
        NULL AS [Selling Currency],
        NULL AS [Total Brokerage]
    FROM
        SellerInvoices si
),
UNIONALL AS (
    Select
        *
    from
        MainAndBookedInvoices
    UNION
    ALL
    Select
        *
    from
        CnAndDnInvoices
),
SellingCurrencyCTE AS (
    Select
        uq.[Job Code],
        STRING_AGG(uq.[Selling Currency], ',') AS 'Selling Currency'
    from
        (
            Select
                DISTINCT [Job Code],
                [Selling Currency]
            from
                UNIONALL
        ) uq
    GROUP BY
        uq.[Job Code]
),
BuyingCurrencyCTE AS (
    Select
        uq.[Job Code],
        STRING_AGG(uq.[Buying Currency], ',') AS 'Buying Currency'
    from
        (
            Select
                DISTINCT [Job Code],
                [Buying Currency]
            from
                UNIONALL
        ) uq
    GROUP BY
        uq.[Job Code]
),
ExampleCTE AS (
    SELECT
        uq.[Job Code],
        uq.Fuel,
        uq.InquiryFuelDetailId,
        uq.Vessel,
        uq.Port,
        uq.Trader,
        uq.UserId,
        uq.UserEmail,
        uq.Buyer,
        uq.[Payment performance],
        uq.[Customer In Out],
        uq.[Job Status],
        uq.[Cancellation Status],
        -- Precompute valid qty for reuse
        SUM(
            CASE
                WHEN [Invoice Type] = 'Invoice'
                OR [Job Status] IN ('Booked', 'Partly Booked', 'Cancelled Stem') THEN Qty
                ELSE 0
            END
        ) AS ValidQty,
        -- Margin per MT
        CASE
            WHEN SUM(
                CASE
                    WHEN [Invoice Type] = 'Invoice'
                    OR [Job Status] IN ('Booked', 'Partly Booked', 'Cancelled Stem') THEN Qty
                    ELSE 0
                END
            ) = 0 THEN NULL
            ELSE SUM(
                [Margin per MT] * CASE
                    WHEN [Invoice Type] = 'Invoice'
                    OR [Job Status] IN ('Booked', 'Partly Booked', 'Cancelled Stem') THEN Qty
                    ELSE 0
                END
            ) / NULLIF(
                SUM(
                    CASE
                        WHEN [Invoice Type] = 'Invoice'
                        OR [Job Status] IN ('Booked', 'Partly Booked', 'Cancelled Stem') THEN Qty
                        ELSE 0
                    END
                ),
                0
            )
        END AS [Margin per MT],
        -- Buying Price
        CASE
            WHEN SUM(
                CASE
                    WHEN [Invoice Type] = 'Invoice'
                    OR [Job Status] IN ('Booked', 'Partly Booked', 'Cancelled Stem') THEN Qty
                    ELSE 0
                END
            ) = 0 THEN NULL
            ELSE SUM(
                ISNULL([Buying Price], 0) * CASE
                    WHEN [Invoice Type] = 'Invoice'
                    OR [Job Status] IN ('Booked', 'Partly Booked', 'Cancelled Stem') THEN Qty
                    ELSE 0
                END
            ) / NULLIF(
                SUM(
                    CASE
                        WHEN [Invoice Type] = 'Invoice'
                        OR [Job Status] IN ('Booked', 'Partly Booked', 'Cancelled Stem') THEN Qty
                        ELSE 0
                    END
                ),
                0
            )
        END AS [Buying Price],
        -- Selling Price
        CASE
            WHEN SUM(
                CASE
                    WHEN [Invoice Type] = 'Invoice'
                    OR [Job Status] IN ('Booked', 'Partly Booked', 'Cancelled Stem') THEN Qty
                    ELSE 0
                END
            ) = 0 THEN NULL
            ELSE SUM(
                ISNULL([Selling Price], 0) * CASE
                    WHEN [Invoice Type] = 'Invoice'
                    OR [Job Status] IN ('Booked', 'Partly Booked', 'Cancelled Stem') THEN Qty
                    ELSE 0
                END
            ) / NULLIF(
                SUM(
                    CASE
                        WHEN [Invoice Type] = 'Invoice'
                        OR [Job Status] IN ('Booked', 'Partly Booked', 'Cancelled Stem') THEN Qty
                        ELSE 0
                    END
                ),
                0
            )
        END AS [Selling Price],
        -- Qty
        SUM(
            CASE
                WHEN [Invoice Type] = 'Invoice'
                OR [Job Status] IN ('Booked', 'Partly Booked', 'Cancelled Stem') THEN Qty
                ELSE 0
            END
        ) AS Qty,
        MIN([Stem Date]) AS [Stem Date],
        MIN([Delivery Date]) AS [Delivery Date],
        SUM(ISNULL([Customer Invoice Amount], 0)) AS [Customer Invoice Amount],
        SUM(ISNULL([Customer Invoice Total Amount], 0)) AS [Customer Invoice Total Amount],
        SUM(ISNULL([Seller Invoice Amount], 0)) AS [Seller Invoice Amount],
        SUM(ISNULL([Seller Invoice Total Amount], 0)) AS [Seller Invoice Total Amount],
        SUM(ISNULL([Amount Received], 0)) AS [Amount Received],
        SUM(ISNULL([Amount Paid], 0)) AS [Amount Paid],
        -- Receipt Status
        CASE
            WHEN SUM(ISNULL([Amount Received], 0)) >= SUM(ISNULL([Customer Invoice Amount], 0))
            AND SUM(ISNULL([Customer Invoice Amount], 0)) > 0 THEN 'Received'
            WHEN SUM(ISNULL([Amount Received], 0)) > 0 THEN 'Partly Received'
            ELSE 'Not Received'
        END AS [Receipt Status],
        -- Payment Status
        CASE
            WHEN SUM(ISNULL([Amount Paid], 0)) >= SUM(ISNULL([Seller Invoice Amount], 0))
            AND SUM(ISNULL([Seller Invoice Amount], 0)) > 0 THEN 'Paid'
            WHEN SUM(ISNULL([Amount Paid], 0)) > 0 THEN 'Partly Paid'
            ELSE 'Not Paid'
        END AS [Payment Status],
        sc.[Selling Currency],
        bc.[Buying Currency],
        CASE
            WHEN COUNT(DISTINCT [Trade Type]) = 1 THEN MAX([Trade Type])
            ELSE STRING_AGG([Trade Type], ', ') WITHIN GROUP (
                ORDER BY
                    [Trade Type]
            )
        END AS [Trade Type],
        SUM(ISNULL([Total Brokerage], 0)) AS [Total Brokerage]
    FROM
        UNIONALL uq
        LEFT JOIN SellingCurrencyCTE sc ON sc.[Job Code] = uq.[Job Code]
        LEFT JOIN BuyingCurrencyCTE bc ON bc.[Job Code] = uq.[Job Code]
    GROUP BY
        uq.[Job Code],
        uq.Fuel,
        uq.InquiryFuelDetailId,
        uq.Vessel,
        uq.Port,
        uq.Trader,
        uq.UserId,
        uq.UserEmail,
        uq.Buyer,
        uq.[Payment performance],
        uq.[Customer In Out],
        uq.[Job Status],
        uq.[Cancellation Status],
        sc.[Selling Currency],
        bc.[Buying Currency]
)
SELECT
    [Job Code],
    Fuel,
    InquiryFuelDetailId,
    Vessel,
    Port,
    Trader,
    UserId,
    UserEmail,
    Buyer,
    [Payment performance],
    [Customer In Out],
    [Job Status],
    [Cancellation Status],
    CASE
        WHEN [Job Status] = 'Cancelled Stem' THEN NULL
        ELSE ROUND([Margin per MT], 2)
    END AS [Margin per MT],
    CASE
        WHEN [Job Status] = 'Cancelled Stem' THEN NULL
        ELSE ROUND([Customer Invoice Amount] / NULLIF(Qty, 0), 2)
    END AS [Selling Price],
    CASE
        WHEN [Job Status] = 'Cancelled Stem' THEN NULL
        ELSE ROUND([Seller Invoice Amount] / NULLIF(Qty, 0), 2)
    END AS [Buying Price],
    CASE
        WHEN [Job Status] = 'Cancelled Stem' THEN NULL
        ELSE ROUND(Qty, 4)
    END AS Qty,
    [Stem Date],
    [Delivery Date],
    ROUND([Customer Invoice Amount], 2) AS [Customer Invoice Amount],
    ROUND([Customer Invoice Total Amount], 2) AS [Customer Invoice Total Amount],
    ROUND([Seller Invoice Amount], 2) AS [Seller Invoice Amount],
    ROUND([Seller Invoice Total Amount], 2) AS [Seller Invoice Total Amount],
    ROUND([Amount Received], 2) AS [Amount Received],
    ROUND([Amount Paid], 2) AS [Amount Paid],
    [Receipt Status],
    [Payment Status],
    [Buying Currency],
    [Selling Currency],
    [Trade Type],
    ROUND([Total Brokerage], 2) AS [Total Brokerage]
FROM
    ExampleCTE
WHERE
    [Job Status] IN (
        'Partly Booked',
        'Booked',
        'Partly Delivered',
        'Delivered',
        'Cancelled Stem'
    )