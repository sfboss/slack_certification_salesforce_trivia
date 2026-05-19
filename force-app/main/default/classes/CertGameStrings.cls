public with sharing class CertGameStrings {
    public static final String HELP_TEXT =
        '*Certification Trivia* commands:\n' +
        '`/certgame play` — start a quick 5-question game (optionally `play <ExamCode>`)\n' +
        '`/certgame challenge @user [ExamCode]` — head-to-head duel (5 questions)\n' +
        '`/certgame games` — list available exams + question counts\n' +
        '`/certgame leaderboard` — show channel leaderboard\n' +
        '`/certgame stats` — your stats in this workspace\n' +
        '`/certgame plan` — manage study plan\n' +
        '`/certgame doctor` — run setup + health checks (admins & players)\n' +
        '`/certgame notify-test` — DM yourself a self-test message to verify notifications work\n' +
        '`/certgame billing` — manage workspace plan (admins)\n' +
        '`/certgame help` — this message';

    public static final String LOCKED_PREMIUM = ':lock: This exam is part of the Pro plan.';
    public static final String QUOTA_REACHED = ':warning: Daily quota reached. Upgrade for more.';
    public static final String INVALID_PACK = 'The pack failed validation. See details below.';
    public static final String IMPORT_OK = 'Pack imported. All questions are Drafts pending review.';

    public static final String UNKNOWN_COMMAND = 'Unknown command. Try `/certgame help`.';
    public static final String NO_EXAM = 'No matching certification exam was found.';
    public static final String NO_QUESTIONS = 'No published questions available for that exam yet.';
    public static final String NOT_INSTALLED = 'Cert Game is not installed for this workspace yet.';
    public static final String NO_STATS = 'No stats yet. Play `/certgame play` to get started.';
    public static final String GENERIC_ERROR = 'Something went wrong. Please try again.';
    public static final String ALREADY_ANSWERED = 'You already answered this round.';
    public static final String TOURNAMENT_NOT_FOUND = 'Tournament not found.';

    public static String formatPoints(Integer pts) { return pts == null ? '0 pts' : pts + ' pts'; }
}