/* Net Charges By Insurance */


SET NOCOUNT ON


/********This is the part added by Esperanza********/

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
		, @CutOffDate DATE
		, @CurrentClosingDate datetime
		;



-- This is the date range and date type that we will look at for this report:

SELECT @StartDate = DATEADD(MM, DATEDIFF(MM, 0, GETDATE())-12, 0); -- DATEADD(MM, DATEDIFF(MM, 0, GETDATE())-6, 0) -- Rolling 12 months
SELECT @EndDate = DATEADD(DD, -1, DATEADD(MM, DATEDIFF(MM, 0, GETDATE()), 0)); -- DATEADD(DD, -1, DATEADD(MM, DATEDIFF(MM, 0, GETDATE()), 0)) -- Rolling 6 months
SELECT @DateType = 'DOS'; -- 'DOE' or 'DOS'
SELECT @CutOffDate = GETDATE() -- This is the last date of entry for to look at for Subsequent Collections
SELECT @CurrentClosingDate = GETDATE();  -- '06/30/2016' for Gross A/R, '12/31/2016' for Net A/R (11/17/2016)

-- This next block defines the effective date for the "Current" Medicaid PPS rate for each of the timeframes:
-- (NOTE: This is usually October 1st)

SELECT @PPSrateDate2015 = '2015-10-01 00:00:00.000';
SELECT @PPSrateDate2016 = '2016-10-01 00:00:00.000';
SELECT @PPSrateDate2017 = '2017-10-01 00:00:00.000';
SELECT @PPSrateDate2018 = '2018-10-01 00:00:00.000';
SELECT @PPSrateDate2019 = '2019-10-01 00:00:00.000';
SELECT @PPSrateDate2020 = '2020-10-01 00:00:00.000';
SELECT @PPSrateDate2021 = '2021-10-01 00:00:00.000';
SELECT @PPSrateDate2022 = '2022-10-01 00:00:00.000';
SELECT @PPSrateDate2023 = '2023-10-01 00:00:00.000';
SELECT @PPSrateDate2024 = '2024-10-01 00:00:00.000';
SELECT @PPSrateDate2025 = '2025-10-01 00:00:00.000';

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


BEGIN

