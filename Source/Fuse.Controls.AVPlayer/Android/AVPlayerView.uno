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

	[Require("gradle.dependency.implementation", "com.google.android.exoplayer:exoplayer-core:2.18.0")]
	[Require("gradle.dependency.implementation", "com.google.android.exoplayer:exoplayer-ui:2.18.0")]
	[Require("gradle.dependency.implementation", "com.google.android.exoplayer:exoplayer-dash:2.18.0")]
	[Require("gradle.dependency.implementation", "com.google.android.exoplayer:exoplayer-hls:2.18.0")]
	extern(Android) class AVPlayerView : LeafView, IAVPlayerView
	{

		AVPlayerBase _host;
		Java.Object _container;
		Java.Object _player;
		Java.Object _playerView;

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
			_player = CreatePlayer();
			Url = _host.Url;
			File = _host.File;
		}

		public override void Dispose()
		{
			base.Dispose();
			if (_player != null)
				Release(_player);
			_container = null;
			_player = null;
			_playerView = null;
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
					if (_player != null)
					{
						if (_file is BundleFileSource)
							SetVideoUri(_player, "file:///android_asset/" + ((BundleFileSource)_file).BundleFile.BundlePath);
						else
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
					if (_player != null)
						SetVideoUri(_player, value);
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
				var position = progress * _duration;
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

		// Events are handled by the host (base class)

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
			SeekToTime(_player, positionSeconds);
		}

		[Foreign(Language.Java)]
		void SetVideoUri(Java.Object handle, string url)
		@{
			com.google.android.exoplayer2.ExoPlayer player = (com.google.android.exoplayer2.ExoPlayer)handle;
			android.net.Uri uri = android.net.Uri.parse(url);
			com.google.android.exoplayer2.MediaItem mediaItem = com.google.android.exoplayer2.MediaItem.fromUri(uri);
			player.setMediaItem(mediaItem);

			player.prepare();
			if (@{AVPlayerView:Of(_this)._autoPlay:Get()}) {
				player.setPlayWhenReady(true);
			}
		@}

		[Foreign(Language.Java)]
		void Release(Java.Object handle)
		@{
			com.google.android.exoplayer2.ExoPlayer player = (com.google.android.exoplayer2.ExoPlayer)handle;
			if (player != null) {
				player.release();
			}
		@}

		[Foreign(Language.Java)]
		static void PlayPlayer(Java.Object player)
		@{
			com.google.android.exoplayer2.ExoPlayer exoPlayer = (com.google.android.exoplayer2.ExoPlayer)player;
			if (exoPlayer != null) {
				exoPlayer.setPlayWhenReady(true);
			}
		@}

		[Foreign(Language.Java)]
		static void PausePlayer(Java.Object player)
		@{
			com.google.android.exoplayer2.ExoPlayer exoPlayer = (com.google.android.exoplayer2.ExoPlayer)player;
			if (exoPlayer != null) {
				exoPlayer.setPlayWhenReady(false);
			}
		@}

		[Foreign(Language.Java)]
		static void StopPlayer(Java.Object player)
		@{
			com.google.android.exoplayer2.ExoPlayer exoPlayer = (com.google.android.exoplayer2.ExoPlayer)player;
			if (exoPlayer != null) {
				exoPlayer.setPlayWhenReady(false);
				exoPlayer.seekTo(0);
			}
		@}

		[Foreign(Language.Java)]
		static void SeekToTime(Java.Object player, double seconds)
		@{
			com.google.android.exoplayer2.ExoPlayer exoPlayer = (com.google.android.exoplayer2.ExoPlayer)player;
			if (exoPlayer != null) {
				long positionMs = (long)(seconds * 1000);
				exoPlayer.seekTo(positionMs);
			}
		@}

		[Foreign(Language.Java)]
		static void SetVolume(Java.Object player, float volume)
		@{
			com.google.android.exoplayer2.ExoPlayer exoPlayer = (com.google.android.exoplayer2.ExoPlayer)player;
			if (exoPlayer != null) {
				exoPlayer.setVolume(volume);
			}
		@}

		[Foreign(Language.Java)]
		static void SetPlaybackRate(Java.Object player, float rate)
		@{
			com.google.android.exoplayer2.ExoPlayer exoPlayer = (com.google.android.exoplayer2.ExoPlayer)player;
			if (exoPlayer != null) {
				com.google.android.exoplayer2.PlaybackParameters parameters = new com.google.android.exoplayer2.PlaybackParameters(rate);
				exoPlayer.setPlaybackParameters(parameters);
			}
		@}

		[Foreign(Language.Java)]
		static void SetLooping(Java.Object player, boolean looping)
		@{
			com.google.android.exoplayer2.ExoPlayer exoPlayer = (com.google.android.exoplayer2.ExoPlayer)player;
			if (exoPlayer != null) {
				exoPlayer.setRepeatMode(looping ? com.google.android.exoplayer2.Player.REPEAT_MODE_ONE : com.google.android.exoplayer2.Player.REPEAT_MODE_OFF);
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

			com.google.android.exoplayer2.ui.PlayerView playerView = new com.google.android.exoplayer2.ui.PlayerView(com.fuse.Activity.getRootActivity());
			playerView.setLayoutParams(new android.widget.FrameLayout.LayoutParams(android.view.ViewGroup.LayoutParams.MATCH_PARENT, android.view.ViewGroup.LayoutParams.MATCH_PARENT));
			frameLayout.addView(playerView);

			com.google.android.exoplayer2.ExoPlayer player = new com.google.android.exoplayer2.ExoPlayer.Builder(com.fuse.Activity.getRootActivity()).build();
			playerView.setPlayer(player);

			@{AVPlayerView:Of(_this)._playerView:Set(playerView)};
			@{AVPlayerView:Of(_this)._player:Set(player)};

			// Add player listener for events
			com.google.android.exoplayer2.Player.Listener playerListener = new com.google.android.exoplayer2.Player.Listener() {
				@Override
				public void onIsPlayingChanged(boolean isPlaying) {
					if (isPlaying) {
						@{AVPlayerView:Of(_this).OnPlaying():Call()};
					} else {
						@{AVPlayerView:Of(_this).OnPaused():Call()};
					}
				}

				@Override
				public void onPlaybackStateChanged(int playbackState) {
					switch (playbackState) {
						case com.google.android.exoplayer2.Player.STATE_BUFFERING:
							@{AVPlayerView:Of(_this).OnBufferingStarted():Call()};
							break;
						case com.google.android.exoplayer2.Player.STATE_READY:
							@{AVPlayerView:Of(_this).OnReadyToPlay():Call()};
							// Update duration and buffering info
							@{AVPlayerView:Of(_this).UpdateDuration():Call()};
							@{AVPlayerView:Of(_this).UpdateBufferProgress():Call()};
							break;
						case com.google.android.exoplayer2.Player.STATE_ENDED:
							@{AVPlayerView:Of(_this).OnEnded():Call()};
							break;
						case com.google.android.exoplayer2.Player.STATE_IDLE:
							// Player is idle, possibly due to an error or initialization
							break;
					}
				}

				@Override
				public void onPlayerError(com.google.android.exoplayer2.PlaybackException error) {
					int errorType = error.errorCode;
					String errorMessage = error.getMessage();
					Throwable cause = error.getCause();
					String detailedMessage = errorMessage;

					if (cause != null) {
						detailedMessage = errorMessage + " (" + cause.getMessage() + ")";
					}

					@{AVPlayerView:Of(_this).OnPlaybackError(string, int):Call(detailedMessage, errorType)};
				}

				@Override
				public void onLoadingChanged(boolean isLoading) {
					if (isLoading) {
						@{AVPlayerView:Of(_this).OnBufferingStarted():Call()};
					} else {
						@{AVPlayerView:Of(_this).OnBufferingEnded():Call()};
					}
				}
			};

			player.addListener(playerListener);

			return player;
		@}

		// Callback methods from native code
		void OnPlaying()
		{
			_isPlaying = true;
			if (_host != null) _host.OnPlaying();
		}

		void OnPaused()
		{
			_isPlaying = false;
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

		void OnBufferingEnded()
		{
			_isBuffering = false;
			if (_host != null) _host.OnLoadingEnded();
		}

		void OnEnded()
		{
			_isPlaying = false;
			if (_host != null) _host.OnEnded();
		}

		void OnStopped()
		{
			_isPlaying = false;
			if (_host != null) _host.OnStopped();
		}

		void OnPlaybackError(string error, int errorCode = -1)
		{
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
			com.google.android.exoplayer2.ExoPlayer player = (com.google.android.exoplayer2.ExoPlayer)@{AVPlayerView:Of(_this)._player:Get()};
			if (player != null) {
				long durationMs = player.getDuration();
				if (durationMs != com.google.android.exoplayer2.C.TIME_UNSET && durationMs > 0) {
					@{AVPlayerView:Of(_this).OnDurationChanged(long):Call(durationMs)};
				}
			}
		@}

		[Foreign(Language.Java)]
		void UpdateBufferProgress()
		@{
			com.google.android.exoplayer2.ExoPlayer player = (com.google.android.exoplayer2.ExoPlayer)@{AVPlayerView:Of(_this)._player:Get()};
			if (player != null) {
				long durationMs = player.getDuration();
				long bufferedPositionMs = player.getBufferedPosition();

				if (durationMs != com.google.android.exoplayer2.C.TIME_UNSET && durationMs > 0) {
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

		// Update position periodically for smoother tracking
		void UpdatePosition()
		{
			OnPositionUpdate(GetCurrentTime(_player));
		}

		[Foreign(Language.Java)]
		void GetCurrentTime(Java.Object player)
		@{
			com.google.android.exoplayer2.ExoPlayer exoPlayer = (com.google.android.exoplayer2.ExoPlayer)player;
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
			com.google.android.exoplayer2.ExoPlayer exoPlayer = (com.google.android.exoplayer2.ExoPlayer)player;
			if (exoPlayer != null) {
				long positionMs = (long)(position * 1000);
				exoPlayer.seekTo(positionMs);
			}
		@}
	}
}
