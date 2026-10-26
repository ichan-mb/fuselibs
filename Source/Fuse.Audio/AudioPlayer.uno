using Fuse.Triggers;
using Fuse.Scripting;
using Uno.UX;
using Uno;
using Uno.Collections;

namespace Fuse
{
	/** Audio playback state */
	public enum PlaybackState
	{
		Stopped,
		Playing,
		Paused,
		Loading,
		Error
	}

	/** Event arguments for audio playback events */
	public class AudioEventArgs : EventArgs, IScriptEvent
	{
		public string FilePath { get; private set; }
		public PlaybackState State { get; private set; }
		public string ErrorMessage { get; private set; }
		public double Progress { get; private set; }
		public double Duration { get; private set; }

		public AudioEventArgs(PlaybackState state, string filePath = "", string errorMessage = "", double progress = 0.0, double duration = 0.0)
		{
			State = state;
			FilePath = filePath;
			ErrorMessage = errorMessage;
			Progress = progress;
			Duration = duration;
		}

		void IScriptEvent.Serialize(IEventSerializer s)
		{
			Serialize(s);
		}

		virtual void Serialize(IEventSerializer s)
		{
			s.AddString("filePath", FilePath);
			s.AddString("state", StateToString(State));
			s.AddString("errorMessage", ErrorMessage);
			s.AddDouble("progress", Progress);
			s.AddDouble("duration", Duration);
		}

		static string StateToString(PlaybackState state)
		{
			switch (state)
			{
				case PlaybackState.Stopped: return "Stopped";
				case PlaybackState.Playing: return "Playing";
				case PlaybackState.Paused: return "Paused";
				case PlaybackState.Loading: return "Loading";
				default: return "Error";
			}
		}
	}

	/** Event arguments for playback position and progress updates */
	public class AudioProgressEventArgs : EventArgs, IScriptEvent
	{
		/** Position in seconds */
		public double Position { get; private set; }

		/** Progress from 0 to 1 */
		public double Progress { get; private set; }

		/** Total duration in seconds */
		public double Duration { get; private set; }

		public AudioProgressEventArgs(double position, double progress, double duration)
		{
			Position = position;
			Progress = progress;
			Duration = duration;
		}

		void IScriptEvent.Serialize(IEventSerializer s)
		{
			Serialize(s);
		}

		virtual void Serialize(IEventSerializer s)
		{
			s.AddDouble("position", Position);
			s.AddDouble("progress", Progress);
			s.AddDouble("duration", Duration);
		}
	}

	/** Main audio player class for playing audio files with full playback control

		This class provides audio playback functionality for iOS and Android platforms.
		It supports play/pause/stop/reset operations, progress tracking, volume control,
		and implements the IMediaPlayback interface for compatibility with trigger actions.

		Each AudioPlayer owns its own native player, so multiple instances can play at the
		same time. Playback goes through the platform audio session (iOS) / audio focus
		(Android): audio from other apps pauses or ducks this player, incoming calls
		interrupt it, and playback pauses when the output device disappears (for example
		when headphones are unplugged). Interrupted playback resumes automatically when the
		interruption ends, unless focus was lost permanently.

		You'll find this class in the Fuse.Audio package, which have to be referenced from your Uno project file.
		For example:
		```json
			{
				"references": [
					"Fuse",
					"FuseJS",
					"Fuse.Audio"
				]
			}
		```

		## Example
		```xml
			<StackPanel Margin="20">
				<AudioPlayer ux:Name="audioPlayer" File="music.mp3" AutoPlay="false">
					<SampleConfig SampleRate="48000" ChannelCount="2" />
				</AudioPlayer>
				<Button Margin="10" Text="Play">
					<Clicked>
						<Play Target="audioPlayer" />
					</Clicked>
				</Button>
				<Button Margin="10" Text="Pause">
					<Clicked>
						<Pause Target="audioPlayer" />
					</Clicked>
				</Button>
				<Button Margin="10" Text="Stop">
					<Clicked>
						<Stop Target="audioPlayer" />
					</Clicked>
				</Button>
				<Slider ux:Name="progressSlider" Value="{Property audioPlayer.Progress}" />
				<Text Value="Duration: {Property audioPlayer.Duration}" />
			</StackPanel>
		```

		## Events
		- PlaybackStarted: Fired when playback begins
		- PlaybackStopped: Fired when playback stops
		- PlaybackPaused: Fired when playback is paused
		- PlaybackCompleted: Fired when playback reaches the end
		- PlaybackError: Fired when an error occurs
		- ProgressChanged: Fired when playback progress changes
		- PositionChanged: Fired when the position changes (throttled to about 10 times per second)
		- AudioSampleReceived: Fired when audio sample data is available (when SampleConfig is present)

		@include Docs/Guide.md
	*/
	public partial class AudioPlayer : Node, IMediaPlayback, IPropertyListener
	{
		// Static property name selectors for OnPropertyChanged notifications
		static Selector _fileName = "File";
		static Selector _urlName = "Url";
		static Selector _autoPlayName = "AutoPlay";
		static Selector _loopName = "Loop";
		static Selector _currentStateName = "CurrentState";
		static Selector _volumeName = "Volume";
		static Selector _mutedName = "Muted";
		static Selector _balanceName = "Balance";
		static Selector _rateName = "Rate";
		static Selector _progressName = "Progress";
		static Selector _positionName = "Position";
		static Selector _durationName = "Duration";
		static Selector _bufferedName = "Buffered";
		static Selector _isBufferingName = "IsBuffering";

