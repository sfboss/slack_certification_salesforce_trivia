@IsTest
private class CertGameTenantService_Test {
    @IsTest
    static void getOrCreateTenantInsertsThenFinds() {
        Tenant__c a = CertGameTenantService.getOrCreateTenant('T_NEW1');
        System.assertNotEquals(null, a.Id);
        Tenant__c b = CertGameTenantService.getOrCreateTenant('T_NEW1');
        System.assertEquals(a.Id, b.Id);
    }

    @IsTest
    static void getOrCreatePlayerInsertsThenFinds() {
        Tenant__c t = CertGameTenantService.getOrCreateTenant('T_PLAY1');
        Player__c p = CertGameTenantService.getOrCreatePlayer(t.Id, 'U_1');
        System.assertNotEquals(null, p.Id);
        Player__c p2 = CertGameTenantService.getOrCreatePlayer(t.Id, 'U_1');
        System.assertEquals(p.Id, p2.Id);
    }

    @IsTest
    static void findReturnsNullWhenMissing() {
        System.assertEquals(null, CertGameTenantService.findTenant('NOPE'));
        Tenant__c t = CertGameTenantService.getOrCreateTenant('T_FIND');
        System.assertEquals(
            null,
            CertGameTenantService.findPlayer(t.Id, 'nope')
        );
    }

    @IsTest
    static void uninstallMarksCancelled() {
        CertGameTenantService.getOrCreateTenant('T_UN1');
        CertGameTenantService.handleUninstall('T_UN1');
        Tenant__c t = [
            SELECT Status__c
            FROM Tenant__c
            WHERE Slack_Team_Id__c = 'T_UN1'
        ];
        System.assertEquals('Cancelled', t.Status__c);
    }

    @IsTest
    static void uninstallUnknownReturnsBlank() {
        System.assertEquals(
            '',
            CertGameTenantService.handleUninstall('NEVER_INSTALLED')
        );
    }
}