/**
 * Created on 04/07/2024.
 */

public without sharing class slackbot_VacationsCommandDispatcher extends Slack.SlashCommandDispatcher {
    public override Slack.ActionHandler invoke(Slack.SlashCommandParameters parameters, Slack.RequestContext context) {
        if (parameters.getText() == 'new') {
            return Slack.ActionHandler.modal(new NewHandler(parameters, context), 'Add Vacation');
        }
        return Slack.ActionHandler.ack(new ViewHandler(parameters, context));
    }

    public class ViewHandler implements Slack.RunnableHandler {
        Slack.SlashCommandParameters parameters;
        Slack.RequestContext context;

        public ViewHandler(Slack.SlashCommandParameters parameters, Slack.RequestContext context){
            this.parameters = parameters;
            this.context = context;
        }

        public void run () {
            Slack.App app = Slack.App.PropellerPlanSlackApp.get();
            Slack.BotClient client = app.getBotClientForTeam(context.getTeamId());
            Slack.ViewReference viewReference = Slack.View.vacation_list.get();
            String channel = context.getChannelId();
            viewReference.setParameter('vacations', getUpcomingVacations());

            Map<String, Integer> usedVacations = calculateVacationsByType();
            viewReference.setParameter('personalVacationUsed', usedVacations.get('personal'));
            viewReference.setParameter('personalVacationTotal', (Integer) Setting__c.getOrgDefaults().Personal_Vacations_Limit__c);
            viewReference.setParameter('dayOffUsed', usedVacations.get('dayOff'));
            viewReference.setParameter('dayOffTotal', (Integer) Setting__c.getOrgDefaults().Days_Off_Limit__c);

            Slack.ChatPostMessageRequest req = new Slack.ChatPostMessageRequest.Builder()
                    .channel(channel)
                    .viewReference(viewReference)
                    .build();

            Slack.ChatPostMessageResponse response = client.chatPostMessage(req);
            if (response.getError() != null) {
                System.debug(response.getError());
            } else {
                System.debug('success');
            }
        }

        private List<Vacation> getUpcomingVacations() {
            List<Vacation> vacations = new List<Vacation>();
            for (Vacation__c v : (List<Vacation__c>)new pp_Query('Vacation__c')
                    .selectAllFields()
                    .addCondition(pp_Query.doAnd(
                            pp_Query.conditionGe('Vacation_End_Date__c', Date.today()),
                            pp_Query.doOr(
                                    pp_Query.conditionEq('CreatedById', UserInfo.getUserId()),
                                    pp_Query.conditionEq('Employee__r.Email', UserInfo.getUserEmail()),
                                    pp_Query.conditionEq('Employee__r.OwnerId', UserInfo.getUserId())
                            )
                    ))
                    .orderBy('Vacation_Start_Date__c')
                    .setLimit(10)
                    .run()) {
                vacations.add(new Vacation(v));
            }
            return vacations;
        }

        private Map<String, Integer> calculateVacationsByType() {
            Integer personalUsed = 0,
                    dayOffUsed = 0;
            List<Holiday__c> holidayList = (List<Holiday__c>) new pp_Query('Holiday__c')
                    .selectField('Date__c')
                    .addConditionEq('Date__c', pp_Query.THIS_YEAR)
                    .addConditionEq('Country_Code__c', ('' + UserInfo.getTimeZone()).endsWithIgnoreCase('minsk') ? 'BY' : 'PL')
                    .setLimit(100)
                    .run();
            Set<Date> holidays = new Set<Date>(pp_R.of(holidayList).pluck('Date__c').toDateList());
            pp_Moment yearStart = new pp_Moment(Date.today().year(), 1, 1),
                    yearEnd = new pp_Moment(Date.today().year(), 12, 31);
            for (Vacation__c v : (List<Vacation__c>) new pp_Query('Vacation__c')
                    .selectFields(new Set<String>{'Vacation_Start_Date__c', 'Vacation_End_Date__c', 'Vacation_Type__c'})
                    .addCondition(pp_Query.doAnd(
                            pp_Query.conditionIn('Vacation_Type__c', new Set<String>{'Day Off', 'Personal Vacation'}),
                            pp_Query.doOr(
                                    pp_Query.conditionEq('CreatedById', UserInfo.getUserId()),
                                    pp_Query.conditionEq('Employee__r.Email', UserInfo.getUserEmail()),
                                    pp_Query.conditionEq('Employee__r.OwnerId', UserInfo.getUserId())
                            ),
                            pp_Query.doOr(
                                    pp_Query.conditionEq('Vacation_Start_Date__c', pp_Query.THIS_YEAR),
                                    pp_Query.conditionEq('Vacation_End_Date__c', pp_Query.THIS_YEAR)
                            )
                    ))
                    .setLimit(20000)
                    .run()) {
                Integer usedWorkingDays = 0;
                pp_Moment startM = v.Vacation_Start_Date__c.year() != Date.today().year() ? yearStart : new pp_Moment(v.Vacation_Start_Date__c),
                        endM = (v.Vacation_End_Date__c.year() != Date.today().year() ? yearEnd : new pp_Moment(v.Vacation_End_Date__c)).add(1, 'd');
                usedWorkingDays = startM.diff(endM, true).asDays();
                for (Date h : holidays) {
                    pp_Moment holiday = new pp_Moment(h);
                    if (holiday.isBetween(startM, endM) && holiday.dayOfWeek() != 6 && holiday.dayOfWeek() != 7) usedWorkingDays--;
                }
                if (v.Vacation_Type__c == 'Personal Vacation') personalUsed += usedWorkingDays;
                else if (v.Vacation_Type__c == 'Day Off') dayOffUsed += usedWorkingDays;
            }
            return new Map<String, Integer>{
                    'personal' => personalUsed,
                    'dayOff' => dayOffUsed
            };
        }
    }

    public class NewHandler implements Slack.ModalHandler {

        Slack.SlashCommandParameters parameters;
        Slack.RequestContext context;

        public NewHandler(Slack.SlashCommandParameters parameters, Slack.RequestContext context){
            this.parameters = parameters;
            this.context = context;
        }

        public Slack.ModalView call() {
            Slack.ViewReference viewReference = Slack.View.vacation_form.get();
            viewReference.setParameter('channel', context.getChannelId());
            viewReference.setParameter('type', 'Day Off');
            viewReference.setParameter('status', 'Planned');
            viewReference.setParameter('title', 'Add Vacation');
            Slack.ModalView modalView = new Slack.ModalView.Builder()
                    .viewReference(viewReference)
                    .build();
            return modalView;
        }
    }

    public class Vacation {
        public String id {get;set;}
        public String type {get;set;}
        public String typeEmoji {get;set;}
        public String status {get;set;}
        public String statusEmoji {get;set;}
        public String datesRange {get;set;}

        public Vacation(Vacation__c v) {
            this.id = v.Id;
            this.type = v.Vacation_Type__c;
            this.typeEmoji = TYPE_EMOJI.get(this.type);
            this.status = v.Status__c;
            this.statusEmoji = STATUS_EMOJI.get(this.status);
            this.datesRange = new pp_Moment(v.Vacation_Start_Date__c).format('MMMM d, yyyy')
                    + (v.Vacation_Start_Date__c != v.Vacation_End_Date__c ? ' - ' + new pp_Moment(v.Vacation_End_Date__c).format('MMMM d, yyyy') : '');
        }
    }

    private static final Map<String, String> TYPE_EMOJI = new Map<String, String>{
            'Day Off' => ':ooo:',
            'Part Time' => ':time-zone-fyi:',
            'Personal Vacation' => ':pto:',
            'Sick Leave' => ':face_with_thermometer:',
            'Holiday Season' => ':confetti_ball:'
    };
    private static final Map<String, String> STATUS_EMOJI = new Map<String, String>{
            'Planned' => ':thinking_face:',
            'Confirmed' => ':white_check_mark:'
    };
}