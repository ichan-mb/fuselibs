namespace Fuse.Controls
{
	public sealed class DownloadEventArgs : Uno.EventArgs, Fuse.Scripting.IScriptEvent
	{
		/**
			The URL of the downloaded file.
		*/
		public readonly string Url;

		/**
			The local file path. Only set for @FileDownloaded; null for @BeginDownload.
		*/
		public readonly string Path;

		public DownloadEventArgs(string url, string path) : base()
		{
			Url = url;
			Path = path;
		}

		void Fuse.Scripting.IScriptEvent.Serialize(Fuse.Scripting.IEventSerializer s)
		{
			s.AddString("url", Url);
			s.AddString("path", Path);
		}
	}
}
