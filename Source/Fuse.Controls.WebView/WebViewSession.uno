using Uno;

namespace Fuse.Controls
{
	/**
		Cookie, cache and storage control for a @WebView.

		The methods are forwarded to the native WebView on Android and iOS. When no
		native WebView is available (for example on desktop), they are no-ops.
	*/
	public interface IWebViewSession
	{
		/**
			Retrieves the cookie header string for the given URL, for example `"session=abc; theme=dark"`.
		*/
		void GetCookies(string url, Action<string> resultHandler);

		/**
			Sets a cookie for the given URL. The `cookie` argument uses the same format as a
			`Set-Cookie` header, for example `"session=abc; Path=/; Secure"`.
		*/
		void SetCookie(string url, string cookie);

		/**
			Removes all cookies.
		*/
		void ClearCookies();

		/**
			Clears the WebView cache.
		*/
		void ClearCache();

		/**
			Clears local storage, session storage, IndexedDB and related web storage.
		*/
		void ClearStorage();

		/**
			Reloads the current page while ignoring cached responses.
		*/
		void ReloadIgnoringCache();
	}

	internal interface IWebViewUserAgentClient
	{
		void SetUserAgent(string userAgent, string userAgentSuffix);
	}

	internal interface IWebViewRequestClient
	{
		void LoadUrlWithHeaders(string url, string[] headerNames, string[] headerValues);
		void PostUrl(string url, string body);
	}
}
