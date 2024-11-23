using Uno;
using Uno.UX;
using Uno.Compiler.ExportTargetInterop;

using Fuse;
using Fuse.Controls;
using Fuse.Controls.Native;
using Fuse.Controls.Native.iOS;

namespace Fuse.Controls.Native.iOS
{
	extern(!iOS) class AVPlayerView
	{
		[UXConstructor]
		public AVPlayerView([UXParameter("Host")]AudioVideoPlayer host) { }
	}

	[ForeignInclude(Language.ObjC, "AVKit/AVKit.h")]
	[ForeignInclude(Language.ObjC, "AVFoundation/AVFoundation.h")]
	[Require("source.include", "iOS/AVPlayerContainer.h")]
	extern(iOS) class AVPlayerView : LeafView, IAVPlayerView
	{

		AudioVideoPlayer _host;
		static ObjC.Object _container;

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
						SetVideoUri(_container, GetBundleAbsolutePath("data/" + ((BundleFileSource)_file).BundleFile.BundlePath));
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

		[Foreign(Language.ObjC)]
		static void SetVideoUri(ObjC.Object handle, string url)
		@{
			AVPlayerViewController* playerViewController = (AVPlayerViewController*)handle;
			NSURL *newURL = [NSURL URLWithString:url];
			if (playerViewController.player != NULL)
			{
				AVPlayerItem *newItem = [AVPlayerItem playerItemWithURL:newURL];
				[playerViewController.player replaceCurrentItemWithPlayerItem:newItem];
			}
			else
			{
				AVPlayer *player = [AVPlayer playerWithURL:newURL];
				playerViewController.player = player;
			}
			[playerViewController.player play];
		@}

		[Foreign(Language.ObjC)]
		static ObjC.Object Create()
		@{
			AVPlayerViewController *playerViewController = [[AVPlayerViewController alloc] init];

			AVPlayerContainer* playerContainer  = [[AVPlayerContainer alloc] init];
			playerContainer.avPlayerView = playerViewController.view;

			[playerContainer setMultipleTouchEnabled:true];
			[playerContainer setAutoresizesSubviews:false];
			[playerContainer setTranslatesAutoresizingMaskIntoConstraints:false];
			[playerContainer setClipsToBounds:true];
			[playerContainer addSubview:playerViewController.view];

			@{_container:set(playerViewController)};

			return playerContainer;
		@}

		[Foreign(Language.ObjC)]
		static string GetBundleAbsolutePath(string bundlePath)
		@{
			return [[[NSBundle bundleForClass:[StrongUnoObject class]] URLForResource:bundlePath withExtension:@""] absoluteString];
		@}
	}
}