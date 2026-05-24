@IsTest
private class CertGameScoringService_Test {
    @IsTest
    static void easyCorrectHasBase10() {
        CertGameScoringService.Input inp = new CertGameScoringService.Input();
        inp.correct = true;
        inp.difficulty = 'Easy';
        inp.timeRemainingSec = 0;
        inp.timeLimitSec = 30;
        inp.streakLength = 0;
        CertGameScoringService.Output o = CertGameScoringService.score(inp);
        System.assertEquals(10, o.basePoints);
        System.assertEquals(10, o.pointsAwarded);
        System.assertEquals(1, o.newStreakLength);
    }

    @IsTest
    static void mediumDefaultBase() {
        System.assertEquals(20, CertGameScoringService.baseFor(null));
        System.assertEquals(20, CertGameScoringService.baseFor('Medium'));
    }

    @IsTest
    static void hardWithFullTimeAndStreak() {
        CertGameScoringService.Input inp = new CertGameScoringService.Input();
        inp.correct = true;
        inp.difficulty = 'Hard';
        inp.timeRemainingSec = 30;
        inp.timeLimitSec = 30;
        inp.streakLength = 5;
        CertGameScoringService.Output o = CertGameScoringService.score(inp);
        System.assertEquals(30, o.basePoints);
        System.assertEquals(15, o.timeBonus);
        System.assertEquals(10, o.streakBonus);
        System.assertEquals(55, o.pointsAwarded);
    }

    @IsTest
    static void streakBonusCappedAt20() {
        CertGameScoringService.Input inp = new CertGameScoringService.Input();
        inp.correct = true;
        inp.difficulty = 'Easy';
        inp.timeRemainingSec = 0;
        inp.timeLimitSec = 30;
        inp.streakLength = 50;
        CertGameScoringService.Output o = CertGameScoringService.score(inp);
        System.assertEquals(20, o.streakBonus);
    }

    @IsTest
    static void wrongWithoutPenalty() {
        CertGameScoringService.Input inp = new CertGameScoringService.Input();
        inp.correct = false;
        inp.difficulty = 'Medium';
        inp.timeRemainingSec = 10;
        inp.timeLimitSec = 30;
        inp.streakLength = 3;
        inp.penaltyEnabled = false;
        CertGameScoringService.Output o = CertGameScoringService.score(inp);
        System.assertEquals(0, o.pointsAwarded);
        System.assertEquals(0, o.newStreakLength);
    }

    @IsTest
    static void wrongWithPenalty() {
        CertGameScoringService.Input inp = new CertGameScoringService.Input();
        inp.correct = false;
        inp.difficulty = 'Hard';
        inp.timeRemainingSec = 0;
        inp.timeLimitSec = 30;
        inp.streakLength = 0;
        inp.penaltyEnabled = true;
        CertGameScoringService.Output o = CertGameScoringService.score(inp);
        System.assertEquals(-15, o.pointsAwarded);
    }

    @IsTest
    static void negativeTimeClampsToZero() {
        CertGameScoringService.Input inp = new CertGameScoringService.Input();
        inp.correct = true;
        inp.difficulty = 'Easy';
        inp.timeRemainingSec = -5;
        inp.timeLimitSec = 30;
        inp.streakLength = 0;
        CertGameScoringService.Output o = CertGameScoringService.score(inp);
        System.assertEquals(0, o.timeBonus);
    }

    @IsTest
    static void zeroTimeLimitGuard() {
        CertGameScoringService.Input inp = new CertGameScoringService.Input();
        inp.correct = true;
        inp.difficulty = 'Easy';
        inp.timeRemainingSec = 5;
        inp.timeLimitSec = 0;
        inp.streakLength = 0;
        CertGameScoringService.Output o = CertGameScoringService.score(inp);
        System.assertNotEquals(null, o.pointsAwarded);
    }

    @IsTest
    static void scoreAllBatch() {
        CertGameScoringService.Input a = new CertGameScoringService.Input();
        a.correct = true;
        a.difficulty = 'Easy';
        a.timeRemainingSec = 0;
        a.timeLimitSec = 30;
        a.streakLength = 0;
        CertGameScoringService.Input b = new CertGameScoringService.Input();
        b.correct = false;
        b.difficulty = 'Easy';
        b.timeRemainingSec = 0;
        b.timeLimitSec = 30;
        b.streakLength = 0;
        List<CertGameScoringService.Output> r = CertGameScoringService.scoreAll(
            new List<CertGameScoringService.Input>{ a, b }
        );
        System.assertEquals(2, r.size());
    }
}