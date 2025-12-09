/**
 * Created on 19/10/2022.
 */

import {LightningElement, wire} from 'lwc';

import searchTasks from '@salesforce/apex/CaseLookupSearch.search';
import getRecentlyViewedTasks from '@salesforce/apex/CaseLookupSearch.getRecentlyViewed';
import getPersonOptions from '@salesforce/apex/TimeTrackerController.getPersonOptions';
import getLogsByTaskAndDate from '@salesforce/apex/TimeTrackerController.getLogsByTaskAndDate';
import upsertLogs from '@salesforce/apex/TimeTrackerController.upsertLogs';
import deleteLogs from '@salesforce/apex/TimeTrackerController.deleteLogs';
import ConfirmationModal from "c/confirmationModal";
import TimelogsEditModal from "c/timelogsEditModal";
import {TimeTrackerServices} from "c/timeTrackerServices";
import {ShowToastEvent} from "lightning/platformShowToastEvent";
import {NavigationMixin} from 'lightning/navigation';

const LOCAL_STORAGE_PERSON_VAR = 'pp__time_tracker_person';

export default class TimeTracker extends NavigationMixin(LightningElement) {
    personOptions = [];
    weekStart = TimeTrackerServices.getMonday(new Date());
    selectedPerson;
    recentlyViewedTasks = [];
    newRecordOptions = [{ value: 'Case', label: 'New Case' }];
    isBusy = true;
    _rows = [];
    _previousDurationTemp;
    _tzoffset = (new Date()).getTimezoneOffset() * 60000;

    @wire(getRecentlyViewedTasks)
    getRecentlyViewedTasks({ data }) {
        if (data) {
            this.recentlyViewedTasks = data;
            this.initTaskLookupDefaultResults();
        }
    }

    get rows() {
        return this._rows;
    }
    get weekDays() {
        let days = [];
        for (let i = 0; i < 7; i++) {
            const day = TimeTrackerServices.addDays(this.weekStart, i);
            let duration = this._rows.reduce((s, r) => ( s + (r.logsByDay[i].duration ? r.logsByDay[i].duration : 0) ), 0);
            days.push({
                id              : i + 1,
                date            : day,
                dateISO         : (new Date(day - this._tzoffset)).toISOString(),
                formatted       : day.toLocaleDateString("en-US", { weekday: 'short', month: 'short', day: 'numeric' }),
                duration        : duration,
                durationHours   : TimeTrackerServices.formatDuration(duration),
                styleClass      : duration > 8 ? 'day-completion_full' : (duration > 0 ? 'day-completion_partial' : ''),
            });
        }
        return days;
    }
    get weekTotalDurationHours() {
        const totalDuration = this._rows.reduce((s, r) => ( s + r.total ), 0);
        return TimeTrackerServices.formatDuration(totalDuration);
    }
    get weekTotalClass() {
        const totalDuration = this._rows.reduce((s, r) => ( s + r.total ), 0);
        return totalDuration > 40 ? 'day-completion_full' : (totalDuration > 0 ? 'day-completion_partial' : '');
    }

    connectedCallback() {
        this.initTaskLookupDefaultResults();

        getPersonOptions({ filters: "Inactive__c = FALSE AND Account.Name = 'Propeller Plan'" })
            .then(result => {
                this.personOptions = result || [];

                let selectedPerson;
                if (localStorage.getItem(LOCAL_STORAGE_PERSON_VAR)){
                    selectedPerson = localStorage.getItem(LOCAL_STORAGE_PERSON_VAR);
                }
                if (selectedPerson && this.personOptions.find(opt => opt.value === selectedPerson)) {
                    this.selectedPerson = selectedPerson;
                } else if (this.personOptions.length) {
                    this.selectedPerson = this.personOptions[0].value;
                }

                this.loadExistingLogs();
            })
            .catch(error => {
                console.error(error);
            });
    }

    loadExistingLogs() {
        const that = this;
        this.isBusy = true;
        getLogsByTaskAndDate({ contactId: this.selectedPerson, fromDate: this.weekStart })
            .then(result => {
                let logsByTaskAndDate = [...(result || [])];
                this._rows = [];

                logsByTaskAndDate.forEach((r, i) => {
                    r.id = i + 1;
                    r.url = '/' + r.taskId;
                    r.totalHours = TimeTrackerServices.formatDuration(r.total);
                    r.logsByDay.forEach(l => {
                        l.date = new Date(l.date);
                        l.dateISO = (new Date(l.date - this._tzoffset)).toISOString();
                        l.id = l.date.getTime();
                        l.formatted = l.date.toLocaleDateString("en-US", { weekday: 'short', month: 'short', day: 'numeric' });
                        l.durationHours = l.duration ? TimeTrackerServices.formatDuration(l.duration) : '';
                    });
                });
                this._rows = logsByTaskAndDate;
                this.isBusy = false;

                this.addEmptyRow();
            })
            .catch(error => {
                console.error(error);
                that.isBusy = false;
            });
    }

