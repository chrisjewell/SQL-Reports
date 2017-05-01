select pv.visit,
	sum(pva.InsPayment)
from PatientVisitAgg as pva
	join PatientProfile as pp
		on pva.PatientProfileId = pp.PatientProfileId
	join PatientVisit as pv
		on pva.PatientVisitId = pv.PatientVisitId
where pp.PatientId = '48798' -- Keystone First Incentive Patient
group by pv.Visit