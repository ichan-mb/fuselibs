using Uno;
using Uno.Collections;
using Uno.UX;
using Fuse.Navigation;

namespace Fuse.Controls
{
	internal interface BufferedWebViewCall
	{
		void Apply(IWebView wv);
	}

	internal class LoadHtmlCall : BufferedWebViewCall
	{
		readonly string html;
		readonly string baseUrl;

		public LoadHtmlCall(string html, string baseUrl)
		{
			this.html = html;
			this.baseUrl = baseUrl;
		}

		public void Apply(IWebView wv)
		{
			wv.LoadHtml(html, baseUrl);
		}
	}

	internal class JavaScriptCall : BufferedWebViewCall
	{
		public readonly Action<string> Handler;
		public readonly string Script;

		public JavaScriptCall(string script, Action<string> handler)
		{
			Script = script;
			Handler = handler;
		}

		public void Apply(IWebView wv)
		{
			if (Handler != null)
				wv.Eval(Script, Handler);
			else
				wv.Eval(Script);
		}
	}

	internal class LoadUrlCall : BufferedWebViewCall
	{
		readonly string _url;

		public LoadUrlCall(string url)
		{
			_url = url;
		}

		public void Apply(IWebView wv)
		{
			wv.LoadUrl(_url);
		}
	}

	internal class LoadUrlWithHeadersCall : BufferedWebViewCall
	{
		readonly string _url;
		readonly string[] _headerNames;
		readonly string[] _headerValues;

		public LoadUrlWithHeadersCall(string url, string[] headerNames, string[] headerValues)
		{
			_url = url;
			_headerNames = headerNames;
			_headerValues = headerValues;
		}

		public void Apply(IWebView wv)
		{
			var client = wv as IWebViewRequestClient;
			if (client != null)
				client.LoadUrlWithHeaders(_url, _headerNames, _headerValues);
			else
				wv.LoadUrl(_url);
		}
	}

	internal class PostUrlCall : BufferedWebViewCall
	{
		readonly string _url;
		readonly string _body;

		public PostUrlCall(string url, string body)
		{
			_url = url;
			_body = body;
		}

		public void Apply(IWebView wv)
		{
			var client = wv as IWebViewRequestClient;
			if (client != null)
				client.PostUrl(_url, _body);
			else
				wv.LoadUrl(_url);
		}
	}

	internal class FallbackWebViewClient : IWebViewError, IWebViewSession, IWebViewRequestClient
	{
		public FileSource File { get; set; }

		readonly List<BufferedWebViewCall> _bufferedCalls = new List<BufferedWebViewCall>();

		public FallbackWebViewClient()
		{
			ZoomEnabled = true;
			ScrollEnabled = true;
		}

		public void ApplyBufferedCalls(IWebView wv)
		{
			while (_bufferedCalls.Count > 0)
			{
				var call = _bufferedCalls[0];
				call.Apply(wv);
				_bufferedCalls.Remove(call);
			}
		}

		public string Source { get; set; }
		public string BaseUrl { get; set; }
		public string Url { get; set; }
		public bool CanGoBack { get { return false; } }
		public bool CanGoForward { get { return false; } }
		public string DocumentTitle { get { return ""; } }
		public event HistoryChangedHandler HistoryChanged;
		public void GoBack() { }
		public void GoForward() { }
		public void Reload() { }
		public void Stop() { }

		public void Eval(string js)
		{
			_bufferedCalls.Add(new JavaScriptCall(js, null));
		}

		public void Eval(string js, Action<string> resultHandler)
		{
			_bufferedCalls.Add(new JavaScriptCall(js, resultHandler));
		}

		public void LoadUrl(string url)
		{
			_bufferedCalls.Add(new LoadUrlCall(url));
		}

		public void LoadHtml(string html)
		{
			LoadHtml(html, "");
		}

		public void LoadHtml(string html, string baseUrl)
		{
			_bufferedCalls.Add(new LoadHtmlCall(html, baseUrl));
		}

		public event ValueChangedHandler<double> ProgressChanged;
		public event EventHandler PageLoaded;
		public event EventHandler BeginLoading;
		public event EventHandler UrlChanged;
		public event EventHandler URISchemeHandler;
		public event EventHandler BeginDownload;
		public event EventHandler FileDownloaded;
		public event EventHandler<PageErrorEventArgs> PageError;
		public double Progress { get { return 0.0; } }
		public bool ZoomEnabled { get; set; }
		public bool ScrollEnabled { get; set; }

		public void GetCookies(string url, Action<string> resultHandler)
		{
			if (resultHandler != null)
				resultHandler("");
		}

		public void SetCookie(string url, string cookie) { }
		public void ClearCookies() { }
		public void ClearCache() { }
		public void ClearStorage() { }
		public void ReloadIgnoringCache() { }

		void IWebViewRequestClient.LoadUrlWithHeaders(string url, string[] headerNames, string[] headerValues)
		{
			_bufferedCalls.Add(new LoadUrlWithHeadersCall(url, headerNames, headerValues));
		}

		void IWebViewRequestClient.PostUrl(string url, string body)
		{
			_bufferedCalls.Add(new PostUrlCall(url, body));
		}
	}
}
