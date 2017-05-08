/* Reimbursement Summary  01/31/2005 
Updated for Batch and DOS information 11/01/2005
Eliminated Charges <> 0 filter to count encounters that are no charge 2/21/06 
3/13/2006 Reflect FQHC Charges as negative insurance adjustments
5/20/2006 Added code to eliminate voids*/



SET NOCOUNT ON;

IF OBJECT_ID('tempdb.dbo.#Summary', 'U') IS NOT NULL
	DROP TABLE #Summary; 


DECLARE @StartDate DATETIME
		, @EndDate DATETIME
		, @DateType VARCHAR(3)
		, @InclResource INT
		, @HCPCType VARCHAR(10)
		, @ServiceType VARCHAR(15)
		, @ResourceType VARCHAR(20)
		, @PPSrateDate2015 DATETIME
		, @PPSrateDate2016 DATETIME
		, @PPSrateDate2017 DATETIME
		, @PPSrateDate2018 DATETIME
		, @PPSrateDate2019 DATETIME
		, @PPSrateDate2020 DATETIME
		, @PPSrateDate2021 DATETIME
		, @PPSrateDate2022 DATETIME
		, @PPSrateDate2023 DATETIME
		, @PPSrateDate2024 DATETIME
		, @PPSrateDate2025 DATETIME
		, @PPSrateFY2015 NUMERIC(10,2)
		, @PPSrateFY2016 NUMERIC(10,2)
		, @PPSrateFY2017 NUMERIC(10,2)
		, @PPSrateFY2018 NUMERIC(10,2)
		, @PPSrateFY2019 NUMERIC(10,2)
		, @PPSrateFY2020 NUMERIC(10,2)
		, @PPSrateFY2021 NUMERIC(10,2)
		, @PPSrateFY2022 NUMERIC(10,2)
		, @PPSrateFY2023 NUMERIC(10,2)
		, @PPSrateFY2024 NUMERIC(10,2)
		, @PPSrateFY2025 NUMERIC(10,2)
		, @Medical_MedicaidConservatismFactor FLOAT
		, @Medical_MedicareConservatismFactor FLOAT
		, @Medical_PrivateOtherConservatismFactor FLOAT
		, @Medical_SelfPaySlideConservatismFactor FLOAT
		, @BHC_MedicaidConservatismFactor FLOAT
		, @BHC_MedicareConservatismFactor FLOAT
		, @BHC_PrivateOtherConservatismFactor FLOAT
		, @BHC_SelfPaySlideConservatismFactor FLOAT
		, @Dental_MedicaidConservatismFactor FLOAT
		, @Dental_MedicareConservatismFactor FLOAT
		, @Dental_PrivateOtherConservatismFactor FLOAT
		, @Dental_SelfPaySlideConservatismFactor FLOAT
		;

-- This is the date range and date type that we will look at for this report:

SELECT @StartDate = '2017-01-01 00:00:00.000';
SELECT @EndDate = '2017-03-31 23:59:59.997';
SELECT @DateType = 'DOS'; -- 'DOE' or 'DOS'

-- These next blocks define the blended net collection rates that we are 
-- applying to Fees/Gross Revenue in order to calculate A/R for each service type:

SELECT @Medical_MedicaidConservatismFactor = 0.5736;		-- Updated 03/13/2017
SELECT @Medical_MedicareConservatismFactor = 0.3744;		-- Updated 03/13/2017
SELECT @Medical_PrivateOtherConservatismFactor = 0.2010;	-- Updated 03/13/2017
SELECT @Medical_SelfPaySlideConservatismFactor = 0.0811;	-- Updated 03/13/2017

SELECT @BHC_MedicaidConservatismFactor = 0.9760;			-- Updated 03/13/2017
SELECT @BHC_MedicareConservatismFactor = 0.0000;			-- Updated 03/13/2017
SELECT @BHC_PrivateOtherConservatismFactor = 0.0000;		-- Updated 03/13/2017
SELECT @BHC_SelfPaySlideConservatismFactor = 0.0000;		-- Updated 03/13/2017

