@IsTest
private class TimecardTest {

    @TestSetup
    public static void setup(){
        Account acc = new Account(Name = 'Propeller Plan', Billing_Country_Code__c = 'PL');
        insert acc;
        Project__c project = new Project__c(Name = 'Test Project', Account__c = acc.Id);
        insert project;
        Case case1 = new Case(Subject = 'Case1', Project__c = project.Id);
        Case case2 = new Case(Subject = 'Case2', Project__c = project.Id);
        Case case3 = new Case(Subject = 'Case3', Project__c = project.Id, Time_Coefficient__c = 1.8);
        Case case4 = new Case(Subject = 'Case4', Project__c = project.Id, Time_Coefficient__c = 2.2);
        insert new List<Case>{case1, case2, case3, case4};
        Id contactRTId = Schema.SObjectType.Contact.getRecordTypeInfosByName().get('Internal').getRecordTypeId();
        Contact contact1 = new Contact(FirstName = 'John', LastName = 'Doe', Default_Time_Coefficient__c = 1.5, AccountId = acc.Id, Email = 'test@pp.test', RecordTypeId = contactRTId, Inactive__c = false);
        Contact contact2 = new Contact(FirstName = 'Jane', LastName = 'Smith', Default_Time_Coefficient__c = 2.0, AccountId = acc.Id, Email = 'test@pp.test', RecordTypeId = contactRTId, Inactive__c = false);
        insert new List<Contact>{contact1, contact2};
        Time_Coefficient__c timeCoefficient1 = new Time_Coefficient__c(Case__c = case3.Id, Contact__c = contact1.Id, Time_Coefficient__c = 2.5);
        insert new List<Time_Coefficient__c>{timeCoefficient1};

    }

    @IsTest
    private static void insertTest(){
        Case case1 = [SELECT Id FROM Case WHERE Subject = 'Case1' LIMIT 1];
        Case case2 = [SELECT Id FROM Case WHERE Subject = 'Case2' LIMIT 1];
        Date lastMonth = Date.today().addMonths(-1);
        Timecard__c card1_lastMonth = new Timecard__c(Case__c = case1.Id, Effort__c = 12, Work_Date__c = lastMonth);
        Timecard__c card1_thisMonth = new Timecard__c(Case__c = case1.Id, Effort__c = 15, Work_Date__c = Date.today());
        Timecard__c card2_lastMonth = new Timecard__c(Case__c = case2.Id, Effort__c = 13, Work_Date__c = lastMonth);
        Timecard__c card2_thisMonth = new Timecard__c(Case__c = case2.Id, Effort__c = 20, Work_Date__c = Date.today());
        Test.startTest();
        insert new List<Timecard__c>{card1_lastMonth, card1_thisMonth, card2_lastMonth, card2_thisMonth};
        Test.stopTest();
        Case case1_after = [SELECT Id, Time_Spent__c, Time_Spent_This_Month__c,
                Project__r.Time_Spent__c, Project__r.Time_Spent_This_Month__c FROM Case WHERE Subject = 'Case1' LIMIT 1];
        Case case2_after = [SELECT Id, Time_Spent__c, Time_Spent_This_Month__c FROM Case WHERE Subject = 'Case2' LIMIT 1];
        System.assertEquals(case1_after.Time_Spent__c, 27);
        System.assertEquals(case2_after.Time_Spent__c, 33);
        System.assertEquals(case1_after.Time_Spent_This_Month__c, 15);
        System.assertEquals(case2_after.Time_Spent_This_Month__c, 20);
        System.assertEquals(case1_after.Project__r.Time_Spent__c, 60);
        System.assertEquals(case1_after.Project__r.Time_Spent_This_Month__c, 35);
    }

    @IsTest
    private static void updateTest(){
        Case case1 = [SELECT Id FROM Case WHERE Subject = 'Case1' LIMIT 1];
        Case case2 = [SELECT Id FROM Case WHERE Subject = 'Case2' LIMIT 1];
        Date lastMonth = Date.today().addMonths(-1);
        Timecard__c card1_lastMonth = new Timecard__c(Case__c = case1.Id, Effort__c = 12, Work_Date__c = lastMonth);
        Timecard__c card1_thisMonth = new Timecard__c(Case__c = case1.Id, Effort__c = 15, Work_Date__c = Date.today());
        Timecard__c card2_lastMonth = new Timecard__c(Case__c = case2.Id, Effort__c = 13, Work_Date__c = lastMonth);
        Timecard__c card2_thisMonth = new Timecard__c(Case__c = case2.Id, Effort__c = 20, Work_Date__c = Date.today());
        insert new List<Timecard__c>{card1_lastMonth, card1_thisMonth, card2_lastMonth, card2_thisMonth};
        Test.startTest();
        card1_thisMonth.Effort__c = 3;
        card2_thisMonth.Work_Date__c = lastMonth;
        update new List<Timecard__c>{card1_thisMonth, card2_thisMonth};
        Test.stopTest();
        Case case1_after = [SELECT Id, Time_Spent__c, Time_Spent_This_Month__c,
                Project__r.Time_Spent__c, Project__r.Time_Spent_This_Month__c FROM Case WHERE Subject = 'Case1' LIMIT 1];
        Case case2_after = [SELECT Id, Time_Spent__c, Time_Spent_This_Month__c FROM Case WHERE Subject = 'Case2' LIMIT 1];
        System.assertEquals(case1_after.Time_Spent__c, 15);
        System.assertEquals(case2_after.Time_Spent__c, 33);
        System.assertEquals(case1_after.Time_Spent_This_Month__c, 3);
        System.assertEquals(case2_after.Time_Spent_This_Month__c, 0);
//        System.assertEquals(case1_after.Project__r.Time_Spent__c, 48);
//        System.assertEquals(case1_after.Project__r.Time_Spent_This_Month__c, 3);
    }

