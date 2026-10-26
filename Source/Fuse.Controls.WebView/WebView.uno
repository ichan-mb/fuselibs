using Uno;
using Uno.UX;
using Fuse.Navigation;
using Fuse.Elements;

namespace Fuse.Controls
{

	/**
		Displays web content natively on android and iOS.

		As the WebView is native only, it needs to be contained in a @NativeViewHost.

		The WebView can be used to present web content either over the http protocol or by loading HTML as a string, and hooks into some useful triggers for building a customized browsing experience, such as @PageBeginLoading, @WhilePageLoading, @PageLoaded and @PageFailed.
		Navigation triggers like @GoBack and @GoForward are complemented with WebView-specific ones, like @Reload, @LoadUrl and @LoadHtml. It can also be used to drive a @ProgressAnimation.

		The @EvaluateJS trigger is noteworthy, since it allows arbitrary JavaScript to be run in the WebView's context and the resulting data be fed back into Fuse:

		```XML
		<App Background="#333">
			<JavaScript>
				module.exports = {
						onPageLoaded : function(res) {
							console.log("WebView arrived at "+ JSON.parse(res.json).url);
					}
				};
			</JavaScript>
			<DockPanel>
				<StatusBarBackground Dock="Top"/>
				<NativeViewHost>
					<WebView Dock="Fill" Url="https://www.google.com">
						<PageLoaded>
							<EvaluateJS Handler="{onPageLoaded}">
								var result = {
									url : document.location.href
								};
								return result;
							</EvaluateJS>
						</PageLoaded>
					</WebView>
				</NativeViewHost>

				<BottomBarBackground Dock="Bottom" />
			</DockPanel>
		</App>
		```

		WebViews can also be fed raw HTML to display by wrapping an @HTML node or via the @LoadHtml trigger action:
		```xml
		<LoadHtml TargetNode="myWebView" BaseUrl="http://my.domain" Source="{html}"/>
		```
	*/
	public partial class WebView : Panel, IWebViewError, IWebViewSession
	{


		static string PreprocUriScheme(string inScheme)
		{
			return inScheme.Contains(":") ? inScheme : (inScheme + ":");
		}

		protected override Fuse.Controls.Native.IView CreateNativeView()
		{
			if defined(Android || iOS)
			{
				string scheme = @(project.mobile.uriScheme);
				scheme = PreprocUriScheme(scheme);
				string[] schemes = scheme!="" ? new string[]{scheme} :  new string[]{};

				if defined(Android)
					return Fuse.Android.Controls.WebView.Create(this, schemes);
				else if defined(iOS)
					return Fuse.iOS.Controls.WebView.Create(this, schemes);
				else
					build_error;
			}

			return base.CreateNativeView();
		}

		public double Progress
		{
			get { return WebViewClient.Progress; }
		}

		public event ValueChangedHandler<double> ProgressChanged;
		/**
			Callback that fires when the page has completed loading
		*/
		public event EventHandler PageLoaded;
		/**
			Callback that fires when a new page begins loading
		*/
		public event EventHandler BeginLoading;
		/**
			Callback that fires when the current url is changed
		*/
		public event EventHandler UrlChanged;
		/**
			Callback that fires if a URL request matching the app's UriScheme is made
		*/
		public event EventHandler URISchemeHandler;
		/**
			Callback that fires when a file will start to download
		*/
		public event EventHandler BeginDownload;
		/**
			Callback that fires when a file has been downloaded
		*/
		public event EventHandler FileDownloaded;

		/**
			Callback that fires when a page fails to load
		*/
		public event EventHandler<PageErrorEventArgs> PageError;


		HTML _html;

		[UXContent]
		public HTML HTMLSource
		{
			get
			{
				return _html;
			}
			set {
				_html = value;
				_html.Receiver = this;
			}
		}

