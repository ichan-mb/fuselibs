using Uno;
using Uno.UX;
using Uno.Platform;
using Uno.Collections;
using Fuse;
using Fuse.Navigation;
using Uno.Compiler.ExportTargetInterop;

namespace Fuse.Android.Controls.WebViewUtils
{
	[ForeignInclude(Language.Java, "com.fuse.webview.JsInterface", "com.fuse.webview.FuseDownloadListener", "com.fuse.webview.FuseWebViewClient", "com.fuse.webview.FuseWebChromeClient", "android.util.Log", "android.webkit.WebView", "android.webkit.WebSettings", "android.webkit.CookieManager", "android.webkit.WebStorage", "com.fuse.webview.ScrollableWebView")]
	public static class WebViewForeign
	{
		[Foreign(Language.Java)]
		public extern (Android) static Java.Object CreateWebView(bool zoomEnabled, bool scrollEnabled)
		@{
			ScrollableWebView wv = new ScrollableWebView(com.fuse.Activity.getRootActivity());
			wv.getSettings().setJavaScriptEnabled(true);
			wv.getSettings().setUseWideViewPort(true); //enabled viewport meta tag
			wv.getSettings().setLoadWithOverviewMode(true); //mimic iOS Safari and Android Chrome
			wv.getSettings().setSupportZoom(zoomEnabled);
			wv.getSettings().setBuiltInZoomControls(zoomEnabled);
			wv.getSettings().setDisplayZoomControls(false);
			wv.getSettings().setDomStorageEnabled(true);
			wv.getSettings().setJavaScriptCanOpenWindowsAutomatically(true);
			wv.getSettings().setSupportMultipleWindows(true);
			wv.setAllowScroll(scrollEnabled);

			return wv;
		@}

		[Foreign(Language.Java)]
		public extern (Android) static void AddJavascriptInterface(this Java.Object handle, string name, Action<string> resultHandler, Action<string> errorHandler)
		@{
			WebView wv = (WebView)handle;
			JsInterface jsi = new JsInterface(resultHandler, errorHandler);
			wv.addJavascriptInterface(jsi, name);
		@}

		[Foreign(Language.Java)]
		public extern (Android) static void EvaluateJavascript(this Java.Object handle, string interfaceName, string js)
		@{
			// JSONObject.quote() produces a properly escaped JavaScript string literal,
			// so scripts containing quotes, backslashes or newlines are evaluated safely.
			String quoted = org.json.JSONObject.quote(js)
				.replace("\u2028", "\\u2028")
				.replace("\u2029", "\\u2029");
			String script = "try{" + interfaceName + ".onResult(eval(" + quoted + "));}" +
				"catch(e){" + interfaceName + ".onError(String(e));}";
			((WebView)handle).evaluateJavascript(script, null);
		@}

		[Foreign(Language.Java)]
		public extern (Android) static Java.Object CreateAndSetWebChromeClient(this Java.Object webViewHandle, Action<int> onProgress, int newWindowPolicy)
		@{
			FuseWebChromeClient client = new FuseWebChromeClient(onProgress, newWindowPolicy);
			((WebView)webViewHandle).setWebChromeClient(client);
			return client;
		@}

		[Foreign(Language.Java)]
		public extern (Android) static void SetWebChromeClientNewWindowPolicy(this Java.Object chromeClientHandle, int policy)
		@{
			((FuseWebChromeClient)chromeClientHandle).setNewWindowPolicy(policy);
		@}

		[Foreign(Language.Java)]
		public extern (Android) static Java.Object CreateAndSetWebViewClient(this Java.Object webViewHandle, Action loaded, Action started, Action changed, Action<string> onCustomURI, string[] customURIs, Func<bool> hasUriSchemeHandler, Action<string, string, int, int, bool> onPageError, int externalNavigationPolicy)
		@{
			FuseWebViewClient client = new FuseWebViewClient(loaded, started, changed, onCustomURI, customURIs, hasUriSchemeHandler, onPageError, externalNavigationPolicy);
			((WebView)webViewHandle).setWebViewClient(client);
			return client;
		@}

		[Foreign(Language.Java)]
		public extern (Android) static void SetExternalNavigationPolicy(this Java.Object clientHandle, int policy)
		@{
			((FuseWebViewClient)clientHandle).setExternalNavigationPolicy(policy);
		@}

		[Foreign(Language.Java)]
		public extern (Android) static Java.Object CreateAndSetDownloadListener(this Java.Object webViewHandle, Action<string> beginDownload, Action<string, string> fileDownloaded)
		@{
			FuseDownloadListener downloadListener = new FuseDownloadListener(beginDownload, fileDownloaded);
			((WebView)webViewHandle).setDownloadListener(downloadListener);
			return downloadListener;
		@}

		[Foreign(Language.Java)]
		public extern (Android) static string GetUrl(this Java.Object handle)
		@{
			WebView wv = (WebView)handle;
			return wv.getUrl();
		@}

		[Foreign(Language.Java)]
		public extern (Android) static string GetTitle(this Java.Object handle)
		@{
			WebView wv = (WebView)handle;
			return wv.getTitle();
		@}

		[Foreign(Language.Java)]
		public extern (Android) static bool CanGoBack(this Java.Object handle)
		@{
			WebView wv = (WebView)handle;
			return wv.canGoBack();
		@}

		[Foreign(Language.Java)]
		public extern (Android) static bool CanGoForward(this Java.Object handle)
		@{
			WebView wv = (WebView)handle;
			return wv.canGoForward();
		@}

		[Foreign(Language.Java)]
		public extern (Android) static void GoBack(this Java.Object handle)
		@{
			WebView wv = (WebView)handle;
			wv.goBack();
		@}

