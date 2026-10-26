using Fuse.Controls;
namespace Fuse.Triggers
{
	/**
		Triggers when a @WebView fails to load a page.

		Unlike @PageLoaded, which only fires when a page finishes loading, this trigger
		fires when the WebView reports a navigation, HTTP, or SSL error.

		## Example

		```xml
			<NativeViewHost>
				<WebView Url="https://example.com">
					<PageFailed Handler="{onError}">
						<Change panel.Color="Red" />
					</PageFailed>
				</WebView>
			</NativeViewHost>
		```

		The error details are also available as a @WebView.PageError event, with the
		fields `url`, `description`, `code`, `httpStatusCode` and `isMainFrame`.
	*/
	public class PageFailed : PulseTrigger<PageErrorEventArgs>
	{
		IWebViewError _webView;

		protected override void OnRooted()
		{
			base.OnRooted();
			_webView = Parent as IWebViewError;
			if (_webView != null)
			{
				_webView.PageError += OnPageError;
			}
			else
			{
				Diagnostics.UserRootError( "WebView", Parent, this );
			}
		}

		void OnPageError(object s, PageErrorEventArgs args)
		{
			Pulse(args);
		}

		protected override void OnUnrooted()
		{
			if (_webView != null)
			{
				_webView.PageError -= OnPageError;
				_webView = null;
			}
			base.OnUnrooted();
		}
	}
}