SELECT @Dental_MedicaidConservatismFactor = 0.7030;			-- Updated 03/13/2017 ---- THIS IS CURRENTLY A VERY ROUGH ESTIMATE BECAUSE THE FEES ON DENTAL PROCEDURES ARE WEIRD
SELECT @Dental_MedicareConservatismFactor = 0.3609;			-- Updated 03/13/2017
SELECT @Dental_PrivateOtherConservatismFactor = 0.6281;		-- Updated 03/13/2017
SELECT @Dental_SelfPaySlideConservatismFactor = 0.2069;		-- Updated 03/13/2017

-- This next block defines the effective date for the "Current" Medicaid PPS rate for each of the timeframes:
-- (NOTE: This is usually October 1st)

SELECT @PPSrateDate2015 = '2015-10-01 00:00:00.000';
SELECT @PPSrateDate2016 = '2016-10-01 00:00:00.000';
SELECT @PPSrateDate2017 = '2017-10-01 00:00:00.000';
SELECT @PPSrateDate2018 = '2018-10-01 00:00:00.000';
--SELECT @PPSrateDate2018 = ;
--SELECT @PPSrateDate2019 = ;
--SELECT @PPSrateDate2020 = ;
--SELECT @PPSrateDate2021 = ;
--SELECT @PPSrateDate2022 = ;
--SELECT @PPSrateDate2023 = ;
--SELECT @PPSrateDate2024 = ;
--SELECT @PPSrateDate2025 = ;

-- This next block defines the "Current" actual Medicaid PPS rate for each of the timeframes:
-- (NOTE: The variable year notation may be a little confusing - essentially, FY2015 represents all time leading 
-- up to 10/1/15, and then FY2016 represents the rate effective starting in FY16 and going through 
-- the first three months of FY17, at which point it changes to the new amount stored in FY2017, and so on.)

SELECT @PPSrateFY2015 = 193.95;
SELECT @PPSrateFY2016 = 195.50;
SELECT @PPSrateFY2017 = 197.65;
--SELECT @PPSrateFY2018 = ;
--SELECT @PPSrateFY2019 = ;
--SELECT @PPSrateFY2020 = ;
--SELECT @PPSrateFY2021 = ;
--SELECT @PPSrateFY2022 = ;
--SELECT @PPSrateFY2023 = ;
--SELECT @PPSrateFY2024 = ;
--SELECT @PPSrateFY2025 = ;


SELECT @InclResource = 1; -- 1 includes Resource, 2 does not
--SELECT @HCPCType = 'HCPC - M', 'HCPC - B', 'HCPC - D'
--SELECT @ServiceType = 'HCPC - MED', 'HCPC - DEN', 'HCPC - BH'
--SELECT @ResourceType = 'Doctors', 'BHC', 'Dentist', 'Hygienist'



CREATE TABLE #Summary 
	(
	DoctorID int,
	DoctorName varchar(60),
	FacilityID int,
	FacilityName varchar(60),
	CompanyID int,
	CompanyName varchar(60),
	PolicyTypeMId int,
	PolicyType varchar(90),
	DepartmentMID int,
	Department varchar(60),
	InsuranceCarriersID int,
	InsuranceCarrier varchar(60),
	InsAllocation numeric(10,2),
	PatAllocation numeric(10,2),
	PatBalance numeric(10,2),
	InsBalance numeric(10,2),
	InsPayment numeric(10,2),
	PatPayment numeric(10,2),
	InsAdjustment numeric(10,2),
	PatAdjustment numeric(10,2),
	Flag varchar(60),
	CPTCode varchar(10),
	ProceduresID int,
	TicketNumber varchar(35),
                Entry datetime,
	Resource varchar(60),
	ResourceType varchar(200),
	RevenueCode varchar(20),
	ResourceID int,
	PatientVisitID int,
	DateofServiceFrom datetime,
	MonthofService varchar(7),
	OVEncounter int,
	InPatientEncounter int,
	OtherEncounter int,
	HomeEncounter int,
	POS varchar(5),
	PatientId VARCHAR(20),
	HCPC VARCHAR(200),
	DateOfEntry datetime,
	FirstFiledDate datetime,
	DaysToChargeEntry varchar(25),
	DaysToClaimSubmission varchar(25),
	PPSrate money
	, MCO varchar(3) -- reads whether or not the insurrance carrier is an MCO
	, MCOExpectedCollection money
	, ProviderInitials varchar(5)
	);

	
