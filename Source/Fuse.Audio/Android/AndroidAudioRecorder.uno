using Uno;
using Uno.IO;
using Uno.Compiler.ExportTargetInterop;

namespace Fuse.Audio
{
	[ForeignInclude(Language.Java,
					"java.io.File",
					"java.io.IOException",
					"android.media.MediaRecorder",
					"android.media.AudioRecord",
					"android.media.AudioFormat",
					"android.os.Environment",
					"android.content.Context",
					"android.content.pm.PackageManager",
					"android.Manifest",
					"androidx.core.content.ContextCompat")]
	internal extern(Android) class AudioRecorderImpl
	{
		static string _currentRecordingPath = "";
		static bool _samplingActive = false;

		// Native state. These are kept on the Uno side because Java foreign blocks are
		// emitted inside the generated method body, so they cannot declare their own fields.
		static Java.Object _mediaRecorder;
		static Java.Object _audioRecord;
		static Java.Object _samplingThread;

		public static bool StartRecording(RecordingConfig config)
		{
			if (!HasRecordingPermission())
			{
				return false;
			}

			// Generate output path if not specified
			if (string.IsNullOrEmpty(config.OutputPath))
			{
				config.OutputPath = GenerateOutputPath(config.Format);
			}

			_currentRecordingPath = config.OutputPath;

			return StartRecordingNative(
				config.OutputPath,
				(int)config.Format,
				config.SampleRate,
				config.BitRate,
				config.Channels,
				(int)config.Source,
				(int)(config.MaxDuration * 1000.0),
				config.MaxFileSize
			);
		}

		public static string StopRecording()
		{
			if (StopRecordingNative(_currentRecordingPath))
			{
				return _currentRecordingPath;
			}
			return "";
		}

		/** Gets the current input peak, normalized to 0..1 */
		public static float GetAmplitude()
		{
			var recorder = _mediaRecorder as Java.Object;
			if (recorder == null)
				return 0.0f;

			return GetAmplitudeImpl(recorder);
		}

		[Foreign(Language.Java)]
		static float GetAmplitudeImpl(Java.Object recorderHandle)
		@{
			try {
				android.media.MediaRecorder recorder = (android.media.MediaRecorder)recorderHandle;
				// getMaxAmplitude resets each call, so this is the peak since the last poll
				return Math.min(1.0f, recorder.getMaxAmplitude() / 32767.0f);
			} catch (Exception e) {
				return 0.0f;
			}
		@}

		public static bool PauseRecording()
		{
			return PauseRecordingNative();
		}

		public static bool ResumeRecording()
		{
			return ResumeRecordingNative();
		}

		public static bool HasRecordingPermission()
		{
			return HasRecordingPermissionNative();
		}

		public static void RequestRecordingPermission(Action<bool> callback)
		{
			// The Android permissions package owns the request/result plumbing: it asks
			// on the UI thread and resolves the promise with the outcome.
			Fuse.Android.Permissions.Permissions
				.Request(Fuse.Android.Permissions.Permissions.Android.RECORD_AUDIO)
				.Then(granted => callback(true), error => callback(false));
		}

		static string GenerateOutputPath(AudioFormat format)
		{
			string extension = GetFileExtension(format);
			string fileName = "recording_" + DateTime.UtcNow.Ticks + "." + extension;
			return Path.Combine(GetRecordingDirectory(), fileName);
		}

		static string GetFileExtension(AudioFormat format)
		{
			switch (format)
			{
				case AudioFormat.WAV: return "wav";
				case AudioFormat.AAC: return "aac";
				case AudioFormat.MP3: return "mp3";
				case AudioFormat.M4A: return "m4a";
				default: return "m4a";
			}
		}

		[Foreign(Language.Java)]
		static string GetRecordingDirectory()
		@{
			Context context = com.fuse.Activity.getRootActivity();
			File dir = new File(context.getExternalFilesDir(Environment.DIRECTORY_MUSIC), "Recordings");
			if (!dir.exists()) {
				dir.mkdirs();
			}
			return dir.getAbsolutePath();
		@}

		[Foreign(Language.Java)]
		static bool StartRecordingNative(string outputPath, int format, int sampleRate, int bitRate, int channels,
		                                 int source, int maxDurationMs, int maxFileSize)
		@{
			android.media.MediaRecorder recorder = new android.media.MediaRecorder();
			try {
				// Stop any existing recording
				StopRecordingNative(null);

				switch (source) {
					case 2: // VoiceRecognition
						recorder.setAudioSource(MediaRecorder.AudioSource.VOICE_RECOGNITION);
						break;
					case 3: // VoiceCommunication
						recorder.setAudioSource(MediaRecorder.AudioSource.VOICE_COMMUNICATION);
						break;
					case 4: // Camcorder
						recorder.setAudioSource(MediaRecorder.AudioSource.CAMCORDER);
						break;
					case 5: // Unprocessed
						if (android.os.Build.VERSION.SDK_INT >= 24)
							recorder.setAudioSource(MediaRecorder.AudioSource.UNPROCESSED);
						else
							recorder.setAudioSource(MediaRecorder.AudioSource.MIC);
						break;
					default: // Default / Microphone
						recorder.setAudioSource(MediaRecorder.AudioSource.MIC);
						break;
				}

				// Set output format based on the format parameter
				switch (format) {
					case 0: // WAV - not directly supported by MediaRecorder, use AAC
					case 1: // AAC
						recorder.setOutputFormat(MediaRecorder.OutputFormat.AAC_ADTS);
						recorder.setAudioEncoder(MediaRecorder.AudioEncoder.AAC);
						break;
					case 2: // MP3 - not directly supported by MediaRecorder, use AAC
						recorder.setOutputFormat(MediaRecorder.OutputFormat.AAC_ADTS);
						recorder.setAudioEncoder(MediaRecorder.AudioEncoder.AAC);
						break;
					case 3: // M4A
					default:
						recorder.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4);
						recorder.setAudioEncoder(MediaRecorder.AudioEncoder.AAC);
						break;
				}

				recorder.setAudioSamplingRate(sampleRate);
				recorder.setAudioEncodingBitRate(bitRate);
				recorder.setAudioChannels(channels);

				// Limits (0 = unlimited)
				if (maxDurationMs > 0)
					recorder.setMaxDuration(maxDurationMs);
				if (maxFileSize > 0)
					recorder.setMaxFileSize(maxFileSize);

				recorder.setOutputFile(outputPath);

				// The recorder stops itself when a limit is reached
				recorder.setOnInfoListener(new android.media.MediaRecorder.OnInfoListener() {
					public void onInfo(android.media.MediaRecorder mr, int what, int extra) {
						if (what == android.media.MediaRecorder.MEDIA_RECORDER_INFO_MAX_DURATION_REACHED ||
							what == android.media.MediaRecorder.MEDIA_RECORDER_INFO_MAX_FILESIZE_REACHED)
							@{NativeRecordingCompleted():call()};
					}
				});

				recorder.prepare();
				recorder.start();

				// Publish the handle only once it is actually recording
				@{SetMediaRecorder(Java.Object):call(recorder)};
				return true;
			} catch (Exception e) {
				e.printStackTrace();
				try {
					recorder.release();
				} catch (Exception ex) {
					ex.printStackTrace();
				}
				@{SetMediaRecorder(Java.Object):call(null)};
				return false;
			}
		@}