		// Private fields
		PlaybackState _currentState = PlaybackState.Stopped;
		double _progress = 0.0;
		double _duration = 0.0;
		double _position = 0.0;
		float _volume = 1.0f;
		bool _muted;
		float _balance;
		double _rate = 1.0;
		string _url = "";
		FileSource _file;
		bool _autoPlay = false;
		bool _loop = false;

		// Buffering / streaming state
		double _buffered;
		bool _isBuffering;
		double _lastNotifiedPosition = -1.0;

		// Audio sampling fields
		SampleConfig _sampleConfig;
		bool _trackingSamples = false;

		SampleConfig _sampleConfigProperty;

		// Native playback state. Each player owns its own native handle, so multiple
		// AudioPlayer instances can exist at the same time.
		object _handle;
		int _generation;
		bool _resumeWhenLoaded;
		bool _ducked;
		bool _resumeAfterInterruption;
		bool _rewindBeforePlay;
		readonly int _callbackId;

		/** Volume multiplier applied while another app has transient audio focus with ducking rights */
		const float DuckingVolume = 0.3f;

		/** Minimum position change (seconds) between PositionChanged events */
		const double PositionChangedInterval = 0.1;

		// Live players keyed by _callbackId. Native callbacks only carry the id, so this
		// is how a completion/error/sample event finds the instance it belongs to.
		static readonly Dictionary<int, AudioPlayer> _instances = new Dictionary<int, AudioPlayer>();
		static int _nextCallbackId;

		// Ids of the players that are currently playing. Used to keep the shared audio
		// session / audio focus active only while something is actually playing.
		static readonly List<int> _playingIds = new List<int>();

		public AudioPlayer()
		{
			_callbackId = ++_nextCallbackId;
		}

		/** Gets or sets the SampleConfig for audio sampling */
		[UXContent]
		public SampleConfig SampleConfig
		{
			get { return _sampleConfigProperty; }
			set
			{
				if (_sampleConfigProperty != value)
				{
					_sampleConfigProperty = value;
					_sampleConfig = value;
					if (IsRootingCompleted)
					{
						UpdateSamplingFromConfig(value);
					}
				}
			}
		}

		[UXOriginSetter("SetFile")]
		/** Gets or sets the audio file to play */
		public FileSource File
		{
			get { return _file; }
			set { SetFile(value, this); }
		}

		public void SetFile(FileSource file, IPropertyListener origin)
		{
			UpdateFile(file, origin);
			ReloadIfRooted();
		}

		// Stream source
		[UXOriginSetter("SetUrl")]
		/** Gets or sets a URL to stream from

			When `Url` is set, it takes precedence over @File. Supports local `file://` URLs as
			well as `http(s)://` (and whatever else the platform player supports, such as HLS
			on iOS). Use @Buffered and @IsBuffering to follow streaming progress.
		*/
		public string Url
		{
			get { return _url; }
			set { SetUrl(value, this); }
		}

		public void SetUrl(string url, IPropertyListener origin)
		{
			UpdateUrl(url, origin);
			ReloadIfRooted();
		}

		void ReloadIfRooted()
		{
			if (!IsRootingCompleted)
				return;

			if (_currentState != PlaybackState.Stopped)
				Stop();

			LoadAudio();
		}

