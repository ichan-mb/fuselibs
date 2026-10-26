using Fuse.Triggers.Actions;
using Fuse.Scripting;
using Uno.UX;
using Uno;

namespace Fuse
{
	/** Audio recording formats supported by the recorder */
	public enum AudioFormat
	{
		WAV,
		AAC,
		MP3,
		M4A
	}

	/** Audio recording quality presets */
	public enum AudioQuality
	{
		Low,
		Medium,
		High,
		Custom
	}

	/** Audio recording state */
	public enum RecordingState
	{
		Stopped,
		Recording,
		Paused
	}

	/** Audio input source used for recording */
	public enum AudioSource
	{
		/** Platform default (the built-in microphone) */
		Default = 0,
		/** The built-in microphone */
		Microphone = 1,
		/** Tuned for speech recognition */
		VoiceRecognition = 2,
		/** Tuned for voice communication (calls), usually with echo cancellation */
		VoiceCommunication = 3,
		/** The camera-mounted microphone */
		Camcorder = 4,
		/** Unprocessed input, without the platform's usual filtering (Android API 24+) */
		Unprocessed = 5
	}

	/** Configuration class for audio recording settings */
	public class RecordingConfig
	{
		public int SampleRate { get; set; }
		public int BitRate { get; set; }
		public int Channels { get; set; } // Mono by default
		public AudioFormat Format { get; set; }
		public AudioQuality Quality { get; set; }
		public string OutputPath { get; set; }
		public AudioSource Source { get; set; }

		/** Maximum recording length in seconds (0 = unlimited) */
		public double MaxDuration { get; set; }

		/** Maximum output file size in bytes (0 = unlimited) */
		public int MaxFileSize { get; set; }

		public RecordingConfig()
		{
			SampleRate = 44100;
			BitRate = 128000;
			Channels = 1;
			Format = AudioFormat.M4A;
			Quality = AudioQuality.Medium;
			OutputPath = "";
			Source = AudioSource.Default;
			MaxDuration = 0;
			MaxFileSize = 0;
		}

		public RecordingConfig(AudioQuality quality)
		{
			Quality = quality;
			switch (quality)
			{
				case AudioQuality.Low:
					SampleRate = 22050;
					BitRate = 64000;
					Channels = 1;
					break;
				case AudioQuality.Medium:
					SampleRate = 44100;
					BitRate = 128000;
					Channels = 1;
					break;
				case AudioQuality.High:
					SampleRate = 48000;
					BitRate = 256000;
					Channels = 2;
					break;
			}
		}
	}

	/** Event arguments for recording events */
	public class RecordingEventArgs : EventArgs, IScriptEvent
	{
		public string FilePath { get; private set; }
		public RecordingState State { get; private set; }
		public string ErrorMessage { get; private set; }

		public RecordingEventArgs(RecordingState state, string filePath = "", string errorMessage = "")
		{
			State = state;
			FilePath = filePath;
			ErrorMessage = errorMessage;
		}

		void IScriptEvent.Serialize(IEventSerializer s)
		{
			Serialize(s);
		}

		virtual void Serialize(IEventSerializer s)
		{
			s.AddString("filePath", FilePath);
			s.AddString("state", State == RecordingState.Stopped ? "Stopped" : State == RecordingState.Recording ? "Recording" : "Paused");
			s.AddString("errorMessage", ErrorMessage);
		}
	}

	/** Event arguments for recording permission changes */
	public class RecordingPermissionEventArgs : EventArgs, IScriptEvent
	{
		public bool Granted { get; private set; }

		public RecordingPermissionEventArgs(bool granted)
		{
			Granted = granted;
		}

		void IScriptEvent.Serialize(IEventSerializer s)
		{
			Serialize(s);
		}

		virtual void Serialize(IEventSerializer s)
		{
			s.AddBool("granted", Granted);
		}
	}

	/** Event arguments for recording level updates */
	public class RecordingLevelEventArgs : EventArgs, IScriptEvent
	{
		/** Peak amplitude of the last metering interval, normalized to 0..1 */
		public float Level { get; private set; }

