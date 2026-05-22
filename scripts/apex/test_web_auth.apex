String expectedAud = AppSettings.get().Web_Google_Client_Id__c;

Certification_Exam__c exam = [
    SELECT Id, Name
    FROM Certification_Exam__c
    WHERE Active__c = true
    AND Id IN (
        SELECT Certification_Exam__c
        FROM Trivia_Question__c
        WHERE Status__c = 'Published'
    )
    ORDER BY Name
    LIMIT 1
];
System.assertNotEquals(null, exam, 'Need at least one active exam with published questions.');

WebAuthService.GoogleClaims c1 = new WebAuthService.GoogleClaims();
c1.iss = 'accounts.google.com';
c1.aud = expectedAud;
c1.sub = 'google-user-1-sub';
c1.email = 'user1@example.com';
c1.name = 'User One';
c1.picture = 'https://example.com/u1.png';
WebAuthService.claimsOverride = c1;
WebAuthService.AuthResult r1 = WebAuthService.signInWithGoogleIdToken('dummy-user-1');
System.assertEquals(true, r1.ok, 'User 1 login should succeed.');
System.assertNotEquals(null, r1.playerId, 'User 1 should map to a Player__c record.');

WebAuthService.GoogleClaims c2 = new WebAuthService.GoogleClaims();
c2.iss = 'accounts.google.com';
c2.aud = expectedAud;
c2.sub = 'google-user-2-sub';
c2.email = 'user2@example.com';
c2.name = 'User Two';
c2.picture = 'https://example.com/u2.png';
WebAuthService.claimsOverride = c2;
WebAuthService.AuthResult r2 = WebAuthService.signInWithGoogleIdToken('dummy-user-2');
System.assertEquals(true, r2.ok, 'User 2 login should succeed.');
System.assertNotEquals(null, r2.playerId, 'User 2 should map to a Player__c record.');
System.assertNotEquals(r1.playerId, r2.playerId, 'Distinct Google users must map to distinct Player__c records.');
WebAuthService.claimsOverride = null;

WebPlayService.RoundDTO round1 = WebPlayService.startSession(r1.playerId, exam.Id, 3);
Integer answered1 = 0;
Boolean forcedWrong = false;
while (round1 != null && round1.finished == false) {
    Game_Round__c gr1 = [SELECT Id, Trivia_Question__c FROM Game_Round__c WHERE Id = :round1.roundId LIMIT 1];
    List<Trivia_Answer_Choice__c> choices1 = [
        SELECT Id, Is_Correct__c
        FROM Trivia_Answer_Choice__c
        WHERE Trivia_Question__c = :gr1.Trivia_Question__c
        ORDER BY Choice_Label__c
    ];
    Id picked1;
    if (!forcedWrong) {
        for (Trivia_Answer_Choice__c choice1 : choices1) {
            if (choice1.Is_Correct__c == false) {
                picked1 = choice1.Id;
                forcedWrong = true;
                break;
            }
        }
    }
    if (picked1 == null) {
        for (Trivia_Answer_Choice__c choice1 : choices1) {
            if (choice1.Is_Correct__c == true) {
                picked1 = choice1.Id;
                break;
            }
        }
    }
    System.assertNotEquals(null, picked1, 'User 1 needs a selectable choice.');
    WebPlayService.AnswerDTO answer1 = WebPlayService.submitAnswer(r1.playerId, gr1.Id, picked1);
    answered1++;
    round1 = answer1.next;
}
System.assertEquals(3, answered1, 'User 1 should answer exactly three questions.');
System.assertEquals(true, forcedWrong, 'User 1 should have at least one wrong answer for weak-spot validation.');

WebPlayService.RoundDTO round2 = WebPlayService.startSession(r2.playerId, exam.Id, 2);
Integer answered2 = 0;
while (round2 != null && round2.finished == false) {
    Game_Round__c gr2 = [SELECT Id, Trivia_Question__c FROM Game_Round__c WHERE Id = :round2.roundId LIMIT 1];
    Trivia_Answer_Choice__c correct2 = [
        SELECT Id
        FROM Trivia_Answer_Choice__c
        WHERE Trivia_Question__c = :gr2.Trivia_Question__c
        AND Is_Correct__c = true
        LIMIT 1
    ];
    WebPlayService.AnswerDTO answer2 = WebPlayService.submitAnswer(r2.playerId, gr2.Id, correct2.Id);
    answered2++;
    round2 = answer2.next;
}
System.assertEquals(2, answered2, 'User 2 should answer exactly two questions.');

Map<Id, Integer> answersByPlayer = new Map<Id, Integer>();
for (AggregateResult ar : [
    SELECT Player__c playerId, COUNT(Id) cnt
    FROM Player_Answer__c
    WHERE Player__c IN :new Set<Id>{ r1.playerId, r2.playerId }
    GROUP BY Player__c
]) {
    answersByPlayer.put((Id) ar.get('playerId'), (Integer) ar.get('cnt'));
}
System.assertEquals(3, answersByPlayer.get(r1.playerId), 'User 1 answers should stay isolated.');
System.assertEquals(2, answersByPlayer.get(r2.playerId), 'User 2 answers should stay isolated.');

WebPlayService.PlayerStatsDTO stats1 = WebPlayService.getStats(r1.playerId);
WebPlayService.PlayerStatsDTO stats2 = WebPlayService.getStats(r2.playerId);
System.assertEquals(3, stats1.totalAnswers, 'User 1 totalAnswers mismatch.');
System.assertEquals(2, stats2.totalAnswers, 'User 2 totalAnswers mismatch.');
System.assert(stats1.weakSpots != null && !stats1.weakSpots.isEmpty(), 'User 1 should have at least one weak spot recorded.');
System.assert(stats2.weakSpots == null || stats2.weakSpots.isEmpty(), 'User 2 should have no weak spots after all-correct answers.');

List<Player__c> players = [
    SELECT Id, Display_Name__c, Total_Points__c, Total_Games__c, Last_Played_At__c
    FROM Player__c
    WHERE Id IN :new Set<Id>{ r1.playerId, r2.playerId }
    ORDER BY Id
];
System.assertEquals(2, players.size(), 'Expected two persisted web players.');
System.debug(JSON.serializePretty(new Map<String, Object>{
    'examId' => exam.Id,
    'playerIds' => new List<Id>{ r1.playerId, r2.playerId },
    'answersByPlayer' => answersByPlayer,
    'user1WeakSpots' => stats1.weakSpots,
    'user2WeakSpots' => stats2.weakSpots
}));