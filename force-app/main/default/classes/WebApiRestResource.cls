/**
 * Public REST endpoint for the web app. Exposed via Salesforce Site guest user.
 * Base: /services/apexrest/web/*
 *
 * Routes:
 *   POST /web/auth/google     { credential }                       -> { sessionToken, player }
 *   GET  /web/me                                                   -> player stats (auth)
 *   GET  /web/exams                                                -> list active exams (auth)
 *   POST /web/session/start   { examId, numQuestions }             -> first RoundDTO (auth)
 *   POST /web/answer          { roundId, choiceId }                -> AnswerDTO (auth)
 *   GET  /web/session/{sid}/next                                   -> next RoundDTO (auth)
 */
@RestResource(urlMapping='/web/*')
global without sharing class WebApiRestResource {

    @HttpGet
    global static void doGet() {
        try {
            String path = pathAfterBase();
            if (path == '/me') { requireAuth(); writeJson(WebPlayService.getStats(currentPlayerId())); return; }
            if (path == '/exams') { requireAuth(); writeJson(WebPlayService.listExams()); return; }
            if (path != null && path.startsWith('/session/') && path.endsWith('/next')) {
                requireAuth();
                String sid = path.substringBetween('/session/', '/next');
                writeJson(WebPlayService.nextRound(currentPlayerId(), (Id) sid));
                return;
            }
            if (path == '/health') { writeJson(new Map<String,Object>{ 'ok' => true, 'ts' => System.now() }); return; }
            if (path == '/config') {
                writeJson(new Map<String,Object>{
                    'googleClientId' => AppSettings.get().Web_Google_Client_Id__c,
                    'orgId' => UserInfo.getOrganizationId()
                });
                return;
            }
            notFound(path);
        } catch (AuthException ae) {
            writeStatus(401, new Map<String,Object>{ 'error' => ae.getMessage() });
        } catch (Exception e) {
            AppLogger.error('WebApiRestResource', 'doGet', 'unhandled', e);
            writeStatus(500, new Map<String,Object>{ 'error' => e.getMessage() });
        }
    }

    @HttpPost
    global static void doPost() {
        try {
            String path = pathAfterBase();
            String body = RestContext.request.requestBody == null ? '' : RestContext.request.requestBody.toString();
            Map<String, Object> json = String.isBlank(body) ? new Map<String, Object>() : (Map<String, Object>) JSON.deserializeUntyped(body);

            if (path == '/auth/google') {
                String credential = (String) json.get('credential');
                if (String.isBlank(credential)) credential = (String) json.get('id_token');
                WebAuthService.AuthResult r = WebAuthService.signInWithGoogleIdToken(credential);
                if (!r.ok) { writeStatus(401, new Map<String,Object>{ 'error' => r.error }); return; }
                writeJson(new Map<String,Object>{
                    'sessionToken' => r.sessionToken,
                    'expiresAt' => r.expiresAt,
                    'player' => new Map<String,Object>{
                        'id' => r.playerId, 'name' => r.name, 'email' => r.email, 'pictureUrl' => r.pictureUrl
                    }
                });
                return;
            }
            if (path == '/session/start') {
                requireAuth();
                String examId = (String) json.get('examId');
                Object nq = json.get('numQuestions');
                Integer n = nq == null ? 5 : Integer.valueOf(String.valueOf(nq));
                writeJson(WebPlayService.startSession(currentPlayerId(), (Id) examId, n));
                return;
            }
            if (path == '/answer') {
                requireAuth();
                String roundId = (String) json.get('roundId');
                String choiceId = (String) json.get('choiceId');
                writeJson(WebPlayService.submitAnswer(currentPlayerId(), (Id) roundId, (Id) choiceId));
                return;
            }
            notFound(path);
        } catch (AuthException ae) {
            writeStatus(401, new Map<String,Object>{ 'error' => ae.getMessage() });
        } catch (WebPlayService.PlayException pe) {
            writeStatus(400, new Map<String,Object>{ 'error' => pe.getMessage() });
        } catch (Exception e) {
            AppLogger.error('WebApiRestResource', 'doPost', 'unhandled', e);
            writeStatus(500, new Map<String,Object>{ 'error' => e.getMessage() });
        }
    }

    // ---- helpers ----

    public class AuthException extends Exception {}

    private static Id currentPlayerIdValue;
    private static Id currentPlayerId() { return currentPlayerIdValue; }

    private static void requireAuth() {
        Map<String,String> headers = RestContext.request.headers == null ? new Map<String,String>() : RestContext.request.headers;
        String tok = headers.get('Authorization');
        if (tok == null) tok = headers.get('authorization');
        if (tok != null && tok.startsWithIgnoreCase('Bearer ')) tok = tok.substring(7);
        if (String.isBlank(tok)) tok = headers.get('X-Web-Session-Token');
        if (String.isBlank(tok) && RestContext.request.params != null) {
            tok = RestContext.request.params.get('session');
        }
        WebSessionToken.TokenResult tr = WebSessionToken.verify(tok);
        if (!tr.valid) throw new AuthException('unauthorized:' + tr.reason);
        currentPlayerIdValue = tr.playerId;
    }

    private static String pathAfterBase() {
        String uri = RestContext.request.requestURI;
        if (uri == null) return null;
        Integer idx = uri.indexOf('/web');
        if (idx < 0) return uri;
        String rest = uri.substring(idx + 4);
        if (String.isBlank(rest)) rest = '/';
        // Trim trailing slash (except root)
        if (rest.length() > 1 && rest.endsWith('/')) rest = rest.substring(0, rest.length() - 1);
        return rest;
    }

    private static void writeJson(Object payload) {
        RestContext.response.statusCode = 200;
        RestContext.response.addHeader('Content-Type', 'application/json; charset=utf-8');
        RestContext.response.responseBody = Blob.valueOf(JSON.serialize(payload, true));
    }

    private static void writeStatus(Integer code, Object payload) {
        RestContext.response.statusCode = code;
        RestContext.response.addHeader('Content-Type', 'application/json; charset=utf-8');
        RestContext.response.responseBody = Blob.valueOf(JSON.serialize(payload, true));
    }

    private static void notFound(String path) {
        writeStatus(404, new Map<String,Object>{ 'error' => 'not_found', 'path' => path });
    }
}