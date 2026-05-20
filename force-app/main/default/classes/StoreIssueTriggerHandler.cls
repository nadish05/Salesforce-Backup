public with sharing class StoreIssueTriggerHandler {

	public static void handleAfterInsert(List<StoreIssue__c> newIssues) {
		if (newIssues == null || newIssues.isEmpty()) {
			return;
		}
		List<StoreIssue__c> toEscalate = new List<StoreIssue__c>();
		for (StoreIssue__c si : newIssues) {
			if (si.Severity__c == 'High' || si.Severity__c == 'Critical') {
				toEscalate.add(si);
			}
		}
		if (toEscalate.isEmpty()) {
			return;
		}

		if (!Schema.SObjectType.Case.isCreateable()) {
			return; // respect CRUD; skip creation if not permitted
		}

		Group maintenanceQueue;
		try {
			maintenanceQueue = [
				SELECT Id FROM Group
				WHERE Type = 'Queue' AND DeveloperName = 'Maintenance_Team'
				LIMIT 1
			];
		} catch (Exception e) {
			maintenanceQueue = null;
		}

		List<Case> casesToCreate = new List<Case>();
		for (StoreIssue__c si2 : toEscalate) {
			Case c = new Case();
			c.Subject = 'Store Issue Escalation: ' + si2.Name;
			c.Origin = 'Internal';
			c.Status = 'New';
			c.Description = (si2.Description__c == null ? '' : si2.Description__c) + '\n\nIssue Id: ' + si2.Id;
			c.AccountId = si2.Store__c;
			if (maintenanceQueue != null) {
				c.OwnerId = maintenanceQueue.Id;
			}
			if (si2.Severity__c == 'Critical' || si2.Severity__c == 'High') {
				c.Priority = 'High';
			} else if (si2.Severity__c == 'Medium') {
				c.Priority = 'Medium';
			} else {
				c.Priority = 'Low';
			}
			casesToCreate.add(c);
		}
		if (!casesToCreate.isEmpty()) {
			SObjectAccessDecision access = Security.stripInaccessible(AccessType.CREATABLE, casesToCreate);
			List<Case> sanitized = (List<Case>)access.getRecords();
			insert sanitized;
		}
	}
}