-- Insert Charges 
INSERT INTO #Summary

SELECT	
	pv.DoctorId, 
	d.ListName AS DoctorName,
	pv.FacilityId, 
	f.ListName AS FacilityName,
	pv.CompanyId, 
	c.ListName AS CompanyName,
	ISNULL(ic.PolicyTypeMId,0) AS PolicyTypeMId, 
	ISNULL(pt.Description,  'Unknown') AS PolicyType, 
	ISNULL(p.DepartmentMId,0) AS DepartmentMId, 
	ISNULL(dp.Description, 'Unknown') AS Department,
	ISNULL(pv.PrimaryInsuranceCarriersId,0),
	ISNULL(ic.ListName,'Self Pay') AS PrimaryInsuranceCarrier, 
	CASE WHEN pvp.CPTCode IN ('520','T1015','900','D2999') THEN 0 ELSE pvpa.OrigInsAllocation END, 
	pvpa.OrigPatAllocation,
	pvpa.OrigPatAllocation,
	pvpa.OrigInsAllocation,
	0, 
	0, 
	CASE WHEN pvp.CPTCode IN ('520','T1015','900','D2999') THEN - pvpa.OrigInsAllocation ELSE 0 END, 
	0,
	convert(varchar(90), 'None'), 
	ISNULL(pvp.Code,'No Code'),
	ISNULL(pvp.ProceduresID,0),
                pv.TicketNumber,
                pv.Entered,
	' ',
	' ',
	' ',
	0,
	pv.PatientVisitID,
	pvp.DateOfServiceFrom,
	SUBSTRING(CONVERT(VARCHAR, pvp.DateOfServiceFrom, 120), 1, 7),
	CASE WHEN pos.Code IN ('11','04','50') AND LEFT(q.Description,8) IN ('HCPC - M', 'HCPC - B', 'HCPC - D') AND pvp.Units < 0 THEN - 1 
		WHEN pos.Code IN ('11','04','50') AND LEFT(q.Description,10) IN ('HCPC - MED', 'HCPC - DEN', 'HCPC - BH') AND pvp.Code NOT IN ('90832UL','96150','96151','96152','90867BH','98966BH') THEN  1 ELSE 0 END, --Changing to include all Med, BHC, Den
	CASE WHEN pos.Code IN ('21','22') AND LEFT(q.Description,8) IN ('HCPC - M', 'HCPC - B', 'HCPC - D') AND pvp.Units < 0 THEN - 1 
		WHEN pos.Code IN ('21','22') AND LEFT(q.Description,10) IN ('HCPC - MED', 'HCPC - DEN', 'HCPC - BH') AND pvp.Code NOT IN ('90832UL','96150','96151','96152','90867BH','98966BH') THEN 1 ELSE 0 END,
	CASE WHEN ISNULL(pos.Code,'') NOT IN ('11','04','21','22') AND LEFT(q.Description,8) IN ('HCPC - M', 'HCPC - B', 'HCPC - D') AND pvp.Units < 0 THEN -1 
		WHEN ISNULL(pos.Code,'') NOT IN ('11','04','21','22') AND LEFT(q.Description,10) IN ('HCPC - MED', 'HCPC - DEN', 'HCPC - BH') AND pvp.Code NOT IN ('90832UL','96150','96151','96152','90867BH','98966BH') THEN 1 ELSE 0 END,
	CASE WHEN pos.Code = '12' AND LEFT(q.Description,8) IN ('HCPC - M', 'HCPC - B', 'HCPC - D') AND pvp.Units < 0 THEN -1 
		WHEN pos.Code = '12' AND LEFT(q.Description,10) IN ('HCPC - MED', 'HCPC - DEN', 'HCPC - BH') AND pvp.Code NOT IN ('90832UL','96150','96151','96152','90867BH','98966BH') THEN 1 ELSE 0 END,
	ISNULL(pos.Code,'None'),
	ISNULL(pp.PatientId, 'Unknown'),
	CASE WHEN (len(ISNULL(q.Description, 'None'))>15) THEN (left(ISNULL(q.Description, 'None'),15) +'...')
		ELSE ISNULL(q.Description, 'None')
		END
	, ' '
	, pv.FirstFiledDate
	, ' '
	, ' '
	, (CASE WHEN pvp.DateOfServiceFrom <= @PPSrateDate2015 THEN @PPSrateFY2015
			WHEN pvp.DateOfServiceFrom >= @PPSrateDate2015 AND pvp.DateOfServiceFrom < @PPSrateDate2016 THEN @PPSrateFY2016
			WHEN pvp.DateOfServiceFrom >= @PPSrateDate2016 AND pvp.DateOfServiceFrom < @PPSrateDate2017 THEN @PPSrateFY2017
			WHEN pvp.DateOfServiceFrom >= @PPSrateDate2017 AND pvp.DateOfServiceFrom < @PPSrateDate2018 THEN @PPSrateFY2018
			WHEN pvp.DateOfServiceFrom >= @PPSrateDate2018 THEN NULL END)
	, (CASE WHEN pv.PrimaryInsuranceCarriersId IN (1788, 1762, 1753, 1755, 1764, 1744, 1799, 1791, 1813, 1790, 1805, 1806) THEN 'Yes' ELSE 'No' END)
	, ' '
	, ' '