		[Foreign(Language.Java)]
		static bool StopRecordingNative(string outputPath)
		@{
			android.media.MediaRecorder recorder = (android.media.MediaRecorder)@{_mediaRecorder:get()};
			if (recorder == null)
				return false;

			try {
				recorder.stop();
				recorder.release();
				@{SetMediaRecorder(Java.Object):call(null)};
				return true;
			} catch (Exception e) {
				// Most commonly the recorder already stopped itself because a limit was
				// reached. Fall back to checking that the file was actually written.
				e.printStackTrace();
				try {
					recorder.release();
				} catch (Exception ex) {
					ex.printStackTrace();
				}
				@{SetMediaRecorder(Java.Object):call(null)};

				if (outputPath == null)
					return false;

				java.io.File file = new java.io.File(outputPath);
				return file.exists() && file.length() > 0;
			}
		@}

		static void NativeRecordingCompleted()
		{
			AudioRecorder.OnNativeRecordingCompleted();
		}

		[Foreign(Language.Java)]
		static bool PauseRecordingNative()
		@{
			try {
				android.media.MediaRecorder recorder = (android.media.MediaRecorder)@{_mediaRecorder:get()};
				if (recorder != null && android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.N) {
					recorder.pause();
					return true;
				}
				return false;
			} catch (Exception e) {
				e.printStackTrace();
				return false;
			}
		@}

		[Foreign(Language.Java)]
		static bool ResumeRecordingNative()
		@{
			try {
				android.media.MediaRecorder recorder = (android.media.MediaRecorder)@{_mediaRecorder:get()};
				if (recorder != null && android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.N) {
					recorder.resume();
					return true;
				}
				return false;
			} catch (Exception e) {
				e.printStackTrace();
				return false;
			}
		@}

		[Foreign(Language.Java)]
		static bool HasRecordingPermissionNative()
		@{
			Context context = com.fuse.Activity.getRootActivity();
			// Recordings are written to getExternalFilesDir(), which is app-specific and
			// needs no storage permission, so RECORD_AUDIO is the only requirement.
			return ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED;
		@}

