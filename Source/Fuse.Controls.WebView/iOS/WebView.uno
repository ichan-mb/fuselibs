using Uno;
using Uno.UX;
using Fuse.Navigation;
using Uno.Compiler.ExportTargetInterop;
using Fuse.Controls;

namespace Fuse.iOS.Controls
{

	extern (iOS) public class WebView :
		Fuse.Controls.Native.iOS.LeafView,
		Fuse.Controls.IWebViewError,
		Fuse.Controls.IWebViewNavigationPolicyClient,
		Fuse.Controls.IWebViewSession,
		Fuse.Controls.IWebViewUserAgentClient,
		Fuse.Controls.IWebViewRequestClient
	{

		public event ValueChangedHandler<double> ProgressChanged;
		Fuse.Controls.WebView _webViewHost;
		readonly ObjC.Object Handle;
		readonly ObjC.Object NavigationDelegate;
		readonly ObjC.Object UIDelegate;
		bool _zoomEnabled;
		bool _scrollEnabled;
		Fuse.Controls.ExternalNavigationPolicy _externalNavigationPolicy;
		Fuse.Controls.NewWindowPolicy _newWindowPolicy;
		string _userAgent;
		string _userAgentSuffix;
		bool _isDisposed;

		public static WebView Create(Fuse.Controls.WebView webViewHost, string[] schemes)
		{
			var wv = WKWebViewHelpers.CreateWebView(webViewHost.ZoomEnabled, webViewHost.ScrollEnabled);
			return new WebView(webViewHost, wv, schemes);
		}

		WebView(Fuse.Controls.WebView webViewHost, ObjC.Object wvHandle, string[] schemes) : base(wvHandle)
		{
			_webViewHost = webViewHost;
			Handle = wvHandle;
			_zoomEnabled = webViewHost.ZoomEnabled;
			_scrollEnabled = webViewHost.ScrollEnabled;
			_externalNavigationPolicy = webViewHost.ExternalNavigationPolicy;
			_newWindowPolicy = webViewHost.NewWindowPolicy;
			_userAgent = webViewHost.UserAgent;
			_userAgentSuffix = webViewHost.UserAgentSuffix;

			NavigationDelegate = NavDelegate.Create(OnBeginNavigation, OnFinishNavigation, OnURLChanged, OnCustomURI, schemes, HasURISchemeHandler);
			WKWebViewHelpers.SetNavigationDelegate(Handle, NavigationDelegate);

			UIDelegate = WKWebViewHelpers.CreateUIDelegate((int)_newWindowPolicy);
			WKWebViewHelpers.SetUIDelegate(Handle, UIDelegate);

			WKWebViewHelpers.SetUserAgent(Handle, _userAgent, _userAgentSuffix);

			// Observe estimatedProgress/canGoBack/canGoForward so progress and
			// history notifications are driven by WebKit instead of per-frame polling.
			NavDelegate.Attach(Handle, NavigationDelegate, OnProgressChanged, OnHistoryChanged, OnPageError, OnBeginDownload, OnFileDownloaded, (int)_externalNavigationPolicy);

			Fuse.Platform.AppEvents.LowMemoryWarning += OnLowMemory;
			_webViewHost.WebViewClient = this;
		}

		public override void Dispose()
		{
			if (_isDisposed) return;
			_isDisposed = true;

			NavDelegate.Detach(NavigationDelegate);
			WKWebViewHelpers.ClearUIDelegate(Handle);
			Fuse.Platform.AppEvents.LowMemoryWarning -= OnLowMemory;

			if (_webViewHost != null)
			{
				_webViewHost.WebViewClient = null;
				_webViewHost = null;
			}

			base.Dispose();
		}

		~WebView()
		{
			Fuse.Platform.AppEvents.LowMemoryWarning -= OnLowMemory;
		}

		void OnLowMemory()
		{
			debug_log "low mem in WebView";
			WKWebViewHelpers.FreeMemory();
		}

		public string BaseUrl { get; set; }

		string _source;
		public string Source
		{
			get { return _source; }
			set { LoadHtml(_source = value); }
		}

		public void LoadHtml(string html)
		{
			LoadHtml(html, BaseUrl);
		}

		public void LoadHtml(string html, string baseUrl)
		{
			if (_isDisposed || string.IsNullOrEmpty(html)) return;
			WKWebViewHelpers.LoadHTML(Handle, html, baseUrl ?? "");
		}

		public string Url
		{
			get { return WKWebViewHelpers.GetURL(Handle); }
			set { LoadUrl(value); }
		}

		public void LoadUrl(string url)
		{
			if (_isDisposed) return;
			if (url == null || url == "") url = "about:blank";
			WKWebViewHelpers.LoadURL(Handle, url);
		}

		public void Eval(string js)
		{
			if (_isDisposed) return;
			WKWebViewHelpers.EvalOnWebView(Handle, js);
		}

		public void Eval(string js, Action<string> onResult)
		{
			if (_isDisposed) return;
			WKWebViewHelpers.EvalOnWebViewWithHandler(Handle, js, onResult);
		}

		FileSource _file;
		public FileSource File
		{
			get { return _file; }
			set
			{
				_file = value;
				if (_file != null)
					LoadFile(_file);
			}
		}

		void LoadFile(FileSource file)
		{
			string data = "";
			try{
				data = file.ReadAllText();
			}catch(Uno.Exception e){
				data = e.ToString();
			}finally{
				LoadHtml(data);
			}
		}

		void OnProgressChanged()
		{
			if (_isDisposed) return;
			if (ProgressChanged != null)
				ProgressChanged(this, new ValueChangedArgs<double>(Progress));
		}


		void OnBeginNavigation()
		{
			if (_isDisposed) return;
			if(BeginLoading != null)
				BeginLoading(this, EventArgs.Empty);
		}

		void OnURLChanged()
		{
			if (_isDisposed) return;
			if(UrlChanged != null)
				UrlChanged(this, EventArgs.Empty);
		}

		void OnHistoryChanged()
		{
			if (_isDisposed) return;
			if(HistoryChanged != null)
				HistoryChanged(this);
		}

		void OnPageError(string url, string description, int code, int httpStatusCode, bool isMainFrame)
		{
			if (_isDisposed) return;
			if (PageError != null)
				PageError(this, new PageErrorEventArgs(url, description, code, httpStatusCode, isMainFrame));
		}

		void OnBeginDownload(string url)
		{
			if (_isDisposed) return;
			if (BeginDownload != null)
				BeginDownload(this, new DownloadEventArgs(url, null));
		}

		void OnFileDownloaded(string url, string path)
		{
			if (_isDisposed) return;
			if (FileDownloaded != null)
				FileDownloaded(this, new DownloadEventArgs(url, path));
		}

		void IWebViewNavigationPolicyClient.SetExternalNavigationPolicy(Fuse.Controls.ExternalNavigationPolicy policy)
		{
			_externalNavigationPolicy = policy;
			if (!_isDisposed)
				NavDelegate.SetExternalNavigationPolicy(NavigationDelegate, (int)policy);
		}

		void IWebViewNavigationPolicyClient.SetNewWindowPolicy(Fuse.Controls.NewWindowPolicy policy)
		{
			_newWindowPolicy = policy;
			if (!_isDisposed)
				WKWebViewHelpers.SetUIDelegateNewWindowPolicy(UIDelegate, (int)policy);
		}

		void IWebViewUserAgentClient.SetUserAgent(string userAgent, string userAgentSuffix)
		{
			_userAgent = userAgent;
			_userAgentSuffix = userAgentSuffix;
			if (!_isDisposed)
				WKWebViewHelpers.SetUserAgent(Handle, userAgent, userAgentSuffix);
		}

		void IWebViewRequestClient.LoadUrlWithHeaders(string url, string[] headerNames, string[] headerValues)
		{
			if (_isDisposed) return;
			WKWebViewHelpers.LoadUrlWithHeaders(Handle, url, headerNames, headerValues);
		}

		void IWebViewRequestClient.PostUrl(string url, string body)
		{
			if (_isDisposed) return;
			WKWebViewHelpers.PostUrl(Handle, url, body);
		}

		void IWebViewSession.GetCookies(string url, Action<string> resultHandler)
		{
			if (_isDisposed)
			{
				if (resultHandler != null) resultHandler("");
				return;
			}
			WKWebViewHelpers.GetCookies(Handle, url, resultHandler);
		}

		void IWebViewSession.SetCookie(string url, string cookie)
		{
			if (!_isDisposed)
				WKWebViewHelpers.SetCookie(Handle, url, cookie);
		}

		void IWebViewSession.ClearCookies()
		{
			if (!_isDisposed)
				WKWebViewHelpers.ClearCookies(Handle);
		}

		void IWebViewSession.ClearCache()
		{
			if (!_isDisposed)
				WKWebViewHelpers.ClearCache(Handle);
		}

		void IWebViewSession.ClearStorage()
		{
			if (!_isDisposed)
				WKWebViewHelpers.ClearStorage(Handle);
		}

		void IWebViewSession.ReloadIgnoringCache()
		{
			if (!_isDisposed)
				WKWebViewHelpers.ReloadIgnoringCache(Handle);
		}

		public bool HasURISchemeHandler()
		{
			return URISchemeHandler != null;
		}

		void OnCustomURI(string url)
		{
			if (_isDisposed) return;
			if(URISchemeHandler!=null)
				URISchemeHandler(this, new URISchemeEventArgs(url));
		}

		void OnFinishNavigation()
		{
			if (_isDisposed) return;
			if(PageLoaded != null)
				PageLoaded(this, EventArgs.Empty);
		}

		public double Progress { get { return WKWebViewHelpers.GetEstimatedProgress(Handle); } }
		public string DocumentTitle { get { return WKWebViewHelpers.GetTitle(Handle); } }
		public bool CanGoBack { get { return WKWebViewHelpers.GetCanGoBack(Handle); } }
		public bool CanGoForward { get { return WKWebViewHelpers.GetCanGoForward(Handle); } }
		public void GoBack() { WKWebViewHelpers.GoBack(Handle); }
		public void GoForward() { WKWebViewHelpers.GoForward(Handle); }
		public void Reload() { WKWebViewHelpers.Reload(Handle); }
		public void Stop() { WKWebViewHelpers.StopLoading(Handle); }
		public event EventHandler BeginLoading;
		public event EventHandler PageLoaded;
		public event EventHandler UrlChanged;
		public event EventHandler URISchemeHandler;
		public event HistoryChangedHandler HistoryChanged;
		public event EventHandler<PageErrorEventArgs> PageError;

		public bool ZoomEnabled
		{
			get { return _zoomEnabled; }
			set
			{
				_zoomEnabled = value;
				if (!_isDisposed)
					WKWebViewHelpers.SetZoomEnabled(Handle, value);
			}
		}

		public bool ScrollEnabled
		{
			get { return _scrollEnabled; }
			set
			{
				_scrollEnabled = value;
				if (!_isDisposed)
					WKWebViewHelpers.SetScrollEnabled(Handle, value);
			}
		}

		public event EventHandler BeginDownload;
		public event EventHandler FileDownloaded;
	}
}
