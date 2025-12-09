/**
 * Created on 19.04.23.
 */

({
    doInit: function(component, event, helper) {
        helper.getOptions(component,'Currency');
        helper.getOptions(component,'Category');
        helper.addCompensation(component);
    },

    addCompensation: function(component, event, helper) {
        helper.addCompensation(component);
    },

    cloneCompensation: function(component, event, helper) {
        var index = event.getSource().get("v.value");
        var compensations = component.get("v.compensations");
        var cloneCompensation = Object.assign({}, compensations[index]);
        compensations.push(cloneCompensation);
        component.set("v.compensations", compensations);
    },

    deleteCompensation: function(component, event, helper) {
        var index = event.getSource().get("v.value");
        var compensations = component.get("v.compensations");
        compensations.splice(index, 1);
        component.set("v.compensations", compensations);
    },

    handleSave: function (component, event, helper){
        var isValid = true;
        var inputsDescription = component.find("inputDescription");
        if(!Array.isArray(inputsDescription)) inputsDescription = [inputsDescription];
        inputsDescription.forEach(function (input) {
            if(!input.reportValidity()) isValid = false;
        });
        var inputsDate = component.find("inputDate");
        if(!Array.isArray(inputsDate)) inputsDate = [inputsDate];
        inputsDate.forEach(function (input) {
            if(!input.reportValidity()) isValid = false;
        });
        var inputsCategory = component.find("inputCategory");
        if(!Array.isArray(inputsCategory)) inputsCategory = [inputsCategory];
        inputsCategory.forEach(function (input) {
            if(!input.reportValidity()) isValid = false;
        });
        var inputsLookup = component.find("inputLookup");
        if(!Array.isArray(inputsLookup)) inputsLookup = [inputsLookup];
        inputsLookup.forEach(function (input) {
            if(input.get("v.value") === undefined || input.get("v.value") === '') {
                input.showError("Complete this field.");
                isValid = false;
            } else {
                input.hideError();
            }
        });
        if(isValid) {
            helper.createCompensations(component, event, helper);
        }
    }
});