		/** Recording position in seconds when this level was measured */
		public double Position { get; private set; }

		public RecordingLevelEventArgs(float level, double position)
		{
			Level = level;
			Position = position;
		}

		void IScriptEvent.Serialize(IEventSerializer s)
		{
			Serialize(s);
		}

		virtual void Serialize(IEventSerializer s)
		{
			s.AddDouble("level", (double)Level);
			s.AddDouble("position", Position);
		}
	}

	/** Main audio recorder class for recording audio with configurable settings

		This class provides audio recording functionality for iOS and Android platforms.
		It supports various audio formats, quality settings, and configuration options.

		See the @AudioPlayer guide (`Docs/Guide.md`) for a full walkthrough of playback and
		recording, including permissions, metering and limits.

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
				<AudioRecorder ux:Name="recorder">
					<SampleConfig SampleRate="44100" UpdateIntervalMs="25" />
				</AudioRecorder>
				<Button Margin="10" Text="Start Recording">
					<Clicked>
						<StartRecording Target="recorder" />
					</Clicked>
				</Button>
				<Button Margin="10" Text="Stop Recording">
					<Clicked>
						<StopRecording Target="recorder" />
					</Clicked>
				</Button>
			</StackPanel>
		```

		## Events
		- RecordingStarted: Fired when recording begins
		- RecordingStopped: Fired when recording stops
		- RecordingPaused: Fired when recording is paused
		- RecordingResumed: Fired when recording resumes
		- RecordingCompleted: Fired when a recording stopped because a limit was reached
		- RecordingError: Fired when an error occurs
		- LevelChanged: Fired periodically while recording, with the input level and position
		- PermissionChanged: Fired when a microphone permission request completes
		- AudioSampleReceived: Fired when audio sample data is available (when SampleConfig is present)
	*/
	public partial class AudioRecorder : Node
	{
		static Selector _recordingDurationName = "RecordingDuration";
		static Selector _recordingLevelName = "RecordingLevel";

		RecordingConfig _config;
		RecordingState _currentState = RecordingState.Stopped;

		// Audio sampling fields
		SampleConfig _sampleConfig;
		bool _trackingSamples = false;

		SampleConfig _sampleConfigProperty;

		// Metering / timing state
		bool _metering;
		bool _stopping;
		float _recordingLevel;
		double _recordingDuration;
		double _recordingStartTime;
		double _recordingOffset;
		double _lastLevelTime = -1.0;

		/** How often LevelChanged fires while recording (seconds) */
		const double MeteringInterval = 0.05;

		// The recorder that is currently recording. Recording is exclusive, so this is
		// how native limit/error callbacks find the recorder they belong to.
		static AudioRecorder _recordingInstance;

