public without sharing class TimecardService {
	private static final Decimal DEFAULT_TIME_COEFFICIENT = 1.0;

	public static void updateParentCases(List<Timecard__c> timecards, Map<Id, Timecard__c> oldCards, Boolean isDelete) {
		Set<Id> caseIds = new Set<Id>();
		for (Timecard__c timecard : timecards) {
			if(isDelete == true || oldCards == null
					|| timecard.Effort__c != oldCards.get(timecard.Id).Effort__c
					|| timecard.Work_Date__c != oldCards.get(timecard.Id).Work_Date__c) {
				caseIds.add(timecard.Case__c);
			}
		}
		List<AggregateResult> results = new pp_Query('Timecard__c')
				.selectField('Case__c')
				.sum('Effort__c', 'monthEffort')
				.addConditionGe('Work_Date__c', Date.today().toStartOfMonth())
				.addConditionLe('Work_Date__c', Date.today())
				.addConditionIn('Case__c', caseIds)
				.groupBy('Case__c')
				.aggregate();
		Map<Id, Decimal> caseId_time = new Map<Id, Decimal>();
		if(!results.isEmpty()){
			for (AggregateResult result : results) {
				caseId_time.put((Id)result.get('Case__c'), (Decimal)result.get('monthEffort'));
			}
		}
		for (Id caseId : caseIds) {
			if(caseId_time.containsKey(caseId)) continue;
			caseId_time.put(caseId, 0.0);
		}
		CaseService.updateTimeSpentThisMonthOnCases(caseId_time);
	}

	public static void calculateEffortWithCoefficient(List<Timecard__c> timecards, Map<Id, Timecard__c> oldCards) {
		Set<String> caseIds = new Set<String>();
		Set<String> personIds = new Set<String>();
		List<Log__c> logs = new List<Log__c>();
		Map<Id, Timecard__c> timecard2Upd = new Map<Id, Timecard__c>();

		try {
			//1 Figure out who to update 1010101010
			for ( Timecard__c tc : timecards ) {
				Timecard__c oldTc = oldCards != null ? oldCards.get(tc.Id) : null;
				Boolean waitingForUpdate =
						oldTc == null
								|| tc.Effort__c != oldTc.Effort__c
								|| tc.Time_Coefficient__c != oldTc.Time_Coefficient__c
								|| tc.Time_Coefficient__c == null;

				if ( tc.Effort__c != null && tc.Effort__c > 0 && waitingForUpdate ) {
					timecard2Upd.put(tc.Id, tc);
					caseIds.add(tc.Case__c);
					personIds.add(tc.Person__c);
				}

			}
			if ( timecard2Upd.isEmpty() ) return;

			//2. Load all overrides: Junction, Case, Contact
			List<Time_Coefficient__c> junctions = getTimeCoefficientsByCaseMap(caseIds, personIds);
			Map<String, Decimal> junctionMap = new Map<String, Decimal>();
			for ( Time_Coefficient__c j : junctions ) {
				junctionMap.put( j.Case__c + '-' + j.Contact__c, j.Time_Coefficient__c );
			}

			Map<Id, Case> caseMap = getCasesById(caseIds);
			Map<Id, Contact> contactMap = getContactsById(personIds);

			for ( Timecard__c tc : timecard2Upd.values() ) {
				String key = tc.Case__c + '-' + tc.Person__c;
				Decimal coefficient = DEFAULT_TIME_COEFFICIENT;

				//3.1 If user already set a coefficient, keep it
				if ( tc.Time_Coefficient__c != null && tc.Time_Coefficient__c > 0 ) {
					coefficient = tc.Time_Coefficient__c;
				} else {
					//3.2 Apply override junction → case → contact → default, calculate final effort
					coefficient = junctionMap.containsKey(key)
							? junctionMap.get(key)
							: caseMap.containsKey(tc.Case__c)
									? caseMap.get(tc.Case__c).Time_Coefficient__c
									: contactMap.containsKey(tc.Person__c)
											? contactMap.get(tc.Person__c).Default_Time_Coefficient__c
											: DEFAULT_TIME_COEFFICIENT;
				}

				tc.Time_Coefficient__c = coefficient;
				tc.Effort_with_Coefficient__c = tc.Effort__c * coefficient;
			}
		} catch (Exception e) {
			logs.add(new Log__c(
					Request__c = 'Got exception: ' + e.getMessage() + ', ' + e.getStackTraceString(),
					Error__c = 'TimeCard Coefficient exception caught')
			);
		} finally {
			if (!logs.isEmpty()) insert logs;
		}
	}

	public static List<Time_Coefficient__c> getTimeCoefficientsByCaseMap(Set<String> relatedCaseIds, Set<String> relatedPersonIds) {
		List<Time_Coefficient__c> timeCoefficients = new List<Time_Coefficient__c>();
		timeCoefficients = new pp_Query('Time_Coefficient__c')
				.selectFields('Time_Coefficient__c, Case__c, Contact__c')
				.addCondition(
						pp_Query.doAnd(
								pp_Query.conditionIn('Case__c', relatedCaseIds),
								pp_Query.conditionIn('Contact__c', relatedPersonIds),
								pp_Query.conditionNotNull('Time_Coefficient__c')
						)
				)
				.run();

		return timeCoefficients;
	}

	public static Map<Id, Case> getCasesById(Set<String> relatedCaseIds) {
		Map<Id, Case> casesMap = new Map<Id, Case>();
		casesMap = new Map<Id, Case>((List<Case>) new pp_Query('Case')
				.selectFields('Time_Coefficient__c')
				.addCondition(
						pp_Query.doAnd(
								pp_Query.conditionIn('Id', relatedCaseIds),
								pp_Query.conditionNotNull('Time_Coefficient__c')
						)
				)
				.run());

		return casesMap;
	}

	public static Map<Id, Contact> getContactsById(Set<String> relatedPersonIds) {
		Map<Id, Contact> contactsMap = new Map<Id, Contact>();
		contactsMap = new Map<Id, Contact>((List<Contact>) new pp_Query('Contact')
				.selectFields('Default_Time_Coefficient__c')
				.addCondition(
						pp_Query.doAnd(
								pp_Query.conditionIn('Id', relatedPersonIds),
								pp_Query.conditionNotNull('Default_Time_Coefficient__c')
						)
				)
				.run());

		return contactsMap;
	}
}