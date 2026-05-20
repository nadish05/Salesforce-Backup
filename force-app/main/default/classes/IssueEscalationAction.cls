public with sharing class IssueEscalationAction {

    public class IssueInput {
        @InvocableVariable(required=true) public Id issueId;
    }

    @InvocableMethod(label='Escalate Store Issue' description='Creates a Case for the provided StoreIssue__c record and assigns it to the Maintenance Team queue.')
    public static void escalate(List<IssueInput> inputs) {
        if (inputs == null || inputs.isEmpty()) {
            return;
        }
        Set<Id> issueIds = new Set<Id>();
        for (IssueInput i : inputs) {
            if (i != null && i.issueId != null) {
                issueIds.add(i.issueId);
            }
        }
        if (issueIds.isEmpty()) {
            return;
        }

        // CRUD/FLS checks
        if (!Schema.SObjectType.StoreIssue__c.isAccessible()) {
            throw new AuraHandledException('Insufficient access to StoreIssue__c');
        }
        if (!Schema.SObjectType.Group.isAccessible()) {
            throw new AuraHandledException('Insufficient access to Group');
        }
        if (!Schema.SObjectType.Case.isCreateable()) {
            throw new AuraHandledException('Insufficient access to create Case');
        }

        Map<Id, StoreIssue__c> issues = new Map<Id, StoreIssue__c>([
            SELECT Id, Name, Description__c, Severity__c, Store__c
            FROM StoreIssue__c WHERE Id IN :issueIds
            WITH SECURITY_ENFORCED
        ]);

        // Locate Maintenance Team queue by DeveloperName
        Group queue = [
            SELECT Id, Name, DeveloperName FROM Group
            WHERE Type = 'Queue' AND DeveloperName = 'Maintenance_Team'
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];

        List<Case> cases = new List<Case>();
        for (StoreIssue__c si : issues.values()) {
            Case c = new Case();
            c.Subject = 'Store Issue Escalation: ' + si.Name;
            c.Origin = 'Internal';
            c.Status = 'New';
            c.Description = si.Description__c;
            c.AccountId = si.Store__c;
            c.OwnerId = queue.Id;
            // Map severity to priority
            if (si.Severity__c == 'Critical') {
                c.Priority = 'High';
            } else if (si.Severity__c == 'High') {
                c.Priority = 'High';
            } else if (si.Severity__c == 'Medium') {
                c.Priority = 'Medium';
            } else {
                c.Priority = 'Low';
            }
            cases.add(c);
        }
        if (!cases.isEmpty()) {
            // Enforce FLS on Case prior to insert
            SObjectAccessDecision access = Security.stripInaccessible(
                AccessType.CREATABLE,
                cases
            );
            List<Case> sanitized = (List<Case>)access.getRecords();
            insert sanitized;
        }
    }
}