FROM   PatientVisit pv 
	INNER JOIN DoctorFacility d ON pv.DoctorId = d.DoctorFacilityId 
	INNER JOIN DoctorFacility f ON pv.FacilityId = f.DoctorFacilityId 
	INNER JOIN DoctorFacility c ON pv.CompanyId = c.DoctorFacilityId 
	INNER JOIN PatientVisitProcs pvp ON pv.PatientVisitId = pvp.PatientVisitId 
	INNER JOIN Batch b ON pvp.BatchID = b.BatchID 
	INNER JOIN PatientVisitProcsAgg pvpa ON pvp.PatientVisitProcsID = pvpa.PatientVisitProcsID
	INNER JOIN PatientProfile pp ON pv.PatientProfileId = pp.PatientProfileId
	LEFT OUTER JOIN Procedures p ON pvp.ProceduresID = p.ProceduresID 
	LEFT OUTER JOIN MedLists dp ON p.DepartmentMID = dp.MedListsID 
	LEFT OUTER JOIN InsuranceCarriers ic ON ic.InsuranceCarriersId = pv.PrimaryInsuranceCarriersId
	LEFT OUTER JOIN MedLists pt ON ic.PolicyTypeMId = pt.MedListsID 
	LEFT OUTER JOIN MedLists pos ON f.PlaceofServiceMID = pos.MedListsID 
	LEFT OUTER JOIN MedLists q ON p.CPTProcedureCodeQualifierMID = q.MedListsID
	

WHERE	/* pvpa.InsAllocation + pvpa.PatAllocation <> 0.00 AND */
    (
	(@DateType = 'DOS' AND pvp.DateofServiceFrom >= ISNULL(@StartDate,'1/1/1900') AND pvp.DateofServiceFrom < ISNULL(@EndDate,'1/1/3000')) OR
	(@DateType = 'DOE' AND pvp.DateofEntry >= ISNULL(@StartDate,'1/1/1900') AND pvp.DateofEntry < ISNULL(@EndDate,'1/1/3000'))
	)
	AND 
    (
	(pvp.DateofServiceFrom >= ISNULL(@StartDate,'1/1/1900') AND pvp.DateofServiceFrom < ISNULL(@EndDate,'1/1/3000'))
	)
	AND --Filter out Test Patients
	(pp.Last NOT LIKE '%Mouse%' 
		AND pp.Last NOT LIKE '%Test%'
		AND pp.Last NOT LIKE '%Vistest%'
	)
	--AND 
	--pv.Description NOT LIKE '%*VOID*%'

-- Next Import Payments and Adjustments
INSERT INTO #Summary

