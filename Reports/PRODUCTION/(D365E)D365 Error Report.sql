SELECT DISTINCT
    ath.JobCode AS 'Job No',
    ath.DocumentType AS 'Document Type',
	CONVERT(DATE, COALESCE(ais.InvoiceDate, ath.DateSent)) AS 'Inv Date',
    ath.InvoiceNumber  AS 'Inv Number',
	ROUND(COALESCE(ais.TotalAmount, aic.TotalAmount),2) AS 'Invoice Amount',
    CONVERT(DATE, ath.DateSent) AS 'Approved Date',
    aed.ErrorReason AS 'Error Msg',
    aed.ErrorCode AS 'Error Code'
FROM AppD365TransactionHeaders ath
LEFT JOIN AppInquiryDetails aid ON aid.Code = ath.JobCode
LEFT JOIN AppInvoiceCustomers aic ON aic.InvoiceCode = ath.InvoiceNumber and aid.id = aic.InquiryDetailId and aic.IsDeleted = 0
LEFT JOIN AppInvoiceSellers ais ON ais.InvoiceNumber = ath.InvoiceNumber and aid.id = ais.InquiryDetailId and ais.IsDeleted = 0
LEFT JOIN AppD365TransactionUpdates atu ON ath.TransactionId = atu.TransactionId
LEFT JOIN AppD365ErrorDetails aed ON atu.Id = aed.TransactionUpdateId
WHERE ath.IsDeleted = 0 
  AND ath.JournalId IS NOT NULL 
  AND ath.JournalId = '' 
  AND ath.Status NOT IN ('JournalCreated', 'Inserted')
  AND (aic.InvoiceCode IS NOT NULL OR ais.InvoiceNumber IS NOT NULL) 
  AND atu.Status LIKE '%error%' 
  AND ath.Status LIKE '%error%'
  AND aed.ErrorReason != ''
  AND (ais.InvoiceStatus NOT IN (40,50) OR aic.InvoiceStatus NOT IN (50,60))
--ORDER BY