#import "WVNavDelegate.h"
#import "WVDownloadDelegate.h"
#import "WVUtils.h"

@interface WVNavDelegate ()
@property (nonatomic, weak) WKWebView* observedWebView;
@end

@implementation WVNavDelegate
-(id)initWithEventHandlers:(Action)beginLoading
	loaded:(Action)pageLoaded
	change:(Action)urlChanged
	uriHandler:(StringAction)uriHandler
	schemes:(NSArray*)schemes
	hasURISchemeHandler:(BoolFunc)hasURISchemeHandler
{
	self = [super init];
	self.onBeginLoading = beginLoading;
	self.onPageLoaded = pageLoaded;
	self.onURLChanged = urlChanged;
	self.onCustomURI = uriHandler;
	self.uriSchemes = schemes;
	self.hasURISchemeHandler = hasURISchemeHandler;
	self.externalNavigationPolicy = WVExternalNavigationPolicyAllow;

	if (@available(iOS 14.5, *))
	{
		WVDownloadDelegate* downloadDelegate = [[WVDownloadDelegate alloc] init];
		__weak WVNavDelegate* weakSelf = self;
		downloadDelegate.onFinished = ^(NSString* url, NSString* path) {
			WVNavDelegate* strongSelf = weakSelf;
			if (strongSelf != nil && strongSelf.onFileDownloaded != nil)
				strongSelf.onFileDownloaded(url, path);
		};
		self.downloadDelegate = downloadDelegate;
	}

	return self;
}

-(void)dealloc
{
	[self detachFromWebView];
}

-(void)attachToWebView:(WKWebView*)webView
{
	if (self.observedWebView == webView)
		return;

	[self detachFromWebView];

	self.observedWebView = webView;

	[webView addObserver:self forKeyPath:@"estimatedProgress" options:NSKeyValueObservingOptionNew context:NULL];
	[webView addObserver:self forKeyPath:@"canGoBack" options:NSKeyValueObservingOptionNew context:NULL];
	[webView addObserver:self forKeyPath:@"canGoForward" options:NSKeyValueObservingOptionNew context:NULL];
}

-(void)detachFromWebView
{
	WKWebView* webView = self.observedWebView;
	if (webView == nil)
		return;

	self.observedWebView = nil;

	@try { [webView removeObserver:self forKeyPath:@"estimatedProgress"]; }
	@catch (NSException* e) { }

	@try { [webView removeObserver:self forKeyPath:@"canGoBack"]; }
	@catch (NSException* e) { }

	@try { [webView removeObserver:self forKeyPath:@"canGoForward"]; }
	@catch (NSException* e) { }
}

-(void)observeValueForKeyPath:(NSString*)keyPath ofObject:(id)object change:(NSDictionary*)change context:(void*)context
{
	if ([keyPath isEqualToString:@"estimatedProgress"])
	{
		if (self.onProgress != nil)
			self.onProgress();
	}
	else if ([keyPath isEqualToString:@"canGoBack"] || [keyPath isEqualToString:@"canGoForward"])
	{
		if (self.onHistoryChanged != nil)
			self.onHistoryChanged();
	}
	else
	{
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}
}

-(void) webView:(WKWebView*)webview
	decidePolicyForNavigationAction:(WKNavigationAction*)navAction
	decisionHandler:(void(^)(WKNavigationActionPolicy))handler
{
	if(self.hasURISchemeHandler())
	{
		NSString* url = navAction.request.URL.absoluteString;
		for(NSString* schemeStr in self.uriSchemes)
		{
			if([url hasPrefix:schemeStr])
			{
				handler(WKNavigationActionPolicyCancel);
				self.onCustomURI(url);
				return;
			}
		}
	}

	NSURL *url = navAction.request.URL;
	if ([url.scheme isEqualToString:@"mailto"] ||
		 [url.scheme isEqualToString:@"sms"] ||
		 [url.scheme isEqualToString:@"tel"])
	{
		if ([WVUtils openURLExternally:url])
		{
			handler(WKNavigationActionPolicyCancel);
			return;
		}
	}

	BOOL isMainFrame = navAction.targetFrame != nil && navAction.targetFrame.isMainFrame;
	BOOL shouldApplyPolicy = isMainFrame &&
		(navAction.navigationType == WKNavigationTypeLinkActivated ||
		 navAction.navigationType == WKNavigationTypeFormSubmitted);

	if (shouldApplyPolicy)
	{
		if (self.externalNavigationPolicy == WVExternalNavigationPolicyBlock)
		{
			handler(WKNavigationActionPolicyCancel);
			return;
		}

		if (self.externalNavigationPolicy == WVExternalNavigationPolicyOpenExternally)
		{
			[WVUtils openURLExternally:url];
			handler(WKNavigationActionPolicyCancel);
			return;
		}
	}

	handler(WKNavigationActionPolicyAllow);
}

