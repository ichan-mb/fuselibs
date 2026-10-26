using Uno;
using Uno.UX;
using Fuse.Navigation;
using Fuse.Triggers;

namespace Fuse.Controls
{
	public interface ISourceReceiver
	{
		string Source { get; set; }
	}

	public interface IWebView : IProgress, IBaseNavigation, ISourceReceiver
	{
		void Eval(string js, Action<string> resultHandler);
		void Eval(string js);
		string BaseUrl { get; set; }
		string Url { get; set; }
		string DocumentTitle { get; }
		event EventHandler PageLoaded;
		event EventHandler BeginLoading;
		event EventHandler UrlChanged;
		event EventHandler URISchemeHandler;
		event EventHandler BeginDownload;
		event EventHandler FileDownloaded;
		void LoadHtml(string html);
		void LoadHtml(string html, string baseUrl);
		void LoadUrl(string url);
		void Stop();
		void Reload();
		FileSource File { get; set; }
		bool ZoomEnabled { get; set; }
		bool ScrollEnabled { get; set; }
	}

	/**
		Extends @IWebView with error reporting.

		Native WebView clients implement this interface. Custom @IWebView implementations
		can keep implementing only @IWebView if they do not need to report errors.
	*/
	public interface IWebViewError : IWebView
	{
		event EventHandler<PageErrorEventArgs> PageError;
	}

	/**
		`<HTML/>` is a semantic utility node used to feed a @WebView component or a @LoadHtml action with raw HTML:

		```XML
		<NativeViewHost>
			<WebView>
				<HTML>
					<![CDATA[
						<h1>Boom!</h1>
					]]>
				</HTML>
			</WebView>
		</NativeViewHost>

		<LoadHtml>
			<HTML>
				<![CDATA[
					<h1>Bang!</h1>
				]]>
			</HTML>
		</LoadHtml>
		```
	*/
	public sealed class HTML : Uno.UX.PropertyObject
	{
		internal ISourceReceiver Receiver;

		[UXContent]
		public string Source
		{
			get
			{
				return Receiver.Source;
			}
			set
			{
				Receiver.Source = value;
			}
		}
	}
}
