package com.fuse.webview;
import com.foreign.Uno.Action_String;
import android.webkit.JavascriptInterface;

public class JsInterface
{
	Action_String _handler;
	Action_String _errorHandler;

	public JsInterface(Action_String handler, Action_String errorHandler)
	{
		_handler = handler;
		_errorHandler = errorHandler;
	}

	@JavascriptInterface
	public void onResult(String result)
	{
		_handler.run(result);
	}

	@JavascriptInterface
	public void onError(String message)
	{
		if (_errorHandler != null)
			_errorHandler.run(message);
	}
}