WITH Resources AS 
	(
	SELECT PatientVisitId
		, PVR.PatientVisitResourceId
		, R.DotId
		, ResourceName = CASE
		WHEN COUNT(*) > 1 THEN '(Multiple)'
		ELSE MAX(R.ListName)
		END
		, ResourceType = MAX(rt.Description)
	FROM PatientVisitResource AS PVR
		INNER JOIN DoctorFacility AS R ON PVR.ResourceId = R.DoctorFacilityId
		LEFT JOIN ResourceTypeAssignments rta ON pvr.ResourceId = rta.ResourceId
		LEFT JOIN MedLists rt ON rta.ResourceTypeId = rt.MedlistsId
	WHERE rt.Description IN ('Doctors', 'BHC', 'Dentists', 'Hygienists')
	GROUP BY PatientVisitId
		, PVR.PatientVisitResourceId
		, R.DotId
	)
	, Collections AS
	(
	SELECT tmp.PatientVisitId
		, tmp.PatientVisitProcsId
		, Payments = SUM((ISNULL(InsurancePayment,0) + ISNULL(PatientPayment,0)))
		, CollectableAdjustments = SUM((ISNULL(CollectableInsuranceAdjustment,0) + ISNULL(NonCollectablePatientAdjustment,0)))
		, NonCollectableAdjustments = SUM((ISNULL(NonCollectableInsuranceAdjustment,0) + ISNULL(NonCollectablePatientAdjustment,0)))

	FROM  (
			SELECT pvp.PatientVisitProcsId AS PatientVisitProcsId
				, pv.PatientVisitId AS PatientVisitId
				, pvp.BatchId AS BatchId
				, pvpa.InsAllocation AS InsuranceCharges
				, pvpa.PatAllocation AS PatientCharges
				, pvp.TotalAllowed AS Allowed


			FROM PatientVisitProcs AS pvp 
				JOIN PatientVisitProcsAgg AS pvpa 
					ON pvp.PatientVisitProcsId = pvpa.PatientVisitProcsId
				JOIN PatientVisit AS pv 
					ON pvp.PatientVisitId = pv.PatientVisitId
				LEFT JOIN InsuranceCarriers AS ic 
					ON pv.PrimaryInsuranceCarriersId = ic.InsuranceCarriersId
				JOIN Batch AS b 
					ON pvp.BatchId = b.BatchId


			WHERE	--Filter on date type and range
				(
				(@DateType = 'DOS' AND pvp.DateOfServiceFrom >= ISNULL(@StartDate, '1/1/1900') AND pvp.DateOfServiceFrom < dateadd(d, 1, ISNULL(@EndDate,'1/1/3000'))) OR
				(@DateType = 'DOE' AND pvp.DateOfEntry >= ISNULL(@StartDate,'1/1/1900') AND pvp.DateOfEntry < dateadd(d,1,ISNULL(@EndDate,'1/1/3000'))))) AS tmp 

		LEFT JOIN (SELECT temp.PatientVisitProcsId
					, InsurancePayment = SUM(
						CASE WHEN t.Action = 'P' AND pm.Source = 2 THEN td.Amount ELSE 0 END)
					, PatientPayment = SUM(
						CASE WHEN t.Action = 'P' AND pm.Source = 1 THEN td.Amount ELSE 0 END)
					, CollectableInsuranceAdjustment = SUM(
						CASE WHEN t.Action = 'A' AND pm.Source = 2 AND ISNULL(ml.FunctionName,'Y') = 'Y' THEN td.Amount ELSE 0 END)
					, NonCollectableInsuranceAdjustment = SUM(
						CASE WHEN t.Action = 'A' AND pm.Source = 2 AND ISNULL(ml.FunctionName,'Y') = 'N'  THEN td.Amount ELSE 0 END)
					, CollectablePatientAdjustment = SUM(
						CASE WHEN t.Action = 'A' AND pm.Source = 1 AND ISNULL(ml.FunctionName,'Y') = 'Y' THEN td.Amount ELSE 0 END)
					, NonCollectablePatientAdjustment = SUM(
						CASE WHEN t.Action = 'A' AND pm.Source = 1 AND ISNULL(ml.FunctionName,'Y') = 'N' THEN td.Amount ELSE 0 END)
					, CheckNumber = pm.CheckCardNumber
					, CheckDate = pm.CheckDate
					, PayerType = pm.PayerType
					, Source = pm.Source
					, DateOfEntry = pm.DateOfEntry

					FROM (
							SELECT pvp.PatientVisitProcsId AS PatientVisitProcsId
								, pvp.BatchId AS BatchId
								, pvpa.InsAllocation AS InsuranceCharges
								, pvpa.PatAllocation AS PatientCharges
								, pvp.TotalAllowed AS Allowed

							FROM     PatientVisitProcs AS pvp 
								JOIN PatientVisitProcsAgg AS pvpa 
									ON pvp.PatientVisitProcsId = pvpa.PatientVisitProcsId
								JOIN PatientVisit pv 
									ON pvp.PatientVisitId = pv.PatientVisitId
								LEFT JOIN InsuranceCarriers AS ic 
									ON pv.PrimaryInsuranceCarriersId = ic.InsuranceCarriersId
								JOIN Batch AS b 
									ON pvp.BatchId = b.BatchId

							WHERE	--Filter on date type and range
								(
								(@DateType = 'DOS' AND pvp.DateOfServiceFrom >= ISNULL(@StartDate,'1/1/1900') AND pvp.DateOfServiceFrom < dateadd(d, 1, ISNULL(@EndDate,'1/1/3000'))) OR
								(@DateType = 'DOE' AND pvp.DateOfEntry >= ISNULL(@StartDate,'1/1/1900') AND pvp.DateOfEntry < dateadd(d,1,ISNULL(@EndDate,'1/1/3000')))
								)) AS temp

						INNER JOIN TransactionDistributions AS td 
							ON temp.PatientVisitProcsId = td.PatientVisitProcsId
						INNER JOIN Transactions AS t 
							ON t.TransactionsId = td.TransactionsId
						INNER JOIN VisitTransactions AS vt 
							ON t.VisitTransactionsId = vt.VisitTransactionsId
						INNER JOIN PaymentMethod AS pm 
							ON vt.PaymentMethodId = pm.PaymentMethodId
						INNER JOIN Batch AS b 
							ON b.BatchId = temp.BatchId
						LEFT OUTER JOIN MedLists AS ml
							ON t.ActionTypeMId = ml.MedListsId


					WHERE (pm.DateOfEntry < DATEADD(d, 1, @CurrentClosingDate))
						OR
						((pm.CheckDate < DATEADD(d, 1, @CurrentClosingDate)) AND (pm.DateOfEntry > DATEADD(d, 1, @CurrentClosingDate)))
						OR
						(pm.DateOfEntry BETWEEN @CurrentClosingDate AND DATEADD(d, 1, @CutOffDate))

					GROUP BY temp.PatientVisitProcsId
							, pm.CheckCardNumber
							, pm.CheckDate
							, pm.PayerType
							, pm.Source
							, pm.DateOfEntry) AS tf 
			ON tmp.PatientVisitProcsId = tf.PatientVisitProcsId
		JOIN PatientVisitProcs AS pvp 
			ON tmp.PatientVisitProcsId = pvp.PatientVisitProcsId
		JOIN PatientVisit AS pv 
			ON pvp.PatientVisitId = pv.PatientVisitId
		LEFT JOIN InsuranceCarriers AS ic 
			ON pv.PrimaryInsuranceCarriersId = ic.InsuranceCarriersId
		JOIN DoctorFacility AS f
			ON pv.FacilityId = DoctorFacilityId
		JOIN DoctorFacility AS d
			ON pv.DoctorId = d.DoctorFacilityId
		JOIN PatientProfile AS pp
			ON pv.PatientProfileId = pp.PatientProfileId
		LEFT OUTER JOIN MedLists pt 
			ON ic.PolicyTypeMId = pt.MedListsID
		LEFT JOIN PatientVisitResource pvr 
			ON pv.PatientVisitID = pvr.PatientVisitID
		INNER JOIN ResourceTypeAssignments rta 
			ON pvr.ResourceId = rta.ResourceId
		INNER JOIN MedLists rt 
			ON rta.ResourceTypeId = rt.MedlistsId

	WHERE pvp.DateOfServiceFrom BETWEEN @StartDate AND @EndDate
		AND rta.ResourceTypeId NOT IN (2460, 2461, 2452) -- Exludes resource subtypes (Prenatal Provider, etc.)
	GROUP BY tmp.PatientVisitId
		, tmp.PatientVisitProcsId
		, pvp.CPTCode	
	)
	