		public WebView()
		{
			ClipToBounds = true;

			if defined(!MOBILE)
			{
				Background = new Fuse.Drawing.SolidColor(float4(0.6f,0.6f,0.6f,1.0f));
				var t = new Fuse.Controls.Text();
				t.Alignment = Alignment.Center;
				t.SetValue("WebView requires a mobile target.", this);
				t.TextAlignment = TextAlignment.Center;
				Children.Add(t);
			}
			WebViewClient = _fallbackClient;
		}

		readonly FallbackWebViewClient _fallbackClient = new FallbackWebViewClient();

		Fuse.Controls.ExternalNavigationPolicy _externalNavigationPolicy = Fuse.Controls.ExternalNavigationPolicy.Allow;
		Fuse.Controls.NewWindowPolicy _newWindowPolicy = Fuse.Controls.NewWindowPolicy.OpenInWebView;
		string _userAgent;
		string _userAgentSuffix;

		IWebView _webViewClient;
		public IWebView WebViewClient
		{
			get { return _webViewClient ?? _fallbackClient; }
			set
			{
				string url = "about:blank";
				string source = "";
				string baseUrl = null;
				bool zoomEnabled = true;
				bool scrollEnabled = true;
				FileSource file = null;

				if (_webViewClient != null)
				{
					_webViewClient.ProgressChanged -= OnProgressChanged;
					_webViewClient.PageLoaded -= OnPageLoaded;
					_webViewClient.BeginLoading -= OnBeginLoading;
					_webViewClient.UrlChanged -= OnPageChanged;
					_webViewClient.URISchemeHandler -= URISchemeHandler;
					_webViewClient.BeginDownload -= BeginDownload;
					_webViewClient.FileDownloaded -= FileDownloaded;

					var oldErrorClient = _webViewClient as IWebViewError;
					if (oldErrorClient != null)
						oldErrorClient.PageError -= OnPageError;

					url = _webViewClient.Url;
					source = _webViewClient.Source ?? "";
					baseUrl = _webViewClient.BaseUrl;
					file = _webViewClient.File;
					zoomEnabled = _webViewClient.ZoomEnabled;
					scrollEnabled = _webViewClient.ScrollEnabled;
				}

				_webViewClient = value ?? _fallbackClient;

				if (_webViewClient != null)
				{
					_webViewClient.ProgressChanged += OnProgressChanged;
					_webViewClient.PageLoaded += OnPageLoaded;
					_webViewClient.BeginLoading += OnBeginLoading;
					_webViewClient.UrlChanged += OnPageChanged;
					_webViewClient.URISchemeHandler += URISchemeHandler;
					_webViewClient.BeginDownload += BeginDownload;
					_webViewClient.FileDownloaded += FileDownloaded;

					var errorClient = _webViewClient as IWebViewError;
					if (errorClient != null)
						errorClient.PageError += OnPageError;

					_webViewClient.BaseUrl = baseUrl;
					_webViewClient.Source = source;
					_webViewClient.ZoomEnabled = zoomEnabled;
					_webViewClient.ScrollEnabled = scrollEnabled;

					if(source == "")
					{
						_webViewClient.Url = url;
					}
					_webViewClient.File = file;

					var policyClient = _webViewClient as IWebViewNavigationPolicyClient;
					if (policyClient != null)
					{
						policyClient.SetExternalNavigationPolicy(ExternalNavigationPolicy);
						policyClient.SetNewWindowPolicy(NewWindowPolicy);
					}

					var userAgentClient = _webViewClient as IWebViewUserAgentClient;
					if (userAgentClient != null)
						userAgentClient.SetUserAgent(_userAgent, _userAgentSuffix);

					applyFallbackCalls(_webViewClient);
				}
			}
		}

		/**
			Determines if pinch-to-zoom gestures are available in the WebView.
			Defaults to 'true'
		*/
		public bool ZoomEnabled {
			set {
				WebViewClient.ZoomEnabled = value;
			}
			get { return WebViewClient.ZoomEnabled; }
		}

