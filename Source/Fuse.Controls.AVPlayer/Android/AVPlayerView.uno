using Uno;
using Uno.UX;
using Uno.Compiler.ExportTargetInterop;
using Uno.Time;

using Fuse;
using Fuse.Controls;
using Fuse.Controls.Native;
using Fuse.Controls.Native.Android;

namespace Fuse.Controls.Native.Android
{
	extern(!Android) class AVPlayerView
	{
		[UXConstructor]
		public AVPlayerView([UXParameter("Host")]AVPlayerBase host) { }
	}

	[Require("gradle.dependency.implementation", "androidx.media3:media3-exoplayer:1.4.1")]
	[Require("gradle.dependency.implementation", "androidx.media3:media3-ui:1.4.1")]
	[Require("gradle.dependency.implementation", "androidx.media3:media3-exoplayer-dash:1.4.1")]
	[Require("gradle.dependency.implementation", "androidx.media3:media3-exoplayer-hls:1.4.1")]
	extern(Android) class AVPlayerView : LeafView, IAVPlayerView
	{

		AVPlayerBase _host;
		Java.Object _container;
		Java.Object _player;
		Java.Object _playerView;
		Java.Object _trackSelector;

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
		Fuse.Elements.StretchMode _stretchMode = Fuse.Elements.StretchMode.Uniform;
		MediaStreamQuality _streamQuality = MediaStreamQuality.Auto;

		[UXConstructor]
		public AVPlayerView([UXParameter("Host")]AVPlayerBase host) : base(CreateContainer())
		{
			_host = host;
			// AutoPlay is read when the source is loaded, so it has to be known up front
			_autoPlay = host.AutoPlay;
			_player = CreatePlayer();
			if (!string.IsNullOrEmpty(host.Url))
				Url = host.Url;
			if (host.File != null)
				File = host.File;
		}

		public override void Dispose()
		{
			StopPositionUpdates();

			if (_playerView != null)
				DetachPlayerView(_playerView);

			if (_player != null)
				Release(_player);

			base.Dispose();

			_container = null;
			_player = null;
			_playerView = null;
			_trackSelector = null;
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
					if (_player != null)
					{
						if (_file is BundleFileSource)
							SetVideoUri(_player, "file:///android_asset/" + ((BundleFileSource)_file).BundleFile.BundlePath);
						else if (_file != null)
						{
							var data = _file.ReadAllBytes();
							var path = Uno.IO.Directory.GetUserDirectory(Uno.IO.UserDirectory.Videos) + "/" + _file.Name;
							Uno.IO.File.WriteAllBytes(path, data);
							SetVideoUri(_player, path);
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
					if (_player != null && !string.IsNullOrEmpty(_url))
						SetVideoUri(_player, _url);
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
				var progress = Math.Max(0.0, Math.Min(1.0, value));
				if (_duration > 0)
					SetPlaybackPosition(_player, progress * _duration);
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
					ApplyVolume();
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
					ApplyVolume();
				}
			}
		}

		// ExoPlayer has no mute flag, muting is a volume of 0
		void ApplyVolume()
		{
			SetVolume(_player, _muted ? 0.0f : _volume);
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
					if (_playerView != null)
						SetUseController(_playerView, _showControls);
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
					UpdateKeepScreenOn();
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
			if (_trackSelector == null)
				return;

			SetMaxVideoBitrate(_trackSelector, GetMaxVideoBitrate(_streamQuality));
		}

		static int GetMaxVideoBitrate(MediaStreamQuality quality)
		{
			switch (quality)
			{
				case MediaStreamQuality.SD:
					return 1500000;
				case MediaStreamQuality.HD:
					return 4000000;
				case MediaStreamQuality.FullHD:
					return 8000000;
				default:
					return int.MaxValue;
			}
		}

		void ApplyStretchMode()
		{
			if (_playerView == null)
				return;

			// 0 = fit (letterbox), 1 = fill (stretch), 2 = zoom (crop)
			var resizeMode = 0;
			if (_stretchMode == Fuse.Elements.StretchMode.Fill)
				resizeMode = 1;
			else if (_stretchMode == Fuse.Elements.StretchMode.UniformToFill)
				resizeMode = 2;

			SetResizeMode(_playerView, resizeMode);
		}

		void UpdateKeepScreenOn()
		{
			if (_playerView == null)
				return;

			SetKeepScreenOn(_playerView, _keepScreenOn && _isPlaying);
		}

		public bool IsBuffering { get { return _isBuffering; } }
		public float BufferProgress { get { return _bufferProgress; } }

		// Events are handled by the host (base class)

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

			if (_host != null)
				_host.OnDurationChanged(0.0);
		}

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
			OnStopped();
		}

		public void Seek(double positionSeconds)
		{
			_position = Math.Max(0.0, positionSeconds);
			SetPlaybackPosition(_player, _position);
		}

		[Foreign(Language.Java)]
		void SetVideoUri(Java.Object handle, string url)
		@{
			androidx.media3.exoplayer.ExoPlayer player = (androidx.media3.exoplayer.ExoPlayer)handle;
			android.net.Uri uri = android.net.Uri.parse(url);
			androidx.media3.common.MediaItem mediaItem = androidx.media3.common.MediaItem.fromUri(uri);
			player.setMediaItem(mediaItem);

			player.prepare();
			if (@{AVPlayerView:Of(_this)._autoPlay:Get()}) {
				player.setPlayWhenReady(true);
			}
		@}

		[Foreign(Language.Java)]
		void Release(Java.Object handle)
		@{
			androidx.media3.exoplayer.ExoPlayer player = (androidx.media3.exoplayer.ExoPlayer)handle;
			if (player != null) {
				player.setPlayWhenReady(false);
				player.release();
			}
		@}

		[Foreign(Language.Java)]
		static void DetachPlayerView(Java.Object playerView)
		@{
			androidx.media3.ui.PlayerView view = (androidx.media3.ui.PlayerView)playerView;
			if (view != null) {
				view.setPlayer(null);
			}
		@}

		[Foreign(Language.Java)]
		static void SetMaxVideoBitrate(Java.Object trackSelector, int maxBitrate)
		@{
			androidx.media3.exoplayer.trackselection.DefaultTrackSelector selector =
				(androidx.media3.exoplayer.trackselection.DefaultTrackSelector)trackSelector;
			if (selector == null) {
				return;
			}

			androidx.media3.common.TrackSelectionParameters.Builder builder =
				selector.getParameters().buildUpon();
			builder.setMaxVideoBitrate(maxBitrate);
			selector.setParameters(builder.build());
		@}

		[Foreign(Language.Java)]
		static void SetResizeMode(Java.Object playerView, int resizeMode)
		@{
			androidx.media3.ui.PlayerView view = (androidx.media3.ui.PlayerView)playerView;
			if (view == null) {
				return;
			}

			switch (resizeMode) {
				case 1:
					view.setResizeMode(androidx.media3.ui.AspectRatioFrameLayout.RESIZE_MODE_FILL);
					break;
				case 2:
					view.setResizeMode(androidx.media3.ui.AspectRatioFrameLayout.RESIZE_MODE_ZOOM);
					break;
				default:
					view.setResizeMode(androidx.media3.ui.AspectRatioFrameLayout.RESIZE_MODE_FIT);
					break;
			}
		@}

		[Foreign(Language.Java)]
		static void SetUseController(Java.Object playerView, bool useController)
		@{
			androidx.media3.ui.PlayerView view = (androidx.media3.ui.PlayerView)playerView;
			if (view != null) {
				view.setUseController(useController);
			}
		@}

		[Foreign(Language.Java)]
		static void SetKeepScreenOn(Java.Object playerView, bool keepScreenOn)
		@{
			androidx.media3.ui.PlayerView view = (androidx.media3.ui.PlayerView)playerView;
			if (view != null) {
				view.setKeepScreenOn(keepScreenOn);
			}
		@}

		[Foreign(Language.Java)]
		static void PlayPlayer(Java.Object player)
		@{
			androidx.media3.exoplayer.ExoPlayer exoPlayer = (androidx.media3.exoplayer.ExoPlayer)player;
			if (exoPlayer != null) {
				exoPlayer.setPlayWhenReady(true);
			}
		@}

		[Foreign(Language.Java)]
		static void PausePlayer(Java.Object player)
		@{
			androidx.media3.exoplayer.ExoPlayer exoPlayer = (androidx.media3.exoplayer.ExoPlayer)player;
			if (exoPlayer != null) {
				exoPlayer.setPlayWhenReady(false);
			}
		@}

		[Foreign(Language.Java)]
		static void StopPlayer(Java.Object player)
		@{
			androidx.media3.exoplayer.ExoPlayer exoPlayer = (androidx.media3.exoplayer.ExoPlayer)player;
			if (exoPlayer != null) {
				exoPlayer.setPlayWhenReady(false);
				exoPlayer.seekTo(0);
			}
		@}

		[Foreign(Language.Java)]
		static void SetVolume(Java.Object player, float volume)
		@{
			androidx.media3.exoplayer.ExoPlayer exoPlayer = (androidx.media3.exoplayer.ExoPlayer)player;
			if (exoPlayer != null) {
				exoPlayer.setVolume(volume);
			}
		@}

		[Foreign(Language.Java)]
		static void SetPlaybackRate(Java.Object player, float rate)
		@{
			androidx.media3.exoplayer.ExoPlayer exoPlayer = (androidx.media3.exoplayer.ExoPlayer)player;
			if (exoPlayer != null) {
				androidx.media3.common.PlaybackParameters parameters = new androidx.media3.common.PlaybackParameters(rate);
				exoPlayer.setPlaybackParameters(parameters);
			}
		@}

		[Foreign(Language.Java)]
		static void SetLooping(Java.Object player, bool looping)
		@{
			androidx.media3.exoplayer.ExoPlayer exoPlayer = (androidx.media3.exoplayer.ExoPlayer)player;
			if (exoPlayer != null) {
				exoPlayer.setRepeatMode(looping ? androidx.media3.common.Player.REPEAT_MODE_ONE : androidx.media3.common.Player.REPEAT_MODE_OFF);
			}
		@}

		[Foreign(Language.Java)]
		static Java.Object CreateContainer()
		@{
			android.widget.FrameLayout frameLayout = new android.widget.FrameLayout(com.fuse.Activity.getRootActivity());
			frameLayout.setFocusable(true);
			frameLayout.setFocusableInTouchMode(true);
			frameLayout.setLayoutParams(new android.widget.FrameLayout.LayoutParams(android.view.ViewGroup.LayoutParams.MATCH_PARENT, android.view.ViewGroup.LayoutParams.MATCH_PARENT));
			return frameLayout;
		@}

		[Foreign(Language.Java)]
		Java.Object CreatePlayer()
		@{
			android.widget.FrameLayout frameLayout = (android.widget.FrameLayout)@{AVPlayerView:Of(_this).Handle:Get()};

			androidx.media3.ui.PlayerView playerView = new androidx.media3.ui.PlayerView(com.fuse.Activity.getRootActivity());
			playerView.setLayoutParams(new android.widget.FrameLayout.LayoutParams(android.view.ViewGroup.LayoutParams.MATCH_PARENT, android.view.ViewGroup.LayoutParams.MATCH_PARENT));
			frameLayout.addView(playerView);

			androidx.media3.exoplayer.trackselection.DefaultTrackSelector trackSelector =
				new androidx.media3.exoplayer.trackselection.DefaultTrackSelector(com.fuse.Activity.getRootActivity());
			@{AVPlayerView:Of(_this)._trackSelector:Set(trackSelector)};

			androidx.media3.exoplayer.ExoPlayer player = new androidx.media3.exoplayer.ExoPlayer.Builder(com.fuse.Activity.getRootActivity())
				.setTrackSelector(trackSelector)
				.build();

			// Media audio: pauses for phone calls and other audio focus loss, and pauses
			// when headphones are unplugged
			androidx.media3.common.AudioAttributes audioAttributes =
				new androidx.media3.common.AudioAttributes.Builder()
					.setUsage(androidx.media3.common.C.USAGE_MEDIA)
					.setContentType(androidx.media3.common.C.AUDIO_CONTENT_TYPE_MOVIE)
					.build();
			player.setAudioAttributes(audioAttributes, true);
			player.setHandleAudioBecomingNoisy(true);

			playerView.setPlayer(player);

			@{AVPlayerView:Of(_this)._playerView:Set(playerView)};
			@{AVPlayerView:Of(_this)._player:Set(player)};

			// Add player listener for events
			androidx.media3.common.Player.Listener playerListener = new androidx.media3.common.Player.Listener() {
				@Override
				public void onIsPlayingChanged(boolean isPlaying) {
					if (isPlaying) {
						@{AVPlayerView:Of(_this).OnPlaying():Call()};
					} else if (!player.getPlayWhenReady()) {
						// `isPlaying` is also false while buffering or when playback ended;
						// only report a pause when playback was actually requested to stop.
						@{AVPlayerView:Of(_this).OnPaused():Call()};
					}
				}

				@Override
				public void onPlaybackStateChanged(int playbackState) {
					switch (playbackState) {
						case androidx.media3.common.Player.STATE_BUFFERING:
							@{AVPlayerView:Of(_this).OnBufferingStarted():Call()};
							break;
						case androidx.media3.common.Player.STATE_READY:
							@{AVPlayerView:Of(_this).OnReadyToPlay():Call()};
							// Update duration and buffering info
							@{AVPlayerView:Of(_this).UpdateDuration():Call()};
							@{AVPlayerView:Of(_this).UpdateBufferProgress():Call()};
							break;
						case androidx.media3.common.Player.STATE_ENDED:
							@{AVPlayerView:Of(_this).OnEnded():Call()};
							break;
						case androidx.media3.common.Player.STATE_IDLE:
							// Player is idle, possibly due to an error or initialization
							break;
					}
				}

				@Override
				public void onPlayerError(androidx.media3.common.PlaybackException error) {
					int errorType = error.errorCode;
					String errorMessage = error.getMessage();
					Throwable cause = error.getCause();
					String detailedMessage = errorMessage;

					if (cause != null) {
						detailedMessage = errorMessage + " (" + cause.getMessage() + ")";
					}

					@{AVPlayerView:Of(_this).OnPlaybackError(string, int):Call(detailedMessage, errorType)};
				}
			};

			player.addListener(playerListener);

			@{AVPlayerView:Of(_this).ApplyStreamQuality():Call()};

			return player;
		@}

		// Callback methods from native code
		void OnPlaying()
		{
			_isPlaying = true;
			StartPositionUpdates();
			UpdateKeepScreenOn();
			if (_host != null) _host.OnPlaying();
		}

		void OnPaused()
		{
			_isPlaying = false;
			StopPositionUpdates();
			UpdateKeepScreenOn();
			if (_host != null) _host.OnPaused();
		}

		void OnBufferingStarted()
		{
			_isBuffering = true;
			if (_host != null) _host.OnLoadingStarted();
		}

		void OnReadyToPlay()
		{
			_isBuffering = false;
			if (_host != null) _host.OnLoadingEnded();
		}

		void OnEnded()
		{
			_isPlaying = false;
			StopPositionUpdates();
			UpdateKeepScreenOn();

			// Report the final position, there will be no more ticks
			if (_player != null)
				OnPositionUpdate(GetCurrentTime(_player));

			if (_host != null) _host.OnEnded();
		}

		void OnStopped()
		{
			_isPlaying = false;
			StopPositionUpdates();
			UpdateKeepScreenOn();
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
			StopPositionUpdates();
			UpdateKeepScreenOn();

			if (_host != null)
			{
				ErrorSeverity severity = DetermineErrorSeverity(errorCode);
				Exception exception = errorCode != -1 ? new Exception("ExoPlayer error code: " + errorCode) : null;
				_host.OnError(error ?? "Unknown playback error", exception, severity);
			}
		}

		/**
			Determines error severity based on ExoPlayer error codes
		*/
		ErrorSeverity DetermineErrorSeverity(int errorCode)
		{
			// ExoPlayer error codes from PlaybackException
			switch (errorCode)
			{
				case 1000: // ERROR_CODE_UNSPECIFIED
				case 1001: // ERROR_CODE_REMOTE_ERROR
					return ErrorSeverity.Fatal;
				case 2000: // ERROR_CODE_IO_UNSPECIFIED
				case 2001: // ERROR_CODE_IO_NETWORK_CONNECTION_FAILED
				case 2002: // ERROR_CODE_IO_NETWORK_CONNECTION_TIMEOUT
					return ErrorSeverity.Error;
				case 3001: // ERROR_CODE_PARSING_CONTAINER_MALFORMED
				case 3002: // ERROR_CODE_PARSING_MANIFEST_MALFORMED
					return ErrorSeverity.Error;
				case 4001: // ERROR_CODE_DECODER_INIT_FAILED
				case 4002: // ERROR_CODE_DECODER_QUERY_FAILED
					return ErrorSeverity.Fatal;
				case 5001: // ERROR_CODE_AUDIO_TRACK_INIT_FAILED
				case 5002: // ERROR_CODE_AUDIO_TRACK_WRITE_FAILED
					return ErrorSeverity.Warning;
				default:
					return ErrorSeverity.Error;
			}
		}

		[Foreign(Language.Java)]
		void UpdateDuration()
		@{
			androidx.media3.exoplayer.ExoPlayer player = (androidx.media3.exoplayer.ExoPlayer)@{AVPlayerView:Of(_this)._player:Get()};
			if (player != null) {
				long durationMs = player.getDuration();
				if (durationMs != androidx.media3.common.C.TIME_UNSET && durationMs > 0) {
					@{AVPlayerView:Of(_this).OnDurationChanged(long):Call(durationMs)};
				}
			}
		@}

		[Foreign(Language.Java)]
		void UpdateBufferProgress()
		@{
			androidx.media3.exoplayer.ExoPlayer player = (androidx.media3.exoplayer.ExoPlayer)@{AVPlayerView:Of(_this)._player:Get()};
			if (player != null) {
				long durationMs = player.getDuration();
				long bufferedPositionMs = player.getBufferedPosition();

				if (durationMs != androidx.media3.common.C.TIME_UNSET && durationMs > 0) {
					float bufferProgress = (float) bufferedPositionMs / (float) durationMs;
					@{AVPlayerView:Of(_this).OnBufferProgressChanged(float):Call(bufferProgress)};
				}
			}
		@}

		void OnDurationChanged(long durationMs)
		{
			_duration = Math.Max(0.0, durationMs / 1000.0);
			if (_host != null) _host.OnDurationChanged(_duration);
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

		// Position updates are driven by the Fuse update loop while the media is playing
		bool _positionUpdatesActive;
		int _updateFrame;

		void StartPositionUpdates()
		{
			if (_positionUpdatesActive)
				return;

			_positionUpdatesActive = true;
			_updateFrame = 0;
			Fuse.UpdateManager.AddAction(OnUpdate);
		}

		void StopPositionUpdates()
		{
			if (!_positionUpdatesActive)
				return;

			_positionUpdatesActive = false;
			Fuse.UpdateManager.RemoveAction(OnUpdate);
		}

		void OnUpdate()
		{
			if (_player == null || !_isPlaying)
				return;

			_updateFrame++;

			// Roughly 10 position updates per second at 60 fps
			if (_updateFrame % 6 == 0)
				OnPositionUpdate(GetCurrentTime(_player));

			// Buffer progress is only needed a couple of times per second
			if (_updateFrame % 30 == 0)
				UpdateBufferProgress();
		}

		[Foreign(Language.Java)]
		long GetCurrentTime(Java.Object player)
		@{
			androidx.media3.exoplayer.ExoPlayer exoPlayer = (androidx.media3.exoplayer.ExoPlayer)player;
			if (exoPlayer != null) {
				return exoPlayer.getCurrentPosition();
			}
			return 0;
		@}

		void OnPositionUpdate(long positionMs)
		{
			_position = Math.Max(0.0, positionMs / 1000.0); // Convert milliseconds to seconds
			if (_host != null) _host.OnPositionChanged(_position);
		}

		[Foreign(Language.Java)]
		void SetPlaybackPosition(Java.Object player, double position)
		@{
			androidx.media3.exoplayer.ExoPlayer exoPlayer = (androidx.media3.exoplayer.ExoPlayer)player;
			if (exoPlayer != null) {
				long positionMs = (long)(position * 1000);
				exoPlayer.seekTo(positionMs);
			}
		@}
	}
}
