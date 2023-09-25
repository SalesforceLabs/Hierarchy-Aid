import { LightningElement ,api, wire, track } from 'lwc';
import getHeirarchyData from '@salesforce/apex/HeirarchyViewController.getHeirarchyData';
import { refreshApex } from '@salesforce/apex';

export default class heirarchyView extends LightningElement {
    @api objApiName;
    @api objFieldNames;
    @api objRelationshipField;
    @api whereCondition = '';
    @api recordId = '';
    @api recordEditId;
    @track expandedRowId = [];
    @track selectedRows = [];
    refreshData;
    isError = false;
    openEdit = false;
    sfdcBaseURL;

    // definition of columns for the tree grid
    gridColumns = [];
    editColumns = [];
    // data provided to the tree grid
    gridData = [];

    @track isloaded = false;

    // To get all records from backend
    @wire(getHeirarchyData, {
        objApiName: "$objApiName",
        objFieldNames: "$objFieldNames",
        objRelationshipField: "$objRelationshipField",
        whereCondition: "$whereCondition",
        recordId: "$recordId"
    })
    heirarchyRecords(result) { 
        this.refreshData = result;
        
        if (result.data) {
            this.isError = false;
            
            this.gridColumns = result.data.colList;
            
            let tempColumns = JSON.parse(JSON.stringify(this.gridColumns));
            tempColumns.forEach(element => {
                
                if (element.fieldName === 'Id') {
                    element.fieldName = element.typeAttributes.label.fieldName;
                } 
            });
            this.editColumns = tempColumns;
            this.prepareGridData(result.data.sObjectList, result.data.colList);
            if (this.objRelationshipField === 'jesttest') {
                this.openEdit = true;
            }
            this.selectedRows = [window.location.origin + '/' + this.recordId];
            this.isloaded = true;
        } else if (result.error) {
            this.isError = true;
        }
    }

    /*
    * This method creates the hierarchy structure based on the records queried from the backend.
    */
    prepareGridData (sObjectList, colList) {
        let apiTypeMap = {};
        let idToParentMap = {};
        colList.forEach(col => {
            apiTypeMap[col.fieldName] = col.type;
        });
        if (sObjectList) {
            let actList = JSON.parse(JSON.stringify(sObjectList));
            const idMapping = actList.reduce((acc, el, i) => {
                acc[el.Id] = i;
                return acc;
            }, {});
            
            let root = [];
            
            actList.forEach(el => {
                
                //to get ref key added to main loop
                idToParentMap[el['Id']] = el[this.objRelationshipField];
                
                //end of ref key added to main loop
                // Handle the root element
                if (el[this.objRelationshipField]) {
                    // Use our mapping to locate the parent element in our data array
                    const parentEl = actList[idMapping[el[this.objRelationshipField]]];

                    // Add our current el to its parent's `children` array
                    if (parentEl) {
                        parentEl._children = [...(parentEl._children || []), el];
                    }                         
                } else {
                    root.push(el);
                }
                if (this.recordId != '') {
                    root = [];
                    root.push(el);
                }
                

                var keys = Object.keys(el);
                keys.forEach(key => {
                    if(typeof el[key] === 'object') {
                        let refKey = key + '.Name';
                        el[refKey] = el[key].Name;
                    }
                    if (apiTypeMap[key] === 'url') {
                        el[key] = window.location.origin + '/' + el[key];
                    }
                });
            });

            //to get expanded rows id of parent
            let loopRecordId = this.recordId;
            let expandedRows = [];
            while (idToParentMap[loopRecordId]) {
                expandedRows.push(window.location.origin + '/' + idToParentMap[loopRecordId]); 
                loopRecordId = idToParentMap[loopRecordId];
            }

            this.gridData = root; 
            this.expandedRowId = expandedRows;             
        }
    }

    /*
    * This method associates the record id of the record for which the edit is being performed.
    */
    handleRowAction (event) {
        let recordLink = event.detail.row.Id;
        this.recordEditId = recordLink.substring(recordLink.lastIndexOf("/")+1,recordLink.length);
        this.openEdit = true;
    }

    /*
    * This method refreshes the grid hierarchy after the edit is performed.
    */
    handleSuccess(event){
        this.openEdit = false;
        this.isloaded = false;
        return refreshApex(this.refreshData);
    }

    /*
    * This method resets the value when edit is cancelled.
    */
    handleReset(event) {
        const inputFields = this.template.querySelectorAll(
            '.recordEditFields'
        );
        if (inputFields) {
            inputFields.forEach(field => {
                field.reset();
            });
        }
        this.openEdit = false;
    }
}