-(void)webView:(WKWebView*)webView
	didFailProvisionalNavigation:(WKNavigation*)navigation
	withError:(NSError*)error
{
	[self reportError:error webView:webView];
}

-(void)webView:(WKWebView*)webView
	decidePolicyForNavigationResponse:(WKNavigationResponse*)navigationResponse
	decisionHandler:(void(^)(WKNavigationResponsePolicy))decisionHandler
{
	if (navigationResponse.isForMainFrame &&
		[navigationResponse.response isKindOfClass:[NSHTTPURLResponse class]])
	{
		NSHTTPURLResponse* response = (NSHTTPURLResponse*)navigationResponse.response;
		if (response.statusCode >= 400)
		{
			NSString* url = response.URL.absoluteString;
			if (url == nil)
				url = webView.URL.absoluteString ?: @"";

			if (self.onPageError != nil)
				self.onPageError(url,
					[NSHTTPURLResponse localizedStringForStatusCode:response.statusCode] ?: @"",
					0,
					(int)response.statusCode,
					YES);
		}
	}

	BOOL isDownload = NO;
	if (!navigationResponse.canShowMIMEType)
		isDownload = YES;
	else if ([navigationResponse.response isKindOfClass:[NSHTTPURLResponse class]])
	{
		NSDictionary* headers = ((NSHTTPURLResponse*)navigationResponse.response).allHeaderFields;
		NSString* disposition = nil;
		for (NSString* key in headers)
		{
			if ([key caseInsensitiveCompare:@"Content-Disposition"] == NSOrderedSame)
			{
				disposition = headers[key];
				break;
			}
		}

		if (disposition != nil && [disposition rangeOfString:@"attachment" options:NSCaseInsensitiveSearch].location != NSNotFound)
			isDownload = YES;
	}

	if (isDownload && navigationResponse.isForMainFrame)
	{
		if (@available(iOS 14.5, *))
		{
			decisionHandler(WKNavigationResponsePolicyDownload);
			return;
		}
	}

	decisionHandler(WKNavigationResponsePolicyAllow);
}

-(void)webView:(WKWebView*)webView
	navigationResponse:(WKNavigationResponse*)navigationResponse
	didBecomeDownload:(WKDownload*)download API_AVAILABLE(ios(14.5))
{
	download.delegate = (WVDownloadDelegate*)self.downloadDelegate;

	if (self.onBeginDownload != nil)
	{
		NSString* url = navigationResponse.response.URL.absoluteString;
		if (url == nil)
			url = webView.URL.absoluteString ?: @"";
		self.onBeginDownload(url);
	}
}

-(void)webView:(WKWebView*)webView
	navigationAction:(WKNavigationAction*)navigationAction
	didBecomeDownload:(WKDownload*)download API_AVAILABLE(ios(14.5))
{
	download.delegate = (WVDownloadDelegate*)self.downloadDelegate;

	if (self.onBeginDownload != nil)
	{
		NSString* url = navigationAction.request.URL.absoluteString;
		self.onBeginDownload(url != nil ? url : @"");
	}
}

-(void)webView:(WKWebView*)webView
	didFailNavigation:(WKNavigation*)navigation
	withError:(NSError*)error
{
	[self reportError:error webView:webView];
}

-(void)webViewWebContentProcessDidTerminate:(WKWebView*)webView
{
	if (self.onPageError != nil)
		self.onPageError(webView.URL.absoluteString ?: @"", @"Web content process terminated", -1, 0, YES);
}

-(void)reportError:(NSError*)error webView:(WKWebView*)webView
{
	if (error == nil)
		return;

	// Cancellation is not a failure; it happens when a navigation is interrupted
	// on purpose, for example by a custom URI scheme handler.
	if ([error.domain isEqualToString:NSURLErrorDomain] && error.code == NSURLErrorCancelled)
		return;

	NSString* url = error.userInfo[NSURLErrorFailingURLStringErrorKey];
	if (url == nil)
		url = webView.URL.absoluteString;
	if (url == nil)
		url = @"";

	if (self.onPageError != nil)
		self.onPageError(url, error.localizedDescription ?: @"", (int)error.code, 0, YES);
}

-(void) webView:(WKWebView*)webview
	didStartProvisionalNavigation:(WKNavigation*)navigation
{
	self.onBeginLoading();
}

-(void) webView:(WKWebView*)webview
	didFinishNavigation:(WKNavigation*)navigation
{
	self.onURLChanged();
	self.onPageLoaded();
}
@end
