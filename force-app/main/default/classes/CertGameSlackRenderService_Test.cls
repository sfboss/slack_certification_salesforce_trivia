@IsTest
private class CertGameSlackRenderService_Test {
    @IsTest
    static void helpHasText() {
        String s = CertGameSlackRenderService.help();
        System.assert(s.contains('ephemeral'));
        System.assert(s.contains('text'));
    }

    @IsTest
    static void textEphemeralAndChannel() {
        System.assert(
            CertGameSlackRenderService.text('hi', true).contains('ephemeral')
        );
        System.assert(
            CertGameSlackRenderService.text('hi', false).contains('in_channel')
        );
    }

    @IsTest
    static void questionBlocksEmitsAnswerActions() {
        String roundId = 'a0R000000000001';
        List<Map<String, Object>> choices = new List<Map<String, Object>>{
            new Map<String, Object>{
                'id' => 'c1',
                'label' => 'A',
                'text' => 'AnswerA'
            },
            new Map<String, Object>{
                'id' => 'c2',
                'label' => 'B',
                'text' => 'AnswerB'
            }
        };
        String s = CertGameSlackRenderService.questionBlocks(
            roundId,
            'Q?',
            choices,
            30
        );
        System.assert(s.contains('game:answer:' + roundId + ':c1'));
        System.assert(s.contains('hourglass_flowing_sand'));
        System.assert(s.contains('30s'));
    }

    @IsTest
    static void resultBlocksCorrectAndWrong() {
        String ok = CertGameSlackRenderService.resultBlocks(
            true,
            'A',
            25,
            null
        );
        System.assert(ok.contains('Correct'));
        List<Map<String, Object>> cites = new List<Map<String, Object>>{
            new Map<String, Object>{ 'title' => 'T', 'url' => 'https://x' }
        };
        String wrong = CertGameSlackRenderService.resultBlocks(
            false,
            'A',
            0,
            cites
        );
        System.assert(wrong.contains('Not quite'));
        System.assert(wrong.contains('https://x'));
    }
}