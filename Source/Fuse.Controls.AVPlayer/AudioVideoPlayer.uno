using Uno;
using Uno.UX;
using Uno.Compiler.ExportTargetInterop;

using Fuse;
using Fuse.Resources;
using Fuse.Controls.Native;
using Fuse.Scripting;
using Fuse.Triggers;
using Fuse.Controls.Native.iOS;
using Fuse.Controls.Native.Android;

namespace Fuse.Controls
{
	/**
		Interface defining the contract for native video player implementations.

		This interface abstracts the platform-specific video player functionality,
		allowing the same API to work across iOS (AVPlayer) and Android (ExoPlayer).
	*/
	interface IAVPlayerView
	{
		/** Sets the video file source from a bundled or local file */
		FileSource File { set; }
		/** Sets the video URL for streaming or remote content */
		string Url { set; }

		// Playback control methods
		void Play();
		void Pause();
		void Stop();
		/** Seeks to the specified position in seconds */
		void Seek(double positionSeconds);

		// Read-only state properties
		bool IsPlaying { get; }
		/** Total duration in seconds, 0 if unknown */
		double Duration { get; }
		/** Current playback position in seconds */
		double Position { get; set; }
		/** Current playback progress (0.0 to 1.0) */
		double Progress { get; set; }
		/** Audio volume (0.0 to 1.0) */
		float Volume { get; set; }
		/** Whether the video loops when it reaches the end */
		bool IsLooping { get; set; }
		/** Playback speed multiplier (0.25 to 4.0) */
		float PlaybackRate { get; set; }
		/** Whether to start playing automatically when loaded */
		bool AutoPlay { get; set; }
		/** Whether the player is currently buffering content */
		bool IsBuffering { get; }
		/** Buffer progress as a percentage (0.0 to 1.0) */
		float BufferProgress { get; }

		// Presentation
		/** How the video is fitted inside the element */
		Fuse.Elements.StretchMode StretchMode { set; }
		/** Whether the platform playback controls are shown */
		bool ShowControls { set; }
		/** Whether the screen is kept awake while playing */
		bool KeepScreenOn { set; }
		/** Whether the audio output is muted */
		bool Muted { set; }
		/** Limits the quality of streaming sources */
		MediaStreamQuality StreamQuality { set; }
	}

	/**
		The playback state of a @MediaPlayer.

		Use the @State property, or the equivalent triggers (@WhilePlaying, @WhilePaused,
		@WhileLoading, @WhileCompleted and @WhileFailed), instead of comparing states
		manually.
	*/
	public enum MediaPlayerState
	{
		/** No source has been loaded */
		Idle,
		/** A source is being loaded, or playback is waiting for more data */
		Loading,
		/** The media is loaded and ready to play, but not playing */
		Ready,
		/** The media is playing */
		Playing,
		/** Playback is paused, or stopped at the beginning */
		Paused,
		/** Playback reached the end of the media */
		Ended,
		/** Playback failed, see @ErrorMessage */
		Failed
	}

	/**
		Limits the video quality used for streaming sources.

		This is a cap rather than a fixed quality: the player still adapts to the available
		bandwidth, but will not select a stream above the limit.
	*/
	public enum MediaStreamQuality
	{
		/** Adaptive, no bitrate limit */
		Auto,
		/** Up to roughly 480p (1.5 Mbit/s) */
		SD,
		/** Up to roughly 720p (4 Mbit/s) */
		HD,
		/** Up to roughly 1080p (8 Mbit/s) */
		FullHD
	}

