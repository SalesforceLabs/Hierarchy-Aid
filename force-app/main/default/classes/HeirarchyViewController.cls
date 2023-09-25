public with sharing class HeirarchyViewController {

    public static List<String> referenceFields = new List<String>();

    @AuraEnabled(cacheable=true)
    public static HeirarchyWrapper getHeirarchyData(String objApiName, String objFieldNames, String objRelationshipField, String whereCondition, String recordId){
        
        HeirarchyWrapper heirarchyWrap = new HeirarchyWrapper();  
        try {

            objRelationshipField = objRelationshipField.trim();
            List<SObject> objList = new List<SObject>();
            List<GridColumnWrapper> gridColumnList = new List<GridColumnWrapper>();
            List<String> objFieldSet = objFieldNames.deleteWhitespace().split(',');
            List<String> accessibilityFieldSet = objFieldNames.deleteWhitespace().split(',');

            SObjectType sObjType = ((SObject) Type.forName(objApiName.trim()).newInstance()).getSObjectType();
            Map<String, Schema.SobjectField> fieldMap = sObjType.getDescribe().fields.getMap();
            
            //Accessibility check for object
            if (!sObjType.getDescribe().isAccessible()) {
                throw new AuraHandledException('This object is not accessible to you - ' + objApiName.trim());
            }

            //Accessibility check for relationship field
            Schema.DescribeFieldResult describeRelationshipField = fieldMap.get(objRelationshipField).getDescribe();
            if (!describeRelationshipField.isAccessible()) {
                throw new AuraHandledException('This field is not accessible to you - ' + objRelationshipField);
            }

            for (String fieldApi : objFieldSet) {
                GridColumnWrapper gridColumn = new GridColumnWrapper();

                Schema.DescribeFieldResult describeField = fieldMap.get(fieldApi).getDescribe();
                //Accessibility check for fields
                if (!describeField.isAccessible()) {
                    //throw new AuraHandledException('This field is not accessible to you - ' + fieldApi);
                    accessibilityFieldSet.remove(accessibilityFieldSet.indexOf(fieldApi));
                    continue;
                }
                
                gridColumn.type = getColumnType(String.valueOf(describeField.getType()));
                gridColumn.fieldName = describeField.getName();
                gridColumn.label = describeField.getLabel();
                if (describeField.getName().equalsIgnoreCase('Name') || describeField.getName().endsWithIgnoreCase('Number')) {
                    gridColumn.fieldName = 'Id';
                    gridColumn.type = 'url';
                }
                if(String.valueOf(describeField.getType()) != 'URL') {
                    //gridColumn.typeAttributes = getColumnAttribute(gridColumn.type, fieldApi);
                    gridColumn.typeAttributes = getColumnAttribute(String.valueOf(describeField.getType()), fieldApi);
                }

                gridColumnList.add(gridColumn);
            }
            GridColumnWrapper gridColumn = new GridColumnWrapper();
            gridColumn.type = 'button-icon';
            gridColumn.initialWidth = 20;
            gridColumn.typeAttributes = getColumnAttribute(gridColumn.type, 'utility:edit');
            gridColumnList.add(gridColumn);

            Set<Id> heirarchyIdSet = new Set<Id>();
            if (String.isNotBlank(recordId)) {
                heirarchyIdSet = getsObjectIdSet (recordId.trim(), objApiName.trim(), objRelationshipField);
            }

            String query = 'SELECT Id, ' + string.escapeSingleQuotes(String.join(accessibilityFieldSet,','));
            //checking for duplicate self lookup field
            query = query.containsIgnoreCase(string.escapeSingleQuotes(objRelationshipField)) ? query : query + ',' + string.escapeSingleQuotes(objRelationshipField);

            if (!referenceFields.isEmpty()) {
                query += ',' + String.join(referenceFields,',');    
            }
            
            query += ' FROM ' + string.escapeSingleQuotes(objApiName.trim());
            if (String.isNotBlank(whereCondition)) {
                query += ' WHERE ' + whereCondition;
            }
            if (heirarchyIdSet != null && !heirarchyIdSet.isEmpty()) {
                if (query.containsIgnoreCase('WHERE')) {
                    query += ' AND Id IN: heirarchyIdSet';
                } else {
                    query += ' WHERE Id IN: heirarchyIdSet';
                }
            }
            query += ' ORDER BY ' + objRelationshipField + ' DESC';
            System.debug('query------ ' + query);
            objList = Database.query(query);

            if (!gridColumnList.isEmpty()) {
                heirarchyWrap.colList = gridColumnList;
            }
            if (objList != null) {
                heirarchyWrap.sObjectList = objList;
            }
            
        } catch (Exception e) {
            system.debug(e.getLineNumber());
            throw new AuraHandledException(e.getMessage());
        }
        return heirarchyWrap;
    }

    /*
    *     @author        Kavita Kanthaliya
    *     @description   This method will return the appropriate type for the columns
    *     @param         String
    *     @return        String
    */
    private static String getColumnType(String sObjectFieldType) {
        switch on sObjectFieldType {
            when 'REFERENCE' {
                return 'url';
            }
            when 'PHONE' {
                return 'phone';
            }
            when 'CURRENCY' {
                return 'currency';
            }
            when 'DATETIME' {
                return 'date';
            }
            when 'TIME' {
                return 'date';
            }
            when 'URL' {
                return 'url';
            }
            when 'PERCENT' {
                return 'percent';
            }
            when else {
                return 'text';
            }
        }
    }

    /*
    *     @author        Kavita Kanthaliya
    *     @description   This method will return the list of the parent Ids name field 
    *     @param         String
    *     @return        String
    */
    private static List<String> getParentHeirarchyFields(String objRelationshipField) {
        List<String> parentQueryFieldList = new List<String>();
        String refBase = objRelationshipField;
        if (refBase.endsWithIgnoreCase('id')) {
            refBase = refBase.substring(0, refBase.length()-2); 
        } else if (refBase.endsWithIgnoreCase('__c')) {
            refBase = refBase.replace('__c', '__r');
        }   
        String parentRelationship = refBase;
        for (Integer i = 1; i <= 5 ; i++) {
            if (i>1) {
                parentRelationship += '.' + refBase;
            }
            parentQueryFieldList.add(parentRelationship + '.' + objRelationshipField);
        }
        return parentQueryFieldList;
    }

    /*
    *     @author        Kavita Kanthaliya
    *     @description   This method will return the appropriate attributes if present for the columns
    *     @param         String, String
    *     @return        TypeAttributes
    */
    private static TypeAttributes getColumnAttribute(String columnType, String fieldApi) {
        TypeAttributes typeAttribute = new TypeAttributes();
        if (fieldApi.equalsIgnoreCase('Name')||fieldApi.endsWithIgnoreCase('Number')) {
            Label labelObj = new Label(); 
            labelObj.fieldName = fieldApi;
            typeAttribute.label = labelObj;
            typeAttribute.target = '_blank';
            return typeAttribute;
        }
        switch on columnType {
            //when 'url' {
            when 'REFERENCE' {
                Label labelObj = new Label(); 
                if (fieldApi.endsWithIgnoreCase('id')) {
                    fieldApi = fieldApi.substring(0, fieldApi.length()-2); 
                    fieldApi += '.Name';
                } else if (fieldApi.endsWithIgnoreCase('__c')) {
                    fieldApi = fieldApi.replace('__c', '__r');
                    fieldApi += '.Name';
                }
                labelObj.fieldName = fieldApi;
                referenceFields.add(fieldApi);
                typeAttribute.label = labelObj;
                typeAttribute.target = '_blank';
                return typeAttribute;
            }
            when 'TIME' {
                typeAttribute.hour = '2-digit';
                typeAttribute.minute = '2-digit';
                typeAttribute.second = '2-digit';
                //typeAttribute.timeZoneName = 'short';
                return typeAttribute;
            }
            when 'DATETIME' {
                typeAttribute.year = 'numeric';
                typeAttribute.month = 'numeric';
                typeAttribute.day = 'numeric';
                typeAttribute.hour = '2-digit';
                typeAttribute.minute = '2-digit';
                typeAttribute.second = '2-digit';
                //typeAttribute.timeZoneName = 'short';
                return typeAttribute;
            }
            when 'button-icon' {
                typeAttribute.iconName = fieldApi;
                typeAttribute.variant = 'bare';
                return typeAttribute;
            }
            when else {
                return null;    
            }
        }
    }

    /*
    *     @author        Kavita Kanthaliya
    *     @description   This method will return the list of parent Ids for query
    *     @param         String, String, String
    *     @return        set<Id>
    */
    private static set<Id> getsObjectIdSet (String recordId, String objApiName, String objRelationshipField) {
        Set<Id> setId = new set<Id>();

        String query = 'SELECT Id, ' + string.escapeSingleQuotes(objRelationshipField);
        List<String> parentQueryFieldList = getParentHeirarchyFields(objRelationshipField);
        if (parentQueryFieldList != null && !parentQueryFieldList.isEmpty()) {
            query += ',' + String.join(parentQueryFieldList,',');
        }
        query += ' FROM ' + string.escapeSingleQuotes(objApiName) + ' WHERE Id=: RecordId OR ' + string.escapeSingleQuotes(objRelationshipField) + '=: RecordId ';
        for (String parentQueryField: parentQueryFieldList) {
            query += ' OR ' + parentQueryField + '=: RecordId ';
        }

        List<sObject> sObjectList = Database.query(query);
        
        for (sObject sObj: sObjectList) {
            setId.add(sObj.Id);
            setId.add(String.valueOf(sObj.get(objRelationshipField)));

            String parentBase = parentQueryFieldList[0].split('\\.')[0];

            if (!setId.contains(null) && sObj.getSObject(parentBase)!= null) {
                setId.add(String.valueOf(sObj.getSObject(parentBase).get(objRelationshipField)));    
            }
            if (!setId.contains(null) && sObj.getSObject(parentBase).getSObject(parentBase) != null) {
                setId.add(String.valueOf(sObj.getSObject(parentBase).getSObject(parentBase).get(objRelationshipField)));
            }
            if (!setId.contains(null) && sObj.getSObject(parentBase).getSObject(parentBase).getSObject(parentBase) != null) {
                setId.add(String.valueOf(sObj.getSObject(parentBase).getSObject(parentBase).getSObject(parentBase).get(objRelationshipField)));
            }
            if (!setId.contains(null) && sObj.getSObject(parentBase).getSObject(parentBase).getSObject(parentBase).getSObject(parentBase) != null) {
                setId.add(String.valueOf(sObj.getSObject(parentBase).getSObject(parentBase).getSObject(parentBase).getSObject(parentBase).get(objRelationshipField)));
            }
            if (!setId.contains(null) && sObj.getSObject(parentBase).getSObject(parentBase).getSObject(parentBase).getSObject(parentBase).getSObject(parentBase) != null) {
                setId.add(String.valueOf(sObj.getSObject(parentBase).getSObject(parentBase).getSObject(parentBase).getSObject(parentBase).getSObject(parentBase).get(objRelationshipField)));     
            }    
        }
        setId.remove(null);
        return setId;

    }

    public class HeirarchyWrapper {
        @AuraEnabled
        public Map<Id,SObject> sObjectListMap;
        @AuraEnabled
        public List<SObject> sObjectList;
        @AuraEnabled
        public List<GridColumnWrapper> colList;
    }

    public class GridColumnWrapper {
        @AuraEnabled
        public String type;
        @AuraEnabled
        public String label;
        @AuraEnabled
        public String fieldName;
        @AuraEnabled
        public Integer initialWidth;
        @AuraEnabled
        public TypeAttributes typeAttributes;
    }

    public class Label {
        @AuraEnabled
        public String fieldName;
    }

    public class TypeAttributes {
        @AuraEnabled
        public Label label;
        @AuraEnabled
        public String target;
        @AuraEnabled
        public Label currencyCode;
        @AuraEnabled
        public String name;
        @AuraEnabled
        public String iconName;
        @AuraEnabled
        public String variant;
        @AuraEnabled
        public String title;
        @AuraEnabled
        public String column;
        @AuraEnabled
        public String sObjectName;
        @AuraEnabled
        public String fieldApiName;
        @AuraEnabled
        public String year;
        @AuraEnabled
        public String month;
        @AuraEnabled
        public String day;
        @AuraEnabled
        public String second;
        @AuraEnabled
        public String minute;
        @AuraEnabled
        public String hour;
        @AuraEnabled
        public String timeZoneName;
        @AuraEnabled
        public String currencyDisplayAs;
    }
        
}