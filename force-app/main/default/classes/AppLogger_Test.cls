@IsTest
private class AppLogger_Test {
    @IsTest
    static void infoWarnErrorWrite() {
        AppLogger.info('Cls', 'm', 'i');
        AppLogger.warn('Cls', 'm', 'w');
        AppLogger.error('Cls', 'm', 'e', new System.NullPointerException());
        AppLogger.info('Cls', 'm', 'it', null);
        Integer c = [SELECT COUNT() FROM App_Log__c];
        System.assert(c >= 3);
    }
}