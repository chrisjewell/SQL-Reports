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
		, @ResourceType VARCHAR(20);
SELECT @StartDate = '2017-04-01 00:00:00.000';
SELECT @EndDate = '2017-04-30 23:59:59.997';
SELECT @DateType = 'DOS'; -- 'DOE' or 'DOS'
SELECT @InclResource = 1; -- 1 includes Resource, 2 does not


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
	HCPC VARCHAR(200)
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
	CASE WHEN pos.Code IN ('11','04','50') AND LEFT(q.Description,8) IN ('HCPC - M','HCPC - D','HCPC - B') AND pvp.Units < 0 THEN - 1 
		WHEN pos.Code IN ('11','04','50') AND LEFT(q.Description,10) IN ('HCPC - MED','HCPC - DEN','HCPC - BH') AND pvp.Code NOT IN ('90832UL','96150','96151','96152','90867BH','98966BH') THEN  1 ELSE 0 END,
	CASE WHEN pos.Code IN ('21','22') AND LEFT(q.Description,8) IN ('HCPC - M','HCPC - D','HCPC - B') AND pvp.Units < 0 THEN - 1 
		WHEN pos.Code IN ('21','22') AND LEFT(q.Description,10) IN ('HCPC - MED','HCPC - DEN','HCPC - BH') AND pvp.Code NOT IN ('90832UL','96150','96151','96152','90867BH','98966BH') THEN 1 ELSE 0 END,
	CASE WHEN ISNULL(pos.Code,'') NOT IN ('11','04','21','22') AND LEFT(q.Description,8) IN ('HCPC - M','HCPC - D','HCPC - B') AND pvp.Units < 0 THEN -1 
		WHEN ISNULL(pos.Code,'') NOT IN ('11','04','21','22') AND LEFT(q.Description,10) IN ('HCPC - MED','HCPC - DEN','HCPC - BH') AND pvp.Code NOT IN ('90832UL','96150','96151','96152','90867BH','98966BH') THEN 1 ELSE 0 END,
	CASE WHEN pos.Code = '12' AND LEFT(q.Description,8) IN ('HCPC - M','HCPC - D','HCPC - B') AND pvp.Units < 0 THEN -1 
		WHEN pos.Code = '12' AND LEFT(q.Description,10) IN ('HCPC - MED','HCPC - DEN','HCPC - BH') AND pvp.Code NOT IN ('90832UL','96150','96151','96152','90867BH','98966BH') THEN 1 ELSE 0 END,
	ISNULL(pos.Code,'None'),
	ISNULL(pp.PatientId, 'Unknown'),
	ISNULL(q.Description, 'None')


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
	(pvp.DateofServiceFrom >= ISNULL(@StartDate,'1/1/1900') AND pvp.DateofServiceFrom < dateadd(d, 1, ISNULL(@EndDate,'1/1/3000')))
	)
	AND  --Filter on doctor
	(
	(NULL IS NOT NULL AND pv.DoctorID IN (NULL)) OR
	(NULL IS NULL)
	)
	AND  --Filter on CPTCode
	(
	(NULL IS NOT NULL AND pvp.ProceduresID IN (NULL)) OR
	(NULL IS NULL)
	)
	AND  --Filter on facility
	(
	(NULL IS NOT NULL AND pv.FacilityID IN (NULL)) OR
	(NULL IS NULL)
	)
	AND  --Filter on company
	(
	(NULL IS NOT NULL AND pv.CompanyID IN (NULL)) OR
	(NULL IS NULL)
	)
	AND  --Filter on insurance carrier
	(
	(NULL IS NOT NULL AND pv.PrimaryInsuranceCarriersId IN (NULL)) OR
	(NULL IS NULL)
	)
	AND  --Filter on batches
	(
	(NULL IS NOT NULL AND b.BatchId IN (NULL)) OR
	(NULL IS NULL)
	)
	--AND 
	--pv.Description NOT LIKE '%*VOID*%'
	AND --Filter out Test Patients
	(pp.Last NOT LIKE '%Mouse%' 
		AND pp.Last NOT LIKE '%Test%'
		AND pp.Last NOT LIKE '%Vistest%'
	)

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
	ISNULL(q.Description, 'None')
	

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
	AND  --Filter on doctor
	(
	(NULL IS NOT NULL AND pv.DoctorID IN (NULL)) OR
	(NULL IS NULL)
	)
	AND  --Filter on CPTCode
	(
	(NULL IS NOT NULL AND pvp.ProceduresID IN (NULL)) OR
	(NULL IS NULL)
	)
	AND  --Filter on facility
	(
	(NULL IS NOT NULL AND pv.FacilityID IN (NULL)) OR
	(NULL IS NULL)
	)
	AND  --Filter on company
	(
	(NULL IS NOT NULL AND pv.CompanyID IN (NULL)) OR
	(NULL IS NULL)
	)
	AND  --Filter on insurance carrier
	(
	(NULL IS NOT NULL AND pv.PrimaryInsuranceCarriersId IN (NULL)) OR
	(NULL IS NULL)
	)
	AND  --Filter on batches
	(
	(NULL IS NOT NULL AND b.BatchId IN (NULL)) OR
	(NULL IS NULL)
	)
	--AND 
	--pv.Description NOT LIKE '%*VOID*%'  -- This code was causing the MASSIVE reduction in HPP Encounters
	AND --Filter out Test Patients
		(pp.Last NOT LIKE '%Mouse%' 
		AND pp.Last NOT LIKE '%Test%'
		AND pp.Last NOT LIKE '%Vistest%')

