---- Create a list of all subscriptions first time ever ----
WITH


EndDates as	--here I list all subscriptions end dates excluding today, who used monthly subscription and are not testing users
(
	SELECT DISTINCT PurchaseHist.[SUBSCRIPTION_SR_KEY]	--unique ID
		, PurchaseHist.[PACKAGE_SR_KEY]					--purchased package
		, CONVERT (varchar(10),PurchaseHist.[PACKAGE_EXPIRY_DATETIME],103) as Pack_Expiry_Time
		, CONVERT (varchar(10),PurchaseHist.[PACKAGE_START_DATETIME],103) as Pack_Start_Time
-- here is a room for payment type as well. Need to investigate key values.
	FROM [MDW_DWL_PLY].[dbo].[PURCHASE_TRAN] PurchaseHist	
	left join [MDW_DWL_PLY].[dbo].[CUSTOMER_SUBSCRIPTION] Subscriptions	
		ON Subscriptions.[SUBSCRIPTION_SR_KEY] = PurchaseHist.[SUBSCRIPTION_SR_KEY]
		
	WHERE PurchaseHist.[USER_TYPE_SR_KEY] not in (4,5)	-- remove test users
		AND PurchaseHist.[PACKAGE_DURATION_SR_KEY] = 1	--only monthly subscriptions
		AND CONVERT (varchar(10),PurchaseHist.[PACKAGE_EXPIRY_DATETIME],121) < CONVERT (varchar (10),getdate()-1,121) --ignore subscribers who didn't go through their first 30-days cycle
--		AND PurchaseHist.[SUBSCRIPTION_SR_KEY] = 26081		--my account for testing
		AND Subscriptions.[IS_TEST_SUBSCRIBER] = 0	--remove even more test users
)
,
StartDate as	--here I list all start dates - no filtering
(
	SELECT DISTINCT PurchaseHist.[SUBSCRIPTION_SR_KEY]	--unique ID
		, PurchaseHist.[PACKAGE_SR_KEY]
		, CONVERT (varchar(10),PurchaseHist.[PACKAGE_EXPIRY_DATETIME],103) as Pack_Expiry_Time
		, CONVERT (varchar(10),PurchaseHist.[PACKAGE_START_DATETIME],103) as Pack_Start_Time
	FROM [MDW_DWL_PLY].[dbo].[PURCHASE_TRAN] PurchaseHist	
)

--now I will take the EndDates list and remove subscribers who have also subscription with Start date equal End date from that first list.
-- Leaving in the first list only those who did not purchase subscription on the date of expiry.
SELECT EndDates.* 
FROM EndDates
LEFT JOIN StartDate
ON EndDates.SUBSCRIPTION_SR_KEY = StartDate.SUBSCRIPTION_SR_KEY
AND EndDates.PACKAGE_SR_KEY = StartDate.PACKAGE_SR_KEY
AND EndDates.Pack_Expiry_Time = StartDate.Pack_Start_Time

WHERE StartDate.Pack_Start_Time IS NULL
	AND StartDate.PACKAGE_SR_KEY IS NULL
	AND StartDate.SUBSCRIPTION_SR_KEY IS NULL
