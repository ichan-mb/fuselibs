package com.fuse.webview;
import android.annotation.TargetApi;
import android.net.http.SslError;
import android.os.Build;
import android.webkit.SslErrorHandler;
import android.webkit.WebResourceError;
import android.webkit.WebResourceRequest;
import android.webkit.WebResourceResponse;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.graphics.Bitmap;
import com.foreign.Uno.Action;
import com.foreign.Uno.Func;
import com.foreign.Uno.Action_String;
import com.foreign.Uno.Action_String_String_int_int_boolean;
import com.uno.StringArray;

public class FuseWebViewClient extends WebViewClient
{
	boolean redirect;
	boolean loadingFinished;

	Action _pageLoadedAction;
	Action _pageStartedAction;
	Action _urlChangedAction;
	Action_String _onCustomURI;
	String[] _customURIs;
	Func _hasUriSchemeHandler;
	Action_String_String_int_int_boolean _onPageError;
	int _externalNavigationPolicy;

	public FuseWebViewClient(Action loaded, Action started, Action changed,
			Action_String onCustomURI, StringArray customURIs, Func hasUriSchemeHandler,
			Action_String_String_int_int_boolean onPageError,
			int externalNavigationPolicy)
	{
		super();
		_pageLoadedAction = loaded;
		_pageStartedAction = started;
		_urlChangedAction = changed;
		_onCustomURI = onCustomURI;
		_customURIs = customURIs.copyArray();
		_hasUriSchemeHandler = hasUriSchemeHandler;
		_onPageError = onPageError;
		_externalNavigationPolicy = externalNavigationPolicy;
		loadingFinished = true;
		redirect = false;
	}

	public void setExternalNavigationPolicy(int policy)
	{
		_externalNavigationPolicy = policy;
	}

	@TargetApi(24)
	@Override
	public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request)
	{
		// Only apply navigation policies to top-level navigations. Sub-resource and
		// iframe navigations must stay inside the WebView.
		if (request == null || !request.isForMainFrame() || request.getUrl() == null)
			return false;

		return shouldOverrideUrlLoading(view, request.getUrl().toString());
	}

	@Override
	public boolean shouldOverrideUrlLoading(WebView view, String url)
	{
		if(tryInterceptUriScheme(url))
			return true;

		if (url.startsWith("mailto:") ||
				url.startsWith("sms:") ||
				url.startsWith("tel:")) {
			WebViewIntents.openExternally(url);
			return true;
		}

		switch (_externalNavigationPolicy)
		{
			case WebViewNavigationPolicy.EXTERNAL_BLOCK:
				return true;

			case WebViewNavigationPolicy.EXTERNAL_OPEN_EXTERNALLY:
				if (WebViewIntents.openExternally(url))
					return true;
				break;

			case WebViewNavigationPolicy.EXTERNAL_ALLOW:
			default:
				break;
		}

		if(!loadingFinished){
			redirect = true;
		}else{
			if (_pageStartedAction != null)
				_pageStartedAction.run();
		}
		loadingFinished = false;

		// Returning false tells the WebView to perform the navigation itself.
		// Calling view.loadUrl(url) here as well would load the URL twice.
		return false;
	}

	private boolean tryInterceptUriScheme(String url){
		boolean hasUriSchemeHandler = _hasUriSchemeHandler.run();
		if(hasUriSchemeHandler)
		{
			for(String uri : _customURIs)
			{
				if(url.indexOf(uri) == 0)
				{
					_onCustomURI.run(url);
					return true;
				}
			}
		}
		return false;
	}

	@Override
	public void onPageStarted(WebView view, String url, Bitmap favIcon)
	{
		if(loadingFinished){
			if (_pageStartedAction != null)
				_pageStartedAction.run();
		}
		loadingFinished = false;
	}

	@Override
	public void onPageFinished(WebView view, String url)
	{
		if(_urlChangedAction != null)
				_urlChangedAction.run();

		if(!redirect)
			loadingFinished = true;

		if(loadingFinished && !redirect){
			loadingFinished = true;
			if (_pageLoadedAction != null)
				_pageLoadedAction.run();
		}else{
			redirect = false;
		}
	}

	@TargetApi(23)
	@Override
	public void onReceivedError(WebView view, WebResourceRequest request, WebResourceError error)
	{
		if (request == null || !request.isForMainFrame())
			return;

		reportError(
			request.getUrl() != null ? request.getUrl().toString() : "",
			error != null && error.getDescription() != null ? error.getDescription().toString() : "",
			error != null ? error.getErrorCode() : 0,
			0);
	}

	@SuppressWarnings("deprecation")
	@Override
	public void onReceivedError(WebView view, int errorCode, String description, String failingUrl)
	{
		// The deprecated overload is used on API levels below 23.
		if (Build.VERSION.SDK_INT >= 23)
			return;

		reportError(failingUrl, description, errorCode, 0);
	}

	@TargetApi(23)
	@Override
	public void onReceivedHttpError(WebView view, WebResourceRequest request, WebResourceResponse errorResponse)
	{
		if (request == null || !request.isForMainFrame())
			return;

		reportError(
			request.getUrl() != null ? request.getUrl().toString() : "",
			errorResponse != null && errorResponse.getReasonPhrase() != null ? errorResponse.getReasonPhrase() : "",
			0,
			errorResponse != null ? errorResponse.getStatusCode() : 0);
	}

	@Override
	public void onReceivedSslError(WebView view, SslErrorHandler handler, SslError error)
	{
		handler.cancel();

		reportError(
			error != null ? error.getUrl() : "",
			error != null ? "SSL error (" + error.getPrimaryError() + ")" : "SSL error",
			WebViewClient.ERROR_FAILED_SSL_HANDSHAKE,
			0);
	}

	private void reportError(String url, String description, int code, int httpStatusCode)
	{
		if (_onPageError != null)
			_onPageError.run(url, description, code, httpStatusCode, true);
	}
}