-- Now we need to identify what tickets are encounters and also group by ticket number

IF @InclResource = 1
BEGIN
-- Now group the items together for a total

WITH Resources
	AS 
	(
	SELECT PatientVisitId
		, ResourceId = CASE
		WHEN COUNT(*) > 1 THEN '(Multiple)'
		ELSE MAX(R.ListName)
		END
	FROM PatientVisitResource AS PVR
		INNER JOIN DoctorFacility AS R ON PVR.ResourceId = R.DoctorFacilityId
	GROUP BY PatientVisitId
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
	ISNULL(rt.Description,'None') AS ResourceType,
	FacilityName,
	#Summary.CPTCode,
	(SUM(InsAllocation) + SUM(PatAllocation)) AS Charges,
	/*SUM(PatAllocation) AS PatAllocation,*/
	SUM(PatBalance) AS PatBalance,
	SUM(InsBalance) AS InsBalance,
	SUM(InsPayment) AS InsPayment,
	SUM(PatPayment) AS PatPayment,
	SUM(InsAdjustment) AS InsAdjustment,
	SUM(PatAdjustment) AS PatAdjustment,
	CASE WHEN SUM(OVEncounter) >= 1 THEN 1 WHEN SUM(OVEncounter) < -1 THEN -1 ELSE SUM(OVEncounter) END AS OVEncounter,
	CASE WHEN SUM(InPatientEncounter) >= 1 THEN 1 WHEN SUM(InPatientEncounter) < -1 THEN -1 ELSE SUM(InPatientEncounter) END AS InPatientEncounter,
	CASE WHEN SUM(OtherEncounter) >= 1 THEN 1 WHEN SUM(OtherEncounter) < -1 THEN -1 ELSE SUM(OtherEncounter) END AS OtherEncounter,
	CASE WHEN SUM(HomeEncounter) >= 1 THEN 1 WHEN SUM(HomeEncounter) < -1 THEN -1 ELSE SUM(HomeEncounter) END AS HomeEncounter
	, HCPC
	, (CASE WHEN SUM(OVEncounter) >= 1 THEN 1 WHEN SUM(OVEncounter) < -1 THEN -1 ELSE SUM(OVEncounter) END +
	CASE WHEN SUM(InPatientEncounter) >= 1 THEN 1 WHEN SUM(InPatientEncounter) < -1 THEN -1 ELSE SUM(InPatientEncounter) END +
	CASE WHEN SUM(OtherEncounter) >= 1 THEN 1 WHEN SUM(OtherEncounter) < -1 THEN -1 ELSE SUM(OtherEncounter) END  +
	CASE WHEN SUM(HomeEncounter) >= 1 THEN 1 WHEN SUM(HomeEncounter) < -1 THEN -1 ELSE SUM(HomeEncounter) END ) AS CountEnc
	, 'Centricity' AS DataSource

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
	rt.Description IN ('Doctors','BHC','Hygienists','Dentists')

	AND
	#Summary.TicketNumber NOT IN ('000347','000842A','006186','010976',
		'021547','023971','033918','043091','045260A','051951','054196',
		'057663','057664','057665','057666','061326','002746','004112',
		'005342','006032','012802','013967','013973','016045','016206',
		'017547','018425','019487','020016','020685','020713','021249',
		'021546','026112','027993','028781','029520','031820','033010',
		'033377','044270','045973','051922','051966','051991','054189',
		'056586','056587','057476','057625','057643','059386','061308',
		'061312','061313','061314','062677','063810','063811','063816',
		'063819','063821','063829','063835','063836','063840','063848',
		'079063','000236','000637','001189','001210','001211','001884',
		'002118','002222A','004680','008323','008673','011702','012921',
		'013322','013868','013950','016196','016449','017509','021799',
		'023132','023968','023990','024005','024981','028422','033069',
		'033332','035577','039397','042398','043316','046141','046142',
		'046235','048285','051929','051932','051934','051936','051957',
		'051960','051980','052012','052017','052028','052694','052696',
		'054190','054236','056055','057638','057644','057672','058772',
		'058829','058839','060536','060546','060581','060701','061323',
		'063306','063404','063405','063846','063856','045265','059952')

	


GROUP BY 
	DoctorName,
	FacilityName,
	CompanyName,
	PolicyType,
	InsuranceCarrier,
	TicketNumber,
	r.ResourceId,
	rt.Description,
	pvr.ResourceID,
	#Summary.DateofServiceFrom,
	#Summary.MonthofService,
	#Summary.PatientId,
	#Summary.CPTCode
	, #Summary.HCPC



ORDER BY 
	CompanyName,
	FacilityName,
	TicketNumber
END


DROP TABLE #Summary