	/**
		Cross-platform video player component for Fuse applications.

		Implements the IMediaPlayback interface for compatibility with Fuse triggers and actions.
		Supports local files and streaming URLs with comprehensive playback controls.

		## Basic Usage

		```ux
		<MediaPlayer
			Url="https://example.com/video.mp4"
			AutoPlay="false"
			Volume="0.8"
			Width="320"
			Height="240" />
		```

		## With Fuse Triggers

		```ux
		<StackPanel>
			<MediaPlayer ux:Name="videoPlayer" Url="video.mp4" />

			<StackPanel Orientation="Horizontal">
				<Button Text="Play">
					<Clicked>
						<Play Target="videoPlayer" />
					</Clicked>
				</Button>
				<Button Text="Pause">
					<Clicked>
						<Pause Target="videoPlayer" />
					</Clicked>
				</Button>
				<Button Text="Stop">
					<Clicked>
						<Stop Target="videoPlayer" />
					</Clicked>
				</Button>
			</StackPanel>
		</StackPanel>
		```

		## Events

		```ux
		<MediaPlayer
			Url="video.mp4"
			Playing="{OnPlaying}"
			Paused="{OnPaused}"
			LoadingStarted="{OnLoadingStarted}"
			Error="{OnError}"
			PlaybackPositionChanged="{OnPositionChanged}"
			DurationChanged="{OnDurationChanged}" />
		```

		## Triggers

		`MediaPlayer` drives the standard Fuse playback triggers on its own, so no extra
		wiring is needed:

		```ux
		<MediaPlayer Url="video.mp4">
			<WhilePlaying />    <!-- Active while playing -->
			<WhilePaused />     <!-- Active while paused -->
			<WhileLoading />    <!-- Active while loading or buffering -->
			<WhileCompleted />  <!-- Active when playback reached the end -->
			<WhileFailed />     <!-- Active when playback failed, see ErrorMessage -->
		</MediaPlayer>
		```

		## State

		The current state is available through @State and is kept in sync with the triggers
		above. When playback fails, @ErrorMessage contains the reason and the @Error event
		is raised.

		## JavaScript

		The player can be controlled from JavaScript through a `ux:Name`:

		```ux
		<MediaPlayer ux:Name="player" Url="video.mp4" />
		<JavaScript>
			player.play();
			player.seek(30);           // seconds
			player.setVolume(0.5);
			player.setMuted(true);
			player.setPlaybackRate(1.5); // 0.25 - 4.0

			console.log(player.getPosition() + " / " + player.getDuration());
			console.log(player.getState()); // "playing", "paused", ...
		</JavaScript>
		```

		## Background playback

		By default playback pauses when the app is sent to the background and resumes when it
		returns to the foreground. For audio, set `PauseWhenBackgrounded="false"` to keep
		playing (on iOS this also requires the `audio` background mode in the app project).

		## Appearance

		`StretchMode` controls how the video is fitted inside the element (`Uniform` by
		default), `ShowControls` toggles the native playback controls, `KeepScreenOn`
		keeps the display awake while playing, `Muted` mutes the audio without changing
		@Volume, and `StreamQuality` caps the quality of adaptive (HLS/DASH) streams.

		Picture-in-Picture is enabled on iOS; the app must declare the "Audio, AirPlay and
		Picture in Picture" background mode. On Android, background audio and lock-screen
		controls require a `MediaSessionService` in the app, which this component does not
		provide yet.
	*/
	public abstract partial class AVPlayerBase : Panel, IMediaPlayback, IProgress, IPropertyListener
	{
		static Selector _fileName = "File";
		static Selector _urlName = "Url";
		static Selector _autoPlayName = "AutoPlay";
		static Selector _isLoopingName = "IsLooping";
		static Selector _playbackRateName = "PlaybackRate";
		static Selector _volumeName = "Volume";
		static Selector _progressName = "Progress";
		static Selector _positionName = "PlaybackPosition";
		static Selector _durationName = "Duration";
		static Selector _isPlayingName = "IsPlaying";
		static Selector _isBufferingName = "IsBuffering";
		static Selector _bufferProgressName = "BufferProgress";
		static Selector _stateName = "State";
		static Selector _errorMessageName = "ErrorMessage";
		static Selector _pauseWhenBackgroundedName = "PauseWhenBackgrounded";
		static Selector _resumeOnForegroundName = "ResumeOnForeground";
		static Selector _mutedName = "Muted";
		static Selector _stretchModeName = "StretchMode";
		static Selector _showControlsName = "ShowControls";
		static Selector _keepScreenOnName = "KeepScreenOn";
		static Selector _streamQualityName = "StreamQuality";
		double _progress = 0.0;
		double _duration = 0.0;
		double _position = 0.0;
		float _volume = 1.0f;

		MediaPlayerState _state = MediaPlayerState.Idle;
		string _errorMessage = "";
		BusyTask _busyTask;

		// True when playback was paused automatically because the app went to the background
		bool _pausedInBackground;

		// A position requested before the native view was ready to accept seeks
		bool _hasPendingSeek;
		double _pendingSeek;

		// File source
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
			if (IsRootingCompleted)
				PushPropertiesToNativeView();
		}