		void UpdateUrl(string url, IPropertyListener origin)
		{
			url = url ?? "";
			if (url != _url)
			{
				_url = url;
				OnPropertyChanged(_urlName, origin);
			}
		}

		void UpdateFile(FileSource file, IPropertyListener origin)
		{
			if (file != _file)
			{
				_file = file;
				OnPropertyChanged(_fileName, origin);
			}
		}

		[UXOriginSetter("SetAutoPlay")]
		/** Gets or sets whether to automatically start playing when the file is loaded */
		public bool AutoPlay
		{
			get { return _autoPlay; }
			set { SetAutoPlay(value, this); }
		}

		public void SetAutoPlay(bool autoPlay, IPropertyListener origin)
		{
			UpdateAutoPlay(autoPlay, origin);
		}

		void UpdateAutoPlay(bool autoPlay, IPropertyListener origin)
		{
			if (autoPlay != _autoPlay)
			{
				_autoPlay = autoPlay;
				OnPropertyChanged(_autoPlayName, origin);
			}
		}

		[UXOriginSetter("SetLoop")]
		/** Gets or sets whether to loop the audio when it reaches the end */
		public bool Loop
		{
			get { return _loop; }
			set { SetLoop(value, this); }
		}

		public void SetLoop(bool loop, IPropertyListener origin)
		{
			UpdateLoop(loop, origin);
			if (IsRootingCompleted)
				ApplyLoop();
		}

		void UpdateLoop(bool loop, IPropertyListener origin)
		{
			if (loop != _loop)
			{
				_loop = loop;
				OnPropertyChanged(_loopName, origin);
			}
		}

		/** Gets the current playback state */
		public PlaybackState CurrentState
		{
			get { return _currentState; }
		}

		void UpdateCurrentState(PlaybackState state)
		{
			if (state != _currentState)
			{
				_currentState = state;
				OnPropertyChanged(_currentStateName);
			}
		}

		[UXOriginSetter("SetVolume")]
		/** Gets or sets the playback volume (0.0 to 1.0) */
		public float Volume
		{
			get { return _volume; }
			set { SetVolume(value, this); }
		}

		public void SetVolume(float volume, IPropertyListener origin)
		{
			UpdateVolume(volume, origin);
			if (IsRootingCompleted)
				ApplyVolume();
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

		[UXOriginSetter("SetMuted")]
		/** Gets or sets whether the player is muted

			Muting keeps the configured @Volume intact, so unmuting restores the previous volume.
		*/
		public bool Muted
		{
			get { return _muted; }
			set { SetMuted(value, this); }
		}

		public void SetMuted(bool muted, IPropertyListener origin)
		{
			if (muted != _muted)
			{
				_muted = muted;
				OnPropertyChanged(_mutedName, origin);
			}

			if (IsRootingCompleted)
				ApplyVolume();
		}

		[UXOriginSetter("SetBalance")]
		/** Gets or sets the stereo balance (-1.0 is all left, 1.0 is all right)

			Not supported when streaming on iOS (AVPlayer has no pan control).
		*/
		public float Balance
		{
			get { return _balance; }
			set { SetBalance(value, this); }
		}

		public void SetBalance(float balance, IPropertyListener origin)
		{
			var clampedBalance = Math.Max(-1.0f, Math.Min(1.0f, balance));
			if (Math.Abs(clampedBalance - _balance) > 0.001f)
			{
				_balance = clampedBalance;
				OnPropertyChanged(_balanceName, origin);
			}

			if (IsRootingCompleted)
				ApplyVolume();
		}

		[UXOriginSetter("SetRate")]
		/** Gets or sets the playback rate (0.25 to 4.0, 1.0 is normal speed) */
		public double Rate
		{
			get { return _rate; }
			set { SetRate(value, this); }
		}

		public void SetRate(double rate, IPropertyListener origin)
		{
			var clampedRate = Math.Max(0.25, Math.Min(4.0, rate));
			if (Math.Abs(clampedRate - _rate) > 0.001)
			{
				_rate = clampedRate;
				OnPropertyChanged(_rateName, origin);
			}

			// Rate can't be changed on a stopped native player without starting it,
			// so it is also applied when playback starts.
			if (IsRootingCompleted && _currentState == PlaybackState.Playing)
				SetRateImpl();
		}

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
				SetPositionImpl();
			}
		}

