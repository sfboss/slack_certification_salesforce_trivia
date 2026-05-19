/**
 * Centralized Slack Block Kit JSON builder. All user-facing Slack UI lives here.
 * Strings are sourced from CertGameStrings.
 * action_id format: `domain:verb:resourceId`, e.g. `game:answer:a01R0000...`.
 */
public with sharing class CertGameSlackRenderService {

    public static String help() {
        List<Object> blocks = new List<Object>();
        blocks.add(new Map<String, Object>{
            'type' => 'header',
            'text' => new Map<String, Object>{ 'type' => 'plain_text', 'text' => 'Certification Trivia', 'emoji' => true }
        });
        blocks.add(section('Study smarter with quick, scored quizzes right inside Slack.'));
        blocks.add(new Map<String, Object>{ 'type' => 'divider' });
        blocks.add(section(
            '*Commands*\n' +
            '`/certgame play` — start a quick 5-question game (optionally `play <ExamCode>`)\n' +
            '`/certgame challenge @user [ExamCode]` — head-to-head duel (5 questions)\n' +
            '`/certgame games` — list available exams + question counts\n' +
            '`/certgame leaderboard` — show channel leaderboard\n' +
            '`/certgame stats` — your stats in this workspace\n' +
            '`/certgame plan` — manage study plan\n' +
            '`/certgame doctor` — run setup + health checks\n' +
            '`/certgame notify-test` — DM yourself a self-test message\n' +
            '`/certgame billing` — manage workspace plan (admins)\n' +
            '`/certgame help` — this message'
        ));
        blocks.add(new Map<String, Object>{
            'type' => 'actions',
            'elements' => new List<Object>{
                new Map<String, Object>{
                    'type' => 'button',
                    'text' => new Map<String, Object>{ 'type' => 'plain_text', 'text' => 'Open Study Plan', 'emoji' => true },
                    'action_id' => 'plan:open',
                    'style' => 'primary'
                },
                new Map<String, Object>{
                    'type' => 'button',
                    'text' => new Map<String, Object>{ 'type' => 'plain_text', 'text' => 'Run Doctor', 'emoji' => true },
                    'action_id' => 'home:doctor:run'
                },
                new Map<String, Object>{
                    'type' => 'button',
                    'text' => new Map<String, Object>{ 'type' => 'plain_text', 'text' => 'Test notifications', 'emoji' => true },
                    'action_id' => 'home:notify:run'
                }
            }
        });
        blocks.add(new Map<String, Object>{
            'type' => 'context',
            'elements' => new List<Object>{
                new Map<String, Object>{ 'type' => 'mrkdwn', 'text' => 'Tip: try `/certgame play` to start a 5-question round.' }
            }
        });
        return JSON.serialize(new Map<String, Object>{
            'response_type' => 'ephemeral',
            'text' => CertGameStrings.HELP_TEXT,
            'blocks' => blocks
        });
    }

    public static String text(String message, Boolean ephemeral) {
        return JSON.serialize(new Map<String, Object>{
            'response_type' => (ephemeral ? 'ephemeral' : 'in_channel'),
            'text' => message
        });
    }

    /**
     * Rich ephemeral error card visible only to the invoking user. Includes a copy-pasteable
     * correlation id so the operator can pull the full stack from App_Log__c.
     */
    public static String errorEnvelope(String subcommand, String correlationId, Exception e) {
        String safeSub = String.isBlank(subcommand) ? '/certgame' : '/certgame ' + subcommand;
        String type = e == null ? 'UnknownError' : e.getTypeName();
        String msg = e == null ? 'no exception message' : (e.getMessage() == null ? '' : e.getMessage());
        if (msg.length() > 300) msg = msg.substring(0, 300) + '...';
        String corr = String.isBlank(correlationId) ? 'n/a' : correlationId;
        List<Object> blocks = new List<Object>();
        blocks.add(section(':warning: *' + safeSub + '* failed.'));
        blocks.add(section('*Error:* `' + type + '`\n*Detail:* ' + msg));
        blocks.add(context('Correlation id: `' + corr + '` — paste into App_Log__c.Correlation_Id__c to retrieve the stack trace.'));
        return JSON.serialize(new Map<String, Object>{
            'response_type' => 'ephemeral',
            'text' => safeSub + ' failed: ' + type,
            'blocks' => blocks
        });
    }

    /**
     * In-Slack debug card: shows last N App_Log__c rows so operators can self-serve diagnostics
     * without leaving the workspace.
     */
    public static String debugLogBlocks(List<App_Log__c> rows) {
        List<Object> blocks = new List<Object>();
        blocks.add(header('Cert Game — Recent Logs'));
        if (rows == null || rows.isEmpty()) {
            blocks.add(section('_No App_Log__c rows found in the last hour._'));
        } else {
            for (App_Log__c r : rows) {
                String occurredAt = r.Occurred_At__c == null ? '?' : r.Occurred_At__c.format();
                String body = '*[' + r.Level__c + ']* ' + occurredAt + '\n'
                    + '`' + r.Class_Name__c + '.' + r.Method_Name__c + '`\n'
                    + (r.Message__c == null ? '' : r.Message__c);
                if (body.length() > 2900) body = body.substring(0, 2900) + '...';
                blocks.add(section(body));
                if (String.isNotBlank(r.Correlation_Id__c)) {
                    blocks.add(context('correlation: `' + r.Correlation_Id__c + '`'));
                }
                blocks.add(divider());
            }
        }
        return JSON.serialize(new Map<String, Object>{
            'response_type' => 'ephemeral',
            'text' => 'Recent Cert Game logs',
            'blocks' => blocks
        });
    }

    /**
     * Quick-play game prompt with answer buttons.
     * @param questionText Question prompt
     * @param choices List<Map> with keys: id, label, text
     */
    public static String questionBlocks(String roundId, String questionText, List<Map<String, Object>> choices, Integer secondsRemaining) {
        return questionBlocks(roundId, questionText, choices, secondsRemaining, null, null, null);
    }

    public static String questionBlocks(String roundId, String questionText, List<Map<String, Object>> choices,
            Integer secondsRemaining, Integer qNum, Integer totalQ, String difficulty) {
        List<Object> blocks = new List<Object>();
        String headerTxt = (qNum != null && totalQ != null)
            ? 'Question ' + qNum + ' of ' + totalQ
            : 'Question';
        blocks.add(header(':brain: ' + headerTxt));

        Map<String, Object> qSection = new Map<String, Object>{
            'type' => 'section',
            'text' => new Map<String, Object>{ 'type' => 'mrkdwn', 'text' => '*' + questionText + '*' }
        };
        List<Object> fields = new List<Object>();
        if (qNum != null && totalQ != null) {
            fields.add(new Map<String, Object>{ 'type' => 'mrkdwn', 'text' => '*Progress*\n' + qNum + ' / ' + totalQ });
        }
        if (secondsRemaining != null) {
            fields.add(new Map<String, Object>{ 'type' => 'mrkdwn', 'text' => '*Timer*\n:hourglass_flowing_sand: ' + secondsRemaining + 's' });
        }
        if (String.isNotBlank(difficulty)) {
            fields.add(new Map<String, Object>{ 'type' => 'mrkdwn', 'text' => '*Difficulty*\n' + difficulty });
        }
        if (!fields.isEmpty()) qSection.put('fields', fields);
        blocks.add(qSection);

        blocks.add(divider());
        List<Object> els = new List<Object>();
        for (Map<String, Object> c : choices) {
            els.add(new Map<String, Object>{
                'type' => 'button',
                'text' => new Map<String, Object>{ 'type' => 'plain_text', 'text' => (String) c.get('label') + '. ' + truncate((String) c.get('text'), 70), 'emoji' => true },
                'action_id' => 'game:answer:' + roundId + ':' + c.get('id'),
                'value' => (String) c.get('id')
            });
        }
        blocks.add(new Map<String, Object>{ 'type' => 'actions', 'elements' => els });
        blocks.add(context(':zap: Lock in your answer — partial credit for speed.'));
        return JSON.serialize(new Map<String, Object>{
            'response_type' => 'in_channel',
            'text' => 'Question ' + (qNum == null ? '' : (qNum + ' of ' + totalQ)),
            'blocks' => blocks
        });
    }

    public static String resultBlocks(Boolean correct, String correctChoiceText, Integer pointsAwarded, List<Map<String, Object>> citations) {
        return resultBlocks(correct, correctChoiceText, pointsAwarded, citations, null, null, null, null);
    }

    public static String resultBlocks(Boolean correct, String correctChoiceText, Integer pointsAwarded,
            List<Map<String, Object>> citations, String explanation, Integer runningPoints,
            Integer correctCount, Integer answeredCount) {
        List<Object> blocks = new List<Object>();
        blocks.add(header(correct ? ':white_check_mark: Correct!' : ':x: Not quite'));

        Map<String, Object> body = new Map<String, Object>{
            'type' => 'section',
            'text' => new Map<String, Object>{
                'type' => 'mrkdwn',
                'text' => correct
                    ? '*+' + pointsAwarded + ' points* — well played.'
                    : 'Correct answer: *' + (correctChoiceText == null ? '' : correctChoiceText) + '*'
            }
        };
        List<Object> fields = new List<Object>();
        if (runningPoints != null) fields.add(new Map<String, Object>{ 'type' => 'mrkdwn', 'text' => '*Score*\n' + runningPoints + ' pts' });
        if (correctCount != null && answeredCount != null && answeredCount > 0) {
            Integer pct = (correctCount * 100) / answeredCount;
            fields.add(new Map<String, Object>{ 'type' => 'mrkdwn', 'text' => '*Accuracy*\n' + correctCount + '/' + answeredCount + ' (' + pct + '%)' });
        }
        if (!fields.isEmpty()) body.put('fields', fields);
        blocks.add(body);

        if (String.isNotBlank(explanation)) {
            String exp = truncate(explanation, 800);
            blocks.add(new Map<String, Object>{
                'type' => 'context',
                'elements' => new List<Object>{
                    new Map<String, Object>{ 'type' => 'mrkdwn', 'text' => ':bulb: ' + exp }
                }
            });
        }
        if (citations != null && !citations.isEmpty()) {
            String txt = '*Sources*';
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

    public static String gameOverBlocks(Integer totalPoints, Integer correctCount, Integer totalQ, String examCode) {
        List<Object> blocks = new List<Object>();
        blocks.add(header(':checkered_flag: Game Over'));
        Integer pct = totalQ == null || totalQ == 0 ? 0 : (correctCount * 100) / totalQ;
        Map<String, Object> body = new Map<String, Object>{
            'type' => 'section',
            'text' => new Map<String, Object>{ 'type' => 'mrkdwn', 'text' => '*Nice run!* Here are your results:' },
            'fields' => new List<Object>{
                new Map<String, Object>{ 'type' => 'mrkdwn', 'text' => '*Final score*\n' + (totalPoints == null ? 0 : totalPoints) + ' pts' },
                new Map<String, Object>{ 'type' => 'mrkdwn', 'text' => '*Correct*\n' + correctCount + ' / ' + totalQ },
                new Map<String, Object>{ 'type' => 'mrkdwn', 'text' => '*Accuracy*\n' + pct + '%' }
            }
        };
        blocks.add(body);
        blocks.add(divider());
        String newGameId = 'game:newgame' + (String.isBlank(examCode) ? '' : (':' + examCode));
        blocks.add(new Map<String, Object>{
            'type' => 'actions',
            'elements' => new List<Object>{
                new Map<String, Object>{
                    'type' => 'button',
                    'text' => new Map<String, Object>{ 'type' => 'plain_text', 'text' => ':game_die: Play again', 'emoji' => true },
                    'action_id' => newGameId,
                    'style' => 'primary'
                },
                new Map<String, Object>{
                    'type' => 'button',
                    'text' => new Map<String, Object>{ 'type' => 'plain_text', 'text' => 'Leaderboard', 'emoji' => true },
                    'action_id' => 'home:leaderboard:run'
                },
                new Map<String, Object>{
                    'type' => 'button',
                    'text' => new Map<String, Object>{ 'type' => 'plain_text', 'text' => 'List games', 'emoji' => true },
                    'action_id' => 'home:games:run'
                }
            }
        });
        return JSON.serialize(new Map<String, Object>{
            'response_type' => 'in_channel',
            'text' => 'Game over — ' + (totalPoints == null ? 0 : totalPoints) + ' pts',
            'blocks' => blocks
        });
    }

    public static String alreadyAnsweredBlocks() {
        List<Object> blocks = new List<Object>();
        blocks.add(section(':information_source: *You already answered this round.*\nStart a fresh game to keep going.'));
        blocks.add(new Map<String, Object>{
            'type' => 'actions',
            'elements' => new List<Object>{
                new Map<String, Object>{
                    'type' => 'button',
                    'text' => new Map<String, Object>{ 'type' => 'plain_text', 'text' => ':game_die: Play again', 'emoji' => true },
                    'action_id' => 'game:newgame',
                    'style' => 'primary'
                },
                new Map<String, Object>{
                    'type' => 'button',
                    'text' => new Map<String, Object>{ 'type' => 'plain_text', 'text' => 'List games', 'emoji' => true },
                    'action_id' => 'home:games:run'
                }
            }
        });
        return JSON.serialize(new Map<String, Object>{
            'response_type' => 'ephemeral',
            'text' => CertGameStrings.ALREADY_ANSWERED,
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
        blocks.add(section('Welcome back! Use `/certgame play` to start a quick game, or pick an action below.'));
        blocks.add(divider());
        blocks.add(new Map<String, Object>{
            'type' => 'actions',
            'elements' => new List<Object>{
                new Map<String, Object>{
                    'type' => 'button',
                    'text' => new Map<String, Object>{ 'type' => 'plain_text', 'text' => 'Open Study Plan', 'emoji' => true },
                    'action_id' => 'plan:open',
                    'style' => 'primary'
                },
                new Map<String, Object>{
                    'type' => 'button',
                    'text' => new Map<String, Object>{ 'type' => 'plain_text', 'text' => 'Run Doctor', 'emoji' => true },
                    'action_id' => 'home:doctor:run'
                },
                new Map<String, Object>{
                    'type' => 'button',
                    'text' => new Map<String, Object>{ 'type' => 'plain_text', 'text' => 'Test notifications', 'emoji' => true },
                    'action_id' => 'home:notify:run'
                },
                new Map<String, Object>{
                    'type' => 'button',
                    'text' => new Map<String, Object>{ 'type' => 'plain_text', 'text' => 'List games', 'emoji' => true },
                    'action_id' => 'home:games:run'
                }
            }
        });
        blocks.add(context('Tip: Doctor checks setup and shows recent errors. Test notifications DMs you a self-test message.'));
        return JSON.serialize(new Map<String, Object>{
            'type' => 'home',
            'blocks' => blocks
        });
    }

    /**
     * Ephemeral card listing available certification exams + question counts per status.
     */
    public static String gamesList(List<CertGameExamCatalogService.ExamSummary> rows) {
        List<Object> blocks = new List<Object>();
        blocks.add(header('Available games'));
        if (rows == null || rows.isEmpty()) {
            blocks.add(section('_No certification exams are configured yet. Admins: open the Cert Game Admin Home tab to import a question pack._'));
        } else {
            for (CertGameExamCatalogService.ExamSummary s : rows) {
                String code = String.isBlank(s.code) ? '(no code)' : s.code;
                String status = s.active == true ? ':white_check_mark: active' : ':grey_exclamation: inactive';
                String counts = s.published + ' published / ' + s.reviewed + ' reviewed / ' + s.draft + ' draft';
                String cta = s.published > 0 && s.active == true
                    ? '\n_Run `/certgame play ' + code + '` to play this exam._'
                    : (s.published == 0
                        ? '\n_No published questions yet — ask an admin to publish drafts._'
                        : '\n_Exam is inactive — admin can re-activate it in Salesforce._');
                blocks.add(section('*' + code + '* — ' + s.name + '\n' + status + ' · ' + counts + cta));
            }
        }
        blocks.add(context('Need to add an exam? Admins: import a JSON question pack from the Cert Game Admin Home tab.'));
        return JSON.serialize(new Map<String, Object>{
            'response_type' => 'ephemeral',
            'text' => 'Available games',
            'blocks' => blocks
        });
    }

    /**
     * Ephemeral status card for the notification self-test.
     */
    public static String notifyTestResult(Boolean ok, String detail) {
        List<Object> blocks = new List<Object>();
        blocks.add(section(ok
            ? ':white_check_mark: *Notification test sent.*'
            : ':no_entry: *Notification test failed.*'));
        blocks.add(section(detail == null ? '' : detail));
        if (!ok) {
            blocks.add(context('Run `/certgame doctor` to inspect recent server errors and pinpoint the cause.'));
        }
        return JSON.serialize(new Map<String, Object>{
            'response_type' => 'ephemeral',
            'text' => ok ? 'Notification test sent.' : 'Notification test failed.',
            'blocks' => blocks
        });
    }

    /**
     * Block Kit doctor report — preflight check results, recent errors, and recent Slack events.
     */
    public static String doctorReport(String teamId, Integer score, Integer max,
            List<CertGameDoctorService.Check> checks,
            List<App_Log__c> errors,
            List<Slack_Event_Log__c> events) {
        List<Object> blocks = new List<Object>();
        String emoji = score == max ? ':white_check_mark:' : (score >= max - 1 ? ':warning:' : ':no_entry:');
        blocks.add(header('Cert Game Doctor — ' + score + '/' + max + ' ' + emoji));
        blocks.add(context('Slack team `' + (teamId == null ? '?' : teamId) + '`  ·  '
            + System.now().format() + ' (org local time)'));
        blocks.add(divider());

        List<String> nextSteps = new List<String>();
        for (CertGameDoctorService.Check c : checks) {
            String icon = c.status == 'OK' ? ':white_check_mark:'
                        : c.status == 'WARN' ? ':warning:' : ':no_entry:';
            String body = icon + ' *' + c.title + '* — ' + (c.detail == null ? '' : c.detail);
            blocks.add(section(body));
            if (String.isNotBlank(c.nextStep) && c.status != 'OK') {
                blocks.add(context(':wrench: ' + c.nextStep));
                nextSteps.add(c.nextStep);
            }
        }

        blocks.add(divider());
        blocks.add(header('Recent server errors (last hour)'));
        if (errors == null || errors.isEmpty()) {
            blocks.add(section('_No ERROR rows. The org is quiet._'));
        } else {
            for (App_Log__c r : errors) {
                String ts = r.Occurred_At__c == null ? '?' : r.Occurred_At__c.format();
                String body = '`' + r.Class_Name__c + '.' + r.Method_Name__c + '` @ ' + ts + '\n'
                    + (r.Message__c == null ? '' : r.Message__c);
                if (body.length() > 2900) body = body.substring(0, 2900) + '...';
                blocks.add(section(body));
                if (String.isNotBlank(r.Correlation_Id__c)) {
                    blocks.add(context('correlation: `' + r.Correlation_Id__c + '`'));
                }
            }
        }

        blocks.add(divider());
        blocks.add(header('Recent Slack events (last 15 min)'));
        if (events == null || events.isEmpty()) {
            blocks.add(section('_No inbound Slack events. Try `/certgame help` to confirm wiring._'));
        } else {
            String txt = '';
            for (Slack_Event_Log__c e : events) {
                String ts = e.Received_At__c == null ? '?' : e.Received_At__c.format();
                txt += '• `' + e.Event_Type__c + '` @ ' + ts
                    + (e.Processed__c ? ' (processed)' : ' (pending)') + '\n';
            }
            blocks.add(section(txt));
        }

        if (!nextSteps.isEmpty()) {
            blocks.add(divider());
            blocks.add(header('Next steps'));
            String steps = '';
            Integer i = 1;
            for (String n : nextSteps) {
                steps += i + '. ' + n + '\n';
                i++;
            }
            blocks.add(section(steps));
        }

        return JSON.serialize(new Map<String, Object>{
            'response_type' => 'ephemeral',
            'text' => 'Cert Game Doctor — ' + score + '/' + max,
            'blocks' => blocks
        });
    }

    // ----- duels -----

    public static String duelChallengeBlocks(String challengerUid, String opponentUid,
                                             Id examId, String examLabel,
                                             String duelGroupId, Integer totalQuestions) {
        List<Object> blocks = new List<Object>();
        blocks.add(header(':crossed_swords: Duel Challenge'));
        blocks.add(section('<@' + challengerUid + '> has challenged <@' + opponentUid + '> to a *'
            + totalQuestions + '-question duel* on *' + examLabel + '*.'));
        blocks.add(context('Each player gets their own random questions. Higher total score wins.'));
        String examIdStr = examId == null ? '' : String.valueOf(examId);
        blocks.add(new Map<String, Object>{
            'type' => 'actions',
            'elements' => new List<Object>{
                new Map<String, Object>{
                    'type' => 'button',
                    'text' => new Map<String, Object>{ 'type' => 'plain_text', 'text' => ':crossed_swords: Accept', 'emoji' => true },
                    'action_id' => 'duel:accept:' + challengerUid + ':' + opponentUid + ':' + examIdStr + ':' + duelGroupId,
                    'style' => 'primary'
                },
                new Map<String, Object>{
                    'type' => 'button',
                    'text' => new Map<String, Object>{ 'type' => 'plain_text', 'text' => 'Decline', 'emoji' => true },
                    'action_id' => 'duel:decline:' + challengerUid + ':' + opponentUid,
                    'style' => 'danger'
                }
            }
        });
        return JSON.serialize(new Map<String, Object>{
            'response_type' => 'in_channel',
            'text' => '<@' + challengerUid + '> challenged <@' + opponentUid + '> to a duel!',
            'blocks' => blocks
        });
    }

    public static String duelStartedBlocks(String challengerUid, String opponentUid,
                                           String examLabel, Integer totalQuestions) {
        List<Object> blocks = new List<Object>();
        blocks.add(header(':crossed_swords: Duel in progress'));
        blocks.add(section('<@' + challengerUid + '> :vs: <@' + opponentUid + '> — *' + totalQuestions
            + ' questions* on *' + examLabel + '*. Check your DMs!'));
        blocks.add(context('Final scoreboard will be posted here when both players finish.'));
        return JSON.serialize(new Map<String, Object>{
            'response_type' => 'in_channel',
            'text' => 'Duel in progress: <@' + challengerUid + '> vs <@' + opponentUid + '>',
            'blocks' => blocks
        });
    }

    public static String duelDeclinedBlocks(String challengerUid, String opponentUid) {
        List<Object> blocks = new List<Object>();
        blocks.add(section(':no_entry_sign: <@' + opponentUid + '> declined <@' + challengerUid + '>\'s duel.'));
        blocks.add(context('No hard feelings — start a quick solo game with `/certgame play`.'));
        return JSON.serialize(new Map<String, Object>{
            'response_type' => 'in_channel',
            'text' => '<@' + opponentUid + '> declined the duel.',
            'blocks' => blocks
        });
    }

    public static String duelFinaleBlocks(String challengerUid, String opponentUid,
                                          Integer challengerPts, Integer opponentPts,
                                          Integer challengerCorrect, Integer opponentCorrect,
                                          Integer totalQuestions, String examLabel, Id examId) {
        Integer cp = challengerPts == null ? 0 : challengerPts;
        Integer op = opponentPts == null ? 0 : opponentPts;
        Integer cc = challengerCorrect == null ? 0 : challengerCorrect;
        Integer oc = opponentCorrect == null ? 0 : opponentCorrect;

        String banner;
        String fallback;
        if (cp > op) {
            banner = ':trophy: *<@' + challengerUid + '> wins the duel!*';
            fallback = '<@' + challengerUid + '> defeats <@' + opponentUid + '>';
        } else if (op > cp) {
            banner = ':trophy: *<@' + opponentUid + '> wins the duel!*';
            fallback = '<@' + opponentUid + '> defeats <@' + challengerUid + '>';
        } else {
            banner = ':handshake: *Tie!* Both players scored the same.';
            fallback = 'Duel tied: <@' + challengerUid + '> vs <@' + opponentUid + '>';
        }

        List<Object> blocks = new List<Object>();
        blocks.add(header(':crossed_swords: Duel Result — ' + examLabel));
        blocks.add(section(banner));
        blocks.add(new Map<String, Object>{
            'type' => 'section',
            'fields' => new List<Object>{
                new Map<String, Object>{ 'type' => 'mrkdwn',
                    'text' => '*<@' + challengerUid + '>*\n' + cp + ' pts • ' + cc + '/' + totalQuestions + ' correct' },
                new Map<String, Object>{ 'type' => 'mrkdwn',
                    'text' => '*<@' + opponentUid + '>*\n' + op + ' pts • ' + oc + '/' + totalQuestions + ' correct' }
            }
        });
        String examIdStr = examId == null ? '' : String.valueOf(examId);
        blocks.add(new Map<String, Object>{
            'type' => 'actions',
            'elements' => new List<Object>{
                new Map<String, Object>{
                    'type' => 'button',
                    'text' => new Map<String, Object>{ 'type' => 'plain_text', 'text' => ':crossed_swords: Rematch', 'emoji' => true },
                    'action_id' => 'duel:rematch:' + challengerUid + ':' + opponentUid + ':' + examIdStr,
                    'style' => 'primary'
                },
                new Map<String, Object>{
                    'type' => 'button',
                    'text' => new Map<String, Object>{ 'type' => 'plain_text', 'text' => ':game_die: Solo game', 'emoji' => true },
                    'action_id' => 'game:newgame'
                }
            }
        });
        return JSON.serialize(new Map<String, Object>{
            'response_type' => 'in_channel',
            'text' => fallback,
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