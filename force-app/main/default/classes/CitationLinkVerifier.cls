/**
 * Performs a lightweight HEAD/GET reachability check against a citation URL.
 * Used by the Question Review console to flag broken citation links.
 */
public with sharing class CitationLinkVerifier {
    /**
     * Returns true if the URL is reachable (HTTP 2xx or 3xx).
     * Falls back to GET if HEAD is not supported by the remote.
     * Failures (timeout, DNS, blocked) return false.
     */
    public static Boolean check(String url) {
        if (String.isBlank(url))
            return false;
        if (!url.startsWith('http://') && !url.startsWith('https://'))
            return false;
        try {
            HttpResponse res = send(url, 'HEAD');
            Integer code = res.getStatusCode();
            if (code == 405 || code == 501) {
                res = send(url, 'GET');
                code = res.getStatusCode();
            }
            return code >= 200 && code < 400;
        } catch (Exception e) {
            return false;
        }
    }

    private static HttpResponse send(String url, String method) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(url);
        req.setMethod(method);
        req.setTimeout(10000);
        req.setHeader('User-Agent', 'CertGameCitationVerifier/1.0');
        return new Http().send(req);
    }
}