/********This ends the part added by Esperanza********/



SELECT 
	pv.TicketNumber
	, CAST(pvp.DateOfServiceFrom AS DATE) AS DateOfService
	, [Month of Service] = SUBSTRING(CONVERT(VARCHAR, pvp.DateOfServiceFrom, 120), 1, 7)
	, d.ListName AS DoctorName
	, ISNULL(r.ResourceName,'None') AS Resource
	, r.DotId As ProviderInitials
	, ISNULL(r.ResourceType,'None') AS ResourceType
	, f.ListName AS FacilityName
	, [Service Type] = (CASE WHEN ISNULL(r.ResourceType,'None') = 'BHC' THEN 'BHC'
			WHEN ISNULL(r.ResourceType,'None') = 'Doctors' THEN 'Medical'
			WHEN ISNULL(r.ResourceType,'None') IN ('Dentists', 'Hygienists') THEN 'Dental'
			ELSE 'Other'
			END)
	, ISNULL(pt.Description,  'Unknown') AS PolicyType 
	, ISNULL(ic.ListName,'Self Pay') AS PrimaryInsuranceCarrier 
	, [Broad Payer Type] =
		(
		CASE 
		WHEN ic.PolicyTypeMId IN (2495, 114348) THEN 'Medicaid/PPS' 
		WHEN ic.PolicyTypeMId IN (2500, 2501) THEN 'Self Pay/Sliding Fee' 
		WHEN ic.PolicyTypeMId IN (2497, 114349, 146) THEN 'Medicare' 
		ELSE 'Private/Other' 
		END
		)
	, [PPS Rate] = (CASE WHEN pvp.DateOfServiceFrom <= @PPSrateDate2015 THEN @PPSrateFY2015
			WHEN pvp.DateOfServiceFrom >= @PPSrateDate2015 AND pvp.DateOfServiceFrom < @PPSrateDate2016 THEN @PPSrateFY2016
			WHEN pvp.DateOfServiceFrom >= @PPSrateDate2016 AND pvp.DateOfServiceFrom < @PPSrateDate2017 THEN @PPSrateFY2017
			WHEN pvp.DateOfServiceFrom >= @PPSrateDate2017 AND pvp.DateOfServiceFrom < @PPSrateDate2018 THEN @PPSrateFY2018
			WHEN pvp.DateOfServiceFrom >= @PPSrateDate2018 THEN NULL END)
	, pvp.CPTCode
	, [Charges] = (pvpa.InsAllocation + pvpa.PatAllocation)
	, Adjustments = (pvpa.InsAdjustment + pvpa.PatAdjustment)
	, [Net Charges] = (pvpa.InsAllocation - pvpa.InsAdjustment) + (pvpa.PatAllocation - pvpa.PatAdjustment)
	, CAST(pv.FirstFiledDate AS DATE) AS FirstFiledDate
	, CAST(pvp.DateOfEntry AS DATE) AS DateofEntry
