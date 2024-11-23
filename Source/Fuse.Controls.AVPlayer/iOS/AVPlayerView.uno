using Uno;
using Uno.UX;
using Uno.Compiler.ExportTargetInterop;
using Uno.Time;

using Fuse;
using Fuse.Controls;
using Fuse.Controls.Native;
using Fuse.Controls.Native.iOS;

namespace Fuse.Controls.Native.iOS
{
	extern(!iOS) class AVPlayerView
	{
		[UXConstructor]
		public AVPlayerView([UXParameter("Host")]AVPlayerBase host) { }
	}

	[ForeignInclude(Language.ObjC, "AVKit/AVKit.h")]
	[ForeignInclude(Language.ObjC, "AVFoundation/AVFoundation.h")]
	[Require("source.include", "iOS/AVPlayerContainer.h")]
	extern(iOS) class AVPlayerView : LeafView, IAVPlayerView
	{

		AVPlayerBase _host;
		ObjC.Object _container;
		ObjC.Object _player;
		ObjC.Object _playerItem;
		ObjC.Object _timeObserver;

		// Playback state
		bool _isPlaying = false;
		bool _isLooping = false;
		bool _autoPlay = true;
		bool _isBuffering = false;
		float _volume = 1.0f;
		float _playbackRate = 1.0f;
		float _bufferProgress = 0.0f;
		double _duration = 0.0;
		double _position = 0.0;
		double _progress = 0.0;

		[UXConstructor]
		public AVPlayerView([UXParameter("Host")]AVPlayerBase host) : base(CreateContainer())
		{
			_host = host;
			_container = CreatePlayer();
			Url = _host.Url;
			File = _host.File;
		}

		public override void Dispose()
		{
			RemoveObservers();
			base.Dispose();
			_container = null;
			_player = null;
			_playerItem = null;
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
					if (_container != null)
					{
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
					if (_container != null)
						SetVideoUri(_container, value);
				}
			}
		}

		// New properties
		public bool IsPlaying { get { return _isPlaying; } }
		public double Duration { get { return _duration; } }
		public double Position
		{
			get { return _position; }
			set
			{
				var clampedPosition = Math.Max(0.0, Math.Min(_duration > 0 ? _duration : double.MaxValue, value));
				if (Math.Abs(_position - clampedPosition) > 0.001)
				{
					_position = clampedPosition;
					SetPlaybackPosition(_player, _position);
				}
			}
		}
		public double Progress
		{
			get { return _progress; }
			set
			{
				var position = value * _duration;
				SetPlaybackPosition(_player, position);
			}
		}
		public bool IsLooping
		{
			get { return _isLooping; }
			set
			{
				if (_isLooping != value)
				{
					_isLooping = value;
					SetLooping(_player, value);
				}
			}
		}

		public float Volume
		{
			get { return _volume; }
			set
			{
				if (Math.Abs(_volume - value) > 0.001f)
				{
					_volume = Math.Max(0.0f, Math.Min(1.0f, value));
					SetVolume(_player, _volume);
				}
			}
		}

		public float PlaybackRate
		{
			get { return _playbackRate; }
			set
			{
				if (Math.Abs(_playbackRate - value) > 0.001f)
				{
					_playbackRate = value;
					SetPlaybackRate(_player, _playbackRate);
				}
			}
		}

		public bool AutoPlay
		{
			get { return _autoPlay; }
			set { _autoPlay = value; }
		}

		public bool IsBuffering { get { return _isBuffering; } }
		public float BufferProgress { get { return _bufferProgress; } }

		// Events
		// Events are handled by the host (base class)

		// Playback state tracking
		void UpdatePlaybackState()
		{
			if (_player != null)
			{
				var rate = GetPlayerRate(_player);
				bool wasPlaying = _isPlaying;
				_isPlaying = rate > 0;

				if (wasPlaying != _isPlaying)
				{
					if (_isPlaying)
					{
						if (_host != null) _host.OnPlaying();
					}
					else
					{
						if (_host != null) _host.OnPaused();
					}
				}
			}
		}

		[Foreign(Language.ObjC)]
		void SetVideoUri(ObjC.Object handle, string url)
		@{
			AVPlayerViewController* playerViewController = (AVPlayerViewController*)handle;
			NSURL *newURL = [NSURL URLWithString:url];

			// Remove previous observers
			@{AVPlayerView:Of(_this).RemoveObservers():Call()};

			if (playerViewController.player != NULL)
			{
				AVPlayerItem *newItem = [AVPlayerItem playerItemWithURL:newURL];
				[playerViewController.player replaceCurrentItemWithPlayerItem:newItem];
				@{AVPlayerView:Of(_this)._playerItem:Set(newItem)};
			}
			else
			{
				AVPlayer *player = [AVPlayer playerWithURL:newURL];
				playerViewController.player = player;
				@{AVPlayerView:Of(_this)._player:Set(player)};
				@{AVPlayerView:Of(_this)._playerItem:Set(player.currentItem)};
			}

			// Add new observers
			@{AVPlayerView:Of(_this).AddPlayerObservers():Call()};

			// Auto-play if enabled
			if (@{AVPlayerView:Of(_this)._autoPlay:Get()}) {
				[playerViewController.player play];
			}
		@}

