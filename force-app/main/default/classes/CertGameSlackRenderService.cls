/**
 * Centralized Slack Block Kit JSON builder. All user-facing Slack UI lives here.
 * Strings are sourced from CertGameStrings.
 * action_id format: `domain:verb:resourceId`, e.g. `game:answer:a01R0000...`.
 */
public with sharing class CertGameSlackRenderService {

    public static String help() {
        return JSON.serialize(new Map<String, Object>{
            'response_type' => 'ephemeral',
            'text' => CertGameStrings.HELP_TEXT
        });
    }

    public static String text(String message, Boolean ephemeral) {
        return JSON.serialize(new Map<String, Object>{
            'response_type' => (ephemeral ? 'ephemeral' : 'in_channel'),
            'text' => message
        });
    }

    /**
     * Quick-play game prompt with answer buttons.
     * @param questionText Question prompt
     * @param choices List<Map> with keys: id, label, text
     */
    public static String questionBlocks(String roundId, String questionText, List<Map<String, Object>> choices, Integer secondsRemaining) {
        List<Object> blocks = new List<Object>();
        blocks.add(section('*' + questionText + '*'));
        List<Object> els = new List<Object>();
        for (Map<String, Object> c : choices) {
            els.add(new Map<String, Object>{
                'type' => 'button',
                'text' => new Map<String, Object>{ 'type' => 'plain_text', 'text' => (String) c.get('label') + '. ' + truncate((String) c.get('text'), 70) },
                'action_id' => 'game:answer:' + roundId + ':' + c.get('id'),
                'value' => (String) c.get('id')
            });
        }
        blocks.add(new Map<String, Object>{ 'type' => 'actions', 'elements' => els });
        if (secondsRemaining != null) {
            blocks.add(context('Time remaining: ' + secondsRemaining + 's'));
        }
        return JSON.serialize(new Map<String, Object>{
            'response_type' => 'in_channel',
            'blocks' => blocks
        });
    }

    public static String resultBlocks(Boolean correct, String correctChoiceText, Integer pointsAwarded, List<Map<String, Object>> citations) {
        List<Object> blocks = new List<Object>();
        blocks.add(section(correct ? ':white_check_mark: Correct! +' + pointsAwarded + ' points'
                                   : ':x: Not quite. Correct answer: *' + correctChoiceText + '*'));
        if (citations != null && !citations.isEmpty()) {
            String txt = 'Sources:';
            for (Map<String, Object> c : citations) {
                txt += '\n• <' + c.get('url') + '|' + c.get('title') + '>';
            }
            blocks.add(section(txt));
        }
        return JSON.serialize(new Map<String, Object>{
            'response_type' => 'in_channel',
            'replace_original' => true,
            'blocks' => blocks
        });
    }

    public static String leaderboardBlocks(String title, List<Map<String, Object>> rows) {
        List<Object> blocks = new List<Object>();
        blocks.add(header(title));
        String txt = '';
        Integer rank = 1;
        for (Map<String, Object> r : rows) {
            txt += String.valueOf(rank++) + '. *' + r.get('name') + '* — ' + r.get('points') + ' pts\n';
        }
        blocks.add(section(txt == '' ? '_No scores yet._' : txt));
        return JSON.serialize(new Map<String, Object>{
            'response_type' => 'in_channel',
            'blocks' => blocks
        });
    }

    public static String appHomeView(Map<String, Object> data) {
        List<Object> blocks = new List<Object>();
        blocks.add(header('Cert Game'));
        blocks.add(section('Welcome back! Use `/certgame play` to start a quick game.'));
        blocks.add(divider());
        return JSON.serialize(new Map<String, Object>{
            'type' => 'home',
            'blocks' => blocks
        });
    }

    // ----- block primitives -----
    public static Map<String, Object> section(String mrkdwn) {
        return new Map<String, Object>{
            'type' => 'section',
            'text' => new Map<String, Object>{ 'type' => 'mrkdwn', 'text' => mrkdwn }
        };
    }
    public static Map<String, Object> header(String txt) {
        return new Map<String, Object>{
            'type' => 'header',
            'text' => new Map<String, Object>{ 'type' => 'plain_text', 'text' => txt }
        };
    }
    public static Map<String, Object> divider() {
        return new Map<String, Object>{ 'type' => 'divider' };
    }
    public static Map<String, Object> context(String txt) {
        return new Map<String, Object>{
            'type' => 'context',
            'elements' => new List<Object>{ new Map<String, Object>{ 'type' => 'mrkdwn', 'text' => txt } }
        };
    }
    private static String truncate(String s, Integer n) {
        if (s == null) return '';
        return s.length() > n ? s.substring(0, n - 1) + '…' : s;
    }
}
