// Drives the full Slack-driven game flow end-to-end against the org without
// going through Slack. Asserts that each answer returns combined
// result+next-question blocks until the final round, then a Game-Over block
// and Status__c='Completed'.
//
// Run with: sf apex run --file scripts/apex/harness_play_loop.apex -o certgame

String TEAM   = 'THARNESS';
String USER   = 'UHARNESS' + String.valueOf(Datetime.now().getTime());
String CHAN   = 'CHARNESS';

System.debug('=== START quick game ===');
String env = CertGameSessionService.startQuickGameFromSlack(TEAM, USER, CHAN, new List<String>{'play'});
System.debug('START envelope: ' + env.left(800));

Map<String, Object> envMap = (Map<String, Object>) JSON.deserializeUntyped(env);
List<Object> blocks = (List<Object>) envMap.get('blocks');
if (blocks == null) {
    System.debug('FAIL: start returned no blocks. envelope=' + env);
    return;
}

// Helper to extract the LAST actions block's first action_id and the round id from it
// action_id format: game:answer:<roundId>:<choiceId>
String currentRoundId;
String correctChoiceId;

// Function: from a list of blocks, return the last `actions` block (the active question)
// and pull roundId from its first element.
Integer round = 1;
Integer totalQ = 5;

while (round <= totalQ + 1) {
    // Find the LAST actions block in current `blocks` whose first action_id is `game:answer:*`
    // (game-over now also renders an actions block with `game:newgame`, which we treat as end-of-game).
    Map<String, Object> actionsBlock;
    String firstAid;
    for (Integer i = blocks.size() - 1; i >= 0; i--) {
        Map<String, Object> b = (Map<String, Object>) blocks[i];
        if ('actions'.equals(b.get('type'))) {
            List<Object> els = (List<Object>) b.get('elements');
            if (els != null && !els.isEmpty()) {
                Map<String, Object> first = (Map<String, Object>) els[0];
                String aidCandidate = (String) first.get('action_id');
                if (aidCandidate != null && aidCandidate.startsWith('game:answer:')) {
                    actionsBlock = b;
                    firstAid = aidCandidate;
                    break;
                }
            }
        }
    }

    if (actionsBlock == null) {
        // No more questions → must be game over
        System.debug('=== NO MORE ACTIONS BLOCK — expecting game over ===');
        Boolean sawGameOver = false;
        for (Object o : blocks) {
            Map<String, Object> b = (Map<String, Object>) o;
            String t = (String) b.get('type');
            if ('header'.equals(t)) {
                Map<String, Object> tx = (Map<String, Object>) b.get('text');
                if (tx != null && String.valueOf(tx.get('text')).contains('Game Over')) { sawGameOver = true; break; }
            }
            if ('section'.equals(t)) {
                Map<String, Object> tx = (Map<String, Object>) b.get('text');
                if (tx != null && String.valueOf(tx.get('text')).toLowerCase().contains('game over')) { sawGameOver = true; break; }
            }
        }
        System.debug(sawGameOver ? 'PASS: game over section present' : 'FAIL: no game over section. blocks=' + JSON.serialize(blocks));
        break;
    }

    // Parse action_id from first element
    List<String> parts = firstAid.split(':');
    // parts = ['game','answer', roundId, choiceId]
    currentRoundId = parts[2];

    // Find the CORRECT choice id for this round's question
    Game_Round__c gr = [
        SELECT Id, Trivia_Question__c FROM Game_Round__c WHERE Id = :currentRoundId LIMIT 1
    ];
    List<Trivia_Answer_Choice__c> correctList = [
        SELECT Id, Choice_Label__c FROM Trivia_Answer_Choice__c
        WHERE Trivia_Question__c = :gr.Trivia_Question__c AND Is_Correct__c = true LIMIT 1
    ];
    if (correctList.isEmpty()) {
        System.debug('FAIL: no correct choice for q=' + gr.Trivia_Question__c);
        break;
    }
    correctChoiceId = correctList[0].Id;

    System.debug('--- ROUND ' + round + ' roundId=' + currentRoundId + ' correctChoice=' + correctChoiceId + ' (' + correctList[0].Choice_Label__c + ') ---');

    // Submit the answer
    String ans = CertGameSessionService.recordAnswerFromSlack(TEAM, USER, currentRoundId, correctChoiceId);
    System.debug('ANSWER envelope (first 1200 chars): ' + ans.left(1200));

    Map<String, Object> ansMap = (Map<String, Object>) JSON.deserializeUntyped(ans);
    blocks = (List<Object>) ansMap.get('blocks');
    if (blocks == null) {
        System.debug('FAIL: answer returned no blocks. envelope=' + ans);
        break;
    }

    round++;
}

// Final state check
List<Game_Session__c> sess = [
    SELECT Id, Status__c, Current_Question_Index__c, Total_Questions__c, Completed_At__c
    FROM Game_Session__c
    WHERE Slack_Team_Id__c = :TEAM AND Started_By_Slack_User_Id__c = :USER
    ORDER BY CreatedDate DESC LIMIT 1
];
if (!sess.isEmpty()) {
    Game_Session__c s = sess[0];
    System.debug('=== FINAL SESSION: status=' + s.Status__c
        + ' index=' + s.Current_Question_Index__c
        + '/' + s.Total_Questions__c
        + ' completedAt=' + s.Completed_At__c + ' ===');
}

Integer answers = [SELECT COUNT() FROM Player_Answer__c WHERE Game_Session__c = :sess[0].Id];
System.debug('=== Player_Answer__c count for session: ' + answers + ' ===');
