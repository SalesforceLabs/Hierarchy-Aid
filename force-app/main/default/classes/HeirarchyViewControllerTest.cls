@IsTest
public inherited sharing class HeirarchyViewControllerTest {
    static Account accParent = new Account();
    static Account accChild = new Account();

    @TestSetup
    static void makeData(){
        //Account accParent = new Account();
        accParent.Name = 'accParent';
        accParent.Industry = 'Apparel';
        accParent.Phone = '3332227555';
        insert accParent;

        //Account accChild = new Account();
        accChild.Name = 'accChild';
        accChild.Industry = 'Banking';
        accChild.Phone = '3362228000';
        accChild.ParentId = accParent.Id;
        insert accChild;

    }

    
    @IsTest static void getHeirarchyDataTest(){
        
        makeData();
        Test.startTest();
            HeirarchyViewController.HeirarchyWrapper heirarchyWrapTest = new HeirarchyViewController.HeirarchyWrapper();
            heirarchyWrapTest = HeirarchyViewController.getHeirarchyData('Account', 'Name,Industry,OwnerId,Phone,createdDate,AnnualRevenue,Website', 'ParentId', '', accChild.Id);
            System.assertEquals(2, heirarchyWrapTest.sObjectList.size(),'The sObject list is not returning 2 records.');
        Test.stopTest();
        
    }
    
}