		// Playback control methods
		public void Play()
		{
			PlayPlayer(_player);
		}

		public void Pause()
		{
			PausePlayer(_player);
		}

		public void Stop()
		{
			StopPlayer(_player);
			OnPlaybackStopped();
		}

		public void Seek(double positionSeconds)
		{
			SeekToTime(_player, positionSeconds);
		}

		[Foreign(Language.ObjC)]
		static void PlayPlayer(ObjC.Object player)
		@{
			AVPlayer* avPlayer = (AVPlayer*)player;
			if (avPlayer != NULL) {
				[avPlayer play];
			}
		@}

		[Foreign(Language.ObjC)]
		static void PausePlayer(ObjC.Object player)
		@{
			AVPlayer* avPlayer = (AVPlayer*)player;
			if (avPlayer != NULL) {
				[avPlayer pause];
			}
		@}

		[Foreign(Language.ObjC)]
		static void StopPlayer(ObjC.Object player)
		@{
			AVPlayer* avPlayer = (AVPlayer*)player;
			if (avPlayer != NULL) {
				[avPlayer pause];
				[avPlayer seekToTime:kCMTimeZero];
			}
		@}

		[Foreign(Language.ObjC)]
		static void SeekToTime(ObjC.Object player, double seconds)
		@{
			AVPlayer* avPlayer = (AVPlayer*)player;
			if (avPlayer != NULL) {
				CMTime time = CMTimeMakeWithSeconds(seconds, 600);
				[avPlayer seekToTime:time];
			}
		@}

		[Foreign(Language.ObjC)]
		static void SetVolume(ObjC.Object player, float volume)
		@{
			AVPlayer* avPlayer = (AVPlayer*)player;
			if (avPlayer != NULL) {
				avPlayer.volume = volume;
			}
		@}

		[Foreign(Language.ObjC)]
		static void SetPlaybackRate(ObjC.Object player, float rate)
		@{
			AVPlayer* avPlayer = (AVPlayer*)player;
			if (avPlayer != NULL) {
				avPlayer.rate = rate;
			}
		@}

		[Foreign(Language.ObjC)]
		static void SetLooping(ObjC.Object player, bool looping)
		@{
			AVPlayer* avPlayer = (AVPlayer*)player;
			if (avPlayer != NULL && looping) {
				[[NSNotificationCenter defaultCenter] addObserverForName:AVPlayerItemDidPlayToEndTimeNotification
					object:avPlayer.currentItem
					queue:[NSOperationQueue mainQueue]
					usingBlock:^(NSNotification *note) {
						[avPlayer seekToTime:kCMTimeZero];
						[avPlayer play];
					}];
			}
		@}

		[Foreign(Language.ObjC)]
		static ObjC.Object CreateContainer()
		@{
			AVPlayerContainer* playerContainer = [[AVPlayerContainer alloc] init];
			[playerContainer setMultipleTouchEnabled:true];
			[playerContainer setAutoresizesSubviews:false];
			[playerContainer setTranslatesAutoresizingMaskIntoConstraints:false];
			[playerContainer setClipsToBounds:true];

			return playerContainer;
		@}

		[Foreign(Language.ObjC)]
		ObjC.Object CreatePlayer()
		@{
			AVPlayerViewController *playerViewController = [[AVPlayerViewController alloc] init];

			AVPlayerContainer* playerContainer = (AVPlayerContainer*)@{AVPlayerView:Of(_this).Handle:Get()};
			playerContainer.avPlayerView = playerViewController.view;
			[playerContainer addSubview:playerViewController.view];

			return playerViewController;
		@}

		[Foreign(Language.ObjC)]
		static string GetBundleAbsolutePath(string bundlePath)
		@{
			return [[[NSBundle bundleForClass:[StrongUnoObject class]] URLForResource:bundlePath withExtension:@""] absoluteString];
		@}

		[Foreign(Language.ObjC)]
		void AddPlayerObservers()
		@{
			AVPlayerViewController* playerViewController = (AVPlayerViewController*)@{AVPlayerView:Of(_this)._container:Get()};
			AVPlayer* player = playerViewController.player;
			AVPlayerItem* playerItem = player.currentItem;

			if (playerItem != NULL) {
				// Add time observer for position updates
				CMTime interval = CMTimeMakeWithSeconds(0.1, 600);
				@{AVPlayerView:Of(_this)._timeObserver:Set([player addPeriodicTimeObserverForInterval:interval queue:dispatch_get_main_queue() usingBlock:^(CMTime time) {
					@{AVPlayerView:Of(_this).OnTimeChanged(double):Call(CMTimeGetSeconds(time))};
					@{AVPlayerView:Of(_this).UpdatePlaybackState():Call()};
					@{AVPlayerView:Of(_this).CheckInitialStatus():Call()};
				}])};

				// Simple initial status check
				@{AVPlayerView:Of(_this).CheckInitialStatus():Call()};
			}
		@}

