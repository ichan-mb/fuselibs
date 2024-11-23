using Uno;
using Uno.UX;
using Uno.Compiler.ExportTargetInterop;

using Fuse;
using Fuse.Controls;
using Fuse.Controls.Native;
using Fuse.Controls.Native.Android;

namespace Fuse.Controls.Native.Android
{
	extern(!Android) class AVPlayerView
	{
		[UXConstructor]
		public AVPlayerView([UXParameter("Host")]AudioVideoPlayer host) { }
	}

	[Require("gradle.dependency.implementation", "com.google.android.exoplayer:exoplayer-core:2.18.0")]
	[Require("gradle.dependency.implementation", "com.google.android.exoplayer:exoplayer-ui:2.18.0")]
	[Require("gradle.dependency.implementation", "com.google.android.exoplayer:exoplayer-dash:2.18.0")]
	[Require("gradle.dependency.implementation", "com.google.android.exoplayer:exoplayer-hls:2.18.0")]
	extern(Android) class AVPlayerView : LeafView, IAVPlayerView
	{

		AudioVideoPlayer _host;
		static Java.Object _container;

		[UXConstructor]
		public AVPlayerView([UXParameter("Host")]AudioVideoPlayer host) : base(Create())
		{
			_host = host;
			Url = _host.Url;
			File = _host.File;
		}

		public override void Dispose()
		{
			base.Dispose();
			Release(_container);
			_container = null;
			_host = null;
		}

		FileSource _file;
		public FileSource File
		{
			set
			{
				if (value != _file)
				{
					_file = value;
					if (_file is BundleFileSource)
					{
						SetVideoUri(_container, "file:///android_asset/" + ((BundleFileSource)_file).BundleFile.BundlePath);
					}
					else
					{
						var data = _file.ReadAllBytes();
						var path = Uno.IO.Directory.GetUserDirectory(Uno.IO.UserDirectory.Videos) + "/" + _file.Name;
						Uno.IO.File.WriteAllBytes(path, data);
						SetVideoUri(_container, path);
					}
				}
			}
		}

		string _url;
		public string Url
		{
			get { return _url; }
			set
			{
				if (value != _url)
				{
					_url = value;
					SetVideoUri(_container, value);
				}
			}
		}

		[Foreign(Language.Java)]
		static void SetVideoUri(Java.Object handle, string url)
		@{
			com.google.android.exoplayer2.ExoPlayer player = (com.google.android.exoplayer2.ExoPlayer)handle;
			android.net.Uri uri = android.net.Uri.parse(url);
			com.google.android.exoplayer2.MediaItem mediaItem = com.google.android.exoplayer2.MediaItem.fromUri(uri);
			player.setMediaItem(mediaItem);

			player.prepare();
			player.setPlayWhenReady(true);
		@}

		[Foreign(Language.Java)]
		static void Release(Java.Object handle)
		@{
			com.google.android.exoplayer2.ExoPlayer player = (com.google.android.exoplayer2.ExoPlayer)handle;
			player.release();
		@}

		[Foreign(Language.Java)]
		static Java.Object Create()
		@{
			android.widget.FrameLayout frameLayout = new android.widget.FrameLayout(com.fuse.Activity.getRootActivity());
			frameLayout.setFocusable(true);
			frameLayout.setFocusableInTouchMode(true);
			frameLayout.setLayoutParams(new android.widget.FrameLayout.LayoutParams(android.view.ViewGroup.LayoutParams.MATCH_PARENT, android.view.ViewGroup.LayoutParams.MATCH_PARENT));

			com.google.android.exoplayer2.ui.PlayerView playerView = new com.google.android.exoplayer2.ui.PlayerView(com.fuse.Activity.getRootActivity());
			playerView.setLayoutParams(new android.widget.FrameLayout.LayoutParams(android.view.ViewGroup.LayoutParams.MATCH_PARENT, android.view.ViewGroup.LayoutParams.MATCH_PARENT));
			frameLayout.addView(playerView);

			com.google.android.exoplayer2.ExoPlayer player = new com.google.android.exoplayer2.ExoPlayer.Builder(com.fuse.Activity.getRootActivity()).build();
			playerView.setPlayer(player);

			@{_container:set(player)};

			return frameLayout;
		@}
	}
}