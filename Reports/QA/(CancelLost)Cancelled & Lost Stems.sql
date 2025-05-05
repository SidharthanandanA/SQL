/* ListOfInquiryCancelStemAndLostStemCommentsReport.v2 */

WITH CancelStems AS (
    SELECT DISTINCT
        aid.Code AS JobId,
        ap.Name AS Port,
        CONVERT(DATE, COALESCE(aics.SellerEmailSentOn, aics.CustomerEmailSentOn)) AS 'Date of cancellation',
        aup.Name AS 'Trader Name',
        aics.Grade AS 'Grade',
        aics.Seller AS 'Seller Name',
        acs.Name AS 'Customer Name',
        CONCAT(
	CASE 
		WHEN aics.CancelTypes = 0 THEN 'With Penalty'
		WHEN aics.CancelTypes = 1 THEN 'Without Penalty'
	END,
	CASE 
		WHEN aics.Comments IS NOT NULL AND aics.Comments != '' THEN CONCAT(' - ',aics.Comments)
		ELSE NULL
	END
	) AS 'Reason for Cancellation/Lost',
	'Cancelled' AS 'Sub Status'
    FROM AppInquiryCancelStems aics
    JOIN AppInquiryDetails aid ON aics.InquiryDetailId = aid.id AND (CustomerEmailLogId IS NOT NULL AND SellerEmailLogId IS NOT NULL)
    LEFT JOIN AppPorts ap ON ap.id = aid.PortNominationId AND ap.IsDeleted = 0
    LEFT JOIN AppUserProfiles aup ON aup.id = aid.UserProfileId AND aup.IsDeleted = 0
    LEFT JOIN AppCustomers acs ON acs.Id = aid.CustomerNominationId AND acs.IsDeleted = 0
    WHERE aics.IsDeleted = 0
),
LostStems AS (

Select DISTINCT
	aid.Code AS 'JobId',
	ap.Name AS 'Port',
	CONVERT(DATE, ails.CreationTime) AS 'Date of Cancellation',
	aup.Name AS 'Trader Name',
	aifd.Description AS 'Grade',
	asel.Name AS 'Seller Name',
	ac.Name AS 'Customer Name',
	CONCAT(
	CASE 
		WHEN ails.LostStemType = 0 THEN 'Customer Withdrawn'
		WHEN ails.LostStemType = 1 THEN 'Another Trader'
		WHEN ails.LostStemType = 2 THEN 'Direct Physical'
		WHEN ails.LostStemType = 3 THEN 'Other'
	END,
	CASE 
		WHEN ails.Comments IS NOT NULL AND ails.Comments != '' THEN CONCAT('-',ails.Comments)
		ELSE NULL
	END
	) AS 'Reason for Cancellation/Lost',
	'Lost' AS 'Sub Status'
	
     FROM AppInquiryFuelDetails aifd
     JOIN AppInquiryLostStems ails ON ails.InquiryDetailId = aifd.InquiryDetailId AND aifd.IsDeleted = 0
	 AND ails.Id NOT IN (SELECT InquiryLostStemId FROM AppInquiryFuelDetails WHERE InquiryLostStemId IS NOT NULL)
     LEFT JOIN AppInquiryDetails aid ON aid.Id = ails.InquiryDetailId AND aid.IsDeleted = 0
     LEFT JOIN AppPorts ap ON ap.Id = aid.PortNominationId AND ap.IsDeleted = 0
     LEFT JOIN AppUserProfiles aup ON aup.Id = aid.UserProfileId AND aup.IsDeleted = 0
     LEFT JOIN AppCustomers ac ON ac.Id = aid.CustomerNominationId AND ac.IsDeleted = 0
     LEFT JOIN AppSellers asel ON asel.Id = aifd.SellerId AND asel.IsDeleted = 0
 
    WHERE aifd.IsLosted = 0

),
LostGrade AS (
 
	SELECT DISTINCT
	aid.Code AS 'JobId',
	ap.Name AS 'Port',
	CONVERT(DATE, ails.CreationTime) AS 'Date of Cancellation',
	aup.Name AS 'Trader Name',
	aifd.Description AS 'Grade',
	asel.Name AS 'Seller Name',
	ac.Name AS 'Customer Name',
	CONCAT(
	CASE 
		WHEN ails.LostStemType = 0 THEN 'Customer Withdrawn'
		WHEN ails.LostStemType = 1 THEN 'Another Trader'
		WHEN ails.LostStemType = 2 THEN 'Direct Physical'
		WHEN ails.LostStemType = 3 THEN 'Other'
	END,
	CASE 
		WHEN ails.Comments IS NOT NULL AND ails.Comments != '' THEN CONCAT('-',ails.Comments)
		ELSE NULL
	END
	) AS 'Reason for Cancellation/Lost',
	'Lost' AS 'Sub Status'
    FROM AppInquiryFuelDetails aifd
    JOIN AppInquiryLostStems ails ON ails.Id = aifd.InquiryLostStemId 
    LEFT JOIN AppInquiryDetails aid ON aid.Id = ails.InquiryDetailId AND aid.IsDeleted = 0
    LEFT JOIN AppPorts ap ON ap.Id = aid.PortNominationId AND ap.IsDeleted = 0
    LEFT JOIN AppUserProfiles aup On aup.Id = aid.UserProfileId AND aup.IsDeleted = 0
    LEFT JOIN AppSellers asel ON asel.Id = aifd.SellerId AND asel.IsDeleted = 0
    LEFT JOIN AppCustomers ac ON ac.Id = aid.CustomerNominationId AND ac.IsDeleted = 0
    ),