SELECT	
	pv.DoctorId, 
	d.ListName AS DoctorName,
	pv.FacilityId, 
	f.ListName AS FacilityName,
	pv.CompanyId, 
	c.ListName AS CompanyName,
	ISNULL(ic.PolicyTypeMId,0) AS PolicyTypeMId, 
	ISNULL(pt.Description,  'Unknown') AS PolicyType, 
	ISNULL(p.DepartmentMId,0) AS DepartmentMId, 
	ISNULL(dp.Description, 'Unknown') AS Department,
	ISNULL(pv.PrimaryInsuranceCarriersId,0),
	ISNULL(ic.ListName,'Self Pay') AS PrimaryInsuranceCarrier, 
	0, 
	0,
	CASE WHEN pm.Source = 1 AND t.Action IN ('A','P') THEN -td.Amount ELSE 0 END,
	CASE WHEN pm.Source = 2 AND t.Action IN ('A','P') THEN -td.Amount ELSE 0 END,
	CASE WHEN pm.Source = 2 AND t.Action = ('P') THEN td.Amount ELSE 0 END, 
	CASE WHEN pm.Source = 1 AND t.Action = ('P') THEN td.Amount ELSE 0 END, 
	CASE WHEN pm.Source = 2 AND t.Action = ('A') THEN td.Amount ELSE 0 END, 
	CASE WHEN pm.Source = 1 AND t.Action = ('A') THEN td.Amount ELSE 0 END, 
	convert(varchar(90), 'None'), 
	ISNULL(pvp.Code,'No Code'),
	ISNULL(pvp.ProceduresID,0),
                pv.TicketNumber,
                pm.DateofEntry,
	' ',
	' ',
	' ',
	0,
	pv.PatientVisitID,
	pvp.DateOfServiceFrom,
	SUBSTRING(CONVERT(VARCHAR, pvp.DateOfServiceFrom, 120), 1, 7),
	0,
	0,
	0,
	0,
	ISNULL(pos.Code,'None'),
	ISNULL(pp.PatientId, 'Unknown'),
	CASE WHEN (len(ISNULL(q.Description, 'None'))>15) THEN (left(ISNULL(q.Description, 'None'),15) +'...')
		ELSE ISNULL(q.Description, 'None')
		END
	, pm.DateOfEntry
	, pv.FirstFiledDate
	, ISNULL(CONVERT(VARCHAR(25), DATEDIFF(day, pvp.DateOfServiceFrom, pm.DateOfEntry)), 'Charge Not Retrieved') -- I should build in some logic to check which date is actually NULL
	, ISNULL(CONVERT(VARCHAR(25), DATEDIFF(day, pvp.DateOfServiceFrom, pv.FirstFiledDate)), 'Not Yet Filed') -- Here too
	, (CASE WHEN pvp.DateOfServiceFrom <= @PPSrateDate2015 THEN @PPSrateFY2015
			WHEN pvp.DateOfServiceFrom >= @PPSrateDate2015 AND pvp.DateOfServiceFrom < @PPSrateDate2016 THEN @PPSrateFY2016
			WHEN pvp.DateOfServiceFrom >= @PPSrateDate2016 AND pvp.DateOfServiceFrom < @PPSrateDate2017 THEN @PPSrateFY2017
			WHEN pvp.DateOfServiceFrom >= @PPSrateDate2017 AND pvp.DateOfServiceFrom < @PPSrateDate2018 THEN @PPSrateFY2018
			WHEN pvp.DateOfServiceFrom >= @PPSrateDate2018 THEN NULL END)
	, (CASE WHEN pv.PrimaryInsuranceCarriersId IN (1788, 1762, 1753, 1755, 1764, 1744, 1799, 1791, 1813, 1790, 1805, 1806) THEN 'Yes' ELSE 'No' END)
	, ' '
	, ' '
	

