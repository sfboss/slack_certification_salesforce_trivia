@IsTest
private class CertGameBracketGenerator_Test {

    @IsTest static void unknownTypeReturnsEmpty() {
        System.assert(CertGameBracketGenerator.generate('Bogus', new List<String>{'a','b'}).isEmpty());
    }

    @IsTest static void roundRobinEvenPlayers() {
        List<CertGameBracketGenerator.Pairing> ps = CertGameBracketGenerator.generate(
            'RoundRobin', new List<String>{'a','b','c','d'});
        // 4 players → 3 rounds × 2 matches = 6
        System.assertEquals(6, ps.size());
    }

    @IsTest static void roundRobinOddPlayersAddsBye() {
        List<CertGameBracketGenerator.Pairing> ps = CertGameBracketGenerator.generate(
            'RoundRobin', new List<String>{'a','b','c'});
        // padded to 4 → 3 rounds × 2 = 6 with byes
        System.assertEquals(6, ps.size());
        Boolean foundBye = false;
        for (CertGameBracketGenerator.Pairing p : ps) if (p.playerA == null || p.playerB == null) foundBye = true;
        System.assert(foundBye);
    }

    @IsTest static void roundRobinSingleNoPairings() {
        System.assert(CertGameBracketGenerator.generate('RoundRobin', new List<String>{'a'}).isEmpty());
    }

    @IsTest static void eliminationPadsToPowerOfTwo() {
        List<CertGameBracketGenerator.Pairing> ps = CertGameBracketGenerator.generate(
            'Elimination', new List<String>{'a','b','c'});
        System.assertEquals(2, ps.size()); // padded to 4
    }

    @IsTest static void eliminationEmpty() {
        System.assert(CertGameBracketGenerator.generate('Elimination', new List<String>()).isEmpty());
    }

    @IsTest static void ladderConsecutivePairs() {
        List<CertGameBracketGenerator.Pairing> ps = CertGameBracketGenerator.generate(
            'OpenLadder', new List<String>{'a','b','c','d'});
        System.assertEquals(3, ps.size());
    }

    @IsTest static void nullPlayersHandled() {
        System.assert(CertGameBracketGenerator.generate('RoundRobin', null).isEmpty());
    }
}