		/**
			Determines if scrolling gestures are available in the WebView.
			Defaults to 'true'
		*/
		public bool ScrollEnabled {
			set {
				WebViewClient.ScrollEnabled = value;
			}
			get { return WebViewClient.ScrollEnabled; }
		}

		/**
			Determines how navigations to URLs that are not handled inside the WebView are treated.
			Defaults to `Allow`.
		*/
		public Fuse.Controls.ExternalNavigationPolicy ExternalNavigationPolicy
		{
			get { return _externalNavigationPolicy; }
			set
			{
				_externalNavigationPolicy = value;
				var client = WebViewClient as IWebViewNavigationPolicyClient;
				if (client != null)
					client.SetExternalNavigationPolicy(value);
			}
		}

		/**
			Determines what happens when the page tries to open a new window, for example with
			`target="_blank"` or `window.open()`. Defaults to `OpenInWebView`.
		*/
		public Fuse.Controls.NewWindowPolicy NewWindowPolicy
		{
			get { return _newWindowPolicy; }
			set
			{
				_newWindowPolicy = value;
				var client = WebViewClient as IWebViewNavigationPolicyClient;
				if (client != null)
					client.SetNewWindowPolicy(value);
			}
		}

		/**
			Overrides the User-Agent header sent by the WebView. When empty, the default
			user agent is used, optionally with @UserAgentSuffix appended.
		*/
		public string UserAgent
		{
			get { return _userAgent; }
			set
			{
				_userAgent = value ?? "";
				ApplyUserAgent();
			}
		}

		/**
			Appends this string to the default User-Agent. Ignored when @UserAgent is set.
		*/
		public string UserAgentSuffix
		{
			get { return _userAgentSuffix; }
			set
			{
				_userAgentSuffix = value ?? "";
				ApplyUserAgent();
			}
		}

		void ApplyUserAgent()
		{
			var client = WebViewClient as IWebViewUserAgentClient;
			if (client != null)
				client.SetUserAgent(_userAgent, _userAgentSuffix);
		}

		/**
			Loads a URL with additional HTTP headers. `headerNames` and `headerValues`
			must have the same length; extra entries are ignored.
		*/
		public void LoadUrl(string url, string[] headerNames, string[] headerValues)
		{
			var client = WebViewClient as IWebViewRequestClient;
			if (client != null)
				client.LoadUrlWithHeaders(url ?? "about:blank", headerNames, headerValues);
			else
				LoadUrl(url);
		}

		/**
			Performs a POST navigation with an `application/x-www-form-urlencoded` body.
		*/
		public void PostUrl(string url, string body)
		{
			var client = WebViewClient as IWebViewRequestClient;
			if (client != null)
				client.PostUrl(url ?? "about:blank", body ?? "");
			else
				LoadUrl(url);
		}

		/**
			Retrieves the cookie header string for the given URL.
		*/
		public void GetCookies(string url, Action<string> resultHandler)
		{
			var session = WebViewClient as IWebViewSession;
			if (session != null)
				session.GetCookies(url ?? "", resultHandler);
			else if (resultHandler != null)
				resultHandler("");
		}

		/**
			Sets a cookie for the given URL.
		*/
		public void SetCookie(string url, string cookie)
		{
			var session = WebViewClient as IWebViewSession;
			if (session != null)
				session.SetCookie(url ?? "", cookie ?? "");
		}

		/**
			Removes all cookies.
		*/
		public void ClearCookies()
		{
			var session = WebViewClient as IWebViewSession;
			if (session != null)
				session.ClearCookies();
		}

		/**
			Clears the WebView cache.
		*/
		public void ClearCache()
		{
			var session = WebViewClient as IWebViewSession;
			if (session != null)
				session.ClearCache();
		}

		/**
			Clears local storage, session storage and related web storage.
		*/
		public void ClearStorage()
		{
			var session = WebViewClient as IWebViewSession;
			if (session != null)
				session.ClearStorage();
		}