		void UpdateFile(FileSource file, IPropertyListener origin)
		{
			if (file != _file)
			{
				_file = file;
				ResetPlaybackPosition(origin);
				OnSourceChanged();
				OnPropertyChanged(_fileName, origin);
			}
		}

		// URL source
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
			if (IsRootingCompleted)
				PushPropertiesToNativeView();
		}

		void UpdateUrl(string url, IPropertyListener origin)
		{
			if (url != _url)
			{
				_url = url ?? "";
				ResetPlaybackPosition(origin);
				OnSourceChanged();
				OnPropertyChanged(_urlName, origin);
			}
		}

		// AutoPlay property
		bool _autoPlay = true;
		[UXOriginSetter("SetAutoPlay")]
		/**
			Gets or sets whether the video should start playing automatically when loaded.
		*/
		public bool AutoPlay
		{
			get { return _autoPlay; }
			set { SetAutoPlay(value, this); }
		}

		public void SetAutoPlay(bool autoPlay, IPropertyListener origin)
		{
			UpdateAutoPlay(autoPlay, origin);
			if (IsRootingCompleted)
				PushPropertiesToNativeView();
		}

		void UpdateAutoPlay(bool autoPlay, IPropertyListener origin)
		{
			if (autoPlay != _autoPlay)
			{
				_autoPlay = autoPlay;
				OnPropertyChanged(_autoPlayName, origin);
			}
		}

		// IsLooping property
		bool _isLooping = false;
		[UXOriginSetter("SetIsLooping")]
		/**
			Gets or sets whether the video should loop when it ends.
		*/
		public bool IsLooping
		{
			get { return _isLooping; }
			set { SetIsLooping(value, this); }
		}

		public void SetIsLooping(bool isLooping, IPropertyListener origin)
		{
			UpdateIsLooping(isLooping, origin);
			if (IsRootingCompleted)
				PushPropertiesToNativeView();
		}

		void UpdateIsLooping(bool isLooping, IPropertyListener origin)
		{
			if (isLooping != _isLooping)
			{
				_isLooping = isLooping;
				OnPropertyChanged(_isLoopingName, origin);
			}
		}

		// PlaybackRate property
		float _playbackRate = 1.0f;
		[UXOriginSetter("SetPlaybackRate")]
		/**
			Gets or sets the playback rate multiplier (0.25 to 4.0).
		*/
		public float PlaybackRate
		{
			get { return _playbackRate; }
			set { SetPlaybackRate(value, this); }
		}

		public void SetPlaybackRate(float playbackRate, IPropertyListener origin)
		{
			UpdatePlaybackRate(playbackRate, origin);
			if (IsRootingCompleted)
				PushPropertiesToNativeView();
		}

		void UpdatePlaybackRate(float playbackRate, IPropertyListener origin)
		{
			var clampedRate = Math.Max(0.25f, Math.Min(4.0f, playbackRate));
			if (Math.Abs(clampedRate - _playbackRate) > 0.001f)
			{
				_playbackRate = clampedRate;
				OnPropertyChanged(_playbackRateName, origin);
			}
		}

		// PauseWhenBackgrounded property
		bool _pauseWhenBackgrounded = true;
		[UXOriginSetter("SetPauseWhenBackgrounded")]
		/**
			Gets or sets whether playback pauses when the app is sent to the background.

			Set this to `false` for audio playback that should keep playing while the app
			is in the background. On iOS this also requires the `audio` background mode to
			be enabled in the app project.

			@default true
		*/
		public bool PauseWhenBackgrounded
		{
			get { return _pauseWhenBackgrounded; }
			set { SetPauseWhenBackgrounded(value, this); }
		}

		public void SetPauseWhenBackgrounded(bool value, IPropertyListener origin)
		{
			UpdatePauseWhenBackgrounded(value, origin);
		}

		void UpdatePauseWhenBackgrounded(bool value, IPropertyListener origin)
		{
			if (value != _pauseWhenBackgrounded)
			{
				_pauseWhenBackgrounded = value;
				OnPropertyChanged(_pauseWhenBackgroundedName, origin);
			}
		}

		// ResumeOnForeground property
		bool _resumeOnForeground = true;
		[UXOriginSetter("SetResumeOnForeground")]
		/**
			Gets or sets whether playback resumes when the app returns to the foreground, if
			it was paused by @PauseWhenBackgrounded.

			@default true
		*/
		public bool ResumeOnForeground
		{
			get { return _resumeOnForeground; }
			set { SetResumeOnForeground(value, this); }
		}

		public void SetResumeOnForeground(bool value, IPropertyListener origin)
		{
			UpdateResumeOnForeground(value, origin);
		}

		void UpdateResumeOnForeground(bool value, IPropertyListener origin)
		{
			if (value != _resumeOnForeground)
			{
				_resumeOnForeground = value;
				OnPropertyChanged(_resumeOnForegroundName, origin);
			}
		}

		// Volume property
		[UXOriginSetter("SetVolume")]
		/**
			Gets or sets the volume (0.0 to 1.0).
		*/
		public float Volume
		{
			get { return _volume; }
			set { SetVolume(value, this); }
		}

		public void SetVolume(float volume, IPropertyListener origin)
		{
			UpdateVolume(volume, origin);
			if (IsRootingCompleted)
				PushPropertiesToNativeView();
		}

		void UpdateVolume(float volume, IPropertyListener origin)
		{
			var clampedVolume = Math.Max(0.0f, Math.Min(1.0f, volume));
			if (Math.Abs(clampedVolume - _volume) > 0.001f)
			{
				_volume = clampedVolume;
				OnPropertyChanged(_volumeName, origin);
			}
		}

		// Muted property
		bool _muted = false;
		[UXOriginSetter("SetMuted")]
		/**
			Gets or sets whether the audio is muted, without changing @Volume.

			@default false
		*/
		public bool Muted
		{
			get { return _muted; }
			set { SetMuted(value, this); }
		}

		public void SetMuted(bool muted, IPropertyListener origin)
		{
			UpdateMuted(muted, origin);
			if (IsRootingCompleted)
				PushPropertiesToNativeView();
		}

		void UpdateMuted(bool muted, IPropertyListener origin)
		{
			if (muted != _muted)
			{
				_muted = muted;
				OnPropertyChanged(_mutedName, origin);
			}
		}

		// StretchMode property
		Fuse.Elements.StretchMode _stretchMode = Fuse.Elements.StretchMode.Uniform;
		[UXOriginSetter("SetStretchMode")]
		/**
			Specifies how the video is fitted inside the element.

			`Fill` stretches the video to the element without keeping the aspect ratio,
			`UniformToFill` fills the element and clips what does not fit, and `Uniform` keeps
			the entire video visible.

			@default StretchMode.Uniform
		*/
		public Fuse.Elements.StretchMode StretchMode
		{
			get { return _stretchMode; }
			set { SetStretchMode(value, this); }
		}

		public void SetStretchMode(Fuse.Elements.StretchMode mode, IPropertyListener origin)
		{
			UpdateStretchMode(mode, origin);
			if (IsRootingCompleted)
				PushPropertiesToNativeView();
		}

		void UpdateStretchMode(Fuse.Elements.StretchMode mode, IPropertyListener origin)
		{
			if (mode != _stretchMode)
			{
				_stretchMode = mode;
				OnPropertyChanged(_stretchModeName, origin);
			}
		}

		// StreamQuality property
		MediaStreamQuality _streamQuality = MediaStreamQuality.Auto;
		[UXOriginSetter("SetStreamQuality")]
		/**
			Gets or sets the maximum video quality used for streaming sources.

			This only affects adaptive streams (HLS/DASH); it is a cap, so the player still
			adapts to the available bandwidth below the limit.

			@default MediaStreamQuality.Auto
		*/
		public MediaStreamQuality StreamQuality
		{
			get { return _streamQuality; }
			set { SetStreamQuality(value, this); }
		}

		public void SetStreamQuality(MediaStreamQuality quality, IPropertyListener origin)
		{
			UpdateStreamQuality(quality, origin);
			if (IsRootingCompleted)
				PushPropertiesToNativeView();
		}

		void UpdateStreamQuality(MediaStreamQuality quality, IPropertyListener origin)
		{
			if (quality != _streamQuality)
			{
				_streamQuality = quality;
				OnPropertyChanged(_streamQualityName, origin);
			}
		}

		// ShowControls property
		bool _showControls = true;
		[UXOriginSetter("SetShowControls")]
		/**
			Gets or sets whether the native playback controls are shown.

			Set this to `false` when providing a custom playback UI.

			@default true
		*/
		public bool ShowControls
		{
			get { return _showControls; }
			set { SetShowControls(value, this); }
		}

		public void SetShowControls(bool showControls, IPropertyListener origin)
		{
			UpdateShowControls(showControls, origin);
			if (IsRootingCompleted)
				PushPropertiesToNativeView();
		}

		void UpdateShowControls(bool showControls, IPropertyListener origin)
		{
			if (showControls != _showControls)
			{
				_showControls = showControls;
				OnPropertyChanged(_showControlsName, origin);
			}
		}

		// KeepScreenOn property
		bool _keepScreenOn = false;
		[UXOriginSetter("SetKeepScreenOn")]
		/**
			Gets or sets whether the screen is kept awake while playing.

			@default false
		*/
		public bool KeepScreenOn
		{
			get { return _keepScreenOn; }
			set { SetKeepScreenOn(value, this); }
		}

		public void SetKeepScreenOn(bool keepScreenOn, IPropertyListener origin)
		{
			UpdateKeepScreenOn(keepScreenOn, origin);
			if (IsRootingCompleted)
				PushPropertiesToNativeView();
		}

		void UpdateKeepScreenOn(bool keepScreenOn, IPropertyListener origin)
		{
			if (keepScreenOn != _keepScreenOn)
			{
				_keepScreenOn = keepScreenOn;
				OnPropertyChanged(_keepScreenOnName, origin);
			}
		}

		// Progress property
		[UXOriginSetter("SetProgress")]
		/** Gets or sets the current playback progress (0.0 to 1.0) */
		public double Progress
		{
			get { return _progress; }
			set { SetProgress(value, this); }
		}

		public void SetProgress(double progress, IPropertyListener origin)
		{
			UpdateProgress(progress, origin);

			// Progress can only be translated to a time once the duration is known
			if (_duration > 0)
				RequestSeek();
		}

		void UpdateProgress(double progress, IPropertyListener origin)
		{
			var clampedProgress = Math.Max(0.0, Math.Min(1.0, progress));
			if (Math.Abs(clampedProgress - _progress) > 0.001)
			{
				_progress = clampedProgress;
				OnPropertyChanged(_progressName, origin);
				// Also update position to keep them in sync
				if (_duration > 0)
				{
					var newPosition = _progress * _duration;
					if (Math.Abs(newPosition - _position) > 0.001)
					{
						_position = newPosition;
						OnPropertyChanged(_positionName, origin);
					}
				}
			}
		}

		// Position property
		[UXOriginSetter("SetPlaybackPosition")]
		public double PlaybackPosition
		{
			get { return _position; }
			set { SetPlaybackPosition(value, this); }
		}

		/** Gets or sets the current playback position in seconds */
		public double IMediaPlayback.Position
		{
			get { return PlaybackPosition; }
			set { PlaybackPosition = value; }
		}

		public void SetPlaybackPosition(double position, IPropertyListener origin)
		{
			UpdatePosition(position, origin);
			RequestSeek();
		}

		void UpdatePosition(double position, IPropertyListener origin)
		{
			// The duration is not known until the media has loaded. Don't clamp against it
			// before that, or the position would be stuck at 0 (live streams never report one).
			var clampedPosition = Math.Max(0.0, _duration > 0 ? Math.Min(_duration, position) : position);
			if (Math.Abs(clampedPosition - _position) > 0.001)
			{
				_position = clampedPosition;
				OnPropertyChanged(_positionName, origin);
				// Also update progress to keep them in sync
				var newProgress = _duration > 0 ? _position / _duration : 0.0;
				if (Math.Abs(newProgress - _progress) > 0.001)
				{
					_progress = newProgress;
					OnPropertyChanged(_progressName, origin);
				}
			}
		}

		void ResetPlaybackPosition(IPropertyListener origin)
		{
			// A pending seek was requested explicitly, so it is kept across source changes
			if (_hasPendingSeek)
				return;

			if (Math.Abs(_position) > 0.001)
			{
				_position = 0.0;
				OnPropertyChanged(_positionName, origin);
			}

			if (Math.Abs(_progress) > 0.001)
			{
				_progress = 0.0;
				OnPropertyChanged(_progressName, origin);
			}
		}

		// Duration property (read-only)
		/** Gets the duration of the audio in seconds */
		public double Duration
		{
			get { return _duration; }
		}

		void UpdateDuration(double duration)
		{
			if (Math.Abs(duration - _duration) > 0.001)
			{
				_duration = duration;
				OnPropertyChanged(_durationName);
			}
		}

		/**
			Gets the current playback state.

			The state is kept in sync with the @WhilePlaying, @WhilePaused, @WhileLoading,
			@WhileCompleted and @WhileFailed triggers.
		*/
		public MediaPlayerState State
		{
			get { return _state; }
		}

		/**
			Gets the message of the last playback error, or an empty string if no error
			has occurred.
		*/
		public string ErrorMessage
		{
			get { return _errorMessage; }
		}

		void UpdateState(MediaPlayerState state)
		{
			if (_state == state)
				return;

			_state = state;
			OnPropertyChanged(_stateName);
			UpdateTriggers();
		}

		// Keeps the playback triggers in sync with the current state
		void UpdateTriggers()
		{
			Fuse.Triggers.WhilePlaying.SetState(this, _state == MediaPlayerState.Playing);
			Fuse.Triggers.WhilePaused.SetState(this, _state == MediaPlayerState.Paused || _state == MediaPlayerState.Ready);
			Fuse.Triggers.WhileCompleted.SetState(this, _state == MediaPlayerState.Ended);

			// WhileLoading also covers buffering during playback, like other Fuse media elements
			var activity = BusyTaskActivity.None;
			if (_state == MediaPlayerState.Failed)
				activity = BusyTaskActivity.Failed;
			else if (_state == MediaPlayerState.Loading || IsBuffering)
				activity = BusyTaskActivity.Loading;

			BusyTask.SetBusy(this, ref _busyTask, activity, _errorMessage);
		}

		void ClearError()
		{
			if (string.IsNullOrEmpty(_errorMessage))
				return;

			_errorMessage = "";
			OnPropertyChanged(_errorMessageName);
		}

		// A new source is loaded as soon as the native player has it, report that right away
		void OnSourceChanged()
		{
			ClearError();
			UpdateState(MediaPlayerState.Loading);
		}

		/**
			Gets whether the video is currently playing.
		*/
		public bool IsPlaying
		{
			get
			{
				var avv = AVPlayerView;
				return avv != null ? avv.IsPlaying : false;
			}
		}

		/**
			Gets whether the video is currently buffering.
		*/
		public bool IsBuffering
		{
			get
			{
				var avv = AVPlayerView;
				return avv != null ? avv.IsBuffering : false;
			}
		}

		/**
			Gets the buffer progress (0.0 to 1.0).
		*/
		public float BufferProgress
		{
			get
			{
				var avv = AVPlayerView;
				return avv != null ? avv.BufferProgress : 0.0f;
			}
		}

		float IMediaPlayback.Volume
		{
			get { return Volume; }
			set { Volume = value; }
		}

		// IProgress interface implementation
		double IProgress.Progress
		{
			get { return Progress; }
			set { Progress = value; }
		}

		// IPropertyListener implementation
		void IPropertyListener.OnPropertyChanged(PropertyObject obj, Selector prop)
		{
			// Handle property changes from bound objects if needed
		}

		public event ValueChangedHandler<double> ProgressChanged;

		event ValueChangedHandler<double> IProgress.ProgressChanged
		{
			add { ProgressChanged += value; }
			remove { ProgressChanged -= value; }
		}

		// Playback control methods
		/**
			Starts or resumes video playback.
		*/
		public void Play()
		{
			var avv = AVPlayerView;
			if (avv == null)
				return;

			// Playing after the end has to restart from the beginning
			if (_state == MediaPlayerState.Ended)
				avv.Seek(0);

			avv.Play();
		}

		/**
			Pauses playback and retains current progress.
		*/
		public void Pause()
		{
			var avv = AVPlayerView;
			if (avv != null)
				avv.Pause();
		}

		/**
			Stops playback and sets progress to 0.
		*/
		public void Stop()
		{
			var avv = AVPlayerView;
			if (avv != null)
				avv.Stop();
		}

		/**
			Resumes playing when stopped or paused.
		*/
		public void Resume()
		{
			Play();
		}

		/**
			Seeks to the specified position in the video.
		*/
		public void Seek(double positionSeconds)
		{
			var avv = AVPlayerView;
			if (avv != null)
				avv.Seek(positionSeconds);
		}

		// Events
		/**
			Raised when video starts playing.
		*/
		public event EventHandler Playing;

		/**
			Raised when video is paused.
		*/
		public event EventHandler Paused;

		/**
			Raised when video is stopped.
		*/
		public event EventHandler Stopped;

		/**
			Raised when video reaches the end.
		*/
		public event EventHandler Ended;

		/**
			Raised when the playback position changes.
		*/
		public event EventHandler<TimeChangedEventArgs> PlaybackPositionChanged;

		/**
			Raised when the duration is determined.
		*/
		public event EventHandler<TimeChangedEventArgs> DurationChanged;

		/**
			Raised when an error occurs during playback.
		*/
		public event EventHandler<ErrorEventArgs> Error;

		/**
			Raised when video starts loading.
		*/
		public event EventHandler LoadingStarted;

		/**
			Raised when video finishes loading.
		*/
		public event EventHandler LoadingEnded;

		/**
			Raised when buffer progress changes.
		*/
		public event EventHandler BufferedChanged;

		// Internal helpers
		IAVPlayerView AVPlayerView
		{
			get { return NativeView as IAVPlayerView; }
		}

		// Seeks the native player, or defers the seek until the native view is available
		void RequestSeek()
		{
			if (IsRootingCompleted)
			{
				var avv = AVPlayerView;
				if (avv != null)
				{
					_hasPendingSeek = false;
					avv.Seek(_position);
					return;
				}
			}

			_pendingSeek = _position;
			_hasPendingSeek = true;
		}

		protected override void OnRooted()
		{
			base.OnRooted();
			PushPropertiesToNativeView();

			Fuse.Platform.Lifecycle.EnteringBackground += OnEnteringBackground;
			Fuse.Platform.Lifecycle.EnteringForeground += OnEnteringForeground;
		}

		protected override void OnUnrooted()
		{
			Fuse.Platform.Lifecycle.EnteringBackground -= OnEnteringBackground;
			Fuse.Platform.Lifecycle.EnteringForeground -= OnEnteringForeground;
			_pausedInBackground = false;

			var avv = AVPlayerView;
			if (avv != null)
			{
				avv.Pause();
				// Remember where we were, so the position is restored if this element is rooted again
				_pendingSeek = _position;
				_hasPendingSeek = true;
			}
			base.OnUnrooted();
		}

		void OnEnteringBackground(Fuse.Platform.ApplicationState state)
		{
			if (!_pauseWhenBackgrounded || _state != MediaPlayerState.Playing)
				return;

			var avv = AVPlayerView;
			if (avv == null)
				return;

			_pausedInBackground = true;
			avv.Pause();
		}

		void OnEnteringForeground(Fuse.Platform.ApplicationState state)
		{
			if (!_pausedInBackground)
				return;

			_pausedInBackground = false;

			// Resume, unless the media ended or failed while we were away
			if (!_resumeOnForeground || _state == MediaPlayerState.Ended || _state == MediaPlayerState.Failed)
				return;

			Play();
		}

		// Push all current properties to native view
		protected override void PushPropertiesToNativeView()
		{
			var avv = AVPlayerView;
			if (avv == null)
				return;

			// The native implementations read AutoPlay while loading a source, so the
			// playback options have to be pushed before File/Url.
			avv.AutoPlay = _autoPlay;
			avv.IsLooping = _isLooping;
			avv.Volume = _volume;
			avv.PlaybackRate = _playbackRate;
			avv.Muted = _muted;
			avv.StretchMode = _stretchMode;
			avv.ShowControls = _showControls;
			avv.KeepScreenOn = _keepScreenOn;
			avv.StreamQuality = _streamQuality;

			// Only one source can be active. Pushing both would load the media twice.
			if (_file != null)
				avv.File = _file;
			else if (!string.IsNullOrEmpty(_url))
				avv.Url = _url;

			// The position is not pushed here: the native player owns it, and pushing it
			// would re-seek on every unrelated property change.
			if (_hasPendingSeek)
			{
				_hasPendingSeek = false;
				avv.Seek(_pendingSeek);
			}
		}

		// Event handlers - forward native events to public events
		internal void OnPlaying()
		{
			UpdateState(MediaPlayerState.Playing);
			OnPropertyChanged(_isPlayingName);
			if (Playing != null)
				Playing(this, EventArgs.Empty);
		}

		internal void OnPaused()
		{
			// Reaching the end or failing also stops playback, but must not hide that state
			if (_state != MediaPlayerState.Ended && _state != MediaPlayerState.Failed)
				UpdateState(MediaPlayerState.Paused);

			OnPropertyChanged(_isPlayingName);
			if (Paused != null)
				Paused(this, EventArgs.Empty);
		}

		internal void OnStopped()
		{
			if (_state != MediaPlayerState.Idle && _state != MediaPlayerState.Failed)
				UpdateState(MediaPlayerState.Paused);

			OnPropertyChanged(_isPlayingName);
			if (Stopped != null)
				Stopped(this, EventArgs.Empty);
		}

		internal void OnEnded()
		{
			UpdateState(MediaPlayerState.Ended);
			OnPropertyChanged(_isPlayingName);
			if (Ended != null)
				Ended(this, EventArgs.Empty);
		}

		internal void OnPositionChanged(double positionSeconds)
		{
			UpdatePosition(positionSeconds, this);
			if (PlaybackPositionChanged != null)
				PlaybackPositionChanged(this, new TimeChangedEventArgs(positionSeconds));

			// Also fire progress changed event
			if (ProgressChanged != null)
				ProgressChanged(this, new ValueChangedArgs<double>(Progress));
		}

		internal void OnDurationChanged(double durationSeconds)
		{
			UpdateDuration(durationSeconds);
			if (DurationChanged != null)
				DurationChanged(this, new TimeChangedEventArgs(durationSeconds));
		}

		internal void OnError(string message, Exception exception = null)
		{
			OnError(message, exception, ErrorSeverity.Error);
		}

		internal void OnError(string message, Exception exception, ErrorSeverity severity)
		{
			var errorMessage = message ?? "Unknown media player error";

			// Some native players keep reporting the same error on every status check
			if (_state == MediaPlayerState.Failed && _errorMessage == errorMessage)
				return;

			_errorMessage = errorMessage;
			OnPropertyChanged(_errorMessageName);

			Fuse.Diagnostics.UserError("MediaPlayer: " + _errorMessage, this);

			UpdateState(MediaPlayerState.Failed);
			OnPropertyChanged(_isPlayingName);
			OnPropertyChanged(_isBufferingName);

			if (Error != null)
				Error(this, new ErrorEventArgs(message, exception, severity));
		}

		internal void OnLoadingStarted()
		{
			// Buffering while playing is reported through IsBuffering, the state stays Playing
			if (_state == MediaPlayerState.Idle || _state == MediaPlayerState.Loading ||
				_state == MediaPlayerState.Ready || _state == MediaPlayerState.Ended)
				UpdateState(MediaPlayerState.Loading);

			OnPropertyChanged(_isBufferingName);
			UpdateTriggers();

			if (LoadingStarted != null)
				LoadingStarted(this, EventArgs.Empty);
		}

		internal void OnLoadingEnded()
		{
			if (_state == MediaPlayerState.Loading)
				UpdateState(MediaPlayerState.Ready);

			OnPropertyChanged(_isBufferingName);
			UpdateTriggers();

			if (LoadingEnded != null)
				LoadingEnded(this, EventArgs.Empty);
		}

		internal void OnBufferedChanged()
		{
			OnPropertyChanged(_bufferProgressName);
			if (BufferedChanged != null)
				BufferedChanged(this, EventArgs.Empty);
		}
	}

	/**
		Event argument class for time-related events (duration changes, position updates)
	*/
	public class TimeChangedEventArgs : EventArgs
	{
		/** The time value in seconds */
		public double Time { get; private set; }

		public TimeChangedEventArgs(double time)
		{
			Time = Math.Max(0.0, time); // Ensure non-negative values
		}
	}

	/**
		Event argument class for error events during media playback
	*/
	public class ErrorEventArgs : EventArgs
	{
		/** Human-readable error message */
		public string Message { get; private set; }
		/** Underlying exception, if available */
		public Exception Exception { get; private set; }
		/** Error severity level */
		public ErrorSeverity Severity { get; private set; }

		public ErrorEventArgs(string message, Exception exception = null, ErrorSeverity severity = ErrorSeverity.Error)
		{
			Message = message ?? "Unknown media player error";
			Exception = exception;
			Severity = severity;
		}
	}

	/**
		Defines the severity levels for media player errors
	*/
	public enum ErrorSeverity
	{
		/** Informational message, playback can continue */
		Info,
		/** Warning that might affect playback quality */
		Warning,
		/** Error that prevents normal playback */
		Error,
		/** Fatal error that requires player restart */
		Fatal
	}
}