--	, [Days to Charge Entry] = ISNULL(CONVERT(VARCHAR(25), DATEDIFF(day, pvp.DateOfServiceFrom, pm.DateOfEntry)), 'Charge Not Retrieved') -- I should build in some logic to check which date is actually NULL
	, [Days to Claim Submission] = CAST(ISNULL(CONVERT(VARCHAR(25), DATEDIFF(day, pvp.DateOfServiceFrom, pv.FirstFiledDate)), NULL) AS INT) -- Here too
	, PaymentsToDate = c.Payments
	, CollectableAdjustmentsToDate = c.CollectableAdjustments
	, NonCollectableAdjustmentsToDate = c.NonCollectableAdjustments
	, AdjustmentsDiff = ((pvpa.InsAdjustment + pvpa.PatAdjustment)-(c.CollectableAdjustments + c.NonCollectableAdjustments))
	, AbsAdjustmentsDiff = ABS((pvpa.InsAdjustment + pvpa.PatAdjustment)-(c.CollectableAdjustments + c.NonCollectableAdjustments))
	, ReportDate = CURRENT_TIMESTAMP
	
FROM PatientVisit pv
	LEFT JOIN Resources r ON pv.PatientVisitID = r.PatientVisitId
	LEFT JOIN PatientVisitResource pvr ON r.PatientVisitID = pvr.PatientVisitID
	JOIN PatientVisitProcs pvp ON pv.PatientVisitId = pvp.PatientVisitId
	JOIN PatientVisitProcsAgg pvpa ON pv.PatientVisitId = pvpa.PatientVisitId AND pvp.PatientVisitProcsId = pvpa.PatientVisitProcsId
	JOIN DoctorFacility d ON pv.DoctorId = d.DoctorFacilityId
	JOIN DoctorFacility f ON pv.FacilityId = f.DoctorFacilityId
	INNER JOIN InsuranceCarriers ic ON pv.PrimaryInsuranceCarriersId = ic.InsuranceCarriersId
	LEFT OUTER JOIN MedLists pt ON ic.PolicyTypeMId = pt.MedListsID
	LEFT JOIN Collections c ON pvp.PatientVisitId = c.PatientVisitId AND pvp.PatientVisitProcsId = c.PatientVisitProcsId


WHERE /*(c.CollectableAdjustments + c.NonCollectableAdjustments) - (pvpa.InsAdjustment + pvpa.PatAdjustment) != 0 AND*/
	--Filter on facility
	(
	(NULL IS NOT NULL AND pv.FacilityID IN (NULL)) OR
	(NULL IS NULL)
	)
	AND  --Filter on insurance carrier
	(
	(NULL IS NOT NULL AND ic.InsuranceCarriersId IN (NULL)) OR
	(NULL IS NULL)
	)
	AND
	(
	((@DateType = 'DOE') AND (pvp.DateOfEntry >= ISNULL(@StartDate,'1/1/1900'))
		AND (pvp.DateOfEntry < dateadd(day, 1, ISNULL(@EndDate,'1/1/3000'))))
		OR
	  ((@DateType = 'DOS') AND(pvp.DateOfServiceFrom  >= ISNULL(@StartDate,'1/1/1900'))
		AND (pvp.DateOfServiceFrom < dateadd(day, 1, ISNULL(@EndDate,'1/1/3000'))))
	)
	--AND
	--(
	--(CASE WHEN ISNULL(r.ResourceType,'None') = 'BHC' THEN 'BHC'
	--	WHEN ISNULL(r.ResourceType,'None') = 'Doctors' THEN 'Medical'
	--	WHEN ISNULL(r.ResourceType,'None') IN ('Dentists', 'Hygienists') THEN 'Dental'
	--	ELSE 'Other'
	--	END) != 'Other'
	--)
	--AND pvp.CPTCode LIKE 'PLB'
	
ORDER BY pvp.DateOfServiceFrom
		, pv.PatientVisitId
	
END