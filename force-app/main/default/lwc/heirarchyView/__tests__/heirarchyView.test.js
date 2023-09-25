import { createElement } from 'lwc';
import heirarchyView from 'c/heirarchyView';
import { registerLdsTestWireAdapter } from '@salesforce/sfdx-lwc-jest';
import getHeirarchyData from '@salesforce/apex/HeirarchyViewController.getHeirarchyData';

// Mock realistic data
const mockGetRecord = require('./data/testData.json');
  
// Register as an LDS wire adapter
const getRecordAdapter = registerLdsTestWireAdapter(getHeirarchyData);

describe ( 'heirarchyViewTestSuite' , () => {
    afterEach(() => {
        // The jsdom instance is shared across test cases in a single file so reset the DOM
        while(document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
    });

    
    const OBJRELATIONSHIPFIELD = "ParentId";
    const RECORDID =  "0015g0000068HmCAAU";
    it( 'test heirarchyRecord' , () => {
        const element = createElement( 'c-heirarchy-view', {
            is: heirarchyView
        });
        element.objRelationshipField = OBJRELATIONSHIPFIELD;
        element.recordId = RECORDID;
        document.body.appendChild(element);

        // Emit data from @wire
        getRecordAdapter.emit(mockGetRecord);

        return Promise.resolve().then(() => {
            const treeElement = element.shadowRoot.querySelector('lightning-tree-grid');
            expect(treeElement.columns.length).toEqual(5);
            expect(treeElement.data.length).toEqual(1);
            
        });

    });

    const OPENEDIT = true; 
    const RECORDEDITID = "0015g0000068HmCAAU";
    const OBJAPINAME = "Account";
    it( 'test recordEditForm' , () => {
        const element = createElement( 'c-heirarchy-view', {
            is: heirarchyView
        });
        
        element.recordEditId = RECORDEDITID;
        element.objRelationshipField = 'jesttest';
        element.recordId = RECORDID;
        element.objApiName = OBJAPINAME;
        document.body.appendChild(element);
    
        getRecordAdapter.emit(mockGetRecord);
        
        return Promise.resolve().then(() => {
            const editElement = element.shadowRoot.querySelector('lightning-button');
            editElement.click();
            const recordField = element.shadowRoot.querySelector('lightning-input-field');
            expect(recordField.value).toBeUndefined();

            const recordForm = element.shadowRoot.querySelector('lightning-record-edit-form');
            expect(recordForm.objectApiName).toEqual(OBJAPINAME);
            expect(recordForm.recordId).toEqual(RECORDEDITID);
            
        });

    });
});