@IsTest
private class AppSettings_Test {
    @IsTest
    static void getDefaultsWhenMissing() {
        App_Setting__mdt s = AppSettings.get();
        System.assertNotEquals(null, s);
        System.assertNotEquals(null, s.Default_Provider__c);
    }
}