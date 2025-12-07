using Fuse.Triggers;
using Fuse.Triggers.Actions;
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
	public class AudioEventArgs : EventArgs
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
	}

	/** Main audio player class for playing audio files with full playback control

		This class provides audio playback functionality for iOS and Android platforms.
		It supports play/pause/stop/reset operations, progress tracking, volume control,
		and implements the IMediaPlayback interface for compatibility with trigger actions.

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
				<AudioPlayer ux:Name="audioPlayer" File="music.mp3" AutoPlay="false" />
				<Button Margin="10" Text="Play">
					<Clicked>
						<PlayAudio />
					</Clicked>
				</Button>
				<Button Margin="10" Text="Pause">
					<Clicked>
						<PauseAudio />
					</Clicked>
				</Button>
				<Button Margin="10" Text="Stop">
					<Clicked>
						<StopAudio />
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
	*/
	public class AudioPlayer : Node, IMediaPlayback, IPropertyListener
	{
		// Static property name selectors for OnPropertyChanged notifications
		static Selector _fileName = "File";
		static Selector _autoPlayName = "AutoPlay";
		static Selector _loopName = "Loop";
		static Selector _currentStateName = "CurrentState";
		static Selector _volumeName = "Volume";
		static Selector _progressName = "Progress";
		static Selector _positionName = "Position";
		static Selector _durationName = "Duration";

		// Private fields
		PlaybackState _currentState = PlaybackState.Stopped;
		double _progress = 0.0;
		double _duration = 0.0;
		double _position = 0.0;
		float _volume = 1.0f;
		FileSource _file;
		bool _autoPlay = false;
		bool _loop = false;

		public AudioPlayer()
		{
		}

		// File source
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
			if (IsRootingCompleted)
			{
				if (_currentState != PlaybackState.Stopped)
				{
					Stop();
				}
				LoadAudio();
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

		// AutoPlay property
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

		// Loop property
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
		}

		void UpdateLoop(bool loop, IPropertyListener origin)
		{
			if (loop != _loop)
			{
				_loop = loop;
				OnPropertyChanged(_loopName, origin);
			}
		}

		// CurrentState property (read-only)
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

		// Volume property
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
				SetVolumeImpl(_volume);
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
				SetProgressImpl(_progress);
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

		// Position property
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
				SetPositionImpl(_position);
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
					OnProgressChanged(); // Fire IProgress event
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
		public event ValueChangedHandler<double> ProgressChanged;

		/** Loads the audio file */
		void LoadAudio()
		{
			if (_file == null) return;

			_currentState = PlaybackState.Loading;
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
			if (Fuse.Audio.AudioPlayerImpl.LoadAudio(_file, out duration))
			{
				UpdateCurrentState(PlaybackState.Stopped);
				UpdateDuration(duration);
				UpdateProgress(0.0, this);
				UpdatePosition(0.0, this);

				if (_autoPlay)
				{
					Resume();
				}
			}
			else
			{
				OnPlaybackError("Failed to load audio file");
			}
		}

		/** Starts or resumes audio playback */
		public void Resume()
		{
			if (_currentState == PlaybackState.Playing)
				return;

			if (_file == null)
			{
				OnPlaybackError("No audio file specified");
				return;
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
			if (Fuse.Audio.AudioPlayerImpl.Resume())
			{
				UpdateCurrentState(PlaybackState.Playing);
				OnPlaybackStarted();
				StartProgressTracking();
			}
			else
			{
				OnPlaybackError("Failed to start playback");
			}
		}

		/** Pauses audio playback */
		public void Pause()
		{
			if (_currentState != PlaybackState.Playing)
				return;

			PauseImpl();
		}

		extern(!Android && !iOS)
		void PauseImpl()
		{
			// No-op for unsupported platforms
		}

		extern(Android || iOS)
		void PauseImpl()
		{
			if (Fuse.Audio.AudioPlayerImpl.Pause())
			{
				UpdateCurrentState(PlaybackState.Paused);
				OnPlaybackPaused();
				StopProgressTracking();
			}
			else
			{
				OnPlaybackError("Failed to pause playback");
			}
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
			Fuse.Audio.AudioPlayerImpl.Stop();
			UpdateCurrentState(PlaybackState.Stopped);
			UpdateProgress(0.0, this);
			UpdatePosition(0.0, this);
			OnPlaybackStopped();
			StopProgressTracking();
		}

		/** Resets playback to the beginning */
		public void Reset()
		{
			SetProgress(0.0, this);
		}

		extern(!Android && !iOS)
		void SetVolumeImpl(float volume)
		{
			// No-op for unsupported platforms
		}

		extern(Android || iOS)
		void SetVolumeImpl(float volume)
		{
			Fuse.Audio.AudioPlayerImpl.SetVolume(volume);
		}

		extern(!Android && !iOS)
		void SetProgressImpl(double progress)
		{
			// No-op for unsupported platforms
		}

		extern(Android || iOS)
		void SetProgressImpl(double progress)
		{
			Fuse.Audio.AudioPlayerImpl.SetProgress(progress);
		}

		extern(!Android && !iOS)
		void SetPositionImpl(double position)
		{
			// No-op for unsupported platforms
		}

		extern(Android || iOS)
		void SetPositionImpl(double position)
		{
			Fuse.Audio.AudioPlayerImpl.SetPosition(position);
		}

		// Progress tracking
		bool _trackingProgress = false;

		void StartProgressTracking()
		{
			if (_trackingProgress) return;
			_trackingProgress = true;
			UpdateManager.AddAction(UpdateProgress);
		}

		void StopProgressTracking()
		{
			if (!_trackingProgress) return;
			_trackingProgress = false;
			UpdateManager.RemoveAction(UpdateProgress);
		}

		void UpdateProgress()
		{
			if (_currentState != PlaybackState.Playing) return;

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
			var currentPosition = Fuse.Audio.AudioPlayerImpl.GetCurrentPosition();
			if (currentPosition >= 0)
			{
				UpdatePosition(currentPosition, this);

				// Check if playback completed
				if (_progress >= 1.0 || currentPosition >= _duration)
				{
					if (_loop)
					{
						Reset();
						Resume();
					}
					else
					{
						UpdateCurrentState(PlaybackState.Stopped);
						OnPlaybackCompleted();
						StopProgressTracking();
					}
				}
			}
		}

		// Event handlers
		void OnPlaybackStarted()
		{
			if (PlaybackStarted != null)
				PlaybackStarted(this, new AudioEventArgs(PlaybackState.Playing, _file != null ? _file.ToString() : "", "", _progress, _duration));
		}

		void OnPlaybackStopped()
		{
			if (PlaybackStopped != null)
				PlaybackStopped(this, new AudioEventArgs(PlaybackState.Stopped, _file != null ? _file.ToString() : "", "", _progress, _duration));
		}

		void OnPlaybackPaused()
		{
			if (PlaybackPaused != null)
				PlaybackPaused(this, new AudioEventArgs(PlaybackState.Paused, _file != null ? _file.ToString() : "", "", _progress, _duration));
		}

		void OnPlaybackCompleted()
		{
			if (PlaybackCompleted != null)
				PlaybackCompleted(this, new AudioEventArgs(PlaybackState.Stopped, _file != null ? _file.ToString() : "", "", _progress, _duration));
		}

		void OnPlaybackError(string errorMessage)
		{
			UpdateCurrentState(PlaybackState.Error);
			StopProgressTracking();
			if (PlaybackError != null)
				PlaybackError(this, new AudioEventArgs(PlaybackState.Error, _file != null ? _file.ToString() : "", errorMessage, _progress, _duration));
		}

		void OnProgressChanged()
		{
			if (ProgressChanged != null)
				ProgressChanged(this, new ValueChangedArgs<double>(_progress));
		}

		// IPropertyListener implementation
		void IPropertyListener.OnPropertyChanged(PropertyObject obj, Selector prop)
		{
			// Handle property changes from bound objects if needed
		}

		protected override void OnRooted()
		{
			base.OnRooted();
			if (_file != null && _currentState == PlaybackState.Stopped)
			{
				LoadAudio();
			}
		}

		protected override void OnUnrooted()
		{
			base.OnUnrooted();
			Stop();
		}
	}
}
