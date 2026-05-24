/**
 * Pure scoring logic, no SOQL/DML. Inputs only.
 * Required ≥95% test coverage.
 *
 * Formula (per README §4.1):
 *   base = difficulty_base (Easy=10, Medium=20, Hard=30)
 *   timeBonus = max(0, base * (timeRemainingSec / timeLimitSec) * 0.5)
 *   streakBonus = streakLength * 2 (cap +20)
 *   penaltyForWrong = -base / 2 (configurable; default off for casual)
 *   final = round(base + timeBonus + streakBonus) when correct, else penalty (or 0)
 */
public with sharing class CertGameScoringService {
    public class Input {
        public Boolean correct;
        public String difficulty; // Easy | Medium | Hard
        public Integer timeRemainingSec;
        public Integer timeLimitSec;
        public Integer streakLength; // consecutive prior corrects, before this answer
        public Boolean penaltyEnabled;
    }

    public class Output {
        public Integer pointsAwarded;
        public Integer basePoints;
        public Integer timeBonus;
        public Integer streakBonus;
        public Integer penalty;
        public Integer newStreakLength;
    }

    public static Output score(Input inp) {
        Output o = new Output();
        Integer base = baseFor(inp.difficulty);
        o.basePoints = base;
        if (inp.correct == true) {
            Decimal tr = inp.timeRemainingSec == null
                ? 0
                : inp.timeRemainingSec;
            Decimal tl = inp.timeLimitSec == null ||
                inp.timeLimitSec == 0
                ? 1
                : inp.timeLimitSec;
            Decimal ratio = tr / tl;
            if (ratio < 0)
                ratio = 0;
            if (ratio > 1)
                ratio = 1;
            o.timeBonus = (Integer) Math.floor((Decimal) base * ratio * 0.5);
            Integer streak = inp.streakLength == null ? 0 : inp.streakLength;
            o.streakBonus = Math.min(streak * 2, 20);
            o.penalty = 0;
            o.pointsAwarded = base + o.timeBonus + o.streakBonus;
            o.newStreakLength = streak + 1;
        } else {
            o.timeBonus = 0;
            o.streakBonus = 0;
            o.penalty = inp.penaltyEnabled == true ? -(base / 2) : 0;
            o.pointsAwarded = o.penalty;
            o.newStreakLength = 0;
        }
        return o;
    }

    public static List<Output> scoreAll(List<Input> ins) {
        List<Output> out = new List<Output>();
        for (Input i : ins)
            out.add(score(i));
        return out;
    }

    public static Integer baseFor(String difficulty) {
        if (difficulty == null)
            return 20;
        String d = difficulty.toLowerCase();
        if (d == 'easy')
            return 10;
        if (d == 'hard')
            return 30;
        return 20; // medium / default
    }
}