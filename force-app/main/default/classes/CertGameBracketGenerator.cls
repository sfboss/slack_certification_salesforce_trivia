/**
 * Generates pairings for tournament brackets.
 * Supports: RoundRobin, Elimination (single), OpenLadder.
 */
public with sharing class CertGameBracketGenerator {

    public class Pairing {
        public Integer round;
        public String playerA;
        public String playerB; // null for bye
    }

    public static List<Pairing> generate(String bracketType, List<String> playerIds) {
        if (playerIds == null) playerIds = new List<String>();
        if (bracketType == 'RoundRobin') return roundRobin(playerIds);
        if (bracketType == 'Elimination') return singleElimination(playerIds);
        if (bracketType == 'OpenLadder') return ladder(playerIds);
        return new List<Pairing>();
    }

    // Circle method round-robin
    public static List<Pairing> roundRobin(List<String> players) {
        List<Pairing> out = new List<Pairing>();
        if (players == null || players.size() < 2) return out;
        List<String> p = new List<String>(players);
        if (Math.mod(p.size(), 2) == 1) p.add(null); // bye marker
        Integer n = p.size();
        if (n < 2) return out;
        Integer rounds = n - 1;
        Integer half = n / 2;
        List<String> arr = new List<String>(p);
        for (Integer r = 0; r < rounds; r++) {
            for (Integer i = 0; i < half; i++) {
                Pairing pr = new Pairing();
                pr.round = r + 1;
                pr.playerA = arr[i];
                pr.playerB = arr[n - 1 - i];
                out.add(pr);
            }
            // rotate (keep arr[0] fixed)
            String last = arr[n - 1];
            for (Integer i = n - 1; i > 1; i--) arr[i] = arr[i - 1];
            arr[1] = last;
        }
        return out;
    }

    public static List<Pairing> singleElimination(List<String> players) {
        List<Pairing> out = new List<Pairing>();
        if (players.isEmpty()) return out;
        // Pad to next power of 2
        Integer size = 1;
        while (size < players.size()) size *= 2;
        List<String> padded = new List<String>(players);
        while (padded.size() < size) padded.add(null);
        for (Integer i = 0; i < size; i += 2) {
            Pairing pr = new Pairing();
            pr.round = 1;
            pr.playerA = padded[i];
            pr.playerB = padded[i + 1];
            out.add(pr);
        }
        return out;
    }

    public static List<Pairing> ladder(List<String> players) {
        List<Pairing> out = new List<Pairing>();
        for (Integer i = 0; i + 1 < players.size(); i++) {
            Pairing pr = new Pairing();
            pr.round = 1;
            pr.playerA = players[i];
            pr.playerB = players[i + 1];
            out.add(pr);
        }
        return out;
    }
}