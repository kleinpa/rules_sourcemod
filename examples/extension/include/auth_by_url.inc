#if defined _auth_by_url_included
 #endinput
#endif
#define _auth_by_url_included

/**
 * Requests a URL in the background and kicks the client if it fails or returns
 * an HTTP error.
 *
 * @param client        Client index.
 * @param url           HTTPS URL to request.
 * @error               Invalid client index or client not connected.
 */
native void AuthByUrl_Check(int client, const char[] url);

public Extension __ext_auth_by_url =
{
    name = "Auth by URL",
    file = "auth_by_url.ext",
    autoload = 1,
    required = 1,
};
