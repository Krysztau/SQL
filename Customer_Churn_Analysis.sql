USE DB1
GO

--Create table to store fixed and improved Purchase Tran
IF OBJECT_ID('tempdb..##KrzyGod_PurchaseHistory') IS NOT NULL
DROP TABLE ##KrzyGod_PurchaseHistory
GO

CREATE TABLE ##KrzyGod_PurchaseHistory  (
    [CustomerNumber] int NOT NULL
	, [Bundle] int NOT NULL
    , [ActualStartDate] varchar(10) NOT NULL
	, [ExpiryDate] varchar(10) NOT NULL
	, [PackHasPredecessor] bit		--indicates if this pack was purchased on expiry date, or is it first in a row
)

insert into ##KrzyGod_PurchaseHistory



SELECT main.[CustomerNumber]
	, main.[Bundle]
	
		--fix error in DB1 where  occasionally start date falls after expiry
	, CASE WHEN  main.[BUNDLE_START] > main.[BUNDLE_EXPIRY] 	
			THEN CONVERT (varchar(10), dateadd (day, -31, main.[BUNDLE_EXPIRY]), 120)
			ELSE CONVERT (varchar(10), main.[BUNDLE_START], 120
		) END as ActualStartDate

	, CONVERT (varchar(10), main.[BUNDLE_EXPIRY],120) AS ExpiryDate

		--Check if "b.Key" in LEFT JOIN is null, if yes, return 0, else 1 
	, CASE WHEN
		CASE WHEN  renews.[BUNDLE_START] > renews.[BUNDLE_EXPIRY] 	--fix error in DB1 where start date falls after expiry
			THEN CONVERT (varchar(10), dateadd (day, -31,renews.[BUNDLE_EXPIRY]), 120)
			ELSE CONVERT (varchar(10), renews.[BUNDLE_START], 120
		) END
	IS NULL THEN 0 ELSE 1 END AS PackHasPredecessor

FROM [dbo].[TRANSACTION_LIST] main with (nolock)
	LEFT JOIN [TRANSACTION_LIST] renews
	ON main.[CustomerNumber] = renews.[CustomerNumber]
	AND main.[Bundle] = renews.[Bundle]
	
		--this matches Start date from main to Expiry date from renews. If NULL - customer started a new cycle. Otherwise customer is happy with bundle and renews the pack.
	AND CONVERT (varchar(10), renews.[BUNDLE_EXPIRY],120) = CASE WHEN  main.[BUNDLE_START] > main.[BUNDLE_EXPIRY] 
			THEN CONVERT (varchar(10), dateadd (day, -31,main.[BUNDLE_EXPIRY]), 120)
			ELSE CONVERT (varchar(10), main.[BUNDLE_START], 120
		) END



WHERE  main.[BUNDLE_DURATION] = 1	-- =1 MONTH

GO

----- Table is now ready to work with -----


WITH AnalizaChurn (CstNumber, BundleNumber, ExpiryDate, PackGotRenewed_IND, MonthsFromStart) AS

(
SELECT	--main list of all transactions that are not purchased as "bundle renewal"
	##KrzyGod_PurchaseHistory.[CustomerNumber]
	, ##KrzyGod_PurchaseHistory.[Bundle]
	, ##KrzyGod_PurchaseHistory.[ExpiryDate]
	, ##KrzyGod_PurchaseHistory.[PackHasPredecessor] --indicates it's a first purchase in the row
	, 1 AS ExpiredCycleNumber
FROM ##KrzyGod_PurchaseHistory
WHERE [PackHasPredecessor] = 0

	UNION ALL
		-- self-referenceing call. Lookup all remining bundles by matching their Start Dates with expiry dates from initial lot. With each iteration there will be more packs finding right match in the main list.
SELECT 
	##KrzyGod_PurchaseHistory.[CustomerNumber]
	, ##KrzyGod_PurchaseHistory.[Bundle]
	, ##KrzyGod_PurchaseHistory.[ExpiryDate]
	, ##KrzyGod_PurchaseHistory.[PackHasPredecessor]--indicates which purchase in the row it is
	, 1+ MonthsFromStart AS ExpiredCycleNumber	-- add one with each iteration to keep track of csutomer/bundle "age"
FROM ##KrzyGod_PurchaseHistory
	JOIN AnalizaChurn
	ON 
	##KrzyGod_PurchaseHistory.[CustomerNumber] = AnalizaChurn.CstNumber
	AND ##KrzyGod_PurchaseHistory.[Bundle] = AnalizaChurn.BundleNumber
	AND ##KrzyGod_PurchaseHistory.[ActualStartDate] = AnalizaChurn.ExpiryDate	--manager-subordinate style lookup
)

SELECT Main.CstNumber, Main.BundleNumber, Main.ExpiryDate, Main.MonthsFromStart	--bunch of standard fields
	
		--identify if customer dropped after this bundle expired, or maybe renewed, or maybe expiry date is in the future so we don't really know just yet.
	, CASE WHEN Renew_IND.[ActualStartDate] is NOT NULL THEN 'Renewed'
		WHEN Main.ExpiryDate >= CONVERT (varchar(10), getdate(),120) THEN 'Active'
		ELSE 'Dropped' END AS EndOfCycleState
		
		--What date was Monday in the week
	, CONVERT (varchar(10)
		, DATEADD(day, 1 - datepart(weekday, dateadd(day, -1, Main.ExpiryDate)), Main.ExpiryDate) 
		, 120 
		--What day was the 1st of the month
	) as WeekStart
	, CONVERT (varchar(10)
		, DATEADD (day, 1 - datepart(day,  Main.ExpiryDate), Main.ExpiryDate) 
		, 120
    ) as Monthstart	

FROM AnalizaChurn Main
	LEFT JOIN ##KrzyGod_PurchaseHistory Renew_IND
	ON Main.ExpiryDate = Renew_IND.[ActualStartDate]
	AND Main.BundleNumber = Renew_IND.[Bundle]
	AND Main.CstNumber = Renew_IND.[CustomerNumber]

-- ORDER BY Main.CstNumber, Main.BundleNumber, Main.ExpiryDate	--quality check



