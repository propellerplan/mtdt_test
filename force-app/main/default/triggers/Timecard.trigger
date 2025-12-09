trigger Timecard on Timecard__c (after insert, before insert, after update, before update, after delete, before delete) {
	if (Trigger.isAfter) {
		TimecardService.updateParentCases(Trigger.isDelete ? Trigger.old : Trigger.new, Trigger.oldMap, Trigger.isDelete);
	}
	if (Trigger.isBefore) {
		if (Trigger.isInsert || Trigger.isUpdate) {
			TimecardService.calculateEffortWithCoefficient(Trigger.new, Trigger.oldMap);
		}
	}
}