		[Foreign(Language.ObjC)]
		void RemoveTimeObserver()
		@{
			AVPlayerViewController* playerViewController = (AVPlayerViewController*)@{AVPlayerView:Of(_this)._container:Get()};
			AVPlayer* player = playerViewController.player;

			if (player != NULL && @{AVPlayerView:Of(_this)._timeObserver:Get()} != NULL) {
				[player removeTimeObserver:@{AVPlayerView:Of(_this)._timeObserver:Get()}];
				@{AVPlayerView:Of(_this)._timeObserver:Set(NULL)};
			}
		@}

		[Foreign(Language.ObjC)]
		void RemoveObservers()
		@{
			@{AVPlayerView:Of(_this).RemoveTimeObserver():Call()};
		@}

		[Foreign(Language.ObjC)]
		void CheckInitialStatus()
		@{
			AVPlayerViewController* playerViewController = (AVPlayerViewController*)@{AVPlayerView:Of(_this)._container:Get()};
			if (playerViewController.player.currentItem != NULL) {
				AVPlayerItem* playerItem = playerViewController.player.currentItem;

				// Simple status check
				if (playerItem.status == AVPlayerItemStatusReadyToPlay && @{AVPlayerView:Of(_this).Duration:Get()} == 0) {
					@{AVPlayerView:Of(_this).OnReadyToPlay():Call()};

					// Get duration if available
					CMTime duration = playerItem.duration;
					if (CMTIME_IS_VALID(duration)) {
						@{AVPlayerView:Of(_this).OnDurationChanged(double):Call(CMTimeGetSeconds(duration))};
					}
				} else if (playerItem.status == AVPlayerItemStatusFailed) {
					NSError *error = playerItem.error;
					NSString *errorMessage = error ? error.localizedDescription : @"Unknown playback error";
					int errorCode = error ? (int)error.code : -1;
					@{AVPlayerView:Of(_this).OnPlaybackError(string, int):Call(errorMessage, errorCode)};
				}
			}
		@}

		// Callback methods from native code
		void OnTimeChanged(double seconds)
		{
			_position = Math.Max(0.0, seconds);
			if (_host != null) _host.OnPositionChanged(_position);

			// Check if playback ended (simple approach)
			var duration = Duration;
			if (duration > 0 && Math.Abs(_position - duration) < 0.1 && !_isPlaying)
			{
				OnPlaybackEnded();
			}
		}

		void OnDurationChanged(double seconds)
		{
			_duration = Math.Max(0.0, seconds);
			if (_host != null) _host.OnDurationChanged(_duration);
		}

		void OnReadyToPlay()
		{
			if (_host != null) _host.OnLoadingEnded();
		}

		void OnPlaybackEnded()
		{
			_isPlaying = false;
			if (_host != null) _host.OnEnded();
		}

		void OnPlaybackStopped()
		{
			_isPlaying = false;
			if (_host != null) _host.OnStopped();
		}

		void OnPlaybackError(string error, int errorCode = -1)
		{
			if (_host != null)
			{
				ErrorSeverity severity = DetermineErrorSeverity(errorCode);
				Exception exception = errorCode != -1 ? new Exception("AVPlayer error code: " + errorCode) : null;
				_host.OnError(error ?? "Unknown playback error", exception, severity);
			}
		}

		/**
			Determines error severity based on AVPlayer error codes
		*/
		ErrorSeverity DetermineErrorSeverity(int errorCode)
		{
			switch (errorCode)
			{
				case -11800: // AVErrorUnknown
				case -11801: // AVErrorOutOfMemory
				case -11807: // AVErrorContentIsNotAuthorized
					return ErrorSeverity.Fatal;
				case -11828: // AVErrorContentIsUnavailable
				case -11829: // AVErrorFormatNotRecognized
					return ErrorSeverity.Error;
				case -11819: // AVErrorNoLongerPlayable
				case -11820: // AVErrorNoCompatibleAlternatesForExternalDisplay
					return ErrorSeverity.Warning;
				default:
					return ErrorSeverity.Error;
			}
		}

		void OnBufferProgressChanged(float progress)
		{
			var newProgress = Math.Max(0.0f, Math.Min(1.0f, progress));

			// Only trigger event if progress actually changed significantly
			if (Math.Abs(newProgress - _bufferProgress) > 0.01f)
			{
				_bufferProgress = newProgress;
				if (_host != null) _host.OnBufferedChanged();
			}
		}

		void OnPositionUpdate(double seconds)
		{
			_position = Math.Max(0.0, seconds);
			if (_host != null) _host.OnPositionChanged(_position);
		}

		[Foreign(Language.ObjC)]
		static void SetPlaybackPosition(ObjC.Object player, double position)
		@{
			AVPlayer* avPlayer = (AVPlayer*)player;
			if (avPlayer != NULL) {
				CMTime time = CMTimeMakeWithSeconds(position, 600);
				[avPlayer seekToTime:time];
			}
		@}

		[Foreign(Language.ObjC)]
		static double GetPlayerRate(ObjC.Object player)
		@{
			AVPlayer* avPlayer = (AVPlayer*)player;
			if (avPlayer != NULL) {
				return avPlayer.rate;
			}
			return 0.0;
		@}
	}
}
