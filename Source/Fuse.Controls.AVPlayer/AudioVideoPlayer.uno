using Uno;
using Uno.UX;
using Uno.Compiler.ExportTargetInterop;

using Fuse;
using Fuse.Resources;
using Fuse.Controls.Native;
using Fuse.Scripting;

namespace Fuse.Controls
{
	using Native.iOS;
	using Native.Android;

	interface IAVPlayerView
	{
		FileSource File { set; }
		string Url { set; }
	}

	public abstract partial class AVPlayerBase : Panel
	{

		static Selector _fileName = "File";

		FileSource _file;
		[UXOriginSetter("SetFile")]
		/**
			Loads a video from a File.

			Only one of `File`, `Url` or `Source` can be specified.
		*/
		public FileSource File
		{
			get { return _file; }
			set { SetFile(value, this); }
		}

		public void SetFile(FileSource file, IPropertyListener origin)
		{
			UpdateFile(file, origin);

			var avv = AVPlayerView;
			if (avv != null)
				avv.File = File;
		}

		void UpdateFile(FileSource file, IPropertyListener origin)
		{
			if (file != _file)
			{
				_file = file;
				OnPropertyChanged(_fileName, origin);
			}
		}

		static Selector _urlName = "Url";

		string _url = "";
		[UXOriginSetter("SetUrl")]
		/**
			Gets or sets Video Url.
		*/
		public string Url
		{
			get { return _url; }
			set { SetUrl(value, this); }
		}

		public void SetUrl(string url, IPropertyListener origin)
		{
			UpdateUrl(url, origin);

			var avv = AVPlayerView;
			if (avv != null)
				avv.Url = url;
		}

		void UpdateUrl(string url, IPropertyListener origin)
		{
			if (url != _url)
			{
				_url = url;
				OnPropertyChanged(_urlName, origin);
			}
		}

		IAVPlayerView AVPlayerView
		{
			get { return (IAVPlayerView)NativeView; }
		}
	}

}