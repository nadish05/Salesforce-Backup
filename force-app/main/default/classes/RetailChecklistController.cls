public with sharing class RetailChecklistController {

    public class TaskDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public String taskLabel;
        @AuraEnabled public String status;
        @AuraEnabled public String notes;
        @AuraEnabled public Integer sortOrder;
        @AuraEnabled public Id checklistId;
    }

    public class ChecklistDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public Id storeId;
        @AuraEnabled public String checklistType;
        @AuraEnabled public Date shiftDate;
        @AuraEnabled public String status;
        @AuraEnabled public List<TaskDTO> tasks;
    }

    private static final Map<String, List<String>> DEFAULT_TASKS_BY_TYPE = new Map<String, List<String>>{
        'Opening' => new List<String>{
            'Unlock and secure doors',
            'Power on POS systems',
            'Cash drawer verification',
            'Floor walkthrough for safety'
        },
        'Closing' => new List<String>{
            'Cash reconciliation',
            'Secure inventory',
            'Clean and sanitize counters',
            'Lock doors and set alarm'
        },
        'Merchandising' => new List<String>{
            'Update promotional signage',
            'Front and face shelves',
            'Restock top sellers',
            'Price label audit'
        },
        'Cleanliness' => new List<String>{
            'Sweep and mop floors',
            'Dust shelves and fixtures',
            'Empty trash and recycling',
            'Clean restrooms'
        }
    };

    @AuraEnabled(cacheable=true)
    public static ChecklistDTO initChecklist(Id storeId, Date shiftDate, String checklistType) {
        if (storeId == null || shiftDate == null || String.isBlank(checklistType)) {
            throw new AuraHandledException('storeId, shiftDate and checklistType are required');
        }

        List<StoreOperationChecklist__c> existing = [
            SELECT Id, Name, Store__c, ChecklistType__c, ShiftDate__c, Status__c
            FROM StoreOperationChecklist__c
            WHERE Store__c = :storeId AND ShiftDate__c = :shiftDate AND ChecklistType__c = :checklistType
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];

        StoreOperationChecklist__c checklist;
        if (!existing.isEmpty()) {
            checklist = existing[0];
        } else {
            if (!Schema.SObjectType.StoreOperationChecklist__c.isCreateable()) {
                throw new AuraHandledException('Insufficient access to create StoreOperationChecklist');
            }
            StoreOperationChecklist__c checklistToCreate = new StoreOperationChecklist__c(
                Store__c = storeId,
                ChecklistType__c = checklistType,
                ShiftDate__c = shiftDate,
                Status__c = 'In Progress'
            );
            SObjectAccessDecision checklistAccess = Security.stripInaccessible(AccessType.CREATABLE, new List<StoreOperationChecklist__c>{ checklistToCreate });
            List<StoreOperationChecklist__c> sanitizedChecklist = (List<StoreOperationChecklist__c>)checklistAccess.getRecords();
            if (!Schema.SObjectType.StoreOperationChecklist__c.isCreateable()) {
                throw new AuraHandledException('Insufficient access to create StoreOperationChecklist');
            }
            insert sanitizedChecklist;
            checklist = sanitizedChecklist[0];
            // Seed default tasks for this checklist type
            List<String> seeds = DEFAULT_TASKS_BY_TYPE.get(checklistType);
            if (seeds != null && !seeds.isEmpty()) {
                if (!Schema.SObjectType.ChecklistTask__c.isCreateable()) {
                    throw new AuraHandledException('Insufficient access to create ChecklistTask');
                }
                List<ChecklistTask__c> tasksToInsert = new List<ChecklistTask__c>();
                Integer orderCounter = 1;
                for (String label : seeds) {
                    tasksToInsert.add(new ChecklistTask__c(
                        Checklist__c = checklist.Id,
                        TaskLabel__c = label,
                        Status__c = 'Pending',
                        SortOrder__c = orderCounter
                    ));
                    orderCounter++;
                }
                SObjectAccessDecision taskCreateAccess = Security.stripInaccessible(AccessType.CREATABLE, tasksToInsert);
                insert (List<ChecklistTask__c>)taskCreateAccess.getRecords();
            }
        }

        return buildChecklistDTO(checklist.Id);
    }

    @AuraEnabled
    public static List<ChecklistTask__c> saveTasks(List<ChecklistTask__c> tasks) {
        if (tasks == null || tasks.isEmpty()) {
            return new List<ChecklistTask__c>();
        }
        List<ChecklistTask__c> toCreate = new List<ChecklistTask__c>();
        List<ChecklistTask__c> toUpdate = new List<ChecklistTask__c>();
        for (ChecklistTask__c t : tasks) {
            if (t.Id == null) {
                toCreate.add(t);
            } else {
                toUpdate.add(t);
            }
        }
        if (!toCreate.isEmpty()) {
            if (!Schema.SObjectType.ChecklistTask__c.isCreateable()) {
                throw new AuraHandledException('Insufficient access to create ChecklistTask');
            }
            SObjectAccessDecision createAccess = Security.stripInaccessible(AccessType.CREATABLE, toCreate);
            insert (List<ChecklistTask__c>)createAccess.getRecords();
        }
        if (!toUpdate.isEmpty()) {
            if (!Schema.SObjectType.ChecklistTask__c.isUpdateable()) {
                throw new AuraHandledException('Insufficient access to update ChecklistTask');
            }
            SObjectAccessDecision updateAccess = Security.stripInaccessible(AccessType.UPDATABLE, toUpdate);
            update (List<ChecklistTask__c>)updateAccess.getRecords();
        }
        Set<Id> ids = new Set<Id>();
        for (ChecklistTask__c t2 : toCreate) {
            ids.add(t2.Id);
        }
        for (ChecklistTask__c t3 : toUpdate) {
            ids.add(t3.Id);
        }
        return [
            SELECT Id, TaskLabel__c, Status__c, Notes__c, SortOrder__c, Checklist__c
            FROM ChecklistTask__c WHERE Id IN :ids WITH SECURITY_ENFORCED
        ];
    }

    @AuraEnabled
    public static StoreOperationChecklist__c submitChecklist(Id checklistId) {
        if (checklistId == null) {
            throw new AuraHandledException('checklistId is required');
        }
        StoreOperationChecklist__c c = [SELECT Id, Status__c FROM StoreOperationChecklist__c WHERE Id = :checklistId WITH SECURITY_ENFORCED LIMIT 1];
        c.Status__c = 'Submitted';
        if (!Schema.SObjectType.StoreOperationChecklist__c.isUpdateable()) {
            throw new AuraHandledException('Insufficient access to update StoreOperationChecklist');
        }
        SObjectAccessDecision checklistUpdateAccess = Security.stripInaccessible(AccessType.UPDATABLE, new List<StoreOperationChecklist__c>{ c });
        update (List<StoreOperationChecklist__c>)checklistUpdateAccess.getRecords();
        return c;
    }

    @AuraEnabled
    @SuppressWarnings('PMD.ExcessiveParameterList')
    public static Id createIssue(Id checklistId, Id taskId, Id storeId, String severity, String description, String base64Data, String fileName, String contentType) {
        if (String.isBlank(severity)) {
            throw new AuraHandledException('Severity is required');
        }
        if (!Schema.SObjectType.StoreIssue__c.isCreateable()) {
            throw new AuraHandledException('Insufficient access to create StoreIssue');
        }
        StoreIssue__c issue = new StoreIssue__c(
            Checklist__c = checklistId,
            Task__c = taskId,
            Store__c = storeId,
            Severity__c = severity,
            Status__c = 'New',
            Description__c = description,
            ReportedBy__c = UserInfo.getUserId(),
            ReportedDate__c = System.now()
        );
        SObjectAccessDecision issueCreateAccess = Security.stripInaccessible(AccessType.CREATABLE, new List<StoreIssue__c>{ issue });
        List<StoreIssue__c> sanitizedIssue = (List<StoreIssue__c>)issueCreateAccess.getRecords();
        if (!Schema.SObjectType.StoreIssue__c.isCreateable()) {
            throw new AuraHandledException('Insufficient access to create StoreIssue');
        }
        insert sanitizedIssue;
        issue = sanitizedIssue[0];

        if (!String.isBlank(base64Data) && !String.isBlank(fileName)) {
            createContentForIssue(issue.Id, base64Data, fileName, contentType);
        }
        return issue.Id;
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Integer> getDashboardKpis(Date startDate, Date endDate) {
        Map<String, Integer> result = new Map<String, Integer>();
        // Checklist counts
        AggregateResult[] checklistAgg = [
            SELECT Status__c status, COUNT(Id) cnt
            FROM StoreOperationChecklist__c
            WHERE ShiftDate__c >= :startDate AND ShiftDate__c <= :endDate
            WITH SECURITY_ENFORCED
            GROUP BY Status__c
        ];
        Integer submitted = 0;
        Integer inProgress = 0;
        for (AggregateResult ar : checklistAgg) {
            String st = (String)ar.get('status');
            Integer cnt = (Integer)ar.get('cnt');
            if (st == 'Submitted') {
                submitted += cnt;
            } else {
                inProgress += cnt;
            }
        }
        result.put('submittedChecklists', submitted);
        result.put('pendingChecklists', inProgress);

        // Open issues by severity
        AggregateResult[] issueAgg = [
            SELECT Severity__c sev, COUNT(Id) cnt
            FROM StoreIssue__c
            WHERE Status__c != 'Closed' AND ReportedDate__c >= :DateTime.newInstance(startDate, Time.newInstance(0,0,0,0)) AND ReportedDate__c <= :DateTime.newInstance(endDate, Time.newInstance(23,59,59,999))
            WITH SECURITY_ENFORCED
            GROUP BY Severity__c
        ];
        for (AggregateResult ar2 : issueAgg) {
            result.put('issues_' + (String)ar2.get('sev'), (Integer)ar2.get('cnt'));
        }
        return result;
    }

    @AuraEnabled(cacheable=true)
    public static List<StoreIssue__c> getOpenIssues(Date startDate, Date endDate, Integer limitSize) {
        Integer size = limitSize == null ? 50 : limitSize;
        return [
            SELECT Id, Name, Severity__c, Status__c, Description__c, Store__c, Checklist__c, Task__c, ReportedDate__c
            FROM StoreIssue__c
            WHERE Status__c != 'Closed' AND ReportedDate__c >= :DateTime.newInstance(startDate, Time.newInstance(0,0,0,0)) AND ReportedDate__c <= :DateTime.newInstance(endDate, Time.newInstance(23,59,59,999))
            WITH SECURITY_ENFORCED
            ORDER BY ReportedDate__c DESC
            LIMIT :size
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<Account> searchStores(String searchKey, Integer limitSize) {
        String key = '%' + (searchKey == null ? '' : searchKey) + '%';
        Integer size = limitSize == null ? 10 : Math.min(limitSize, 50);
        return [SELECT Id, Name FROM Account WHERE Name LIKE :key WITH SECURITY_ENFORCED ORDER BY Name LIMIT :size];
    }

    private static ChecklistDTO buildChecklistDTO(Id checklistId) {
        StoreOperationChecklist__c c = [
            SELECT Id, Name, Store__c, ChecklistType__c, ShiftDate__c, Status__c
            FROM StoreOperationChecklist__c WHERE Id = :checklistId WITH SECURITY_ENFORCED LIMIT 1
        ];
        List<ChecklistTask__c> tasks = [
            SELECT Id, TaskLabel__c, Status__c, Notes__c, SortOrder__c, Checklist__c
            FROM ChecklistTask__c WHERE Checklist__c = :checklistId WITH SECURITY_ENFORCED ORDER BY SortOrder__c, CreatedDate
        ];
        ChecklistDTO dto = new ChecklistDTO();
        dto.id = c.Id;
        dto.name = c.Name;
        dto.storeId = c.Store__c;
        dto.checklistType = c.ChecklistType__c;
        dto.shiftDate = c.ShiftDate__c;
        dto.status = c.Status__c;
        dto.tasks = new List<TaskDTO>();
        for (ChecklistTask__c t : tasks) {
            TaskDTO td = new TaskDTO();
            td.id = t.Id;
            td.taskLabel = t.TaskLabel__c;
            td.status = t.Status__c;
            td.notes = t.Notes__c;
            td.sortOrder = (t.SortOrder__c == null) ? null : Integer.valueOf(t.SortOrder__c);
            td.checklistId = t.Checklist__c;
            dto.tasks.add(td);
        }
        return dto;
    }

    @SuppressWarnings('PMD.ExcessiveParameterList')
    private static void createContentForIssue(Id issueId, String base64Data, String fileName, String contentType) {
        // Expect base64Data in format "data:<contentType>;base64,<payload>" or raw base64
        String payload = base64Data;
        Integer commaIdx = base64Data != null ? base64Data.indexOf(',') : -1;
        if (commaIdx > -1) {
            payload = base64Data.substring(commaIdx + 1);
        }
        if (!Schema.SObjectType.ContentVersion.isCreateable()) {
            throw new AuraHandledException('Insufficient access to upload file');
        }
        ContentVersion cv = new ContentVersion();
        cv.Title = fileName;
        cv.PathOnClient = fileName;
        // FileType is not writeable; rely on VersionData and Title
        cv.VersionData = EncodingUtil.base64Decode(payload);
        SObjectAccessDecision fileCreateAccess = Security.stripInaccessible(AccessType.CREATABLE, new List<ContentVersion>{ cv });
        List<ContentVersion> sanitizedCv = (List<ContentVersion>)fileCreateAccess.getRecords();
        if (!Schema.SObjectType.ContentVersion.isCreateable()) {
            throw new AuraHandledException('Insufficient access to upload file');
        }
        insert sanitizedCv;
        cv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :sanitizedCv[0].Id WITH SECURITY_ENFORCED LIMIT 1];
        if (!Schema.SObjectType.ContentDocumentLink.isCreateable()) {
            throw new AuraHandledException('Insufficient access to link file');
        }
        ContentDocumentLink cdl = new ContentDocumentLink(
            LinkedEntityId = issueId,
            ContentDocumentId = cv.ContentDocumentId,
            ShareType = 'V'
        );
        SObjectAccessDecision linkCreateAccess = Security.stripInaccessible(AccessType.CREATABLE, new List<ContentDocumentLink>{ cdl });
        insert (List<ContentDocumentLink>)linkCreateAccess.getRecords();
    }
}