		public AudioRecorder()
		{
			_config = new RecordingConfig();
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

		/** Gets or sets the sample rate for recording (default: 44100 Hz) */
		public int SampleRate
		{
			get { return _config.SampleRate; }
			set { _config.SampleRate = value; }
		}

		/** Gets or sets the bit rate for recording (default: 128000 bps) */
		public int BitRate
		{
			get { return _config.BitRate; }
			set { _config.BitRate = value; }
		}

		/** Gets or sets the number of channels (1 = mono, 2 = stereo, default: 1) */
		public int Channels
		{
			get { return _config.Channels; }
			set { _config.Channels = Math.Max(1, Math.Min(2, value)); }
		}

		/** Gets or sets the audio format (default: M4A) */
		public AudioFormat Format
		{
			get { return _config.Format; }
			set { _config.Format = value; }
		}

		/** Gets or sets the audio quality preset (default: Medium) */
		public AudioQuality Quality
		{
			get { return _config.Quality; }
			set
			{
				if (value == AudioQuality.Custom)
				{
					_config.Quality = value;
					return;
				}

				// Apply the preset without losing the source/limit/output settings
				var config = new RecordingConfig(value);
				config.Format = _config.Format;
				config.OutputPath = _config.OutputPath;
				config.Source = _config.Source;
				config.MaxDuration = _config.MaxDuration;
				config.MaxFileSize = _config.MaxFileSize;
				_config = config;
			}
		}

		/** Gets or sets the output file path (if empty, a default path will be used) */
		public string OutputPath
		{
			get { return _config.OutputPath; }
			set { _config.OutputPath = value; }
		}

		/** Gets or sets the audio input source (default: Default) */
		public AudioSource Source
		{
			get { return _config.Source; }
			set { _config.Source = value; }
		}

		/** Gets or sets the maximum recording length in seconds (0 = unlimited, applied on start) */
		public double MaxDuration
		{
			get { return _config.MaxDuration; }
			set { _config.MaxDuration = Math.Max(0.0, value); }
		}

		/** Gets or sets the maximum output file size in bytes (0 = unlimited, applied on start) */
		public int MaxFileSize
		{
			get { return _config.MaxFileSize; }
			set { _config.MaxFileSize = Math.Max(0, value); }
		}

		/** Gets how long the current (or last) recording has been running, in seconds */
		public double RecordingDuration
		{
			get { return _recordingDuration; }
		}

		/** Gets the most recent input level, normalized to 0..1 */
		public float RecordingLevel
		{
			get { return _recordingLevel; }
		}

		/** Gets the current recording state */
		public RecordingState CurrentState
		{
			get { return _currentState; }
		}

		/** Event fired when recording starts */
		public event EventHandler<RecordingEventArgs> RecordingStarted;

		/** Event fired when recording stops */
		public event EventHandler<RecordingEventArgs> RecordingStopped;

		/** Event fired when recording is paused */
		public event EventHandler<RecordingEventArgs> RecordingPaused;

		/** Event fired when recording resumes */
		public event EventHandler<RecordingEventArgs> RecordingResumed;

		/** Event fired when an error occurs */
		public event EventHandler<RecordingEventArgs> RecordingError;

		/** Event fired when the recording stopped because MaxDuration or MaxFileSize was reached */
		public event EventHandler<RecordingEventArgs> RecordingCompleted;

		/** Event fired periodically while recording, with the input level and position */
		public event EventHandler<RecordingLevelEventArgs> LevelChanged;

		/** Event fired when a recording permission request completes */
		public event EventHandler<RecordingPermissionEventArgs> PermissionChanged;

		/** Event fired when audio sample data is available during recording (for visualization/analysis) */
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
				if (_currentState == RecordingState.Recording && SamplingEnabled)
					StartAudioSampling();
			}
		}

		/** Starts audio recording */
		public void StartRecording()
		{
			if (_currentState != RecordingState.Stopped)
			{
				OnRecordingError("Cannot start recording: already recording or paused");
				return;
			}

			if (!CanStartRecording())
			{
				OnRecordingError("Microphone permission has not been granted");
				return;
			}

			StartRecordingImpl();
		}

		extern(!Android && !iOS)
		bool CanStartRecording()
		{
			// Let the platform implementation report that recording is unsupported
			return true;
		}

		extern(Android || iOS)
		bool CanStartRecording()
		{
			return HasRecordingPermission();
		}

		extern(!Android && !iOS)
		void StartRecordingImpl()
		{
			OnRecordingError("Audio recording is not yet implemented for this platform");
		}

		extern(Android || iOS)
		void StartRecordingImpl()
		{
			if (!Fuse.Audio.AudioRecorderImpl.StartRecording(_config))
			{
				OnRecordingError("Failed to start recording");
				return;
			}

			BeginRecording();
			OnRecordingStarted(_config.OutputPath);
		}

		/** Stops audio recording */
		public void StopRecording()
		{
			if (_currentState == RecordingState.Stopped)
			{
				OnRecordingError("Cannot stop recording: not currently recording");
				return;
			}

			StopRecordingImpl();
		}

		void StopRecordingImpl()
		{
			var filePath = StopRecordingCore();
			if (string.IsNullOrEmpty(filePath))
			{
				OnRecordingError("Failed to stop recording");
				return;
			}

			OnRecordingStopped(filePath);
		}