FROM 
	PatientVisit pv 
	INNER JOIN PatientProfile pp ON pv.PatientProfileId = pp.PatientProfileId 
	INNER JOIN DoctorFacility d ON pv.DoctorId = d .DoctorFacilityId 
	INNER JOIN DoctorFacility f ON pv.FacilityId = f.DoctorFacilityId 
	INNER JOIN DoctorFacility c ON pv.CompanyId = c.DoctorFacilityId 
	INNER JOIN VisitTransactions vt ON pv.PatientVisitId = vt.PatientVisitid 
	INNER JOIN PaymentMethod pm ON vt.PaymentMethodId = pm.PaymentMethodId 
	INNER JOIN Batch b ON pm.BatchID = b.BatchID 
	INNER JOIN Transactions t ON vt.VisitTransactionsId = t .VisitTransactionsId 
	INNER JOIN TransactionDistributions td ON t .TransactionsId = td.TransactionsId 
	LEFT OUTER JOIN PatientVisitProcs pvp ON td.PatientVisitProcsId = pvp.PatientVisitProcsId 
	LEFT OUTER JOIN Procedures p ON pvp.ProceduresID = p.ProceduresID 
	LEFT OUTER JOIN MedLists dp ON p.DepartmentMID = dp.MedListsID 
	LEFT OUTER JOIN MedLists at ON t.ActionTypeMId = at.MedListsId 
	LEFT OUTER JOIN InsuranceCarriers ic ON pv.PrimaryInsuranceCarriersID = ic.InsuranceCarriersID 
	LEFT OUTER JOIN MedLists pt ON ic.PolicyTypeMId = pt.MedListsID 
	LEFT OUTER JOIN MedLists pos ON f.PlaceofServiceMID = pos.MedListsID
	LEFT OUTER JOIN MedLists q ON p.CPTProcedureCodeQualifierMID = q.MedListsID

WHERE	
	td.Amount <> 0.00 AND
	(
	(@DateType = 'DOS' AND pvp.DateofServiceFrom >= ISNULL(@StartDate,'1/1/1900') AND pvp.DateofServiceFrom < ISNULL(@EndDate,'1/1/3000')) OR
	(@DateType = 'DOE' AND pm.DateofEntry >= ISNULL(@StartDate,'1/1/1900') AND pm.DateofEntry < ISNULL(@EndDate,'1/1/3000'))
	)
	AND 
    (
	(pvp.DateofServiceFrom >= ISNULL(@StartDate,'1/1/1900') AND pvp.DateofServiceFrom < ISNULL(@EndDate,'1/1/3000'))
	)
	AND --Filter out Test Patients
	(
	pp.Last NOT LIKE '%Mouse%' 
		AND pp.Last NOT LIKE '%Test%'
		AND pp.Last NOT LIKE '%Vistest%'
	)
	--AND 
	--pv.Description NOT LIKE '%*VOID*%'


-- Now we need to identify what tickets are encounters and also group by ticket number

IF @InclResource = 1
BEGIN
-- Now group the items together for a total

WITH Resources
	AS 
	(
	SELECT PatientVisitId
		, R.DotId
		, ResourceId = CASE
		WHEN COUNT(*) > 1 THEN '(Multiple)'
		ELSE MAX(R.ListName)
		END
	FROM PatientVisitResource AS PVR
		INNER JOIN DoctorFacility AS R ON PVR.ResourceId = R.DoctorFacilityId
	GROUP BY PatientVisitId
		, R.DotId
	)

	
