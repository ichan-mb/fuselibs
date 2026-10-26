using Uno;
using Uno.Compiler.ExportTargetInterop;

namespace Fuse.iOS.Controls
{

	[Require("source.include", "iOS/WVUIDelegate.h")]
	[Require("source.include", "WebKit/WebKit.h")]
	static extern(iOS) class WKWebViewHelpers
	{
		[Foreign(Language.ObjC)]
		public static void EvalOnWebViewWithHandler(ObjC.Object webview, string js, Action<string> handler)
		@{
				WKWebView* wv = webview;
				[wv evaluateJavaScript:js completionHandler:^(id result, NSError* error) {
					handler(result);
				}];
		@}

		[Foreign(Language.ObjC)]
		public static void EvalOnWebView(ObjC.Object webview, string js)
		@{
				WKWebView* wv = webview;
				[wv evaluateJavaScript:js completionHandler:nil];
		@}

		[Foreign(Language.ObjC)]
		public static void LoadHTML(ObjC.Object webview, string html, string baseURL)
		@{
				WKWebView* wv = webview;
				NSURL* nsBaseUrl = [baseURL length] > 0 ? [NSURL URLWithString:baseURL] : nil;
				[wv loadHTMLString:html baseURL:nsBaseUrl];
		@}

		[Foreign(Language.ObjC)]
		public static ObjC.Object CreateWebView(bool zoomEnabled, bool scrollEnabled)
		@{
			WKWebViewConfiguration* configuration = [[WKWebViewConfiguration alloc] init];
			configuration.preferences.javaScriptCanOpenWindowsAutomatically = YES;

			WKWebView* wv = [[WKWebView alloc] initWithFrame:CGRectZero configuration:configuration];
			wv.scrollView.scrollEnabled = scrollEnabled;
			// WKWebView has no public API for disabling zoom. Disabling the pinch
			// gesture is the supported workaround and avoids replacing the scroll
			// view delegate, which WKWebView relies on internally.
			wv.scrollView.pinchGestureRecognizer.enabled = zoomEnabled;
			wv.allowsBackForwardNavigationGestures = YES;
			wv.allowsLinkPreview = NO;

			return wv;
		@}

		[Foreign(Language.ObjC)]
		public static ObjC.Object CreateUIDelegate(int newWindowPolicy)
		@{
			WVUIDelegate* delegate = [[WVUIDelegate alloc] init];
			delegate.newWindowPolicy = (WVNewWindowPolicy)newWindowPolicy;
			return delegate;
		@}

		[Foreign(Language.ObjC)]
		public static void SetUIDelegateNewWindowPolicy(ObjC.Object delegateHandle, int newWindowPolicy)
		@{
			((WVUIDelegate*)delegateHandle).newWindowPolicy = (WVNewWindowPolicy)newWindowPolicy;
		@}

		[Foreign(Language.ObjC)]
		public static void SetUIDelegate(ObjC.Object webViewHandle, ObjC.Object delegateHandle)
		@{
			[(WKWebView*)webViewHandle setUIDelegate:(WVUIDelegate*)delegateHandle];
		@}

		[Foreign(Language.ObjC)]
		public static void ClearUIDelegate(ObjC.Object webViewHandle)
		@{
			[(WKWebView*)webViewHandle setUIDelegate:nil];
		@}

		[Foreign(Language.ObjC)]
		public static void SetZoomEnabled(ObjC.Object handle, bool zoomEnabled)
		@{
			WKWebView* wv = handle;
			wv.scrollView.pinchGestureRecognizer.enabled = zoomEnabled;
		@}

		[Foreign(Language.ObjC)]
		public static void SetScrollEnabled(ObjC.Object handle, bool scrollEnabled)
		@{
			WKWebView* wv = handle;
			wv.scrollView.scrollEnabled = scrollEnabled;
		@}

		[Foreign(Language.ObjC)]
		public static void SetUserAgent(ObjC.Object handle, string userAgent, string userAgentSuffix)
		@{
			WKWebView* wv = handle;

			if (userAgent != nil && [userAgent length] > 0)
			{
				wv.customUserAgent = userAgent;
			}
			else
			{
				wv.customUserAgent = nil;
				wv.applicationNameForUserAgent = (userAgentSuffix != nil && [userAgentSuffix length] > 0) ? userAgentSuffix : nil;
			}
		@}

		[Foreign(Language.ObjC)]
		public static void LoadUrlWithHeaders(ObjC.Object handle, string url, string[] headerNames, string[] headerValues)
		@{
			WKWebView* wv = handle;
			NSURL* nsUrl = [NSURL URLWithString:url];
			if (nsUrl == nil)
				return;

			NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:nsUrl];
			NSArray* names = [headerNames copyArray];
			NSArray* values = [headerValues copyArray];
			NSUInteger count = MIN(names.count, values.count);
			for (NSUInteger i = 0; i < count; i++)
				[request setValue:values[i] forHTTPHeaderField:names[i]];

			[wv loadRequest:request];
		@}