		[Foreign(Language.Java)]
		public extern (Android) static void GoForward(this Java.Object handle)
		@{
			WebView wv = (WebView)handle;
			wv.goForward();
		@}

		[Foreign(Language.Java)]
		public extern (Android) static void Reload(this Java.Object handle)
		@{
			WebView wv = (WebView)handle;
			wv.reload();
		@}

		[Foreign(Language.Java)]
		public extern (Android) static void StopLoading(this Java.Object handle)
		@{
			WebView wv = (WebView)handle;
			wv.stopLoading();
		@}

		[Foreign(Language.Java)]
		public extern (Android) static void LoadHtml(this Java.Object handle, string html, string baseUrl)
		@{
			WebView wv = (WebView)handle;
			wv.loadDataWithBaseURL(baseUrl, html, "text/html", "UTF-8", null);
		@}

		[Foreign(Language.Java)]
		public extern (Android) static void LoadUrl(this Java.Object handle, string url)
		@{
			WebView wv = (WebView)handle;
			wv.loadUrl(url);
		@}

		[Foreign(Language.Java)]
		public extern (Android) static void SetZoomEnabled(this Java.Object handle, bool enabled)
		@{
			WebView wv = (WebView)handle;
			wv.getSettings().setSupportZoom(enabled);
			wv.getSettings().setBuiltInZoomControls(enabled);
			wv.getSettings().setDisplayZoomControls(false);
		@}

		[Foreign(Language.Java)]
		public extern (Android) static void SetScrollEnabled(this Java.Object handle, bool enabled)
		@{
			((ScrollableWebView)handle).setAllowScroll(enabled);
		@}

		[Foreign(Language.Java)]
		public extern (Android) static void SetUserAgent(this Java.Object handle, string userAgent, string userAgentSuffix)
		@{
			WebView wv = (WebView)handle;
			WebSettings settings = wv.getSettings();

			if (userAgent != null && userAgent.length() > 0)
				settings.setUserAgentString(userAgent);
			else if (userAgentSuffix != null && userAgentSuffix.length() > 0)
				settings.setUserAgentString(settings.getDefaultUserAgent(com.fuse.Activity.getRootActivity()) + " " + userAgentSuffix);
			else
				settings.setUserAgentString(null);
		@}

		[Foreign(Language.Java)]
		public extern (Android) static void LoadUrlWithHeaders(this Java.Object handle, string url, string[] headerNames, string[] headerValues)
		@{
			WebView wv = (WebView)handle;
			String[] names = headerNames != null ? headerNames.copyArray() : null;
			String[] values = headerValues != null ? headerValues.copyArray() : null;

			if (names == null || values == null || names.length == 0)
			{
				wv.loadUrl(url);
				return;
			}

			java.util.HashMap<String, String> headers = new java.util.HashMap<String, String>();
			int count = Math.min(names.length, values.length);
			for (int i = 0; i < count; i++)
				headers.put(names[i], values[i]);

			wv.loadUrl(url, headers);
		@}

		[Foreign(Language.Java)]
		public extern (Android) static void PostUrl(this Java.Object handle, string url, string body)
		@{
			WebView wv = (WebView)handle;
			try {
				wv.postUrl(url, body != null ? body.getBytes("UTF-8") : new byte[0]);
			} catch (java.io.UnsupportedEncodingException e) {
				wv.postUrl(url, new byte[0]);
			}
		@}

		[Foreign(Language.Java)]
		public static void GetCookies(string url, Action<string> resultHandler)
		@{
			String cookies = CookieManager.getInstance().getCookie(url);
			if (resultHandler != null)
				resultHandler.run(cookies != null ? cookies : "");
		@}

		[Foreign(Language.Java)]
		public static void SetCookie(string url, string cookie)
		@{
			CookieManager manager = CookieManager.getInstance();
			manager.setAcceptCookie(true);
			manager.setCookie(url, cookie);
			manager.flush();
		@}

		[Foreign(Language.Java)]
		public static void ClearCookies()
		@{
			CookieManager manager = CookieManager.getInstance();
			manager.removeAllCookies(null);
			manager.flush();
		@}

		[Foreign(Language.Java)]
		public extern (Android) static void ClearCache(this Java.Object handle)
		@{
			((WebView)handle).clearCache(true);
		@}

		[Foreign(Language.Java)]
		public static void ClearStorage()
		@{
			WebStorage.getInstance().deleteAllData();
		@}

		[Foreign(Language.Java)]
		public extern (Android) static void ReloadIgnoringCache(this Java.Object handle)
		@{
			WebView wv = (WebView)handle;
			wv.clearCache(true);
			wv.reload();
		@}

		[Foreign(Language.Java)]
		public extern (Android) static void DestroyWebView(this Java.Object handle, Java.Object chromeClient, Java.Object downloadListener, string interfaceName)
		@{
			WebView wv = (WebView)handle;

			if (chromeClient != null)
				((FuseWebChromeClient)chromeClient).dispose();

			if (downloadListener != null)
				((FuseDownloadListener)downloadListener).dispose();

			wv.stopLoading();
			wv.setWebViewClient(null);
			wv.setWebChromeClient(null);
			wv.setDownloadListener(null);

			if (interfaceName != null)
				wv.removeJavascriptInterface(interfaceName);

			wv.loadUrl("about:blank");
			wv.clearHistory();

			android.view.ViewGroup parent = (android.view.ViewGroup)wv.getParent();
			if (parent != null)
				parent.removeView(wv);

			wv.destroy();
		@}

		[Foreign(Language.Java)]
		public extern (Android) static double GetProgress(this Java.Object handle)
		@{
			WebView wv = (WebView)handle;
			return wv.getProgress();
		@}

	}

}
