/**
 * Created on 19.04.23.
 */

({
    addCompensation: function(component) {
        var newCompensation = {
            sobjectType: "Compensation__c",
            Date__c: new Date().toISOString(),
            CurrencyIsoCode: '',
            Category__c: '',
            Total__c: 0.00
        };
        var compensations = component.get("v.compensations");
        compensations.push(newCompensation);
        component.set("v.compensations", compensations);
    },

    getOptions: function (component, type) {
        var action = component.get("c.getPicklistValues");
        action.setParams({
            "objectName": "Compensation__c",
            "fieldName": type === 'Category' ? "Category__c" : "CurrencyIsoCode"
        });
        action.setCallback(this, function(response) {
            var state = response.getState();
            if (state === "SUCCESS") {
                var options = response.getReturnValue();
                var fieldMap = [];
                fieldMap.push({label: 'None', value: ''});
                if(type === 'Currency') {
                    for(var key in options) {
                        fieldMap.push({label: key, value: key});
                    }
                    component.set("v.currencyOptions", fieldMap);
                } else {
                    for (var key in options) {
                        fieldMap.push({label: options[key], value: key});
                    }
                    component.set("v.categoryOptions", fieldMap);
                }
            }
        });
        $A.enqueueAction(action);
    },

    createCompensations: function (component, event, helper) {
        component.utils.callApexPromise(component.get("c.createCompensations"), {
            'compensations' : component.get("v.compensations")
        }).then($A.getCallback(function (response) {
            var params = {
                title : "Success",
                message: "Compensations were created",
                duration: "3000",
                type: "success"
            };
            component.utils.showToast(params);
            var utilityBar = component.find("utilitybar");
            utilityBar.minimizeUtility();
            component.set("v.compensations", []);
            helper.addCompensation(component);
        })).catch($A.getCallback(function (error) {
            component.utils.showError(component, error);
        })).finally(function () {
            component.utils.hideSpinner(component);
        });
    }
});