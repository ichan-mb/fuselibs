using Uno;
using Uno.UX;
using Uno.Platform;
using Uno.Collections;
using Fuse;
using Fuse.Navigation;
using Uno.Compiler.ExportTargetInterop;
using Fuse.Android.Controls.WebViewUtils.WebViewForeign;

namespace Fuse.Android.Controls.WebViewUtils
{
	extern (Android) sealed internal class EvaluateJsCommand
	{
		readonly Action<string> _handler;
		public readonly string JavaScript;

		public EvaluateJsCommand(string javaScript, Action<string> handler)
		{
			JavaScript = javaScript;
			_handler = handler;
		}

		public void Execute(Java.Object webViewHandle, string interfaceName)
		{
			webViewHandle.EvaluateJavascript(interfaceName, JavaScript);
		}

		public void HandleResult(string result)
		{
			if(_handler!=null)
				_handler(result);
		}

		public void HandleError(string message)
		{
			debug_log("WebView.Eval failed: " + message);
			if(_handler!=null)
				_handler(null);
		}
	}

	extern (Android) sealed public class JSEvalRequestManager
	{
		List<EvaluateJsCommand> _evaluateRequests = new List<EvaluateJsCommand>();
		EvaluateJsCommand _currentRequest;
		Java.Object _webViewHandle;
		string _interfaceName;
		bool _isDisposed;

		public JSEvalRequestManager(Java.Object webViewHandle)
		{
			_webViewHandle = webViewHandle;
			_webViewHandle.AddJavascriptInterface(_interfaceName = "FuseJSInterface", OnJsResult, OnJsError);
		}

		public void EvaluateJs(string js, Action<string> handler)
		{
			if (_isDisposed) return;

			var cmd = new EvaluateJsCommand(js, handler);
			_evaluateRequests.Add(cmd);
			if(_evaluateRequests.Count==1)
				NextRequest();
		}

		void NextRequest()
		{
			if (_isDisposed || _webViewHandle == null) return;
			if(_evaluateRequests.Count==0) return;
			_currentRequest = _evaluateRequests[0];
			_evaluateRequests.RemoveAt(0);
			_currentRequest.Execute(_webViewHandle, _interfaceName);
		}

		void OnJsResult(string result)
		{
			if (_isDisposed) return;

			var request = _currentRequest;
			_currentRequest = null;

			if (request != null)
				request.HandleResult(result);

			NextRequest();
		}

		void OnJsError(string message)
		{
			if (_isDisposed) return;

			var request = _currentRequest;
			_currentRequest = null;

			if (request != null)
				request.HandleError(message);

			NextRequest();
		}

		public void Dispose()
		{
			_isDisposed = true;
			_evaluateRequests.Clear();
			_currentRequest = null;
			_webViewHandle = null;
		}
	}
}