		public static void StartAudioSampling(int sampleRate, int channelCount, int format,
		                                     int bufferSize, int updateIntervalMs)
		{
			if (_samplingActive)
				return;

			StartAudioSamplingImpl(sampleRate, channelCount, format, bufferSize, updateIntervalMs);
		}

		[Foreign(Language.Java)]
		static void StartAudioSamplingImpl(int sampleRate, int channelCount, int format,
		                                  int bufferSize, int updateIntervalMs)
		@{
			try {
				// Use AudioRecord for real-time audio sampling during recording
				int audioFormat = AudioFormat.ENCODING_PCM_16BIT;
				int channelConfig = (channelCount == 1) ? AudioFormat.CHANNEL_IN_MONO : AudioFormat.CHANNEL_IN_STEREO;

				int minBufferSize = AudioRecord.getMinBufferSize(sampleRate, channelConfig, audioFormat);
				final int actualBufferSize = Math.max(minBufferSize, bufferSize * channelCount * 2); // 2 bytes per sample for 16-bit

				final int channelsPerFrame = channelCount;
				final int sampleFormat = format;
				final int sleepIntervalMs = updateIntervalMs;

				final android.media.AudioRecord audioRecord = new android.media.AudioRecord(
					android.media.MediaRecorder.AudioSource.MIC,
					sampleRate,
					channelConfig,
					audioFormat,
					actualBufferSize
				);

				if (audioRecord.getState() != AudioRecord.STATE_INITIALIZED) {
					audioRecord.release();
					return;
				}

				audioRecord.startRecording();
				@{SetAudioRecord(Java.Object):call(audioRecord)};
				@{SetSamplingActive(bool):call(true)};

				// Start background thread for continuous sampling
				Thread samplingThread = new Thread(new Runnable() {
					@Override
					public void run() {
						byte[] buffer = new byte[actualBufferSize];
						while (@{_samplingActive:get()}) {

							int bytesRead = audioRecord.read(buffer, 0, buffer.length);
							if (bytesRead > 0) {
								// Calculate actual sample count
								int sampleCount = bytesRead / (channelsPerFrame * 2); // 2 bytes per 16-bit sample

								// Create copy of data for callback
								byte[] sampleData = new byte[bytesRead];
								System.arraycopy(buffer, 0, sampleData, 0, bytesRead);

								@{OnRecordingAudioSampleCaptured(int,int,int,int,byte[],double):call(
									sampleRate,
									channelsPerFrame,
									sampleFormat,
									sampleCount,
									sampleData,
									System.currentTimeMillis())};
							}

							try {
								Thread.sleep(sleepIntervalMs);
							} catch (InterruptedException e) {
								break;
							}
						}
					}
				});
				samplingThread.start();
				@{SetSamplingThread(Java.Object):call(samplingThread)};
			} catch (Exception e) {
				// Audio sampling might not be supported on all devices
				e.printStackTrace();
			}
		@}

		static void SetMediaRecorder(Java.Object recorder)
		{
			_mediaRecorder = recorder;
		}

		static void SetAudioRecord(Java.Object audioRecord)
		{
			_audioRecord = audioRecord;
		}

		static void SetSamplingThread(Java.Object samplingThread)
		{
			_samplingThread = samplingThread;
		}

		static void SetSamplingActive(bool active)
		{
			_samplingActive = active;
		}

		static void OnRecordingAudioSampleCaptured(int sampleRate, int channelCount, int format,
		                                          int sampleCount, byte[] data, double timestamp)
		{
			// Forward to AudioRecorder's callback
			AudioRecorder.OnRecordingAudioSampleAvailable(sampleRate, channelCount, format, sampleCount, data, timestamp);
		}

		public static void StopAudioSampling()
		{
			if (!_samplingActive)
				return;

			StopAudioSamplingImpl();
			_samplingActive = false;
		}

		[Foreign(Language.Java)]
		static void StopAudioSamplingImpl()
		@{
			try {
				@{SetSamplingActive(bool):call(false)};

				android.media.AudioRecord audioRecord = (android.media.AudioRecord)@{_audioRecord:get()};
				if (audioRecord != null) {
					try {
						audioRecord.stop();
					} catch (Exception ignored) {
						// Already stopped
					}
					audioRecord.release();
					@{SetAudioRecord(Java.Object):call(null)};
				}

				Thread samplingThread = (Thread)@{_samplingThread:get()};
				if (samplingThread != null) {
					samplingThread.interrupt();
					@{SetSamplingThread(Java.Object):call(null)};
				}
			} catch (Exception e) {
				// Ignore errors during cleanup
				e.printStackTrace();
			}
		@}
	}
}