SELECT
	TicketNumber,
	#Summary.PatientId,
	CAST(#Summary.DateofServiceFrom AS DATE) AS DateofService,
	#Summary.MonthofService,
	InsuranceCarrier,
	PolicyType,
	DoctorName,
	ISNULL(r.ResourceId,'None') AS Resource,
	r.DotId As ProviderInitials,
	ISNULL(rt.Description,'None') AS ResourceType,
	FacilityName,
--	CPTCode,
--	(SUM(InsAllocation) + SUM(PatAllocation)) AS Charges,
--	SUM(PatBalance) AS PatBalance,
--	SUM(InsBalance) AS InsBalance,
--	SUM(InsPayment) AS InsPayment,
--	SUM(PatPayment) AS PatPayment,
--	SUM(InsAdjustment) AS InsAdjustment,
--	SUM(PatAdjustment) AS PatAdjustment,
	CASE WHEN SUM(OVEncounter) >= 1 THEN 1 WHEN SUM(OVEncounter) < -1 THEN -1 ELSE SUM(OVEncounter) END AS OVEncounter,
	CASE WHEN SUM(InPatientEncounter) >= 1 THEN 1 WHEN SUM(InPatientEncounter) < -1 THEN -1 ELSE SUM(InPatientEncounter) END AS InPatientEncounter,
	CASE WHEN SUM(OtherEncounter) >= 1 THEN 1 WHEN SUM(OtherEncounter) < -1 THEN -1 ELSE SUM(OtherEncounter) END AS OtherEncounter,
	CASE WHEN SUM(HomeEncounter) >= 1 THEN 1 WHEN SUM(HomeEncounter) < -1 THEN -1 ELSE SUM(HomeEncounter) END AS HomeEncounter
	, (CASE WHEN SUM(OVEncounter) >= 1 THEN 1 WHEN SUM(OVEncounter) < -1 THEN -1 ELSE SUM(OVEncounter) END +
	CASE WHEN SUM(InPatientEncounter) >= 1 THEN 1 WHEN SUM(InPatientEncounter) < -1 THEN -1 ELSE SUM(InPatientEncounter) END +
	CASE WHEN SUM(OtherEncounter) >= 1 THEN 1 WHEN SUM(OtherEncounter) < -1 THEN -1 ELSE SUM(OtherEncounter) END  +
	CASE WHEN SUM(HomeEncounter) >= 1 THEN 1 WHEN SUM(HomeEncounter) < -1 THEN -1 ELSE SUM(HomeEncounter) END ) AS CountEnc
--	, HCPC
	, (CASE WHEN ISNULL(rt.Description,'None') = 'BHC' THEN 'BHC'
			WHEN ISNULL(rt.Description,'None') = 'Doctors' THEN 'Medical'
			WHEN ISNULL(rt.Description,'None') IN ('Dentists', 'Hygienists') THEN 'Dental'
			ELSE 'Other'
			END) AS ServiceType
	, MCO AS [MCO?]
	, [Broad Payer Type] =
		(
		CASE 
		WHEN #Summary.PolicyTypeMId IN (2495, 114348) THEN 'Medicaid/PPS' 
		WHEN #Summary.PolicyTypeMId IN (2500, 2501) THEN 'Self Pay/Sliding Fee' 
		WHEN #Summary.PolicyTypeMId IN (2497, 114349, 146) THEN 'Medicare' 
		ELSE 'Private/Other' 
		END
		)	

FROM 
	#Summary
	LEFT JOIN PatientVisitResource pvr ON #Summary.PatientVisitID = pvr.PatientVisitID
	LEFT JOIN DoctorFacility d ON pvr.ResourceID = d.DoctorFacilityID
	LEFT JOIN Resources r ON #Summary.PatientVisitID = r.PatientVisitId
--	LEFT JOIN Visits v ON #Summary.PatientVisitID = v.PatientVisitId
	INNER JOIN ResourceTypeAssignments rta ON pvr.ResourceId = rta.ResourceId
	INNER JOIN MedLists rt ON rta.ResourceTypeId = rt.MedlistsId
	
		

WHERE 
	(
	(NULL IS NOT NULL AND pvr.ResourceID IN (NULL)) OR
	(NULL IS NULL)
	)
	AND
	rt.Description IN ('Doctors', 'BHC', 'Dentists', 'Hygienists') -- To bring all of the information together in one report


GROUP BY 
	DoctorName,
	FacilityName,
--	CPTCode,
	CompanyName,
	PolicyType,
	#Summary.PolicyTypeMId,
	InsuranceCarrier,
	TicketNumber,
	r.ResourceId,
	rt.Description,
	r.DotId,
	pvr.ResourceID,
	#Summary.DateofServiceFrom,
	#Summary.MonthofService,
	#Summary.PatientId
--	, #Summary.HCPC
	, #Summary.PPSrate
	, #Summary.MCO
	

ORDER BY 
	CompanyName,
	FacilityName,
	TicketNumber
END


DROP TABLE #Summary