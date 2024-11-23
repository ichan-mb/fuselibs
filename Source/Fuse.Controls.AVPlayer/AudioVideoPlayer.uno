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

		## JavaScript

		```javascript
		// Property access works
		console.log("Duration: " + videoPlayer.duration + "s");
		console.log("Position: " + videoPlayer.position + "s");

		// Property setting works
		videoPlayer.volume = 0.8;
		videoPlayer.position = 30.0; // Seek to 30 seconds
		videoPlayer.autoPlay = false;

		// Event handlers
		function OnPlaying() {
			console.log("Video started playing");
		}

		function OnPositionChanged(args) {
			console.log("Position: " + args.Time + "s");
		}
		```
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
		double _progress = 0.0;
		double _duration = 0.0;
		double _position = 0.0;
		float _volume = 1.0f;

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
			if (IsRootingCompleted)
			{
				_position = _progress * _duration;
				PushPropertiesToNativeView();
			}
		}

		void UpdateProgress(double progress, IPropertyListener origin)
		{
			var clampedProgress = Math.Max(0.0, Math.Min(1.0, progress));
			if (Math.Abs(clampedProgress - _progress) > 0.001)
			{
				_progress = clampedProgress;
				OnPropertyChanged(_progressName, origin);
				// Also update position to keep them in sync
				var newPosition = _progress * _duration;
				if (Math.Abs(newPosition - _position) > 0.001)
				{
					_position = newPosition;
					OnPropertyChanged(_positionName, origin);
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
			if (IsRootingCompleted)
			{
				_position = position;
				PushPropertiesToNativeView();
			}
		}

		void UpdatePosition(double position, IPropertyListener origin)
		{
			var clampedPosition = Math.Max(0.0, Math.Min(_duration, position));
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
			if (avv != null)
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
			get { return (IAVPlayerView)NativeView; }
		}

		protected override void OnRooted()
		{
			base.OnRooted();
			PushPropertiesToNativeView();
		}

		protected override void OnUnrooted()
		{
			base.OnUnrooted();
		}

		// Push all current properties to native view
		protected override void PushPropertiesToNativeView()
		{
			var avv = AVPlayerView;
			if (avv != null)
			{
				if (_file != null)
					avv.File = _file;
				if (!string.IsNullOrEmpty(_url))
					avv.Url = _url;

				avv.AutoPlay = _autoPlay;
				avv.IsLooping = _isLooping;
				avv.Volume = _volume;
				avv.Position = _position;
				avv.Progress = _progress;
				avv.PlaybackRate = _playbackRate;
			}
		}

		// Event handlers - forward native events to public events
		internal void OnPlaying()
		{
			if (Playing != null)
				Playing(this, EventArgs.Empty);
		}

		internal void OnPaused()
		{
			if (Paused != null)
				Paused(this, EventArgs.Empty);
		}

		internal void OnStopped()
		{
			if (Stopped != null)
				Stopped(this, EventArgs.Empty);
		}

		internal void OnEnded()
		{
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
			// Log error for debugging
			Fuse.Diagnostics.InternalError("MediaPlayer Error: " + message, this);

			if (Error != null)
				Error(this, new ErrorEventArgs(message, exception));
		}

		internal void OnError(string message, Exception exception, ErrorSeverity severity)
		{
			// Log error for debugging with severity
			Fuse.Diagnostics.InternalError("MediaPlayer Error (" + severity + "): " + message, this);

			if (Error != null)
				Error(this, new ErrorEventArgs(message, exception, severity));
		}

		internal void OnLoadingStarted()
		{
			if (LoadingStarted != null)
				LoadingStarted(this, EventArgs.Empty);
		}

		internal void OnLoadingEnded()
		{
			if (LoadingEnded != null)
				LoadingEnded(this, EventArgs.Empty);
		}

		internal void OnBufferedChanged()
		{
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
