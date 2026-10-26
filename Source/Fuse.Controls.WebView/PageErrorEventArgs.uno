namespace Fuse.Controls
{
	/**
		Describes why a @WebView failed to load a page.
	*/
	public sealed class PageErrorEventArgs : Uno.EventArgs, Fuse.Scripting.IScriptEvent
	{
		/**
			The URL that failed to load.
		*/
		public readonly string Url;

		/**
			A human readable description of the error.
		*/
		public readonly string Description;

		/**
			The platform-specific error code. For HTTP errors this is 0, see @HttpStatusCode.
		*/
		public readonly int Code;

		/**
			The HTTP status code when the error was reported for an HTTP response, otherwise 0.
		*/
		public readonly int HttpStatusCode;

		/**
			Whether the error happened for the main frame or a sub-resource.
		*/
		public readonly bool IsMainFrame;

		public PageErrorEventArgs(string url, string description, int code, int httpStatusCode, bool isMainFrame) : base()
		{
			Url = url ?? "";
			Description = description ?? "";
			Code = code;
			HttpStatusCode = httpStatusCode;
			IsMainFrame = isMainFrame;
		}

		void Fuse.Scripting.IScriptEvent.Serialize(Fuse.Scripting.IEventSerializer s)
		{
			s.AddString("url", Url);
			s.AddString("description", Description);
			s.AddInt("code", Code);
			s.AddInt("httpStatusCode", HttpStatusCode);
			s.AddBool("isMainFrame", IsMainFrame);
		}
	}
}
