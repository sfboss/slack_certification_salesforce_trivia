/**
 * Centralized Slack Block Kit JSON builder. All user-facing Slack UI lives here.
 * Strings are sourced from CertGameStrings.
 * action_id format: `domain:verb:resourceId`, e.g. `game:answer:a01R0000...`.
 */
public with sharing class CertGameSlackRenderService {
    public static String help() {
        List<Object> blocks = new List<Object>();
        blocks.add(header(':mortar_board:  Certification Trivia'));
        blocks.add(
            context('Salesforce certs, scored. Fast rounds. No leaving Slack.')
        );
        blocks.add(
            new Map<String, Object>{
                'type' => 'actions',
                'elements' => new List<Object>{
                    new Map<String, Object>{
                        'type' => 'button',
                        'style' => 'primary',
                        'text' => new Map<String, Object>{
                            'type' => 'plain_text',
                            'text' => ':zap:  Play now',
                            'emoji' => true
                        },
                        'action_id' => 'game:newgame'
                    },
                    new Map<String, Object>{
                        'type' => 'button',
                        'text' => new Map<String, Object>{
                            'type' => 'plain_text',
                            'text' => ':books:  Browse exams',
                            'emoji' => true
                        },
                        'action_id' => 'home:games:run'
                    },
                    new Map<String, Object>{
                        'type' => 'button',
                        'text' => new Map<String, Object>{
                            'type' => 'plain_text',
                            'text' => ':dart:  Study plan',
                            'emoji' => true
                        },
                        'action_id' => 'plan:open'
                    }
                }
            }
        );
        blocks.add(divider());
        blocks.add(
            new Map<String, Object>{
                'type' => 'rich_text',
                'elements' => new List<Object>{
                    new Map<String, Object>{
                        'type' => 'rich_text_quote',
                        'elements' => new List<Object>{
                            new Map<String, Object>{
                                'type' => 'text',
                                'text' => 'How it works: ',
                                'style' => new Map<String, Object>{
                                    'bold' => true
                                }
                            },
                            new Map<String, Object>{
                                'type' => 'text',
                                'text' => '5-question rounds drawn from published banks. '
                            },
                            new Map<String, Object>{
                                'type' => 'text',
                                'text' => 'Score = base (by difficulty) + speed bonus + streak bonus. '
                            },
                            new Map<String, Object>{
                                'type' => 'text',
                                'text' => 'Wrong answers reset your streak.'
                            }
                        }
                    }
                }
            }
        );
        blocks.add(divider());
        blocks.add(
            new Map<String, Object>{
                'type' => 'actions',
                'elements' => new List<Object>{
                    new Map<String, Object>{
                        'type' => 'button',
                        'text' => new Map<String, Object>{
                            'type' => 'plain_text',
                            'text' => 'Show all commands',
                            'emoji' => true
                        },
                        'action_id' => 'help:show:commands'
                    }
                }
            }
        );
        blocks.add(
            context(
                ':gear: v0.9  ·  <https://github.com/sfboss/slack_certification_salesforce_trivia|:question:  Docs>'
            )
        );
        return JSON.serialize(
            new Map<String, Object>{
                'response_type' => 'ephemeral',
                'text' => CertGameStrings.HELP_TEXT,
                'blocks' => blocks
            }
        );
    }

    /**
     * Opens the full command reference as a modal via views.open. Triggered from
     * the help card's "Show all commands" button (action_id `help:show:commands`).
     * Returns empty string — the modal is delivered out-of-band via the Slack API.
     */
    public static String helpCommandsModal(String triggerId) {
        if (String.isBlank(triggerId))
            return '';
        Map<String, Object> view = new Map<String, Object>{
            'type' => 'modal',
            'callback_id' => 'help:commands',
            'title' => new Map<String, Object>{
                'type' => 'plain_text',
                'text' => 'CertGame Commands',
                'emoji' => true
            },
            'close' => new Map<String, Object>{
                'type' => 'plain_text',
                'text' => 'Close',
                'emoji' => true
            },
            'blocks' => buildCommandRefBlocks()
        };
        SlackApiClient.openView(triggerId, view);
        return '';
    }

    private static List<Object> buildCommandRefBlocks() {
        List<Object> blocks = new List<Object>();
        addCommandGroup(
            blocks,
            ':zap:  Play',
            new List<List<String>>{
                new List<String>{
                    '/certgame play [CODE]',
                    'Start a 5-question solo round. Omit `CODE` to auto-pick.'
                },
                new List<String>{
                    '/certgame challenge @user [CODE]',
                    'Head-to-head duel in this channel. Alias: `/certgame duel`.'
                }
            }
        );
        blocks.add(divider());
        addCommandGroup(
            blocks,
            ':bar_chart:  Stats & progress',
            new List<List<String>>{
                new List<String>{
                    '/certgame stats',
                    'Your accuracy, streak, and lifetime points.'
                },
                new List<String>{
                    '/certgame leaderboard [CODE]',
                    'Top scorers, optionally scoped to a cert.'
                },
                new List<String>{
                    '/certgame games',
                    'List configured exams + question counts.'
                },
                new List<String>{
                    '/certgame plan',
                    'Open the study plan modal.'
                }
            }
        );
        blocks.add(divider());
        addCommandGroup(
            blocks,
            ':gear:  Admin',
            new List<List<String>>{
                new List<String>{
                    '/certgame billing',
                    'Manage workspace plan (admins only).'
                }
            }
        );
        blocks.add(divider());
        addCommandGroup(
            blocks,
            ':wrench:  Diagnostics',
            new List<List<String>>{
                new List<String>{
                    '/certgame doctor',
                    'Run setup + health checks.'
                },
                new List<String>{
                    '/certgame notify-test',
                    'DM yourself a self-test card.'
                },
                new List<String>{
                    '/certgame debug',
                    'Last hour of `App_Log__c` entries.'
                }
            }
        );
        return blocks;
    }

    private static void addCommandGroup(
        List<Object> blocks,
        String title,
        List<List<String>> entries
    ) {
        blocks.add(header(title));
        for (List<String> e : entries) {
            blocks.add(
                new Map<String, Object>{
                    'type' => 'rich_text',
                    'elements' => new List<Object>{
                        new Map<String, Object>{
                            'type' => 'rich_text_preformatted',
                            'elements' => new List<Object>{
                                new Map<String, Object>{
                                    'type' => 'text',
                                    'text' => e[0]
                                }
                            }
                        }
                    }
                }
            );
            blocks.add(context(e[1]));
        }
    }

    public static String text(String message, Boolean ephemeral) {
        return JSON.serialize(
            new Map<String, Object>{
                'response_type' => (ephemeral ? 'ephemeral' : 'in_channel'),
                'text' => message
            }
        );
    }

    /**
     * Rich ephemeral error card visible only to the invoking user. Includes a copy-pasteable
     * correlation id so the operator can pull the full stack from App_Log__c.
     */
    public static String errorEnvelope(
        String subcommand,
        String correlationId,
        Exception e
    ) {
        String safeSub = String.isBlank(subcommand)
            ? '/certgame'
            : '/certgame ' + subcommand;
        String type = e == null ? 'UnknownError' : e.getTypeName();
        String msg = e == null
            ? 'no exception message'
            : (e.getMessage() == null ? '' : e.getMessage());
        if (msg.length() > 300)
            msg = msg.substring(0, 300) + '...';
        String corr = String.isBlank(correlationId) ? 'n/a' : correlationId;
        List<Object> blocks = new List<Object>();
        blocks.add(section(':warning: *' + safeSub + '* failed.'));
        blocks.add(section('*Error:* `' + type + '`\n*Detail:* ' + msg));
        blocks.add(
            context(
                'Correlation id: `' +
                    corr +
                    '` — paste into App_Log__c.Correlation_Id__c to retrieve the stack trace.'
            )
        );
        return JSON.serialize(
            new Map<String, Object>{
                'response_type' => 'ephemeral',
                'text' => safeSub +
                ' failed: ' +
                type,
                'blocks' => blocks
            }
        );
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
                String occurredAt = r.Occurred_At__c == null
                    ? '?'
                    : r.Occurred_At__c.format();
                String body =
                    '*[' +
                    r.Level__c +
                    ']* ' +
                    occurredAt +
                    '\n' +
                    '`' +
                    r.Class_Name__c +
                    '.' +
                    r.Method_Name__c +
                    '`\n' +
                    (r.Message__c == null ? '' : r.Message__c);
                if (body.length() > 2900)
                    body = body.substring(0, 2900) + '...';
                blocks.add(section(body));
                if (String.isNotBlank(r.Correlation_Id__c)) {
                    blocks.add(
                        context('correlation: `' + r.Correlation_Id__c + '`')
                    );
                }
                blocks.add(divider());
            }
        }
        return JSON.serialize(
            new Map<String, Object>{
                'response_type' => 'ephemeral',
                'text' => 'Recent Cert Game logs',
                'blocks' => blocks
            }
        );
    }

    /**
     * Quick-play game prompt with answer buttons.
     * @param questionText Question prompt
     * @param choices List<Map> with keys: id, label, text
     */
    public static String questionBlocks(
        String roundId,
        String questionText,
        List<Map<String, Object>> choices,
        Integer secondsRemaining
    ) {
        return questionBlocks(
            roundId,
            questionText,
            choices,
            secondsRemaining,
            null,
            null,
            null
        );
    }

    public static String questionBlocks(
        String roundId,
        String questionText,
        List<Map<String, Object>> choices,
        Integer secondsRemaining,
        Integer qNum,
        Integer totalQ,
        String difficulty
    ) {
        List<Object> blocks = new List<Object>();
        String headerTxt = (qNum != null &&
            totalQ != null)
            ? 'Question ' + qNum + ' of ' + totalQ
            : 'Question';
        blocks.add(header(':brain:  ' + headerTxt));

        // Metadata strip: difficulty pill · timer · progress dots
        List<Object> metaEls = new List<Object>();
        if (String.isNotBlank(difficulty)) {
            metaEls.add(
                new Map<String, Object>{
                    'type' => 'mrkdwn',
                    'text' => '`' +
                    difficulty +
                    '`'
                }
            );
        }
        if (secondsRemaining != null) {
            if (!metaEls.isEmpty())
                metaEls.add(
                    new Map<String, Object>{ 'type' => 'mrkdwn', 'text' => '•' }
                );
            metaEls.add(
                new Map<String, Object>{
                    'type' => 'mrkdwn',
                    'text' => ':hourglass_flowing_sand: ' +
                    secondsRemaining +
                    's'
                }
            );
        }
        if (qNum != null && totalQ != null) {
            if (!metaEls.isEmpty())
                metaEls.add(
                    new Map<String, Object>{ 'type' => 'mrkdwn', 'text' => '•' }
                );
            metaEls.add(
                new Map<String, Object>{
                    'type' => 'mrkdwn',
                    'text' => progressDots(qNum, totalQ)
                }
            );
        }
        if (!metaEls.isEmpty()) {
            blocks.add(
                new Map<String, Object>{
                    'type' => 'context',
                    'elements' => metaEls
                }
            );
        }

        blocks.add(divider());

        // Question stem
        blocks.add(
            new Map<String, Object>{
                'type' => 'section',
                'text' => new Map<String, Object>{
                    'type' => 'mrkdwn',
                    'text' => '*' +
                    questionText +
                    '*'
                }
            }
        );

        // Each choice gets its own section row with a "Select X" accessory button.
        for (Map<String, Object> c : choices) {
            String label = (String) c.get('label');
            String text = truncate((String) c.get('text'), 140);
            blocks.add(
                new Map<String, Object>{
                    'type' => 'section',
                    'text' => new Map<String, Object>{
                        'type' => 'mrkdwn',
                        'text' => '*' +
                        label +
                        '.*  ' +
                        text
                    },
                    'accessory' => new Map<String, Object>{
                        'type' => 'button',
                        'text' => new Map<String, Object>{
                            'type' => 'plain_text',
                            'text' => 'Select ' + label,
                            'emoji' => true
                        },
                        'action_id' => 'game:answer:' +
                        roundId +
                        ':' +
                        c.get('id'),
                        'value' => (String) c.get('id')
                    }
                }
            );
        }

        blocks.add(divider());
        blocks.add(
            context(':zap: Lock in your answer — partial credit for speed.')
        );
        return JSON.serialize(
            new Map<String, Object>{
                'response_type' => 'in_channel',
                'text' => 'Question ' +
                (qNum == null ? '' : (qNum + ' of ' + totalQ)),
                'blocks' => blocks
            }
        );
    }

    private static String progressDots(Integer cur, Integer total) {
        if (cur == null || total == null || total <= 0)
            return '';
        String s = '';
        for (Integer i = 1; i <= total; i++)
            s += (i <= cur ? '●' : '○');
        return s;
    }

    public static String resultBlocks(
        Boolean correct,
        String correctChoiceText,
        Integer pointsAwarded,
        List<Map<String, Object>> citations
    ) {
        return resultBlocks(
            correct,
            correctChoiceText,
            pointsAwarded,
            citations,
            null,
            null,
            null,
            null
        );
    }

    public static String resultBlocks(
        Boolean correct,
        String correctChoiceText,
        Integer pointsAwarded,
        List<Map<String, Object>> citations,
        String explanation,
        Integer runningPoints,
        Integer correctCount,
        Integer answeredCount
    ) {
        List<Object> blocks = new List<Object>();
        blocks.add(
            header(correct ? ':white_check_mark:  Correct!' : ':x:  Not quite')
        );

        // Graded-review body: rich_text_quote provides a left vertical bar so the
        // result reads like a scored exam item rather than a chat reply.
        List<Object> quoteEls = new List<Object>();
        if (correct) {
            quoteEls.add(
                new Map<String, Object>{
                    'type' => 'text',
                    'text' => '+' +
                    (pointsAwarded == null ? 0 : pointsAwarded) +
                    ' points',
                    'style' => new Map<String, Object>{ 'bold' => true }
                }
            );
            quoteEls.add(
                new Map<String, Object>{
                    'type' => 'text',
                    'text' => ' — well played.'
                }
            );
        } else {
            quoteEls.add(
                new Map<String, Object>{
                    'type' => 'text',
                    'text' => 'Correct answer: ',
                    'style' => new Map<String, Object>{ 'bold' => true }
                }
            );
            quoteEls.add(
                new Map<String, Object>{
                    'type' => 'text',
                    'text' => correctChoiceText == null ? '' : correctChoiceText
                }
            );
        }
        if (String.isNotBlank(explanation)) {
            quoteEls.add(
                new Map<String, Object>{ 'type' => 'text', 'text' => '\n\n' }
            );
            quoteEls.add(
                new Map<String, Object>{
                    'type' => 'text',
                    'text' => truncate(explanation, 800)
                }
            );
        }
        blocks.add(
            new Map<String, Object>{
                'type' => 'rich_text',
                'elements' => new List<Object>{
                    new Map<String, Object>{
                        'type' => 'rich_text_quote',
                        'elements' => quoteEls
                    }
                }
            }
        );

        // Compact score strip — one line, dot-separated, no headers stealing weight.
        List<Object> scoreEls = new List<Object>();
        if (runningPoints != null) {
            scoreEls.add(
                new Map<String, Object>{
                    'type' => 'mrkdwn',
                    'text' => ':zap:  *Score:* ' +
                    runningPoints +
                    ' pts'
                }
            );
        }
        if (
            correctCount != null &&
            answeredCount != null &&
            answeredCount > 0
        ) {
            Integer pct = (correctCount * 100) / answeredCount;
            if (!scoreEls.isEmpty())
                scoreEls.add(
                    new Map<String, Object>{ 'type' => 'mrkdwn', 'text' => '•' }
                );
            scoreEls.add(
                new Map<String, Object>{
                    'type' => 'mrkdwn',
                    'text' => '*Accuracy:* ' +
                    correctCount +
                    '/' +
                    answeredCount +
                    ' (' +
                    pct +
                    '%)'
                }
            );
        }
        if (!scoreEls.isEmpty()) {
            blocks.add(
                new Map<String, Object>{
                    'type' => 'context',
                    'elements' => scoreEls
                }
            );
        }

        // Sources as a single context line — footnote weight, not a heading.
        if (citations != null && !citations.isEmpty()) {
            String txt = ':books:  ';
            Boolean first = true;
            for (Map<String, Object> c : citations) {
                if (!first)
                    txt += ' · ';
                txt += '<' + c.get('url') + '|' + c.get('title') + '>';
                first = false;
            }
            blocks.add(context(txt));
        }
        return JSON.serialize(
            new Map<String, Object>{
                'response_type' => 'in_channel',
                'replace_original' => true,
                'blocks' => blocks
            }
        );
    }

    public static String gameOverBlocks(
        Integer totalPoints,
        Integer correctCount,
        Integer totalQ,
        String examCode
    ) {
        return gameOverBlocks(
            totalPoints,
            correctCount,
            totalQ,
            examCode,
            null,
            null
        );
    }

    public static String gameOverBlocks(
        Integer totalPoints,
        Integer correctCount,
        Integer totalQ,
        String examCode,
        Id playerId,
        Id examId
    ) {
        List<Object> blocks = new List<Object>();
        blocks.add(header(':checkered_flag: Game Over'));
        Integer pct = totalQ == null ||
            totalQ == 0
            ? 0
            : (correctCount * 100) / totalQ;
        Map<String, Object> body = new Map<String, Object>{
            'type' => 'section',
            'text' => new Map<String, Object>{
                'type' => 'mrkdwn',
                'text' => '*Nice run!* Here are your results:'
            },
            'fields' => new List<Object>{
                new Map<String, Object>{
                    'type' => 'mrkdwn',
                    'text' => '*Final score*\n' +
                    (totalPoints == null ? 0 : totalPoints) +
                    ' pts'
                },
                new Map<String, Object>{
                    'type' => 'mrkdwn',
                    'text' => '*Correct*\n' +
                    correctCount +
                    ' / ' +
                    totalQ
                },
                new Map<String, Object>{
                    'type' => 'mrkdwn',
                    'text' => '*Accuracy*\n' +
                    pct +
                    '%'
                }
            }
        };
        blocks.add(body);
        blocks.add(divider());
        String newGameId =
            'game:newgame' + (String.isBlank(examCode) ? '' : (':' + examCode));
        List<Object> actionEls = new List<Object>{
            new Map<String, Object>{
                'type' => 'button',
                'text' => new Map<String, Object>{
                    'type' => 'plain_text',
                    'text' => ':game_die: Play again',
                    'emoji' => true
                },
                'action_id' => newGameId,
                'style' => 'primary'
            },
            new Map<String, Object>{
                'type' => 'button',
                'text' => new Map<String, Object>{
                    'type' => 'plain_text',
                    'text' => 'Leaderboard',
                    'emoji' => true
                },
                'action_id' => 'home:leaderboard:run'
            },
            new Map<String, Object>{
                'type' => 'button',
                'text' => new Map<String, Object>{
                    'type' => 'plain_text',
                    'text' => 'List games',
                    'emoji' => true
                },
                'action_id' => 'home:games:run'
            }
        };
        if (playerId != null) {
            String reportUrl = CertGameReadinessReportController.mintReportUrl(
                playerId,
                examId
            );
            if (String.isNotBlank(reportUrl)) {
                actionEls.add(
                    new Map<String, Object>{
                        'type' => 'button',
                        'text' => new Map<String, Object>{
                            'type' => 'plain_text',
                            'text' => ':notebook: Open Study Guide',
                            'emoji' => true
                        },
                        'action_id' => 'report:view',
                        'style' => 'primary',
                        'url' => reportUrl
                    }
                );
            }
        }
        blocks.add(
            new Map<String, Object>{
                'type' => 'actions',
                'elements' => actionEls
            }
        );
        return JSON.serialize(
            new Map<String, Object>{
                'response_type' => 'in_channel',
                'text' => 'Game over — ' +
                (totalPoints == null ? 0 : totalPoints) +
                ' pts',
                'blocks' => blocks
            }
        );
    }

    public static String alreadyAnsweredBlocks() {
        List<Object> blocks = new List<Object>();
        blocks.add(
            section(
                ':information_source: *You already answered this round.*\nStart a fresh game to keep going.'
            )
        );
        blocks.add(
            new Map<String, Object>{
                'type' => 'actions',
                'elements' => new List<Object>{
                    new Map<String, Object>{
                        'type' => 'button',
                        'text' => new Map<String, Object>{
                            'type' => 'plain_text',
                            'text' => ':game_die: Play again',
                            'emoji' => true
                        },
                        'action_id' => 'game:newgame',
                        'style' => 'primary'
                    },
                    new Map<String, Object>{
                        'type' => 'button',
                        'text' => new Map<String, Object>{
                            'type' => 'plain_text',
                            'text' => 'List games',
                            'emoji' => true
                        },
                        'action_id' => 'home:games:run'
                    }
                }
            }
        );
        return JSON.serialize(
            new Map<String, Object>{
                'response_type' => 'ephemeral',
                'text' => CertGameStrings.ALREADY_ANSWERED,
                'blocks' => blocks
            }
        );
    }

    public static String leaderboardBlocks(
        String title,
        List<Map<String, Object>> rows
    ) {
        List<Object> blocks = new List<Object>();
        blocks.add(header(title));
        String txt = '';
        Integer rank = 1;
        for (Map<String, Object> r : rows) {
            txt +=
                String.valueOf(rank++) +
                '. *' +
                r.get('name') +
                '* — ' +
                r.get('points') +
                ' pts\n';
        }
        blocks.add(section(txt == '' ? '_No scores yet._' : txt));
        return JSON.serialize(
            new Map<String, Object>{
                'response_type' => 'in_channel',
                'blocks' => blocks
            }
        );
    }

    public static String appHomeView(Map<String, Object> data) {
        List<Object> blocks = new List<Object>();
        blocks.add(header('Cert Game'));
        blocks.add(
            section(
                'Welcome back! Use `/certgame play` to start a quick game, or pick an action below.'
            )
        );
        blocks.add(divider());
        blocks.add(
            new Map<String, Object>{
                'type' => 'actions',
                'elements' => new List<Object>{
                    new Map<String, Object>{
                        'type' => 'button',
                        'text' => new Map<String, Object>{
                            'type' => 'plain_text',
                            'text' => 'Open Study Plan',
                            'emoji' => true
                        },
                        'action_id' => 'plan:open',
                        'style' => 'primary'
                    },
                    new Map<String, Object>{
                        'type' => 'button',
                        'text' => new Map<String, Object>{
                            'type' => 'plain_text',
                            'text' => ':notebook: Study Guide',
                            'emoji' => true
                        },
                        'action_id' => 'report:open'
                    },
                    new Map<String, Object>{
                        'type' => 'button',
                        'text' => new Map<String, Object>{
                            'type' => 'plain_text',
                            'text' => 'Run Doctor',
                            'emoji' => true
                        },
                        'action_id' => 'home:doctor:run'
                    },
                    new Map<String, Object>{
                        'type' => 'button',
                        'text' => new Map<String, Object>{
                            'type' => 'plain_text',
                            'text' => 'Test notifications',
                            'emoji' => true
                        },
                        'action_id' => 'home:notify:run'
                    },
                    new Map<String, Object>{
                        'type' => 'button',
                        'text' => new Map<String, Object>{
                            'type' => 'plain_text',
                            'text' => 'List games',
                            'emoji' => true
                        },
                        'action_id' => 'home:games:run'
                    }
                }
            }
        );
        blocks.add(
            context(
                'Tip: the Study Guide shows your accuracy, weak domains, and timing trends - pulled from your real play data.'
            )
        );
        return JSON.serialize(
            new Map<String, Object>{ 'type' => 'home', 'blocks' => blocks }
        );
    }

    /**
     * Ephemeral card listing available certification exams + question counts per status.
     */
    public static String gamesList(
        List<CertGameExamCatalogService.ExamSummary> rows
    ) {
        List<Object> blocks = new List<Object>();
        blocks.add(header('Available games'));
        if (rows == null || rows.isEmpty()) {
            blocks.add(
                section(
                    '_No certification exams are configured yet. Admins: open the Cert Game Admin Home tab to import a question pack._'
                )
            );
        } else {
            for (CertGameExamCatalogService.ExamSummary s : rows) {
                String code = String.isBlank(s.code) ? '(no code)' : s.code;
                String status = s.active == true
                    ? ':white_check_mark: active'
                    : ':grey_exclamation: inactive';
                String counts =
                    s.published +
                    ' published / ' +
                    s.reviewed +
                    ' reviewed / ' +
                    s.draft +
                    ' draft';
                Boolean playable =
                    s.published > 0 &&
                    s.active == true &&
                    !String.isBlank(s.code);
                String cta = playable
                    ? '\n_Click *Play* or run `/certgame play ' + code + '`._'
                    : (s.published == 0
                          ? '\n_No published questions yet — ask an admin to publish drafts._'
                          : (s.active != true
                                ? '\n_Exam is inactive — admin can re-activate it in Salesforce._'
                                : '\n_Missing certification code — admin must set one to enable play._'));
                Map<String, Object> sec = new Map<String, Object>{
                    'type' => 'section',
                    'text' => new Map<String, Object>{
                        'type' => 'mrkdwn',
                        'text' => '*' +
                        code +
                        '* — ' +
                        s.name +
                        '\n' +
                        status +
                        ' · ' +
                        counts +
                        cta
                    }
                };
                if (playable) {
                    sec.put(
                        'accessory',
                        new Map<String, Object>{
                            'type' => 'button',
                            'text' => new Map<String, Object>{
                                'type' => 'plain_text',
                                'text' => ':game_die: Play',
                                'emoji' => true
                            },
                            'action_id' => 'game:newgame:' + code,
                            'value' => code,
                            'style' => 'primary'
                        }
                    );
                }
                blocks.add(sec);
            }
        }
        blocks.add(
            context(
                'Need to add an exam? Admins: import a JSON question pack from the Cert Game Admin Home tab.'
            )
        );
        return JSON.serialize(
            new Map<String, Object>{
                'response_type' => 'ephemeral',
                'text' => 'Available games',
                'blocks' => blocks
            }
        );
    }

    /**
     * Ephemeral status card for the notification self-test.
     */
    public static String notifyTestResult(Boolean ok, String detail) {
        List<Object> blocks = new List<Object>();
        blocks.add(
            section(
                ok
                    ? ':white_check_mark: *Notification test sent.*'
                    : ':no_entry: *Notification test failed.*'
            )
        );
        blocks.add(section(detail == null ? '' : detail));
        if (!ok) {
            blocks.add(
                context(
                    'Run `/certgame doctor` to inspect recent server errors and pinpoint the cause.'
                )
            );
        }
        return JSON.serialize(
            new Map<String, Object>{
                'response_type' => 'ephemeral',
                'text' => ok
                    ? 'Notification test sent.'
                    : 'Notification test failed.',
                'blocks' => blocks
            }
        );
    }

    /**
     * Block Kit doctor report — preflight check results, recent errors, and recent Slack events.
     */
    public static String doctorReport(
        String teamId,
        Integer score,
        Integer max,
        List<CertGameDoctorService.Check> checks,
        List<App_Log__c> errors,
        List<Slack_Event_Log__c> events
    ) {
        List<Object> blocks = new List<Object>();
        String emoji = score == max
            ? ':white_check_mark:'
            : (score >= max - 1 ? ':warning:' : ':no_entry:');
        blocks.add(
            header('Cert Game Doctor — ' + score + '/' + max + ' ' + emoji)
        );
        blocks.add(
            context(
                'Slack team `' +
                    (teamId == null ? '?' : teamId) +
                    '`  ·  ' +
                    System.now().format() +
                    ' (org local time)'
            )
        );
        blocks.add(divider());

        List<String> nextSteps = new List<String>();
        for (CertGameDoctorService.Check c : checks) {
            String icon = c.status == 'OK'
                ? ':white_check_mark:'
                : c.status == 'WARN' ? ':warning:' : ':no_entry:';
            String body =
                icon +
                ' *' +
                c.title +
                '* — ' +
                (c.detail == null ? '' : c.detail);
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
                String ts = r.Occurred_At__c == null
                    ? '?'
                    : r.Occurred_At__c.format();
                String body =
                    '`' +
                    r.Class_Name__c +
                    '.' +
                    r.Method_Name__c +
                    '` @ ' +
                    ts +
                    '\n' +
                    (r.Message__c == null ? '' : r.Message__c);
                if (body.length() > 2900)
                    body = body.substring(0, 2900) + '...';
                blocks.add(section(body));
                if (String.isNotBlank(r.Correlation_Id__c)) {
                    blocks.add(
                        context('correlation: `' + r.Correlation_Id__c + '`')
                    );
                }
            }
        }

        blocks.add(divider());
        blocks.add(header('Recent Slack events (last 15 min)'));
        if (events == null || events.isEmpty()) {
            blocks.add(
                section(
                    '_No inbound Slack events. Try `/certgame help` to confirm wiring._'
                )
            );
        } else {
            String txt = '';
            for (Slack_Event_Log__c e : events) {
                String ts = e.Received_At__c == null
                    ? '?'
                    : e.Received_At__c.format();
                txt +=
                    '• `' +
                    e.Event_Type__c +
                    '` @ ' +
                    ts +
                    (e.Processed__c ? ' (processed)' : ' (pending)') +
                    '\n';
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

        return JSON.serialize(
            new Map<String, Object>{
                'response_type' => 'ephemeral',
                'text' => 'Cert Game Doctor — ' +
                score +
                '/' +
                max,
                'blocks' => blocks
            }
        );
    }

    // ----- duels -----

    public static String duelChallengeBlocks(
        String challengerUid,
        String opponentUid,
        Id examId,
        String examLabel,
        String duelGroupId,
        Integer totalQuestions
    ) {
        List<Object> blocks = new List<Object>();
        blocks.add(header(':crossed_swords: Duel Challenge'));
        blocks.add(
            section(
                '<@' +
                    challengerUid +
                    '> has challenged <@' +
                    opponentUid +
                    '> to a *' +
                    totalQuestions +
                    '-question duel* on *' +
                    examLabel +
                    '*.'
            )
        );
        blocks.add(
            context(
                'Each player gets their own random questions. Higher total score wins.'
            )
        );
        String examIdStr = examId == null ? '' : String.valueOf(examId);
        blocks.add(
            new Map<String, Object>{
                'type' => 'actions',
                'elements' => new List<Object>{
                    new Map<String, Object>{
                        'type' => 'button',
                        'text' => new Map<String, Object>{
                            'type' => 'plain_text',
                            'text' => ':crossed_swords: Accept',
                            'emoji' => true
                        },
                        'action_id' => 'duel:accept:' +
                        challengerUid +
                        ':' +
                        opponentUid +
                        ':' +
                        examIdStr +
                        ':' +
                        duelGroupId,
                        'style' => 'primary'
                    },
                    new Map<String, Object>{
                        'type' => 'button',
                        'text' => new Map<String, Object>{
                            'type' => 'plain_text',
                            'text' => 'Decline',
                            'emoji' => true
                        },
                        'action_id' => 'duel:decline:' +
                        challengerUid +
                        ':' +
                        opponentUid,
                        'style' => 'danger'
                    }
                }
            }
        );
        return JSON.serialize(
            new Map<String, Object>{
                'response_type' => 'in_channel',
                'text' => '<@' +
                challengerUid +
                '> challenged <@' +
                opponentUid +
                '> to a duel!',
                'blocks' => blocks
            }
        );
    }

    public static String duelStartedBlocks(
        String challengerUid,
        String opponentUid,
        String examLabel,
        Integer totalQuestions
    ) {
        List<Object> blocks = new List<Object>();
        blocks.add(header(':crossed_swords: Duel in progress'));
        blocks.add(
            section(
                '<@' +
                    challengerUid +
                    '> :vs: <@' +
                    opponentUid +
                    '> — *' +
                    totalQuestions +
                    ' questions* on *' +
                    examLabel +
                    '*. Check your DMs!'
            )
        );
        blocks.add(
            context(
                'Final scoreboard will be posted here when both players finish.'
            )
        );
        return JSON.serialize(
            new Map<String, Object>{
                'response_type' => 'in_channel',
                'text' => 'Duel in progress: <@' +
                challengerUid +
                '> vs <@' +
                opponentUid +
                '>',
                'blocks' => blocks
            }
        );
    }

    public static String duelDeclinedBlocks(
        String challengerUid,
        String opponentUid
    ) {
        List<Object> blocks = new List<Object>();
        blocks.add(
            section(
                ':no_entry_sign: <@' +
                    opponentUid +
                    '> declined <@' +
                    challengerUid +
                    '>\'s duel.'
            )
        );
        blocks.add(
            context(
                'No hard feelings — start a quick solo game with `/certgame play`.'
            )
        );
        return JSON.serialize(
            new Map<String, Object>{
                'response_type' => 'in_channel',
                'text' => '<@' +
                opponentUid +
                '> declined the duel.',
                'blocks' => blocks
            }
        );
    }

    public static String duelFinaleBlocks(
        String challengerUid,
        String opponentUid,
        Integer challengerPts,
        Integer opponentPts,
        Integer challengerCorrect,
        Integer opponentCorrect,
        Integer totalQuestions,
        String examLabel,
        Id examId
    ) {
        Integer cp = challengerPts == null ? 0 : challengerPts;
        Integer op = opponentPts == null ? 0 : opponentPts;
        Integer cc = challengerCorrect == null ? 0 : challengerCorrect;
        Integer oc = opponentCorrect == null ? 0 : opponentCorrect;

        String banner;
        String fallback;
        if (cp > op) {
            banner = ':trophy: *<@' + challengerUid + '> wins the duel!*';
            fallback =
                '<@' +
                challengerUid +
                '> defeats <@' +
                opponentUid +
                '>';
        } else if (op > cp) {
            banner = ':trophy: *<@' + opponentUid + '> wins the duel!*';
            fallback =
                '<@' +
                opponentUid +
                '> defeats <@' +
                challengerUid +
                '>';
        } else {
            banner = ':handshake: *Tie!* Both players scored the same.';
            fallback =
                'Duel tied: <@' +
                challengerUid +
                '> vs <@' +
                opponentUid +
                '>';
        }

        List<Object> blocks = new List<Object>();
        blocks.add(header(':crossed_swords: Duel Result — ' + examLabel));
        blocks.add(section(banner));
        blocks.add(
            new Map<String, Object>{
                'type' => 'section',
                'fields' => new List<Object>{
                    new Map<String, Object>{
                        'type' => 'mrkdwn',
                        'text' => '*<@' +
                        challengerUid +
                        '>*\n' +
                        cp +
                        ' pts • ' +
                        cc +
                        '/' +
                        totalQuestions +
                        ' correct'
                    },
                    new Map<String, Object>{
                        'type' => 'mrkdwn',
                        'text' => '*<@' +
                        opponentUid +
                        '>*\n' +
                        op +
                        ' pts • ' +
                        oc +
                        '/' +
                        totalQuestions +
                        ' correct'
                    }
                }
            }
        );
        String examIdStr = examId == null ? '' : String.valueOf(examId);
        blocks.add(
            new Map<String, Object>{
                'type' => 'actions',
                'elements' => new List<Object>{
                    new Map<String, Object>{
                        'type' => 'button',
                        'text' => new Map<String, Object>{
                            'type' => 'plain_text',
                            'text' => ':crossed_swords: Rematch',
                            'emoji' => true
                        },
                        'action_id' => 'duel:rematch:' +
                        challengerUid +
                        ':' +
                        opponentUid +
                        ':' +
                        examIdStr,
                        'style' => 'primary'
                    },
                    new Map<String, Object>{
                        'type' => 'button',
                        'text' => new Map<String, Object>{
                            'type' => 'plain_text',
                            'text' => ':game_die: Solo game',
                            'emoji' => true
                        },
                        'action_id' => 'game:newgame'
                    }
                }
            }
        );
        return JSON.serialize(
            new Map<String, Object>{
                'response_type' => 'in_channel',
                'text' => fallback,
                'blocks' => blocks
            }
        );
    }

    /**
     * Ephemeral Study Guide card: one URL button per active theme. Posted in response
     * to `/certgame report` and to the App Home `report:open` block_action.
     * If examId is null the report falls back to "all exams played" via the service layer.
     * The default theme is rendered first with primary style; remaining themes follow.
     */
    public static String studyGuideCard(
        Id playerId,
        Id examId,
        List<CertGameReadinessReportService.ThemeOption> themes
    ) {
        List<Object> blocks = new List<Object>();
        blocks.add(header(':notebook:  Your Study Guide'));
        blocks.add(
            section(
                'A personalized readiness report built from your accuracy, streaks, and weakest domains. Pick a theme to open it in your browser.'
            )
        );
        blocks.add(divider());

        List<Object> actionElements = new List<Object>();
        Boolean rendered = false;

        if (themes != null && !themes.isEmpty()) {
            // Default first, then remaining; cap at 5 so the actions block stays clean.
            List<CertGameReadinessReportService.ThemeOption> ordered = new List<CertGameReadinessReportService.ThemeOption>();
            for (CertGameReadinessReportService.ThemeOption t : themes)
                if (t.isDefault)
                    ordered.add(t);
            for (CertGameReadinessReportService.ThemeOption t : themes)
                if (!t.isDefault)
                    ordered.add(t);
            Integer cap = Math.min(5, ordered.size());
            for (Integer i = 0; i < cap; i++) {
                CertGameReadinessReportService.ThemeOption t = ordered[i];
                String url = CertGameReadinessReportController.mintReportUrl(
                    playerId,
                    examId,
                    t.key
                );
                String label = String.isBlank(t.name) ? t.key : t.name;
                Map<String, Object> btn = new Map<String, Object>{
                    'type' => 'button',
                    'text' => new Map<String, Object>{
                        'type' => 'plain_text',
                        'text' => ':rocket:  ' + truncate(label, 70),
                        'emoji' => true
                    },
                    'url' => url,
                    'action_id' => 'report:open:' + t.key
                };
                if (i == 0)
                    btn.put('style', 'primary');
                actionElements.add(btn);
                rendered = true;
            }
        }

        if (!rendered) {
            // No themes seeded yet - fall back to a single button using the legacy template.
            String url = CertGameReadinessReportController.mintReportUrl(
                playerId,
                examId,
                null
            );
            actionElements.add(
                new Map<String, Object>{
                    'type' => 'button',
                    'style' => 'primary',
                    'text' => new Map<String, Object>{
                        'type' => 'plain_text',
                        'text' => ':rocket:  Open Study Guide',
                        'emoji' => true
                    },
                    'url' => url,
                    'action_id' => 'report:open:default'
                }
            );
        }

        blocks.add(
            new Map<String, Object>{
                'type' => 'actions',
                'elements' => actionElements
            }
        );
        blocks.add(
            context(
                ':lock: Link is signed to you and expires in 7 days. Re-run `/certgame report` to refresh it.'
            )
        );

        return JSON.serialize(
            new Map<String, Object>{
                'response_type' => 'ephemeral',
                'text' => 'Your Study Guide is ready.',
                'blocks' => blocks
            }
        );
    }

    // ----- block primitives -----
    public static Map<String, Object> section(String mrkdwn) {
        return new Map<String, Object>{
            'type' => 'section',
            'text' => new Map<String, Object>{
                'type' => 'mrkdwn',
                'text' => mrkdwn
            }
        };
    }
    public static Map<String, Object> header(String txt) {
        return new Map<String, Object>{
            'type' => 'header',
            'text' => new Map<String, Object>{
                'type' => 'plain_text',
                'text' => txt
            }
        };
    }
    public static Map<String, Object> divider() {
        return new Map<String, Object>{ 'type' => 'divider' };
    }
    public static Map<String, Object> context(String txt) {
        return new Map<String, Object>{
            'type' => 'context',
            'elements' => new List<Object>{
                new Map<String, Object>{ 'type' => 'mrkdwn', 'text' => txt }
            }
        };
    }
    private static String truncate(String s, Integer n) {
        if (s == null)
            return '';
        return s.length() > n ? s.substring(0, n - 1) + '…' : s;
    }
}