		/**
			Reloads the current page while ignoring cached responses.
		*/
		public void ReloadIgnoringCache()
		{
			var session = WebViewClient as IWebViewSession;
			if (session != null)
				session.ReloadIgnoringCache();
		}

		void applyFallbackCalls(IWebView client)
		{
			// When the client is reset to the fallback (for example on dispose),
			// replaying into the fallback itself would re-buffer the calls forever.
			if (client == (IWebView)_fallbackClient) return;

			_fallbackClient.ApplyBufferedCalls(client);
		}

		void OnPageChanged(object sender, EventArgs args)
		{
			UpdateRestState();
			if (UrlChanged != null)
				UrlChanged(this, EventArgs.Empty);
		}

		void OnBeginLoading(object sender, EventArgs args)
		{
			if (BeginLoading != null)
				BeginLoading(this, EventArgs.Empty);
		}

		void OnProgressChanged(object sender, EventArgs args)
		{
			if (ProgressChanged != null)
				ProgressChanged(this, new ValueChangedArgs<double>(Progress));
		}

		void OnPageLoaded(object sender, EventArgs args)
		{
			if (PageLoaded != null)
				PageLoaded(this, EventArgs.Empty);
		}

		void OnPageError(object sender, PageErrorEventArgs args)
		{
			if (PageError != null)
				PageError(this, args);
		}

		public string DocumentTitle
		{
			get { return WebViewClient.DocumentTitle; }
		}

		public void LoadHtml(string html, string baseUrl)
		{
			WebViewClient.LoadHtml(html ?? "", baseUrl);
		}
		public void LoadHtml(string html)
		{
			WebViewClient.LoadHtml(html ?? "");
		}

		/**
			When loading HTML from source; The base URL serving as scope for the HTML.
		*/
		public string BaseUrl
		{
			get { return WebViewClient.BaseUrl; }
			set { WebViewClient.BaseUrl = value ?? ""; }
		}

		/**
			The HTML source code to display.
		*/
		public string Source
		{
			get { return WebViewClient.Source; }
			set { WebViewClient.Source = value ?? ""; }
		}

		internal void UpdateRestState()
		{
			OnPropertyChanged(_urlName, this);
			OnHistoryChanged();
		}

		static Selector _urlName = "Url";

		public void SetUrl(string value, IPropertyListener origin)
		{
			OnPropertyChanged(_urlName, origin);
			WebViewClient.Url = value;
			UpdateRestState();
		}

		[UXOriginSetter("SetUrl")]
		/**
			The URL from which to load content
		*/
		public string Url
		{
			get { return WebViewClient.Url; }
			set { SetUrl(value ?? "about:blank", this); }
		}

		/**
			The File from which to load HTML
		*/
		public FileSource File
		{
			get { return WebViewClient.File; }
			set { WebViewClient.File = value; }
		}

		public bool CanGoBack
		{
			get { return WebViewClient.CanGoBack; }
		}

		public bool CanGoForward
		{
			get { return WebViewClient.CanGoForward; }
		}

		public void Eval(string js)
		{
			WebViewClient.Eval(js ?? "");
		}

		public void Eval(string js, Action<string> resultHandler)
		{
			WebViewClient.Eval(js ?? "", resultHandler);
		}

		public void GoBack()
		{
			WebViewClient.GoBack();
		}

		public void GoForward()
		{
			WebViewClient.GoForward();
		}

		public void Reload()
		{
			WebViewClient.Reload();
		}

		public void Stop()
		{
			WebViewClient.Stop();
		}

		public void LoadUrl(string url)
		{
			WebViewClient.LoadUrl(url ?? "about:blank");
		}

		public event HistoryChangedHandler HistoryChanged;

		protected void OnHistoryChanged()
		{
			if (HistoryChanged != null)
				HistoryChanged(this);
		}
	}

}
