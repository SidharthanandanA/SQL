-- 28 June 2024
-- Modified on 03-01-2025

SELECT 
    aup.UserName AS 'User Name',
    aup.Name AS 'First Name',
    aup.SurName AS 'Last Name',
    aup.Email,
    ar.Name AS 'Roles',
    CASE WHEN aup.Active = 1 THEN 'Active'
		 WHEN aup.Active = 0 THEN 'InActive'
	END AS 'Active/Inactive',
    CASE 
		WHEN aup.IsSso is null THEN 'Disabled'
        WHEN aup.IsSso = 0 THEN 'Disabled'
        WHEN aup.IsSso = 1 THEN 'Enabled'
    END AS 'SSO',
    CONVERT(DATE, aup.CreationTime) AS 'Created On',
    CONVERT(DATE, aup.LastModificationTime) AS 'Modified On',
    CONVERT(DATE, asl.LastLoginTime) AS 'Last Login Date'
FROM AppUserProfiles aup
LEFT JOIN AbpUserRoles aur ON aur.UserId = aup.UserId
LEFT JOIN AbpRoles ar ON ar.Id = aur.RoleId
LEFT JOIN 
    (SELECT 
         UserID,
         MAX(CreationTime) AS LastLoginTime
     FROM AbpSecurityLogs
     GROUP BY UserID
    ) AS asl ON aup.UserID = asl.UserID
Where aup.IsDeleted = 0