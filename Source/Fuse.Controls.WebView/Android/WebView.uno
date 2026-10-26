using Uno;
using Uno.UX;
using Uno.Platform;
using Uno.Collections;
using Fuse;
using Fuse.Navigation;
using Fuse.Android.Controls.WebViewUtils;
using Fuse.Android.Controls.WebViewUtils.WebViewForeign;
using Fuse.Controls;

namespace Fuse.Android.Controls
{

	extern (Android) public class WebView :
		Fuse.Controls.Native.Android.LeafView,
		Fuse.Controls.IWebViewError,
		Fuse.Controls.IWebViewNavigationPolicyClient,
		Fuse.Controls.IWebViewSession,
		Fuse.Controls.IWebViewUserAgentClient,
		Fuse.Controls.IWebViewRequestClient
	{
		Java.Object _downloadListenerHandle;
		Java.Object _webChromeClientHandle;
		Java.Object _webViewClientHandle;
		Java.Object _webViewHandle;

		public event ValueChangedHandler<double> ProgressChanged;
		public event EventHandler BeginLoading;
		public event EventHandler UrlChanged;
		public event EventHandler PageLoaded;
		public event EventHandler URISchemeHandler;
		public event EventHandler BeginDownload;
		public event EventHandler FileDownloaded;
		public event EventHandler<PageErrorEventArgs> PageError;

		Fuse.Controls.WebView _webViewHost;
		JSEvalRequestManager _evalRequestMgr;
		string[] _uriSchemes;
		bool _zoomEnabled;
		bool _scrollEnabled;
		Fuse.Controls.ExternalNavigationPolicy _externalNavigationPolicy;
		Fuse.Controls.NewWindowPolicy _newWindowPolicy;
		string _userAgent;
		string _userAgentSuffix;
		bool _isDisposed;

		public static WebView Create(Fuse.Controls.WebView webViewHost, string[] schemes)
		{
			var handle = WebViewForeign.CreateWebView(webViewHost.ZoomEnabled, webViewHost.ScrollEnabled);
			return new WebView(webViewHost, handle, schemes);
		}

		WebView(Fuse.Controls.WebView host, Java.Object handle, string[] schemes) : base(handle)
		{
			_webViewHost = host;
			_webViewHandle = handle;
			_zoomEnabled = host.ZoomEnabled;
			_scrollEnabled = host.ScrollEnabled;
			_externalNavigationPolicy = host.ExternalNavigationPolicy;
			_newWindowPolicy = host.NewWindowPolicy;
			_userAgent = host.UserAgent;
			_userAgentSuffix = host.UserAgentSuffix;

			_evalRequestMgr = new JSEvalRequestManager(_webViewHandle);

			_webViewHandle.SetUserAgent(_userAgent, _userAgentSuffix);

			_downloadListenerHandle = _webViewHandle.CreateAndSetDownloadListener(OnBeginDownload, OnFileDownloaded);
			_webChromeClientHandle = _webViewHandle.CreateAndSetWebChromeClient(OnProgressChanged, (int)_newWindowPolicy);
			_webViewClientHandle = _webViewHandle.CreateAndSetWebViewClient(
				OnPageLoaded,
				OnBeginloading,
				OnUrlChanged,
				OnCustomURI,
				schemes,
				HasURISchemeHandler,
				OnPageError,
				(int)_externalNavigationPolicy
			);
			_uriSchemes = schemes;

			_webViewHost.WebViewClient = this;
		}

		public bool HasURISchemeHandler()
		{
			return URISchemeHandler!=null;
		}

		void IWebViewNavigationPolicyClient.SetExternalNavigationPolicy(Fuse.Controls.ExternalNavigationPolicy policy)
		{
			_externalNavigationPolicy = policy;
			if (_webViewClientHandle != null)
				_webViewClientHandle.SetExternalNavigationPolicy((int)policy);
		}

		void IWebViewNavigationPolicyClient.SetNewWindowPolicy(Fuse.Controls.NewWindowPolicy policy)
		{
			_newWindowPolicy = policy;
			if (_webChromeClientHandle != null)
				_webChromeClientHandle.SetWebChromeClientNewWindowPolicy((int)policy);
		}

		void IWebViewUserAgentClient.SetUserAgent(string userAgent, string userAgentSuffix)
		{
			_userAgent = userAgent;
			_userAgentSuffix = userAgentSuffix;
			if (_webViewHandle != null)
				_webViewHandle.SetUserAgent(userAgent, userAgentSuffix);
		}

		void IWebViewRequestClient.LoadUrlWithHeaders(string url, string[] headerNames, string[] headerValues)
		{
			if (_isDisposed || _webViewHandle == null) return;
			_webViewHandle.LoadUrlWithHeaders(url, headerNames, headerValues);
			OnHistoryChanged();
		}

		void IWebViewRequestClient.PostUrl(string url, string body)
		{
			if (_isDisposed || _webViewHandle == null) return;
			_webViewHandle.PostUrl(url, body);
			OnHistoryChanged();
		}

		void IWebViewSession.GetCookies(string url, Action<string> resultHandler)
		{
			if (_isDisposed)
			{
				if (resultHandler != null) resultHandler("");
				return;
			}
			WebViewForeign.GetCookies(url, resultHandler);
		}

		void IWebViewSession.SetCookie(string url, string cookie)
		{
			if (!_isDisposed)
				WebViewForeign.SetCookie(url, cookie);
		}

		void IWebViewSession.ClearCookies()
		{
			if (!_isDisposed)
				WebViewForeign.ClearCookies();
		}

		void IWebViewSession.ClearCache()
		{
			if (!_isDisposed && _webViewHandle != null)
				_webViewHandle.ClearCache();
		}

		void IWebViewSession.ClearStorage()
		{
			if (!_isDisposed)
				WebViewForeign.ClearStorage();
		}

		void IWebViewSession.ReloadIgnoringCache()
		{
			if (!_isDisposed && _webViewHandle != null)
				_webViewHandle.ReloadIgnoringCache();
		}

		public override void Dispose()
		{
			if (_isDisposed) return;
			_isDisposed = true;

			if (_webViewHost != null)
			{
				_webViewHost.WebViewClient = null;
				_webViewHost = null;
			}

			if (_evalRequestMgr != null)
			{
				_evalRequestMgr.Dispose();
				_evalRequestMgr = null;
			}

			if (_webViewHandle != null)
			{
				_webViewHandle.DestroyWebView(_webChromeClientHandle, _downloadListenerHandle, "FuseJSInterface");
				_webViewHandle = null;
			}

			_webChromeClientHandle = null;
			_webViewClientHandle = null;
			_downloadListenerHandle = null;

			base.Dispose();
		}

		void OnCustomURI(string url)
		{
			if (_isDisposed) return;
			if(URISchemeHandler!=null)
				URISchemeHandler(this, new URISchemeEventArgs(url));
		}

		void OnPageLoaded()
		{
			if (_isDisposed) return;
			if(PageLoaded!=null)
				PageLoaded(this, EventArgs.Empty);
		}

		void OnPageError(string url, string description, int code, int httpStatusCode, bool isMainFrame)
		{
			if (_isDisposed) return;
			if (PageError != null)
				PageError(this, new PageErrorEventArgs(url, description, code, httpStatusCode, isMainFrame));
		}

		void OnBeginloading()
		{
			if (_isDisposed) return;
			if(BeginLoading!=null)
				BeginLoading(this, EventArgs.Empty);
		}

		void OnUrlChanged()
		{
			if (_isDisposed) return;
			if(UrlChanged!=null)
				UrlChanged(this, EventArgs.Empty);
			OnHistoryChanged();
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

		public void Eval(string js, Action<string> resultHandler)
		{
			if (_evalRequestMgr != null)
				_evalRequestMgr.EvaluateJs(js, resultHandler);
		}

		public void Eval(string js)
		{
			if (_evalRequestMgr != null)
				_evalRequestMgr.EvaluateJs(js, null);
		}

		public string BaseUrl { get; set; }

		string _source;
		public string Source
		{
			get { return _source; }
			set { LoadHtml(_source = value); }
		}

		public string Url
		{
			get { return _webViewHandle.GetUrl(); }
			set { LoadUrl(value); }
		}

		public string DocumentTitle
		{
			get { return _webViewHandle.GetTitle(); }
		}

		public bool CanGoBack
		{
			get { return _webViewHandle.CanGoBack(); }
		}

		public bool CanGoForward
		{
			get { return _webViewHandle.CanGoForward(); }
		}

		public void GoBack()
		{
			_webViewHandle.GoBack();
		}

		public void GoForward()
		{
			_webViewHandle.GoForward();
		}

		public void Reload()
		{
			_webViewHandle.Reload();
		}

		public void Stop()
		{
			_webViewHandle.StopLoading();
		}

		public event HistoryChangedHandler HistoryChanged;

		void OnHistoryChanged()
		{
			if (HistoryChanged != null && _webViewHost != null)
			{
				HistoryChanged(_webViewHost);
			}
		}

		public void LoadHtml(string html)
		{
			LoadHtml(html, null);
		}

		public void LoadHtml(string html, string baseUrl)
		{
			if (_isDisposed || _webViewHandle == null) return;
			if(html == null || html == "") return;
			_webViewHandle.LoadHtml(html, baseUrl ?? BaseUrl ?? "");

			OnHistoryChanged();
		}

		public void LoadUrl(string url)
		{
			if (_isDisposed || _webViewHandle == null) return;
			if (url == null || url== "") url = "about:blank";
			//This extra check is needed on android since setting the Url directly doesn't trigger shouldOverrideUrlLoading
			if(HasURISchemeHandler())
			{
				foreach(string uri in _uriSchemes)
				{
					if(url.IndexOf(uri) == 0)
					{
						OnCustomURI(url);
						return;
					}
				}
			}
			_webViewHandle.LoadUrl(url);
			OnHistoryChanged();
		}

		void OnProgressChanged(int newProgress)
		{
			if (_isDisposed) return;
			if (ProgressChanged != null)
				ProgressChanged(this, new ValueChangedArgs<double>(newProgress/100.0));
		}

		public double Progress
		{
			get { return _webViewHandle.GetProgress() / 100.0; }
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

		public bool ZoomEnabled
		{
			get { return _zoomEnabled; }
			set
			{
				_zoomEnabled = value;
				if (_webViewHandle != null)
					_webViewHandle.SetZoomEnabled(value);
			}
		}

		public bool ScrollEnabled
		{
			get { return _scrollEnabled; }
			set
			{
				_scrollEnabled = value;
				if (_webViewHandle != null)
					_webViewHandle.SetScrollEnabled(value);
			}
		}
	}
}