		/**
			Stops the native recorder and resets the timing/metering state.
			Returns the output path, or an empty string when no file was produced.
		*/
		string StopRecordingCore()
		{
			UpdateRecordingDuration();

			// The native stop may report completion (iOS does this for manual stops too),
			// so suppress the completion path while stopping deliberately.
			_stopping = true;
			var filePath = StopNativeRecording();
			_stopping = false;

			_currentState = RecordingState.Stopped;
			_recordingOffset = _recordingDuration;
			_recordingInstance = null;
			StopMetering();
			StopAudioSampling();

			return filePath;
		}

		/** Pauses audio recording */
		public void PauseRecording()
		{
			if (_currentState != RecordingState.Recording)
			{
				OnRecordingError("Cannot pause recording: not currently recording");
				return;
			}

			PauseRecordingImpl();
		}

		extern(!Android && !iOS)
		void PauseRecordingImpl()
		{
			// No-op for unsupported platforms
		}

		extern(Android || iOS)
		void PauseRecordingImpl()
		{
			UpdateRecordingDuration();

			if (Fuse.Audio.AudioRecorderImpl.PauseRecording())
			{
				_currentState = RecordingState.Paused;
				_recordingOffset = _recordingDuration;
				StopMetering();
				StopAudioSampling();
				OnRecordingPaused(_config.OutputPath);
			}
			else
			{
				OnRecordingError("Failed to pause recording");
			}
		}

		/** Resumes audio recording */
		public void ResumeRecording()
		{
			if (_currentState != RecordingState.Paused)
			{
				OnRecordingError("Cannot resume recording: not currently paused");
				return;
			}

			ResumeRecordingImpl();
		}

		extern(!Android && !iOS)
		void ResumeRecordingImpl()
		{
			// No-op for unsupported platforms
		}

		extern(Android || iOS)
		void ResumeRecordingImpl()
		{
			if (!Fuse.Audio.AudioRecorderImpl.ResumeRecording())
			{
				OnRecordingError("Failed to resume recording");
				return;
			}

			BeginRecording();
			OnRecordingResumed(_config.OutputPath);
		}

		/** Shared state transitions for a recording that is now running */
		void BeginRecording()
		{
			_currentState = RecordingState.Recording;
			_recordingInstance = this;
			StartTimer();
			StartMetering();

			if (SamplingEnabled)
				StartAudioSampling();
		}

		/** Checks if recording permission is granted */
		public bool HasRecordingPermission()
		{
			return HasRecordingPermissionImpl();
		}

		extern(!Android && !iOS)
		bool HasRecordingPermissionImpl()
		{
			return false;
		}

		extern(Android || iOS)
		bool HasRecordingPermissionImpl()
		{
			return Fuse.Audio.AudioRecorderImpl.HasRecordingPermission();
		}

		/** Requests recording permission. The result is reported through PermissionChanged. */
		public void RequestRecordingPermission()
		{
			RequestRecordingPermissionImpl(OnPermissionChanged);
		}

		void OnPermissionChanged(bool granted)
		{
			if (PermissionChanged != null)
				PermissionChanged(this, new RecordingPermissionEventArgs(granted));
		}

		extern(!Android && !iOS)
		void RequestRecordingPermissionImpl(Action<bool> callback)
		{
			callback(false);
		}

		extern(Android || iOS)
		void RequestRecordingPermissionImpl(Action<bool> callback)
		{
			Fuse.Audio.AudioRecorderImpl.RequestRecordingPermission(callback);
		}

		extern(!Android && !iOS)
		string StopNativeRecording()
		{
			return "";
		}

		extern(Android || iOS)
		string StopNativeRecording()
		{
			return Fuse.Audio.AudioRecorderImpl.StopRecording();
		}

		// ---- Timing and metering ----

		void StartTimer()
		{
			_recordingStartTime = Uno.Diagnostics.Clock.GetSeconds();
		}

