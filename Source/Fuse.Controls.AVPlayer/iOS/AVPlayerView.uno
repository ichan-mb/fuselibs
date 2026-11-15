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
		ObjC.Object _endObserver;
		ObjC.Object _interruptionObserver;
		ObjC.Object _routeChangeObserver;
		bool _readyNotified;
		bool _interrupted;

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

		// Presentation state
		bool _muted = false;
		bool _showControls = true;
		bool _keepScreenOn = false;
		bool _idleTimerSet;
		Fuse.Elements.StretchMode _stretchMode = Fuse.Elements.StretchMode.Uniform;
		MediaStreamQuality _streamQuality = MediaStreamQuality.Auto;

		[UXConstructor]
		public AVPlayerView([UXParameter("Host")]AVPlayerBase host) : base(CreateContainer())
		{
			_host = host;
			// AutoPlay is read when the source is loaded, so it has to be known up front
			_autoPlay = host.AutoPlay;
			_container = CreatePlayer();
			ConfigureAudioSession();
			AddAudioSessionObservers();
			if (!string.IsNullOrEmpty(host.Url))
				Url = host.Url;
			if (host.File != null)
				File = host.File;
		}

		public override void Dispose()
		{
			RemoveObservers();
			RemoveAudioSessionObservers();

			if (_idleTimerSet)
			{
				_idleTimerSet = false;
				SetIdleTimerDisabled(false);
			}

			if (_player != null)
				ReleasePlayer(_player);

			if (_container != null)
				DetachPlayerView(_container);

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
					ResetMediaInfo();
					if (_container != null)
					{
						if (_file is BundleFileSource)
							SetVideoUri(_container, GetBundleAbsolutePath("data/" + ((BundleFileSource)_file).BundleFile.BundlePath));
						else if (_file != null)
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
					ResetMediaInfo();
					if (_container != null && !string.IsNullOrEmpty(_url))
						SetVideoUri(_container, _url);
				}
			}
		}

		void ResetPlaybackPosition()
		{
			_position = 0.0;
			_progress = 0.0;
		}

		// Called when a new source is loaded, before the native player is told about it
		void ResetMediaInfo()
		{
			ResetPlaybackPosition();
			_duration = 0.0;
			_bufferProgress = 0.0f;
			_readyNotified = false;

			if (_host != null)
				_host.OnDurationChanged(0.0);
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
				if (_duration > 0)
					SetPlaybackPosition(_player, Math.Max(0.0, Math.Min(1.0, value)) * _duration);
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
					ApplyLooping();
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
					_playbackRate = Math.Max(0.25f, Math.Min(4.0f, value));

					// Assigning a rate to a paused AVPlayer starts playback, so the rate is
					// only applied here when the player is already playing.
					if (GetPlayerRate(_player) > 0.0)
						SetPlaybackRate(_player, _playbackRate);
				}
			}
		}

		public bool AutoPlay
		{
			get { return _autoPlay; }
			set { _autoPlay = value; }
		}

		public Fuse.Elements.StretchMode StretchMode
		{
			set
			{
				if (_stretchMode != value)
				{
					_stretchMode = value;
					ApplyStretchMode();
				}
			}
		}

		public bool ShowControls
		{
			set
			{
				if (_showControls != value)
				{
					_showControls = value;
					if (_container != null)
						SetShowsPlaybackControls(_container, _showControls);
				}
			}
		}

		public bool KeepScreenOn
		{
			set
			{
				if (_keepScreenOn != value)
				{
					_keepScreenOn = value;
					UpdateIdleTimer();
				}
			}
		}

		public bool Muted
		{
			set
			{
				if (_muted != value)
				{
					_muted = value;
					if (_player != null)
						SetPlayerMuted(_player, _muted);
				}
			}
		}

		public MediaStreamQuality StreamQuality
		{
			set
			{
				if (_streamQuality != value)
				{
					_streamQuality = value;
					ApplyStreamQuality();
				}
			}
		}

		void ApplyStreamQuality()
		{
			if (_playerItem != null)
				SetItemPeakBitRate(_playerItem, GetMaxVideoBitrate(_streamQuality));
		}

		static double GetMaxVideoBitrate(MediaStreamQuality quality)
		{
			switch (quality)
			{
				case MediaStreamQuality.SD:
					return 1500000.0;
				case MediaStreamQuality.HD:
					return 4000000.0;
				case MediaStreamQuality.FullHD:
					return 8000000.0;
				default:
					return 0.0; // no limit
			}
		}

		void ApplyStretchMode()
		{
			if (_container == null)
				return;

			// 0 = aspect fit (letterbox), 1 = stretch, 2 = aspect fill (crop)
			var gravity = 0;
			if (_stretchMode == Fuse.Elements.StretchMode.Fill)
				gravity = 1;
			else if (_stretchMode == Fuse.Elements.StretchMode.UniformToFill)
				gravity = 2;

			SetVideoGravity(_container, gravity);
		}

		void UpdateIdleTimer()
		{
			// Waiting to play (status 1) counts as playing, the screen should stay on while buffering
			var playing = _player != null && GetTimeControlStatus(_player) != 0;
			var disable = _keepScreenOn && playing;
			if (disable == _idleTimerSet)
				return;

			_idleTimerSet = disable;
			SetIdleTimerDisabled(disable);
		}

		public bool IsBuffering { get { return _isBuffering; } }
		public float BufferProgress { get { return _bufferProgress; } }

		// Events
		// Events are handled by the host (base class)

		// Playback state tracking
		//
		// `timeControlStatus` is used instead of `rate`, since the rate is 0 while the
		// player is waiting for more data even though playback is still intended.
		void UpdatePlaybackState()
		{
			if (_player == null)
				return;

			var status = GetTimeControlStatus(_player); // 0 = paused, 1 = waiting, 2 = playing

			var buffering = status == 1;
			if (buffering != _isBuffering)
			{
				_isBuffering = buffering;
				if (_host != null)
				{
					if (buffering)
						_host.OnLoadingStarted();
					else
						_host.OnLoadingEnded();
				}
			}

			var wasPlaying = _isPlaying;
			_isPlaying = status != 0;

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

			UpdateIdleTimer();
		}

		[Foreign(Language.ObjC)]
		void SetVideoUri(ObjC.Object handle, string url)
		@{
			AVPlayerViewController* playerViewController = (AVPlayerViewController*)handle;
			if (playerViewController.player == NULL) {
				return;
			}

			NSURL *newURL = [NSURL URLWithString:url];
			if (newURL == NULL) {
				return;
			}

			// Remove the observers that are bound to the previous item
			@{AVPlayerView:Of(_this).RemoveObservers():Call()};

			AVPlayerItem *newItem = [AVPlayerItem playerItemWithURL:newURL];
			[playerViewController.player replaceCurrentItemWithPlayerItem:newItem];
			@{AVPlayerView:Of(_this)._playerItem:Set(newItem)};

			// Add new observers
			@{AVPlayerView:Of(_this).AddPlayerObservers():Call()};
			@{AVPlayerView:Of(_this).ApplyLooping():Call()};
			@{AVPlayerView:Of(_this).ApplyStreamQuality():Call()};

			// Auto-play if enabled
			if (@{AVPlayerView:Of(_this)._autoPlay:Get()}) {
				@{AVPlayerView:Of(_this).Play():Call()};
			}
		@}

		// Playback control methods
		public void Play()
		{
			PlayPlayer(_player, _playbackRate);
			UpdateIdleTimer();
		}

		public void Pause()
		{
			PauseInternal();
		}

		// Pauses the native player and reports the change immediately.
		//
		// Playback state is otherwise reported by the periodic time observer, which stops
		// firing when playback stops. Without this, a pause would never reach the host and
		// `WhilePlaying` would stay active.
		void PauseInternal()
		{
			PausePlayer(_player);
			UpdatePlaybackState();
		}

		public void Stop()
		{
			StopPlayer(_player);
			OnPlaybackStopped();
		}

		public void Seek(double positionSeconds)
		{
			_position = Math.Max(0.0, positionSeconds);
			SeekToTime(_player, _position);
		}

		[Foreign(Language.ObjC)]
		static void PlayPlayer(ObjC.Object player, float rate)
		@{
			AVPlayer* avPlayer = (AVPlayer*)player;
			if (avPlayer != NULL) {
				// Using `play` would reset the rate back to 1.0
				avPlayer.rate = rate > 0.0f ? rate : 1.0f;
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
		ObjC.Object AddEndObserver(ObjC.Object playerItem)
		@{
			AVPlayerItem* item = (AVPlayerItem*)playerItem;

			return [[NSNotificationCenter defaultCenter] addObserverForName:AVPlayerItemDidPlayToEndTimeNotification
			                                                       object:item
			                                                        queue:[NSOperationQueue mainQueue]
			                                                   usingBlock:^(NSNotification *note) {
				@{AVPlayerView:Of(_this).OnPlaybackItemEnded():Call()};
			}];
		@}

		[Foreign(Language.ObjC)]
		static void RemoveNotificationObserver(ObjC.Object token)
		@{
			if (token != NULL) {
				[[NSNotificationCenter defaultCenter] removeObserver:(id)token];
			}
		@}

		// Looping is implemented with a single end-of-item observer that is replaced
		// every time the flag or the source changes.
		void ApplyLooping()
		{
			RemoveEndObserver();

			if (_isLooping && _playerItem != null)
				_endObserver = AddEndObserver(_playerItem);
		}

		void RemoveEndObserver()
		{
			if (_endObserver == null)
				return;

			RemoveNotificationObserver(_endObserver);
			_endObserver = null;
		}

		[Foreign(Language.ObjC)]
		void ConfigureAudioSession()
		@{
			// Playback category, so media is audible even when the ringer switch is off
			NSError* error = nil;
			[[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:&error];
		@}

		// Interruptions (phone calls, other apps taking over the audio session) and audio
		// route changes (unplugging headphones) are handled by the player itself.
		void AddAudioSessionObservers()
		{
			if (_interruptionObserver != null)
				return;

			_interruptionObserver = AddInterruptionObserver();
			_routeChangeObserver = AddRouteChangeObserver();
		}

		void RemoveAudioSessionObservers()
		{
			if (_interruptionObserver != null)
			{
				RemoveNotificationObserver(_interruptionObserver);
				_interruptionObserver = null;
			}

			if (_routeChangeObserver != null)
			{
				RemoveNotificationObserver(_routeChangeObserver);
				_routeChangeObserver = null;
			}
		}

		[Foreign(Language.ObjC)]
		ObjC.Object AddInterruptionObserver()
		@{
			return [[NSNotificationCenter defaultCenter] addObserverForName:AVAudioSessionInterruptionNotification
			                                                         object:nil
			                                                          queue:[NSOperationQueue mainQueue]
			                                                     usingBlock:^(NSNotification* note) {
				NSNumber* type = [note.userInfo objectForKey:AVAudioSessionInterruptionTypeKey];
				if (type == nil) {
					return;
				}

				if ([type integerValue] == AVAudioSessionInterruptionTypeBegan) {
					@{AVPlayerView:Of(_this).OnAudioInterruptionBegan():Call()};
				} else {
					NSNumber* options = [note.userInfo objectForKey:AVAudioSessionInterruptionOptionKey];
					if (options != nil && (([options integerValue] & AVAudioSessionInterruptionOptionShouldResume) != 0)) {
						@{AVPlayerView:Of(_this).OnAudioInterruptionEnded():Call()};
					}
				}
			}];
		@}

		[Foreign(Language.ObjC)]
		ObjC.Object AddRouteChangeObserver()
		@{
			return [[NSNotificationCenter defaultCenter] addObserverForName:AVAudioSessionRouteChangeNotification
			                                                         object:nil
			                                                          queue:[NSOperationQueue mainQueue]
			                                                     usingBlock:^(NSNotification* note) {
				NSNumber* reason = [note.userInfo objectForKey:AVAudioSessionRouteChangeReasonKey];
				if (reason == nil) {
					return;
				}

				if ([reason integerValue] == AVAudioSessionRouteChangeReasonOldDeviceUnavailable) {
					@{AVPlayerView:Of(_this).OnAudioRouteUnavailable():Call()};
				}
			}];
		@}

		// Playback was interrupted by the system, resume when it says we may
		void OnAudioInterruptionBegan()
		{
			if (!_isPlaying)
				return;

			_interrupted = true;
			PauseInternal();
		}

		void OnAudioInterruptionEnded()
		{
			if (!_interrupted)
				return;

			_interrupted = false;
			Play();
		}

		// Headphones were unplugged; don't continue out loud through the speaker
		void OnAudioRouteUnavailable()
		{
			_interrupted = false;
			PauseInternal();
		}

		[Foreign(Language.ObjC)]
		static void SetItemPeakBitRate(ObjC.Object playerItem, double peakBitRate)
		@{
			AVPlayerItem* item = (AVPlayerItem*)playerItem;
			if (item != NULL) {
				item.preferredPeakBitRate = peakBitRate;
			}
		@}

		[Foreign(Language.ObjC)]
		static void SetIdleTimerDisabled(bool disabled)
		@{
			[UIApplication sharedApplication].idleTimerDisabled = disabled;
		@}

		[Foreign(Language.ObjC)]
		static void SetVideoGravity(ObjC.Object container, int gravity)
		@{
			AVPlayerViewController* playerViewController = (AVPlayerViewController*)container;
			if (playerViewController == NULL) {
				return;
			}

			switch (gravity) {
				case 1:
					playerViewController.videoGravity = AVLayerVideoGravityResize;
					break;
				case 2:
					playerViewController.videoGravity = AVLayerVideoGravityResizeAspectFill;
					break;
				default:
					playerViewController.videoGravity = AVLayerVideoGravityResizeAspect;
					break;
			}
		@}

		[Foreign(Language.ObjC)]
		static void SetShowsPlaybackControls(ObjC.Object container, bool show)
		@{
			AVPlayerViewController* playerViewController = (AVPlayerViewController*)container;
			if (playerViewController != NULL) {
				playerViewController.showsPlaybackControls = show;
			}
		@}

		[Foreign(Language.ObjC)]
		static void SetPlayerMuted(ObjC.Object player, bool muted)
		@{
			AVPlayer* avPlayer = (AVPlayer*)player;
			if (avPlayer != NULL) {
				avPlayer.muted = muted;
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

			// Picture-in-Picture (requires the "Audio, AirPlay and Picture in Picture"
			// background mode in the app project)
			playerViewController.allowsPictureInPicturePlayback = YES;

			// Create the player up front, so playback options can be applied before a
			// source is loaded.
			AVPlayer *player = [[AVPlayer alloc] init];
			playerViewController.player = player;
			@{AVPlayerView:Of(_this)._player:Set(player)};

			AVPlayerContainer* playerContainer = (AVPlayerContainer*)@{AVPlayerView:Of(_this).Handle:Get()};
			playerContainer.avPlayerView = playerViewController.view;
			[playerContainer addSubview:playerViewController.view];

			return playerViewController;
		@}

		[Foreign(Language.ObjC)]
		static void ReleasePlayer(ObjC.Object player)
		@{
			AVPlayer* avPlayer = (AVPlayer*)player;
			if (avPlayer == NULL) {
				return;
			}

			[avPlayer pause];
			[avPlayer replaceCurrentItemWithPlayerItem:nil];
		@}

		[Foreign(Language.ObjC)]
		static void DetachPlayerView(ObjC.Object container)
		@{
			AVPlayerViewController* playerViewController = (AVPlayerViewController*)container;
			if (playerViewController == NULL) {
				return;
			}

			[playerViewController.view removeFromSuperview];
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
					@{AVPlayerView:Of(_this).UpdateBufferProgress():Call()};
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

		void RemoveObservers()
		{
			RemoveTimeObserver();
			RemoveEndObserver();
		}

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
		}

		// Raised by the AVPlayerItemDidPlayToEndTimeNotification observer
		void OnPlaybackItemEnded()
		{
			if (_isLooping)
			{
				ResetPlaybackPosition();
				Seek(0);
				Play();
				return;
			}

			OnPlaybackEnded();
		}

		void OnDurationChanged(double seconds)
		{
			_duration = Math.Max(0.0, seconds);
			if (_host != null) _host.OnDurationChanged(_duration);
		}

		void OnReadyToPlay()
		{
			// CheckInitialStatus() runs on every time-observer tick until the duration is
			// known, which is never the case for some live streams.
			if (_readyNotified)
				return;

			_readyNotified = true;
			if (_host != null) _host.OnLoadingEnded();
		}

		void OnPlaybackEnded()
		{
			_isPlaying = false;
			_isBuffering = false;
			UpdateIdleTimer();

			// Report the final position, there will be no more updates
			if (_duration > 0)
			{
				_position = _duration;
				if (_host != null) _host.OnPositionChanged(_position);
			}

			if (_host != null) _host.OnEnded();
		}

		void OnPlaybackStopped()
		{
			_isPlaying = false;
			_isBuffering = false;
			UpdateIdleTimer();
			ResetPlaybackPosition();

			if (_host != null)
			{
				_host.OnPositionChanged(0.0);
				_host.OnStopped();
			}
		}

		void OnPlaybackError(string error, int errorCode = -1)
		{
			_isPlaying = false;
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

		[Foreign(Language.ObjC)]
		static int GetTimeControlStatus(ObjC.Object player)
		@{
			AVPlayer* avPlayer = (AVPlayer*)player;
			if (avPlayer == NULL) {
				return 0;
			}

			return (int)avPlayer.timeControlStatus;
		@}

		void UpdateBufferProgress()
		{
			if (_player == null)
				return;

			OnBufferProgressChanged((float)GetBufferProgress(_player));
		}

		[Foreign(Language.ObjC)]
		static double GetBufferProgress(ObjC.Object player)
		@{
			AVPlayer* avPlayer = (AVPlayer*)player;
			if (avPlayer == NULL) {
				return 0.0;
			}

			AVPlayerItem* item = avPlayer.currentItem;
			if (item == NULL) {
				return 0.0;
			}

			double duration = CMTimeGetSeconds(item.duration);
			if (!(duration > 0.0)) {
				return 0.0;
			}

			NSArray* ranges = item.loadedTimeRanges;
			if (ranges == NULL || ranges.count == 0) {
				return 0.0;
			}

			CMTimeRange range = [[ranges lastObject] CMTimeRangeValue];
			double buffered = CMTimeGetSeconds(CMTimeRangeGetEnd(range));
			double progress = buffered / duration;

			if (!(progress > 0.0)) {
				return 0.0;
			}

			return progress > 1.0 ? 1.0 : progress;
		@}
	}
}