    initTaskLookupDefaultResults() {
        // Make sure that the lookup is present and if so, set its default results
        const lookup = this.template.querySelector('c-lookup');
        if (lookup) {
            lookup.setDefaultResults(this.recentlyViewedTasks);
        }
    }

    addEmptyRow() {
        this._rows.push({
            id          : this._rows.length + 1,
            virtual     : true,
            isEdit      : false,
            total       : 0,
            totalHours  : '0:00',
            logsByDay  : this.weekDays.map(d => ({
                id              : d.date.getTime(),
                date            : d.date,
                dateISO         : (new Date(d.date - this._tzoffset)).toISOString(),
                formatted       : d.date.toLocaleDateString("en-US", { weekday: 'short', month: 'short', day: 'numeric' }),
                durationHours   : '',
            })),
        });
    }
    updateEditFlag(index) {
        let rowsTemp = [...this._rows];
        this._rows = [];
        rowsTemp.forEach((r, i) => r.isEdit = typeof index !== "undefined" && i === index);
        this._rows = rowsTemp;
    }


    handleChangePerson(evt) {
        this.selectedPerson = evt.detail.value;
        localStorage.setItem(LOCAL_STORAGE_PERSON_VAR, this.selectedPerson);
        this.loadExistingLogs();
    }
    handlePreviousClick(evt) {
        this.weekStart = TimeTrackerServices.addDays(this.weekStart, -7);
        this.loadExistingLogs();
    }
    handleThisClick(evt) {
        this.weekStart = TimeTrackerServices.getMonday(new Date());
        this.loadExistingLogs();
    }
    handleNextClick(evt) {
        this.weekStart = TimeTrackerServices.addDays(this.weekStart, 7);
        this.loadExistingLogs();
    }
    handleReportClick(evt) {
        evt.preventDefault();
        evt.stopPropagation();
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: '00O5a000007j4PIEAY',
                objectApiName: 'Report',
                actionName: 'view'
            }
        });
    }
    handleEditClick(evt) {
        this.updateEditFlag(parseInt(evt.target.dataset.index));

        const that = this;
        setTimeout(() => {
            that.initTaskLookupDefaultResults();
            that.template.querySelector('c-lookup')?.focus();
        }, 50);
    }
    handleTaskSearch(event) {
        const lookupElement = event.target;
        searchTasks(event.detail)
            .then(results => {
                lookupElement.setSearchResults(results);
            })
            .catch(error => {
                // TODO: handle error
            });
    }
    handleLookupChange(evt) {
        const rowIndex = parseInt(evt.target.dataset.row);
        const selection = evt.target.getSelection();
        console.log(rowIndex, selection);
        if (selection) {
            let rowsTemp = [...this._rows];
            this._rows = [];
            rowsTemp[rowIndex].taskId = selection[0].id;
            rowsTemp[rowIndex].url = '/' + selection[0].id;
            rowsTemp[rowIndex].subject = selection[0].title;
            rowsTemp[rowIndex].project = selection[0].subtitle;
            rowsTemp[rowIndex].isEdit = false;
            rowsTemp[rowIndex].virtual = false;
            this._rows = rowsTemp;

            this.addEmptyRow();
        }
    }
    handleLookupBlur(evt) {
        this.updateEditFlag();
    }
    handleDurationChange(evt) {
        const rowIndex = parseInt(evt.target.dataset.row);
        const dayIndex = parseInt(evt.target.dataset.day);

        this._rows[rowIndex].logsByDay[dayIndex].durationHours = evt.target.value;
    }
    handleDurationFocus(evt) {
        const rowIndex = parseInt(evt.target.dataset.row);
        const dayIndex = parseInt(evt.target.dataset.day);
        this._previousDurationTemp = this._rows[rowIndex].logsByDay[dayIndex].durationHours;
    }
    handleDurationBlur(evt) {
        const rowIndex = parseInt(evt.target.dataset.row);
        const dayIndex = parseInt(evt.target.dataset.day);

        if (this._previousDurationTemp !== this._rows[rowIndex].logsByDay[dayIndex].durationHours) {
            let rowsTemp = [...this._rows];

            const dayDuration = TimeTrackerServices.parseDuration(rowsTemp[rowIndex].logsByDay[dayIndex].durationHours);
            const log = {
                Id: rowsTemp[rowIndex].logsByDay[dayIndex].logId,
                Case__c: rowsTemp[rowIndex].taskId,
                Effort__c: dayDuration,
                Work_Date__c: rowsTemp[rowIndex].logsByDay[dayIndex].dateISO.substring(0, 10)
            };
            upsertLogs({logsJSON: JSON.stringify([log]), contactId: this.selectedPerson})
                .then(result => {
                    const logs = result || [];

                    rowsTemp[rowIndex].logsByDay[dayIndex].logId = logs.length ? logs[0].Id : undefined;
                    rowsTemp[rowIndex].logsByDay[dayIndex].duration = dayDuration;
                    rowsTemp[rowIndex].logsByDay[dayIndex].durationHours = dayDuration ? TimeTrackerServices.formatDuration(dayDuration) : '';

                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Success!',
                            message: rowsTemp[rowIndex].logsByDay[dayIndex].logId
                                ? `${rowsTemp[rowIndex].logsByDay[dayIndex].durationHours} was logged into the task "${rowsTemp[rowIndex].subject}"`
                                : `Timecard for "${rowsTemp[rowIndex].subject}" on ${rowsTemp[rowIndex].logsByDay[dayIndex].dateISO.substring(0, 10)} has been removed`,
                            variant: "success"
                        })
                    );
                })
                .catch(error => {
                    console.error(error);

                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Error!',
                            message: error.message,
                            variant: "error"
                        })
                    );
                })
                .finally(() => {
                    this._rows = [];
                    const taskTotalDuration = rowsTemp[rowIndex].logsByDay.reduce((s, d) => (s + (d.duration ? d.duration : 0)), 0);
                    rowsTemp[rowIndex].total = taskTotalDuration;
                    rowsTemp[rowIndex].totalHours = TimeTrackerServices.formatDuration(taskTotalDuration);
                    this._rows = rowsTemp;
                });
        }
        this._previousDurationTemp = undefined;
    }
    handleEditRow(evt) {
        const that = this;
        const rowIndex = parseInt(evt.target.dataset.row);
        const taskSubject = this._rows[rowIndex].subject;

        TimelogsEditModal.open({
            header  : `${taskSubject}: Edit Timecards`,
            rows    : this._rows[rowIndex].logsByDay,
        }).then((result) => {
            console.log(result);
            if (result === 'saved') {
                that.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success!',
                        message: `Timecards for "${taskSubject}" have been updated.`,
                        variant: "success"
                    })
                );
                that.loadExistingLogs();
            } else {
                that.isBusy = false;
            }
        });
    }
    handleDeleteRow(evt) {
        const that = this;
        const rowIndex = parseInt(evt.target.dataset.row);
        let hasSavedLogs = false;
        this._rows[rowIndex].logsByDay.forEach(l => { if (l.logId) hasSavedLogs = true; });
        if (hasSavedLogs) {
            ConfirmationModal.open({
                size            : 'small',
                header          : 'Delete Timecards',
                content         : `Are you sure you want to delete Timecards from ${(new Date(this.weekStart - this._tzoffset)).toISOString().substring(0, 10)} to ${(new Date(TimeTrackerServices.addDays(this.weekStart, 7) - this._tzoffset)).toISOString().substring(0, 10)} for "${this._rows[rowIndex].subject}"?`,
                primaryButton   : 'Delete',
            }).then((result) => {
                console.log(result);
                if (result === 'primary') {
                    that.isBusy = true;
                    deleteLogs({
                        contactId   : that.selectedPerson,
                        taskId      : that._rows[rowIndex].taskId,
                        fromDate    : that.weekStart
                    })
                        .then(() => {
                            that.loadExistingLogs();
                        })
                        .catch(error => {
                            that.isBusy = false;
                            console.error(error);

                            this.dispatchEvent(
                                new ShowToastEvent({
                                    title: 'Error!',
                                    message: error.message,
                                    variant: "error"
                                })
                            );
                        });
                }
            });
        } else {
            let rowsTemp = [...this._rows];
            this._rows = [];
            rowsTemp.splice(rowIndex, 1);
            this._rows = rowsTemp;
            if (this._rows.length === 0) this.addEmptyRow();
        }
    }
}