		void UpdateRecordingDuration()
		{
			var duration = _recordingOffset;
			if (_currentState == RecordingState.Recording)
				duration += Uno.Diagnostics.Clock.GetSeconds() - _recordingStartTime;

			if (Math.Abs(duration - _recordingDuration) < 0.001)
				return;

			_recordingDuration = duration;
			OnPropertyChanged(_recordingDurationName);
		}

		void StartMetering()
		{
			if (_metering)
				return;

			_metering = true;
			_lastLevelTime = -1.0;
			UpdateManager.AddAction(UpdateMetering);
		}

		void StopMetering()
		{
			if (!_metering)
				return;

			_metering = false;
			UpdateManager.RemoveAction(UpdateMetering);
		}

		void UpdateMetering()
		{
			if (_currentState != RecordingState.Recording)
				return;

			UpdateRecordingDuration();

			if (_lastLevelTime >= 0.0 && _recordingDuration - _lastLevelTime < MeteringInterval)
				return;

			_lastLevelTime = _recordingDuration;

			var level = GetAmplitudeImpl();
			if (Math.Abs(level - _recordingLevel) > 0.005f)
			{
				_recordingLevel = level;
				OnPropertyChanged(_recordingLevelName);
			}

			if (LevelChanged != null)
				LevelChanged(this, new RecordingLevelEventArgs(_recordingLevel, _recordingDuration));
		}

		extern(!Android && !iOS)
		float GetAmplitudeImpl()
		{
			return 0.0f;
		}

		extern(Android || iOS)
		float GetAmplitudeImpl()
		{
			return Fuse.Audio.AudioRecorderImpl.GetAmplitude();
		}

		// ---- Native callbacks ----

		/** Called when the platform stopped the recording because a limit was reached */
		internal static void OnNativeRecordingCompleted()
		{
			var recorder = _recordingInstance;
			if (recorder != null)
				recorder.CompleteRecording();
		}

		/** Called when the platform reports a recording error */
		internal static void OnNativeRecordingError(string message)
		{
			var recorder = _recordingInstance;
			if (recorder == null)
			{
				Fuse.Diagnostics.UserError(message, null);
				return;
			}

			recorder.AbortRecording(message);
		}

		/** Releases the native recorder after a fatal error */
		void AbortRecording(string message)
		{
			if (_currentState != RecordingState.Stopped)
				StopRecordingCore();

			OnRecordingError(message);
		}

		void CompleteRecording()
		{
			if (_stopping || _currentState == RecordingState.Stopped)
				return;

			var filePath = StopRecordingCore();
			if (string.IsNullOrEmpty(filePath))
			{
				OnRecordingError("Recording did not produce a file");
				return;
			}

			OnRecordingStopped(filePath);

			if (RecordingCompleted != null)
				RecordingCompleted(this, new RecordingEventArgs(RecordingState.Stopped, filePath));
		}

		void OnRecordingStarted(string filePath)
		{
			if (RecordingStarted != null)
				RecordingStarted(this, new RecordingEventArgs(RecordingState.Recording, filePath));
		}

		void OnRecordingStopped(string filePath)
		{
			if (RecordingStopped != null)
				RecordingStopped(this, new RecordingEventArgs(RecordingState.Stopped, filePath));
		}

		void OnRecordingPaused(string filePath)
		{
			if (RecordingPaused != null)
				RecordingPaused(this, new RecordingEventArgs(RecordingState.Paused, filePath));
		}

		void OnRecordingResumed(string filePath)
		{
			if (RecordingResumed != null)
				RecordingResumed(this, new RecordingEventArgs(RecordingState.Recording, filePath));
		}

		/**
			Reports an error to the app. This is also used for control-flow errors (wrong state),
			so it must not disturb a recording that is still running.
		*/
		void OnRecordingError(string errorMessage)
		{
			if (RecordingError != null)
				RecordingError(this, new RecordingEventArgs(RecordingState.Stopped, "", errorMessage));
		}

		void OnAudioSampleReceived(AudioSample sample)
		{
			if (AudioSampleReceived != null)
				AudioSampleReceived(this, new AudioSampleEventArgs(sample));
		}

