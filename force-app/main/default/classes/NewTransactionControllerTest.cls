/**
 * Created on 14.04.23.
 */

@IsTest
private class NewTransactionControllerTest {

    @IsTest
    static void doInitTest() {
        Map<String, String> options = NewTransactionController.getPicklistValues('Transaction__c', 'CurrencyIsoCode');
        System.assert(!options.isEmpty());
    }
}