		[Foreign(Language.ObjC)]
		public static void PostUrl(ObjC.Object handle, string url, string body)
		@{
			WKWebView* wv = handle;
			NSURL* nsUrl = [NSURL URLWithString:url];
			if (nsUrl == nil)
				return;

			NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:nsUrl];
			request.HTTPMethod = @"POST";
			request.HTTPBody = [body dataUsingEncoding:NSUTF8StringEncoding];
			[request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];

			[wv loadRequest:request];
		@}

		[Foreign(Language.ObjC)]
		public static void GetCookies(ObjC.Object handle, string url, Action<string> resultHandler)
		@{
			WKWebView* wv = handle;
			NSURL* nsUrl = [NSURL URLWithString:url];
			WKHTTPCookieStore* store = wv.configuration.websiteDataStore.httpCookieStore;

			[store getAllCookies:^(NSArray<NSHTTPCookie*>* cookies) {
				NSMutableArray* matching = [NSMutableArray array];

				for (NSHTTPCookie* cookie in cookies)
				{
					if (nsUrl == nil || nsUrl.host == nil)
					{
						[matching addObject:cookie];
						continue;
					}

					NSString* host = nsUrl.host;
					NSString* domain = cookie.domain;
					BOOL domainMatches = NO;

					if (domain != nil)
					{
						if ([domain hasPrefix:@"."])
							domainMatches = [host hasSuffix:domain] || [host isEqualToString:[domain substringFromIndex:1]];
						else
							domainMatches = [host isEqualToString:domain] || [host hasSuffix:[@"." stringByAppendingString:domain]];
					}

					if (!domainMatches)
						continue;

					NSString* requestPath = nsUrl.path.length > 0 ? nsUrl.path : @"/";
					if (cookie.path.length > 0 && ![requestPath hasPrefix:cookie.path])
						continue;

					if (cookie.isSecure && ![[nsUrl.scheme lowercaseString] isEqualToString:@"https"])
						continue;

					[matching addObject:cookie];
				}

				NSDictionary* fields = [NSHTTPCookie requestHeaderFieldsWithCookies:matching];
				NSString* header = fields[@"Cookie"];
				if (resultHandler != nil)
					resultHandler(header != nil ? header : @"");
			}];
		@}

		[Foreign(Language.ObjC)]
		public static void SetCookie(ObjC.Object handle, string url, string cookie)
		@{
			WKWebView* wv = handle;
			NSURL* nsUrl = [NSURL URLWithString:url];
			if (nsUrl == nil)
				return;

			NSDictionary* fields = [NSDictionary dictionaryWithObject:cookie forKey:@"Set-Cookie"];
			NSArray* cookies = [NSHTTPCookie cookiesWithResponseHeaderFields:fields forURL:nsUrl];
			WKHTTPCookieStore* store = wv.configuration.websiteDataStore.httpCookieStore;

			for (NSHTTPCookie* c in cookies)
				[store setCookie:c completionHandler:nil];
		@}

		[Foreign(Language.ObjC)]
		public static void ClearCookies(ObjC.Object handle)
		@{
			WKWebsiteDataStore* store = ((WKWebView*)handle).configuration.websiteDataStore;
			NSSet* types = [NSSet setWithObject:WKWebsiteDataTypeCookies];
			[store removeDataOfTypes:types modifiedSince:[NSDate distantPast] completionHandler:nil];
		@}

		[Foreign(Language.ObjC)]
		public static void ClearCache(ObjC.Object handle)
		@{
			WKWebsiteDataStore* store = ((WKWebView*)handle).configuration.websiteDataStore;
			NSSet* types = [NSSet setWithObjects:WKWebsiteDataTypeDiskCache, WKWebsiteDataTypeMemoryCache, nil];
			[store removeDataOfTypes:types modifiedSince:[NSDate distantPast] completionHandler:nil];
			[[NSURLCache sharedURLCache] removeAllCachedResponses];
		@}

		[Foreign(Language.ObjC)]
		public static void ClearStorage(ObjC.Object handle)
		@{
			WKWebsiteDataStore* store = ((WKWebView*)handle).configuration.websiteDataStore;
			NSSet* types = [NSSet setWithObjects:
				WKWebsiteDataTypeLocalStorage,
				WKWebsiteDataTypeSessionStorage,
				WKWebsiteDataTypeIndexedDBDatabases,
				WKWebsiteDataTypeWebSQLDatabases,
				WKWebsiteDataTypeOfflineWebApplicationCache,
				nil];
			[store removeDataOfTypes:types modifiedSince:[NSDate distantPast] completionHandler:nil];
		@}

		[Foreign(Language.ObjC)]
		public static void ReloadIgnoringCache(ObjC.Object handle)
		@{
			[[NSURLCache sharedURLCache] removeAllCachedResponses];
			[(WKWebView*)handle reload];
		@}

		[Foreign(Language.ObjC)]
		public static string GetURL(ObjC.Object handle)
		@{
			WKWebView* wv = handle;
			return wv.URL.absoluteString;
		@}

		[Foreign(Language.ObjC)]
		public static void LoadURL(ObjC.Object handle, String url)
		@{
			WKWebView* wv = handle;
			id nsurl = [NSURL URLWithString:url];
			id request = [[NSURLRequest alloc] initWithURL:nsurl];
			[wv loadRequest:request];
		@}

		[Foreign(Language.ObjC)]
		public static double GetEstimatedProgress(ObjC.Object handle)
		@{
			WKWebView* wv = handle;
			return wv.estimatedProgress;
		@}

		[Foreign(Language.ObjC)]
		public static string GetTitle(ObjC.Object handle)
		@{
			WKWebView* wv = handle;
			return wv.title;
		@}

		[Foreign(Language.ObjC)]
		public static bool GetCanGoBack(ObjC.Object handle)
		@{
			WKWebView* wv = handle;
			return wv.canGoBack;
		@}

		[Foreign(Language.ObjC)]
		public static void GoBack(ObjC.Object handle)
		@{
			WKWebView* wv = handle;
			[wv goBack];
		@}

		[Foreign(Language.ObjC)]
		public static bool GetCanGoForward(ObjC.Object handle)
		@{
			WKWebView* wv = handle;
			return wv.canGoForward;
		@}

		[Foreign(Language.ObjC)]
		public static void GoForward(ObjC.Object handle)
		@{
			WKWebView* wv = handle;
			[wv goForward];
		@}

		[Foreign(Language.ObjC)]
		public static void Reload(ObjC.Object handle)
		@{
			WKWebView* wv = handle;
			[wv reload];
		@}

		[Foreign(Language.ObjC)]
		public static void StopLoading(ObjC.Object handle)
		@{
			WKWebView* wv = handle;
			[wv stopLoading];
		@}

		[Foreign(Language.ObjC)]
		public static void FreeMemory()
		@{
			id cache = [NSURLCache sharedURLCache];
			if(cache!=nil)
				[cache removeAllCachedResponses];
		@}

		[Foreign(Language.ObjC)]
		public static void SetNavigationDelegate(ObjC.Object webViewHandle, ObjC.Object delegateHandle)
		@{
			[webViewHandle setNavigationDelegate:delegateHandle];
		@}
	}
}