		// Audio sampling methods
		void StartAudioSampling()
		{
			if (_trackingSamples || !SamplingEnabled || _currentState != RecordingState.Recording)
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
			if (_sampleConfig != null)
			{
				Fuse.Audio.AudioRecorderImpl.StartAudioSampling(
					_sampleConfig.GetSampleRate(),
					_sampleConfig.GetChannelCount(),
					_sampleConfig.GetAudioSampleFormat(),
					_sampleConfig.GetBufferSize(),
					_sampleConfig.GetUpdateIntervalMs()
				);
			}
		}

		extern(!Android && !iOS)
		void StopAudioSamplingImpl()
		{
			// No-op for unsupported platforms
		}

		extern(Android || iOS)
		void StopAudioSamplingImpl()
		{
			Fuse.Audio.AudioRecorderImpl.StopAudioSampling();
		}

		// Called from the native implementation when sample data is available during recording
		public static void OnRecordingAudioSampleAvailable(int sampleRate, int channelCount, int format,
		                                                   int sampleCount, byte[] data, double timestamp)
		{
			// Recording is exclusive, so the active recording is the receiver
			var recorder = _recordingInstance;
			if (recorder == null)
				return;

			recorder.OnAudioSampleReceived(new AudioSample(sampleRate, channelCount, (AudioSampleFormat)format, sampleCount, data, timestamp));
		}

		protected override void OnRooted()
		{
			base.OnRooted();

			// Apply SampleConfig if present
			if (_sampleConfigProperty != null)
				UpdateSamplingFromConfig(_sampleConfigProperty);
		}

		protected override void OnUnrooted()
		{
			base.OnUnrooted();

			// Only stop an active recording: calling StopRecording() while stopped
			// reports a spurious RecordingError.
			if (_currentState != RecordingState.Stopped)
				StopRecording();

			StopAudioSampling();
			StopMetering();

			if (_recordingInstance == this)
				_recordingInstance = null;
		}

	}

	/** Base class for trigger actions that operate on an @AudioRecorder */
	public abstract class RecordingAction : TriggerAction
	{
		/** The AudioRecorder to target. If not specified, searches up the node hierarchy. */
		public AudioRecorder Source { get; set; }

		/** Name used in diagnostics */
		protected abstract string ActionName { get; }

		protected abstract void PerformOn(AudioRecorder recorder);

		protected override void Perform(Node target)
		{
			var recorder = Source ?? target.FindByType<AudioRecorder>();
			if (recorder == null)
			{
				Fuse.Diagnostics.UserError(ActionName + ": No AudioRecorder found" + (Source != null ? "" : " in node hierarchy"), this);
				return;
			}

			PerformOn(recorder);
		}
	}

	/** Trigger action to start audio recording */
	public class StartRecording : RecordingAction
	{
		protected override string ActionName { get { return "StartRecording"; } }

		protected override void PerformOn(AudioRecorder recorder)
		{
			recorder.StartRecording();
		}
	}

	/** Trigger action to stop audio recording */
	public class StopRecording : RecordingAction
	{
		protected override string ActionName { get { return "StopRecording"; } }

		protected override void PerformOn(AudioRecorder recorder)
		{
			recorder.StopRecording();
		}
	}

	/** Trigger action to pause audio recording */
	public class PauseRecording : RecordingAction
	{
		protected override string ActionName { get { return "PauseRecording"; } }

		protected override void PerformOn(AudioRecorder recorder)
		{
			recorder.PauseRecording();
		}
	}

	/** Trigger action to resume audio recording */
	public class ResumeRecording : RecordingAction
	{
		protected override string ActionName { get { return "ResumeRecording"; } }

		protected override void PerformOn(AudioRecorder recorder)
		{
			recorder.ResumeRecording();
		}
	}

	/** Trigger action to request recording permission */
	public class RequestRecordingPermission : RecordingAction
	{
		protected override string ActionName { get { return "RequestRecordingPermission"; } }

		protected override void PerformOn(AudioRecorder recorder)
		{
			recorder.RequestRecordingPermission();
		}
	}
}