InquiryLost AS (
 
	SELECT DISTINCT
	aid.Code AS 'JobId',
	ap.Name AS 'Port',
	CONVERT(DATE, aid.LostStemOn) AS 'Date of Cancellation',
	aup.Name AS 'Trader Name',
	aifd.Description AS 'Grade',
	asel.Name AS 'Seller Name',
	ac.Name AS 'Customer Name',
	CONCAT(
	CASE 
		WHEN ails.LostStemType = 0 THEN 'Customer Withdrawn'
		WHEN ails.LostStemType = 1 THEN 'Another Trader'
		WHEN ails.LostStemType = 2 THEN 'Direct Physical'
		WHEN ails.LostStemType = 3 THEN 'Other'
	END,
	CASE 
		WHEN ails.Comments IS NOT NULL AND ails.Comments != '' THEN CONCAT('-',ails.Comments)
		WHEN aid.LostStemComment IS NOT NULL AND aid.LostStemComment != '' THEN aid.LostStemComment
		ELSE NULL
	END
	) AS 'Reason for Cancellation/Lost',
	'Lost' AS 'Sub Status'
    FROM AppInquiryFuelDetails aifd
    JOIN AppInquiryDetails aid ON aid.Id = aifd.InquiryDetailId
	LEFT JOIN AppInquiryLostStems ails ON ails.CreatorId = aid.CreatorId AND ails.Comments = aid.LostStemComment AND ails.CreationTime = aid.LostStemOn AND ails.IsDeleted = 0 
    LEFT JOIN AppPorts ap ON ap.Id = aid.PortNominationId AND ap.IsDeleted = 0
    LEFT JOIN AppUserProfiles aup On aup.Id = aid.UserProfileId AND aup.IsDeleted = 0
    LEFT JOIN AppSellers asel ON asel.Id = aifd.SellerId AND asel.IsDeleted = 0
    LEFT JOIN AppCustomers ac ON ac.Id = aid.CustomerNominationId AND ac.IsDeleted = 0
	WHERE InquiryStatus = 1500 AND aid.Id NOT IN (SELECT InquiryDetailId FROM AppInquiryLostStems WHERE InquiryDetailId IS NOT  NUll AND IsDeleted = 0)
    ),	
UNIONCTE AS (
SELECT * FROM CancelStems
   UNION 
SELECT * FROM LostStems
   UNION 
SELECT * FROM LostGrade
   UNION
Select * from InquiryLost
)
SELECT * FROM UNIONCTE
    ORDER BY CAST(SUBSTRING(JobId, 2, LEN(JobId) - 1) AS INT) DESC