    @IsTest
    private static void deleteTest(){
        Case case1 = [SELECT Id FROM Case WHERE Subject = 'Case1' LIMIT 1];
        Case case2 = [SELECT Id FROM Case WHERE Subject = 'Case2' LIMIT 1];
        Date lastMonth = Date.today().addMonths(-1);
        Timecard__c card1_lastMonth = new Timecard__c(Case__c = case1.Id, Effort__c = 12, Work_Date__c = lastMonth);
        Timecard__c card1_thisMonth = new Timecard__c(Case__c = case1.Id, Effort__c = 15, Work_Date__c = Date.today());
        Timecard__c card2_lastMonth = new Timecard__c(Case__c = case2.Id, Effort__c = 13, Work_Date__c = lastMonth);
        Timecard__c card2_thisMonth = new Timecard__c(Case__c = case2.Id, Effort__c = 20, Work_Date__c = Date.today());
        insert new List<Timecard__c>{card1_lastMonth, card1_thisMonth, card2_lastMonth, card2_thisMonth};
        Test.startTest();
        delete new List<Timecard__c>{card1_lastMonth, card2_thisMonth};
        Test.stopTest();
        Case case1_after = [SELECT Id, Time_Spent__c, Time_Spent_This_Month__c,
                Project__r.Time_Spent__c, Project__r.Time_Spent_This_Month__c FROM Case WHERE Subject = 'Case1' LIMIT 1];
        Case case2_after = [SELECT Id, Time_Spent__c, Time_Spent_This_Month__c FROM Case WHERE Subject = 'Case2' LIMIT 1];
        System.assertEquals(case1_after.Time_Spent__c, 15);
        System.assertEquals(case2_after.Time_Spent__c, 13);
        System.assertEquals(case1_after.Time_Spent_This_Month__c, 15);
        System.assertEquals(case2_after.Time_Spent_This_Month__c, 0);
//        System.assertEquals(case1_after.Project__r.Time_Spent__c, 28);
//        System.assertEquals(case1_after.Project__r.Time_Spent_This_Month__c, 15);
    }

    @IsTest
    static void insertTimecardWithCoefficientTest() {
        Contact contact = [SELECT Id FROM Contact WHERE LastName = 'Doe' LIMIT 1];
        Case caseObj = [SELECT Id FROM Case WHERE Subject = 'Case3' LIMIT 1];

        Timecard__c timecard = new Timecard__c(
                Case__c = caseObj.Id,
                Person__c = contact.Id,
                Effort__c = 10
        );

        Test.startTest();
        insert timecard;
        Test.stopTest();

        Timecard__c insertedTimecard = [SELECT Id, Time_Coefficient__c, Effort_with_Coefficient__c FROM Timecard__c WHERE Id = :timecard.Id];
        // Time_Coefficient__c should be 2.5 from the junction object
        System.assertEquals(2.5, insertedTimecard.Time_Coefficient__c);
        // Effort_with_Coefficient__c should be 25 (10 * 2.5)
        System.assertEquals(25, insertedTimecard.Effort_with_Coefficient__c);
    }

    @IsTest
    static void updateTimecardWithCoefficientTest() {
        Contact contact = [SELECT Id FROM Contact WHERE LastName = 'Doe' LIMIT 1];
        Case caseObj = [SELECT Id FROM Case WHERE Subject = 'Case1' LIMIT 1];

        Timecard__c timecard = new Timecard__c(
                Case__c = caseObj.Id,
                Person__c = contact.Id,
                Effort__c = 10
        );
        insert timecard;

        timecard.Effort__c = 20;
        Test.startTest();
        update timecard;
        Test.stopTest();

        Timecard__c updatedTimecard = [SELECT Id, Time_Coefficient__c, Effort_with_Coefficient__c FROM Timecard__c WHERE Id = :timecard.Id];
        // Time_Coefficient__c should still be 1.5 from the contact
        System.assertEquals(1.5, updatedTimecard.Time_Coefficient__c);
        // Effort_with_Coefficient__c should now be 30 (20 * 1.5)
        System.assertEquals(30, updatedTimecard.Effort_with_Coefficient__c);
    }

    @IsTest
    static void timecardUpdateWithTimeCoefficientChangeTest() {
        Contact contact = [SELECT Id FROM Contact WHERE LastName = 'Smith' LIMIT 1];
        Case caseObj = [SELECT Id FROM Case WHERE Subject = 'Case4' LIMIT 1];

        Timecard__c timecard = new Timecard__c(
                Case__c = caseObj.Id,
                Person__c = contact.Id,
                Effort__c = 15,
                Time_Coefficient__c = 1.0
        );
        insert timecard;

        timecard.Time_Coefficient__c = 3.0;
        Test.startTest();
        update timecard;
        Test.stopTest();

        Timecard__c updatedTimecard = [SELECT Id, Time_Coefficient__c, Effort_with_Coefficient__c FROM Timecard__c WHERE Id = :timecard.Id];
        // Time_Coefficient__c should be updated to 3 from the timecard
        System.assertEquals(3.0, updatedTimecard.Time_Coefficient__c);
        // Effort_with_Coefficient__c should now be 45 (15 * 3.0)
        System.assertEquals(45, updatedTimecard.Effort_with_Coefficient__c);
    }
}