		void UpdateProgress(double progress, IPropertyListener origin)
		{
			var clampedProgress = Math.Max(0.0, Math.Min(1.0, progress));
			if (Math.Abs(clampedProgress - _progress) > 0.001)
			{
				_progress = clampedProgress;
				OnPropertyChanged(_progressName, origin);
				OnProgressChanged(); // Fire IProgress event
				// Also update position to keep them in sync
				var newPosition = _progress * _duration;
				if (Math.Abs(newPosition - _position) > 0.001)
				{
					_position = newPosition;
					OnPropertyChanged(_positionName, origin);
				}
			}
		}

		[UXOriginSetter("SetPosition")]
		/** Gets or sets the current playback position in seconds */
		public double Position
		{
			get { return _position; }
			set { SetPosition(value, this); }
		}

		public void SetPosition(double position, IPropertyListener origin)
		{
			UpdatePosition(position, origin);
			if (IsRootingCompleted)
				SetPositionImpl();
		}

		void UpdatePosition(double position, IPropertyListener origin)
		{
			// Streams can have an unknown (or still loading) duration, so only clamp when known
			var clampedPosition = Math.Max(0.0, _duration > 0.0 ? Math.Min(_duration, position) : position);
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
					OnProgressChanged(); // Fire IProgress event
				}
			}
		}

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

		/** Gets how many seconds of the current source are buffered (streams only) */
		public double Buffered
		{
			get { return _buffered; }
		}

		void UpdateBuffered(double buffered)
		{
			if (Math.Abs(buffered - _buffered) > 0.01)
			{
				_buffered = buffered;
				OnPropertyChanged(_bufferedName);
			}
		}

		/** Gets whether playback is currently waiting for more data (streams only) */
		public bool IsBuffering
		{
			get { return _isBuffering; }
		}

		void UpdateIsBuffering(bool isBuffering)
		{
			if (isBuffering != _isBuffering)
			{
				_isBuffering = isBuffering;
				OnPropertyChanged(_isBufferingName);
			}
		}

		/** Event fired when playback starts */
		public event EventHandler<AudioEventArgs> PlaybackStarted;

		/** Event fired when playback stops */
		public event EventHandler<AudioEventArgs> PlaybackStopped;

		/** Event fired when playback is paused */
		public event EventHandler<AudioEventArgs> PlaybackPaused;

		/** Event fired when playback completes naturally */
		public event EventHandler<AudioEventArgs> PlaybackCompleted;

		/** Event fired when an error occurs */
		public event EventHandler<AudioEventArgs> PlaybackError;

		/** Event fired when progress changes */
		public event EventHandler<AudioProgressEventArgs> ProgressChanged;

		/** Event fired when the playback position changes (throttled to ~10 updates per second) */
		public event EventHandler<AudioProgressEventArgs> PositionChanged;

		/** Event fired when audio sample data is available (for visualization/analysis) */
		public event EventHandler<AudioSampleEventArgs> AudioSampleReceived;

		/** Gets whether audio sampling is enabled (true when SampleConfig is present) */
		public bool SamplingEnabled
		{
			get { return _sampleConfig != null; }
		}

		/** Updates sampling configuration from SampleConfig component */
		public void UpdateSamplingFromConfig(SampleConfig config)
		{
			_sampleConfig = config;
			if (IsRootingCompleted)
			{
				StopAudioSampling();
				if (_currentState == PlaybackState.Playing && SamplingEnabled)
					StartAudioSampling();
			}
		}

		/** Loads the audio file */
		void LoadAudio()
		{
			if (_file == null && string.IsNullOrEmpty(_url)) return;

			// Drop any previous native player and invalidate callbacks still in flight
			ReleasePlayer();

			UpdateCurrentState(PlaybackState.Loading);
			LoadAudioImpl();
		}

		extern(!Android && !iOS)
		void LoadAudioImpl()
		{
			OnPlaybackError("Audio playback is not yet implemented for this platform");
		}

		extern(Android || iOS)
		void LoadAudioImpl()
		{
			double duration;
			_handle = Fuse.Audio.AudioPlayerImpl.LoadAudio(_file, _url, _callbackId, _generation, out duration);

			if (_handle == null)
				return; // the platform implementation has already reported the error

			// iOS prepares synchronously and returns the duration here. Android prepares
			// asynchronously and reports through OnNativePrepared instead.
			if (duration >= 0.0)
				OnPrepared(_generation, duration);
		}

		/** Starts or resumes audio playback */
		public void Resume()
		{
			if (_currentState == PlaybackState.Playing)
				return;

			if (_file == null && string.IsNullOrEmpty(_url))
			{
				OnPlaybackError("No audio file specified");
				return;
			}

			if (_currentState == PlaybackState.Loading)
			{
				// Start as soon as the native player reports it is ready
				_resumeWhenLoaded = true;
				return;
			}

			if (_handle == null)
				return;

			if (_rewindBeforePlay)
			{
				// The player finished; start the next play from the beginning again
				_rewindBeforePlay = false;
				_position = 0.0;
				UpdateProgress(0.0, this);
				SetPositionImpl();
			}

			ResumeImpl();
		}

		extern(!Android && !iOS)
		void ResumeImpl()
		{
			// No-op for unsupported platforms
		}

		extern(Android || iOS)
		void ResumeImpl()
		{
			// Keep the shared audio session / audio focus alive while anything is playing
			var wasIdle = _playingIds.Count == 0;
			if (wasIdle)
				ActivateAudioSessionImpl();

			if (Fuse.Audio.AudioPlayerImpl.Resume(_handle, _rate))
			{
				AddPlaying();
				UpdateCurrentState(PlaybackState.Playing);
				OnPlaybackStarted();
				StartProgressTracking();
				if (SamplingEnabled)
					StartAudioSampling();
			}
			else
			{
				if (wasIdle)
					DeactivateAudioSessionImpl();
				OnPlaybackError("Failed to start playback");
			}
		}

		/** Pauses audio playback */
		public void Pause()
		{
			if (_currentState != PlaybackState.Playing)
				return;

			if (PauseImpl())
			{
				UpdateCurrentState(PlaybackState.Paused);
				RemovePlaying();
				OnPlaybackPaused();
				StopProgressTracking();
				StopAudioSampling();
			}
			else
			{
				OnPlaybackError("Failed to pause playback");
			}
		}

		extern(!Android && !iOS)
		bool PauseImpl()
		{
			return false;
		}

		extern(Android || iOS)
		bool PauseImpl()
		{
			if (_handle == null)
				return false;
			return Fuse.Audio.AudioPlayerImpl.Pause(_handle);
		}

		/** Stops audio playback and resets position to beginning */
		public void Stop()
		{
			if (_currentState == PlaybackState.Stopped)
				return;

			StopImpl();
		}

		extern(!Android && !iOS)
		void StopImpl()
		{
			// No-op for unsupported platforms
		}

		extern(Android || iOS)
		void StopImpl()
		{
			if (_handle != null)
				Fuse.Audio.AudioPlayerImpl.Stop(_handle);

			UpdateCurrentState(PlaybackState.Stopped);
			RemovePlaying();
			UpdateProgress(0.0, this);
			UpdatePosition(0.0, this);
			OnPlaybackStopped();
			StopProgressTracking();
			StopAudioSampling();
			_resumeWhenLoaded = false;
			_rewindBeforePlay = false;
			_lastNotifiedPosition = -1.0;
		}

		/** Resets playback to the beginning */
		public void Reset()
		{
			SetProgress(0.0, this);
		}

		/** Releases the native player and invalidates any callbacks still in flight */
		void ReleasePlayer()
		{
			_generation++;

			if (_handle == null)
				return;

			ReleaseImpl();
			_handle = null;
		}

		extern(!Android && !iOS)
		void ReleaseImpl()
		{
			// No-op for unsupported platforms
		}

		extern(Android || iOS)
		void ReleaseImpl()
		{
			Fuse.Audio.AudioPlayerImpl.Release(_handle, _callbackId);
		}

		void ApplyVolume()
		{
			if (_handle == null)
				return;

			var effective = _ducked ? _volume * DuckingVolume : _volume;
			if (_muted)
				effective = 0.0f;

			SetVolumeImpl(effective, _balance);
		}

		void ApplyLoop()
		{
			if (_handle == null)
				return;

			SetLoopImpl(_loop);
		}

		extern(!Android && !iOS)
		void SetVolumeImpl(float volume, float balance)
		{
			// No-op for unsupported platforms
		}

		extern(Android || iOS)
		void SetVolumeImpl(float volume, float balance)
		{
			if (_handle != null)
				Fuse.Audio.AudioPlayerImpl.SetVolume(_handle, volume, balance);
		}

		extern(!Android && !iOS)
		void SetLoopImpl(bool loop)
		{
			// No-op for unsupported platforms
		}

		extern(Android || iOS)
		void SetLoopImpl(bool loop)
		{
			if (_handle != null)
				Fuse.Audio.AudioPlayerImpl.SetLoop(_handle, loop);
		}

		extern(!Android && !iOS)
		void SetRateImpl()
		{
			// No-op for unsupported platforms
		}

		extern(Android || iOS)
		void SetRateImpl()
		{
			if (_handle != null)
				Fuse.Audio.AudioPlayerImpl.SetRate(_handle, _rate);
		}

		extern(!Android && !iOS)
		void SetPositionImpl()
		{
			// No-op for unsupported platforms
		}

		extern(Android || iOS)
		void SetPositionImpl()
		{
			if (_handle != null)
				Fuse.Audio.AudioPlayerImpl.SetPosition(_handle, _position);
		}

		void SetDucked(bool ducked)
		{
			if (_ducked == ducked)
				return;

			_ducked = ducked;
			ApplyVolume();
		}

		// Progress tracking
		bool _trackingProgress = false;

		void StartProgressTracking()
		{
			if (_trackingProgress)
				return;

			_trackingProgress = true;
			UpdateManager.AddAction(TickProgress);
		}

		void StopProgressTracking()
		{
			if (!_trackingProgress)
				return;

			_trackingProgress = false;
			UpdateManager.RemoveAction(TickProgress);
		}

		void TickProgress()
		{
			if (_currentState != PlaybackState.Playing)
				return;

			UpdateProgressImpl();
		}

		extern(!Android && !iOS)
		void UpdateProgressImpl()
		{
			// No-op for unsupported platforms
		}

		extern(Android || iOS)
		void UpdateProgressImpl()
		{
			if (_handle == null)
				return;

			var currentPosition = Fuse.Audio.AudioPlayerImpl.GetCurrentPosition(_handle);
			if (currentPosition >= 0)
				UpdatePosition(currentPosition, this);

			// Buffering state is polled every frame: a stalled stream keeps the same
			// position, so it must not be behind the position-change gate below.
			var buffered = Fuse.Audio.AudioPlayerImpl.GetBuffered(_handle, _callbackId);
			if (buffered >= 0)
				UpdateBuffered(buffered);

			UpdateIsBuffering(Fuse.Audio.AudioPlayerImpl.IsBuffering(_handle, _callbackId));

			var error = Fuse.Audio.AudioPlayerImpl.GetError(_handle);
			if (!string.IsNullOrEmpty(error))
			{
				OnPlaybackError(error);
				return;
			}

			if (Math.Abs(_position - _lastNotifiedPosition) < PositionChangedInterval)
				return;

			_lastNotifiedPosition = _position;
			OnPositionChanged();

			var duration = Fuse.Audio.AudioPlayerImpl.GetDuration(_handle);
			if (duration > 0)
				UpdateDuration(duration);
		}

		// Event handlers
		string SourcePath()
		{
			if (_file != null)
				return _file.ToString();

			return _url ?? "";
		}

		void OnPlaybackStarted()
		{
			if (PlaybackStarted != null)
				PlaybackStarted(this, new AudioEventArgs(PlaybackState.Playing, SourcePath(), "", _progress, _duration));
		}

		void OnPlaybackStopped()
		{
			if (PlaybackStopped != null)
				PlaybackStopped(this, new AudioEventArgs(PlaybackState.Stopped, SourcePath(), "", _progress, _duration));
		}

		void OnPlaybackPaused()
		{
			if (PlaybackPaused != null)
				PlaybackPaused(this, new AudioEventArgs(PlaybackState.Paused, SourcePath(), "", _progress, _duration));
		}

		void OnPlaybackCompleted()
		{
			if (PlaybackCompleted != null)
				PlaybackCompleted(this, new AudioEventArgs(PlaybackState.Stopped, SourcePath(), "", _progress, _duration));
		}

		void OnPlaybackError(string errorMessage)
		{
			_resumeWhenLoaded = false;
			UpdateCurrentState(PlaybackState.Error);
			StopProgressTracking();
			StopAudioSampling();
			if (PlaybackError != null)
				PlaybackError(this, new AudioEventArgs(PlaybackState.Error, SourcePath(), errorMessage, _progress, _duration));
		}

		void OnProgressChanged()
		{
			if (ProgressChanged != null)
				ProgressChanged(this, new AudioProgressEventArgs(_position, _progress, _duration));
		}

		void OnPositionChanged()
		{
			if (PositionChanged != null)
				PositionChanged(this, new AudioProgressEventArgs(_position, _progress, _duration));
		}

		void OnAudioSampleReceived(AudioSample sample)
		{
			if (AudioSampleReceived != null)
				AudioSampleReceived(this, new AudioSampleEventArgs(sample));
		}

		// Audio sampling methods
		void StartAudioSampling()
		{
			if (_trackingSamples || !SamplingEnabled || _currentState != PlaybackState.Playing)
				return;

			_trackingSamples = true;
			StartAudioSamplingImpl();
		}

		void StopAudioSampling()
		{
			if (!_trackingSamples)
				return;

			_trackingSamples = false;
			StopAudioSamplingImpl();
		}

		extern(!Android && !iOS)
		void StartAudioSamplingImpl()
		{
			// No-op for unsupported platforms
		}

		extern(Android || iOS)
		void StartAudioSamplingImpl()
		{
			if (_sampleConfig == null || _handle == null)
				return;

			if defined(Android)
			{
				if (_sampleConfig.Format == AudioSampleFormat.Float32)
					Fuse.Diagnostics.UserWarning("Float32 audio sampling is not supported by the Android visualizer; Int16 is used instead", this);
			}

			Fuse.Audio.AudioPlayerImpl.StartAudioSampling(
				_handle,
				_callbackId,
				_sampleConfig.GetSampleRate(),
				_sampleConfig.GetChannelCount(),
				_sampleConfig.GetAudioSampleFormat(),
				_sampleConfig.GetBufferSize(),
				_sampleConfig.GetUpdateIntervalMs()
			);
		}

		extern(!Android && !iOS)
		void StopAudioSamplingImpl()
		{
			// No-op for unsupported platforms
		}

		extern(Android || iOS)
		void StopAudioSamplingImpl()
		{
			if (_handle != null)
				Fuse.Audio.AudioPlayerImpl.StopAudioSampling(_handle, _callbackId);
		}

		// ---- Native callbacks ----
		// These are called by the platform implementations. Every callback carries the
		// generation it was created for, so events from a released/reloaded player are ignored.

		internal static void OnNativePrepared(int callbackId, int generation, double duration)
		{
			AudioPlayer player;
			if (_instances.TryGetValue(callbackId, out player))
				player.OnPrepared(generation, duration);
		}

		internal static void OnNativeCompleted(int callbackId, int generation)
		{
			AudioPlayer player;
			if (_instances.TryGetValue(callbackId, out player))
				player.OnCompleted(generation);
		}

		internal static void OnNativeError(int callbackId, int generation, string message)
		{
			AudioPlayer player;
			if (_instances.TryGetValue(callbackId, out player))
				player.OnError(generation, message);
			else
				Fuse.Diagnostics.UserError(message, null);
		}

		internal static void OnNativeAudioSample(int callbackId, int sampleRate, int channelCount, int format,
		                                         int sampleCount, byte[] data, double timestamp)
		{
			AudioPlayer player;
			if (!_instances.TryGetValue(callbackId, out player))
				return;

			player.OnAudioSampleReceived(new AudioSample(sampleRate, channelCount, (AudioSampleFormat)format, sampleCount, data, timestamp));
		}

		internal static void OnNativeAudioFocusChanged(int change)
		{
			switch ((Fuse.Audio.AudioFocusChange)change)
			{
				case Fuse.Audio.AudioFocusChange.Lost:
					PauseAll(false);
					break;
				case Fuse.Audio.AudioFocusChange.LostTransient:
					PauseAll(true);
					break;
				case Fuse.Audio.AudioFocusChange.CanDuck:
					DuckAll(true);
					break;
				case Fuse.Audio.AudioFocusChange.Gained:
					DuckAll(false);
					ResumeInterrupted();
					break;
			}
		}

		internal static void OnNativeInterruptionBegan()
		{
			PauseAll(true);
		}

		internal static void OnNativeInterruptionEnded(bool shouldResume)
		{
			if (shouldResume)
				ResumeInterrupted();
		}

		internal static void OnNativeRouteChanged()
		{
			// Headphones were unplugged or a Bluetooth output disconnected.
			PauseAll(false);
		}

		void OnPrepared(int generation, double duration)
		{
			if (generation != _generation)
				return;

			UpdateDuration(duration);
			UpdateProgress(0.0, this);
			UpdatePosition(0.0, this);
			UpdateCurrentState(PlaybackState.Stopped);
			_rewindBeforePlay = false;
			_lastNotifiedPosition = -1.0;

			// Local sources are fully available once prepared. Streams report their own
			// buffered range through the polling path instead.
			if (duration > 0.0 && string.IsNullOrEmpty(_url))
				UpdateBuffered(duration);

			UpdateIsBuffering(false);
			ApplyVolume();
			ApplyLoop();

			if (_autoPlay || _resumeWhenLoaded)
			{
				_resumeWhenLoaded = false;
				Resume();
			}
		}

		void OnCompleted(int generation)
		{
			if (generation != _generation)
				return;

			RemovePlaying();
			StopProgressTracking();
			StopAudioSampling();

			if (_loop)
			{
				// Restart from the beginning. Native gapless looping comes with the
				// platform loop support, which is still handled here for now.
				UpdateCurrentState(PlaybackState.Stopped);
				Reset();
				Resume();
				return;
			}

			_rewindBeforePlay = true;
			UpdateCurrentState(PlaybackState.Stopped);
			OnPlaybackCompleted();
		}

		void OnError(int generation, string message)
		{
			if (generation != _generation)
				return;

			RemovePlaying();
			OnPlaybackError(message);
		}

		void AddPlaying()
		{
			if (!_playingIds.Contains(_callbackId))
				_playingIds.Add(_callbackId);
		}

		void RemovePlaying()
		{
			if (_playingIds.Remove(_callbackId) && _playingIds.Count == 0)
				DeactivateAudioSessionImpl();
		}

		static void PauseAll(bool resumeLater)
		{
			foreach (var id in Ids())
			{
				AudioPlayer player;
				if (!_instances.TryGetValue(id, out player))
					continue;
				if (player._currentState != PlaybackState.Playing)
					continue;

				player._resumeAfterInterruption = resumeLater;
				player.Pause();
			}
		}

		static void ResumeInterrupted()
		{
			foreach (var id in Ids())
			{
				AudioPlayer player;
				if (!_instances.TryGetValue(id, out player))
					continue;
				if (!player._resumeAfterInterruption)
					continue;

				player._resumeAfterInterruption = false;
				player.Resume();
			}
		}

		static void DuckAll(bool duck)
		{
			foreach (var id in Ids())
			{
				AudioPlayer player;
				if (_instances.TryGetValue(id, out player))
					player.SetDucked(duck);
			}
		}

		static List<int> Ids()
		{
			var ids = new List<int>();
			foreach (var entry in _instances)
				ids.Add(entry.Key);
			return ids;
		}

		extern(!Android && !iOS)
		void ActivateAudioSessionImpl()
		{
			// No-op for unsupported platforms
		}

		extern(Android || iOS)
		void ActivateAudioSessionImpl()
		{
			Fuse.Audio.AudioPlayerImpl.ActivateAudioSession();
		}

		extern(!Android && !iOS)
		void DeactivateAudioSessionImpl()
		{
			// No-op for unsupported platforms
		}

		extern(Android || iOS)
		void DeactivateAudioSessionImpl()
		{
			Fuse.Audio.AudioPlayerImpl.DeactivateAudioSession();
		}

		// IPropertyListener implementation
		void IPropertyListener.OnPropertyChanged(PropertyObject obj, Selector prop)
		{
			// Handle property changes from bound objects if needed
		}

		protected override void OnRooted()
		{
			base.OnRooted();

			_instances[_callbackId] = this;

			if ((_file != null || !string.IsNullOrEmpty(_url)) && _currentState == PlaybackState.Stopped)
				LoadAudio();

			// Apply SampleConfig if present
			if (_sampleConfigProperty != null)
				UpdateSamplingFromConfig(_sampleConfigProperty);
		}

		protected override void OnUnrooted()
		{
			if (_currentState != PlaybackState.Stopped)
				Stop();

			StopProgressTracking();
			StopAudioSampling();
			RemovePlaying();

			// Release the native player explicitly: Stop() is a no-op when the player is
			// already stopped, and the native resources must not outlive the node.
			ReleasePlayer();

			_instances.Remove(_callbackId);

			base.OnUnrooted();
		}
	}
}
