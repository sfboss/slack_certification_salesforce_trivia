/**
 * Renders the `/certgame whoami` ephemeral status card.
 * Shows the caller's Slack identity, linked Google account (if any),
 * web last-login time, tenant, and plan — so users can confirm
 * Slack ↔ Google ↔ Tenant wiring without leaving Slack.
 */
public with sharing class CertGameWhoamiService {
    public static String run(String teamId, String userId) {
        Tenant__c tenant;
        List<Tenant__c> tenants = [
            SELECT
                Id,
                Name,
                Workspace_Name__c,
                Plan__c,
                Status__c,
                Slack_Team_Id__c
            FROM Tenant__c
            WHERE Slack_Team_Id__c = :teamId
            LIMIT 1
        ];
        if (!tenants.isEmpty())
            tenant = tenants[0];

        Player__c player;
        List<Player__c> players = [
            SELECT
                Id,
                Display_Name__c,
                Slack_User_Id__c,
                Slack_Team_Id__c,
                Google_Email__c,
                Google_Name__c,
                Google_Sub__c,
                Google_Picture_URL__c,
                Web_Last_Login_At__c,
                Last_Played_At__c,
                Total_Games__c,
                Total_Points__c,
                Tenant__c,
                Tenant__r.Name,
                Tenant__r.Plan__c
            FROM Player__c
            WHERE Slack_User_Id__c = :userId AND Slack_Team_Id__c = :teamId
            LIMIT 1
        ];
        if (!players.isEmpty())
            player = players[0];

        List<Object> blocks = new List<Object>();
        blocks.add(
            CertGameSlackRenderService.header(':bust_in_silhouette:  whoami')
        );

        blocks.add(
            CertGameSlackRenderService.section(
                '*Slack*\n' +
                    '• User: `' +
                    userId +
                    '`\n' +
                    '• Team: `' +
                    teamId +
                    '`'
            )
        );

        if (player == null) {
            blocks.add(
                CertGameSlackRenderService.section(
                    '*Player record*\n_No Player__c found for this Slack identity._ ' +
                    'Run `/certgame play` to create one.'
                )
            );
        } else {
            String googleLine = String.isNotBlank(player.Google_Sub__c)
                ? ':white_check_mark:  Linked as *' +
                  (player.Google_Name__c == null
                      ? player.Google_Email__c
                      : player.Google_Name__c) +
                  '* (' +
                  player.Google_Email__c +
                  ')'
                : ':warning:  Not linked. Sign in at the web companion to link.';
            String lastWeb = player.Web_Last_Login_At__c == null
                ? '_never_'
                : player.Web_Last_Login_At__c.format();
            String lastPlay = player.Last_Played_At__c == null
                ? '_never_'
                : player.Last_Played_At__c.format();

            blocks.add(
                CertGameSlackRenderService.section(
                    '*Player*\n' +
                        '• Display name: ' +
                        (String.isBlank(player.Display_Name__c)
                            ? '_unset_'
                            : player.Display_Name__c) +
                        '\n' +
                        '• Google: ' +
                        googleLine +
                        '\n' +
                        '• Web last login: ' +
                        lastWeb +
                        '\n' +
                        '• Last played: ' +
                        lastPlay +
                        '\n' +
                        '• Total games: ' +
                        (player.Total_Games__c == null
                            ? 0
                            : player.Total_Games__c.intValue()) +
                        '   Points: ' +
                        (player.Total_Points__c == null
                            ? 0
                            : player.Total_Points__c.intValue())
                )
            );
        }

        if (tenant == null) {
            blocks.add(
                CertGameSlackRenderService.section(
                    '*Tenant*\n_No Tenant__c for this Slack team._ Reinstall the app or contact admin.'
                )
            );
        } else {
            blocks.add(
                CertGameSlackRenderService.section(
                    '*Tenant*\n' +
                        '• Workspace: ' +
                        (String.isBlank(tenant.Workspace_Name__c)
                            ? tenant.Name
                            : tenant.Workspace_Name__c) +
                        '\n' +
                        '• Plan: `' +
                        (String.isBlank(tenant.Plan__c)
                            ? 'Free'
                            : tenant.Plan__c) +
                        '`\n' +
                        '• Status: `' +
                        (String.isBlank(tenant.Status__c)
                            ? 'Active'
                            : tenant.Status__c) +
                        '`'
                )
            );
        }

        blocks.add(
            CertGameSlackRenderService.context(
                'Tip: open the web companion and sign in with Google to link this Slack user to a Google account.'
            )
        );

        return JSON.serialize(
            new Map<String, Object>{
                'response_type' => 'ephemeral',
                'blocks' => blocks
            }
        );
    }
}