using Fuse.Triggers;
using Fuse.Triggers.Actions;
using Uno.UX;
using Uno;
using Uno.Collections;

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

	/** Configuration class for audio recording settings */
	public class RecordingConfig
	{
		public int SampleRate { get; set; }
		public int BitRate { get; set; }
		public int Channels { get; set; } // Mono by default
		public AudioFormat Format { get; set; }
		public AudioQuality Quality { get; set; }
		public string OutputPath { get; set; }

		public RecordingConfig()
		{
			SampleRate = 44100;
			BitRate = 128000;
			Channels = 1;
			Format = AudioFormat.M4A;
			Quality = AudioQuality.Medium;
			OutputPath = "";
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
	public class RecordingEventArgs : EventArgs
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
	}

	/** Main audio recorder class for recording audio with configurable settings

		This class provides audio recording functionality for iOS and Android platforms.
		It supports various audio formats, quality settings, and configuration options.

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
				<Button Margin="10" Text="Start Recording">
					<Clicked>
						<StartRecording />
					</Clicked>
				</Button>
				<Button Margin="10" Text="Stop Recording">
					<Clicked>
						<StopRecording />
					</Clicked>
				</Button>
			</StackPanel>
		```

		## Events
		- RecordingStarted: Fired when recording begins
		- RecordingStopped: Fired when recording stops
		- RecordingPaused: Fired when recording is paused
		- RecordingResumed: Fired when recording resumes
		- RecordingError: Fired when an error occurs
	*/
	public class AudioRecorder : Node
	{
		RecordingConfig _config;
		RecordingState _currentState = RecordingState.Stopped;

		public AudioRecorder()
		{
			_config = new RecordingConfig();
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
				_config.Quality = value;
				if (value != AudioQuality.Custom)
				{
					_config = new RecordingConfig(value);
				}
			}
		}

		/** Gets or sets the output file path (if empty, a default path will be used) */
		public string OutputPath
		{
			get { return _config.OutputPath; }
			set { _config.OutputPath = value; }
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

		/** Starts audio recording */
		public void StartRecording()
		{
			if (_currentState != RecordingState.Stopped)
			{
				OnRecordingError("Cannot start recording: already recording or paused");
				return;
			}

			StartRecordingImpl();
		}

		extern(!Android && !iOS)
		void StartRecordingImpl()
		{
			OnRecordingError("Audio recording is not yet implemented for this platform");
		}

		extern(Android || iOS)
		void StartRecordingImpl()
		{
			if (Fuse.Audio.AudioRecorderImpl.StartRecording(_config))
			{
				_currentState = RecordingState.Recording;
				OnRecordingStarted(_config.OutputPath);
			}
			else
			{
				OnRecordingError("Failed to start recording");
			}
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

		extern(!Android && !iOS)
		void StopRecordingImpl()
		{
			// No-op for unsupported platforms
		}

		extern(Android || iOS)
		void StopRecordingImpl()
		{
			var filePath = Fuse.Audio.AudioRecorderImpl.StopRecording();
			if (!string.IsNullOrEmpty(filePath))
			{
				_currentState = RecordingState.Stopped;
				OnRecordingStopped(filePath);
			}
			else
			{
				OnRecordingError("Failed to stop recording");
			}
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
			if (Fuse.Audio.AudioRecorderImpl.PauseRecording())
			{
				_currentState = RecordingState.Paused;
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
			if (Fuse.Audio.AudioRecorderImpl.ResumeRecording())
			{
				_currentState = RecordingState.Recording;
				OnRecordingResumed(_config.OutputPath);
			}
			else
			{
				OnRecordingError("Failed to resume recording");
			}
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

		/** Requests recording permission */
		public void RequestRecordingPermission()
		{
			RequestRecordingPermissionImpl();
		}

		extern(!Android && !iOS)
		void RequestRecordingPermissionImpl()
		{
			// No-op for unsupported platforms
		}

		extern(Android || iOS)
		void RequestRecordingPermissionImpl()
		{
			Fuse.Audio.AudioRecorderImpl.RequestRecordingPermission();
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

		void OnRecordingError(string errorMessage)
		{
			if (RecordingError != null)
				RecordingError(this, new RecordingEventArgs(RecordingState.Stopped, "", errorMessage));
		}
	}

	/** Trigger actions for controlling audio recording */

	/** Trigger action to start audio recording */
	public class StartRecording : TriggerAction
	{
		/** The AudioRecorder to target. If not specified, searches up the node hierarchy. */
		public AudioRecorder Source { get; set; }

		protected override void Perform(Node target)
		{
			var recorder = Source ?? target.FindByType<AudioRecorder>();
			if (recorder != null)
			{
				recorder.StartRecording();
			}
			else
			{
				Fuse.Diagnostics.UserError("StartRecording: No AudioRecorder found" + (Source != null ? "" : " in node hierarchy"), this);
			}
		}
	}

	/** Trigger action to stop audio recording */
	public class StopRecording : TriggerAction
	{
		/** The AudioRecorder to target. If not specified, searches up the node hierarchy. */
		public AudioRecorder Source { get; set; }

		protected override void Perform(Node target)
		{
			var recorder = Source ?? target.FindByType<AudioRecorder>();
			if (recorder != null)
			{
				recorder.StopRecording();
			}
			else
			{
				Fuse.Diagnostics.UserError("StopRecording: No AudioRecorder found" + (Source != null ? "" : " in node hierarchy"), this);
			}
		}
	}

	/** Trigger action to pause audio recording */
	public class PauseRecording : TriggerAction
	{
		/** The AudioRecorder to target. If not specified, searches up the node hierarchy. */
		public AudioRecorder Source { get; set; }

		protected override void Perform(Node target)
		{
			var recorder = Source ?? target.FindByType<AudioRecorder>();
			if (recorder != null)
			{
				recorder.PauseRecording();
			}
			else
			{
				Fuse.Diagnostics.UserError("PauseRecording: No AudioRecorder found" + (Source != null ? "" : " in node hierarchy"), this);
			}
		}
	}

	/** Trigger action to resume audio recording */
	public class ResumeRecording : TriggerAction
	{
		/** The AudioRecorder to target. If not specified, searches up the node hierarchy. */
		public AudioRecorder Source { get; set; }

		protected override void Perform(Node target)
		{
			var recorder = Source ?? target.FindByType<AudioRecorder>();
			if (recorder != null)
			{
				recorder.ResumeRecording();
			}
			else
			{
				Fuse.Diagnostics.UserError("ResumeRecording: No AudioRecorder found" + (Source != null ? "" : " in node hierarchy"), this);
			}
		}
	}

	/** Trigger action to request recording permission */
	public class RequestRecordingPermission : TriggerAction
	{
		/** The AudioRecorder to target. If not specified, searches up the node hierarchy. */
		public AudioRecorder Source { get; set; }

		protected override void Perform(Node target)
		{
			var recorder = Source ?? target.FindByType<AudioRecorder>();
			if (recorder != null)
			{
				recorder.RequestRecordingPermission();
			}
			else
			{
				Fuse.Diagnostics.UserError("RequestRecordingPermission: No AudioRecorder found" + (Source != null ? "" : " in node hierarchy"), this);
			}
		}
	}
}
