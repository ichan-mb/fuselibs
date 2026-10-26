using Uno;
using Uno.UX;
using Uno.Compiler.ExportTargetInterop;
using Uno.Collections;
using Fuse.Android.Bindings;

namespace Fuse.Audio
{
	[ForeignInclude(Language.Java,
		"android.media.MediaPlayer",
		"android.media.AudioAttributes",
		"android.media.AudioFocusRequest",
		"android.media.AudioManager",
		"android.content.Context",
		"android.content.res.AssetFileDescriptor",
		"android.os.Build",
		"java.io.File",
		"java.io.FileOutputStream",
		"android.media.PlaybackParams",
		"android.media.audiofx.Visualizer")]
	internal extern(Android) static class AudioPlayerImpl
	{
		// Cache files created for byte-array sources, keyed by player callback id
		static readonly Dictionary<int, string> _tempFiles = new Dictionary<int, string>();

		// Active visualizers, keyed by player callback id
		static readonly Dictionary<int, Java.Object> _visualizers = new Dictionary<int, Java.Object>();

		// Streaming state, keyed by player callback id
		static readonly Dictionary<int, double> _durations = new Dictionary<int, double>();
		static readonly Dictionary<int, int> _bufferedPercent = new Dictionary<int, int>();
		static readonly Dictionary<int, bool> _buffering = new Dictionary<int, bool>();

		static bool _audioFocusHeld;
		static Java.Object _audioFocusListener;
		static Java.Object _audioFocusRequest;

		/**
			Creates a native player for the given source and starts preparing it.

			Returns the native handle, or null when the source could not be opened (in which
			case the error has already been reported through `AudioPlayer.OnNativeError`).

			`duration` is -1: Android reports the real duration asynchronously through
			`NativePrepared`.
		*/
		public static object LoadAudio(FileSource fileSource, string url, int callbackId, int generation, out double duration)
		{
			duration = -1.0;

			try
			{
				// Url takes precedence over File
				if (!string.IsNullOrEmpty(url))
					return LoadFromUrl(url, callbackId, generation);

				if (fileSource == null)
				{
					AudioPlayer.OnNativeError(callbackId, generation, "No audio file or url specified");
					return null;
				}

				var bundleFileSource = fileSource as BundleFileSource;
				if (bundleFileSource != null)
					return LoadFromBundle(AndroidDeviceInterop.OpenAssetFileDescriptor(bundleFileSource), callbackId, generation);

				return LoadFromBytes(fileSource.ReadAllBytes(), callbackId, generation);
			}
			catch (Exception e)
			{
				AudioPlayer.OnNativeError(callbackId, generation, "Failed to load audio: " + e.Message);
				return null;
			}
		}

		[Foreign(Language.Java)]
		static Java.Object LoadFromUrl(string url, int callbackId, int generation)
		@{
			android.media.MediaPlayer player = new android.media.MediaPlayer();
			try {
				player.setDataSource(url);

				ConfigurePlayer(player, callbackId, generation);
				player.prepareAsync();
				return player;
			} catch (Exception e) {
				ReleasePlayer(player);
				@{NativeError(int,int,string):call(callbackId, generation, "Failed to load audio: " + e.getMessage())};
				return null;
			}
		@}

		[Foreign(Language.Java)]
		static Java.Object LoadFromBundle(Java.Object fd, int callbackId, int generation)
		@{
			android.media.MediaPlayer player = new android.media.MediaPlayer();
			try {
				AssetFileDescriptor afd = (AssetFileDescriptor)fd;
				player.setDataSource(afd.getFileDescriptor(), afd.getStartOffset(), afd.getLength());
				afd.close();

				ConfigurePlayer(player, callbackId, generation);
				player.prepareAsync();
				return player;
			} catch (Exception e) {
				ReleasePlayer(player);
				@{NativeError(int,int,string):call(callbackId, generation, "Failed to load audio: " + e.getMessage())};
				return null;
			}
		@}

		[Foreign(Language.Java)]
		static Java.Object LoadFromBytes(byte[] data, int callbackId, int generation)
		@{
			android.media.MediaPlayer player = new android.media.MediaPlayer();
			try {
				java.io.File tempFile = java.io.File.createTempFile("audio", ".tmp", com.fuse.Activity.getRootActivity().getCacheDir());
				@{SetTempFilePath(int,string):call(callbackId, tempFile.getAbsolutePath())};

				java.io.FileOutputStream fos = new java.io.FileOutputStream(tempFile);
				fos.write(data.copyArray());
				fos.close();

				player.setDataSource(tempFile.getAbsolutePath());

				ConfigurePlayer(player, callbackId, generation);
				player.prepareAsync();
				return player;
			} catch (Exception e) {
				@{DeleteTempFileForPlayer(int):call(callbackId)};
				ReleasePlayer(player);
				@{NativeError(int,int,string):call(callbackId, generation, "Failed to load audio: " + e.getMessage())};
				return null;
			}
		@}

		[Foreign(Language.Java)]
		static void ConfigurePlayer(Java.Object playerHandle, int callbackId, int generation)
		@{
			android.media.MediaPlayer player = (android.media.MediaPlayer)playerHandle;
			final int cbId = callbackId;
			final int gen = generation;

			// Media usage, so the media volume keys and audio focus behave as expected
			android.media.AudioAttributes attributes = new android.media.AudioAttributes.Builder()
				.setUsage(android.media.AudioAttributes.USAGE_MEDIA)
				.setContentType(android.media.AudioAttributes.CONTENT_TYPE_MUSIC)
				.build();
			player.setAudioAttributes(attributes);

			player.setOnPreparedListener(new android.media.MediaPlayer.OnPreparedListener() {
				public void onPrepared(android.media.MediaPlayer mp) {
					@{NativePrepared(int,int,double):call(cbId, gen, mp.getDuration() / 1000.0)};
				}
			});

			player.setOnCompletionListener(new android.media.MediaPlayer.OnCompletionListener() {
				public void onCompletion(android.media.MediaPlayer mp) {
					@{NativeCompleted(int,int):call(cbId, gen)};
				}
			});

			player.setOnErrorListener(new android.media.MediaPlayer.OnErrorListener() {
				public boolean onError(android.media.MediaPlayer mp, int what, int extra) {
					@{NativeError(int,int,string):call(cbId, gen, "MediaPlayer error: " + what + ", " + extra)};
					return true;
				}
			});

			// Streaming progress. Local files report 100% immediately.
			player.setOnBufferingUpdateListener(new android.media.MediaPlayer.OnBufferingUpdateListener() {
				public void onBufferingUpdate(android.media.MediaPlayer mp, int percent) {
					@{SetBufferedPercent(int,int):call(cbId, percent)};
				}
			});

			player.setOnInfoListener(new android.media.MediaPlayer.OnInfoListener() {
				public boolean onInfo(android.media.MediaPlayer mp, int what, int extra) {
					if (what == android.media.MediaPlayer.MEDIA_INFO_BUFFERING_START)
						@{SetBufferingState(int,bool):call(cbId, true)};
					else if (what == android.media.MediaPlayer.MEDIA_INFO_BUFFERING_END)
						@{SetBufferingState(int,bool):call(cbId, false)};
					return false;
				}
			});
		@}

		static void NativePrepared(int callbackId, int generation, double duration)
		{
			_durations[callbackId] = duration;
			AudioPlayer.OnNativePrepared(callbackId, generation, duration);
		}

		static void NativeCompleted(int callbackId, int generation)
		{
			AudioPlayer.OnNativeCompleted(callbackId, generation);
		}

		static void NativeError(int callbackId, int generation, string message)
		{
			Fuse.Diagnostics.UserError("Android audio: " + message, null);
			AudioPlayer.OnNativeError(callbackId, generation, message);
		}

		static void NativeSample(int callbackId, int sampleRate, int channelCount, int format,
		                         int sampleCount, byte[] data, double timestamp)
		{
			AudioPlayer.OnNativeAudioSample(callbackId, sampleRate, channelCount, format, sampleCount, data, timestamp);
		}

		static void NativeAudioFocusChanged(int change)
		{
			AudioPlayer.OnNativeAudioFocusChanged(change);
		}

		static void SetTempFilePath(int callbackId, string path)
		{
			_tempFiles[callbackId] = path;
		}

		static void SetBufferedPercent(int callbackId, int percent)
		{
			_bufferedPercent[callbackId] = percent;
		}

		static void SetBufferingState(int callbackId, bool buffering)
		{
			_buffering[callbackId] = buffering;
		}

		static void DeleteTempFileForPlayer(int callbackId)
		{
			string path;
			if (!_tempFiles.TryGetValue(callbackId, out path))
				return;

			DeleteFileImpl(path);
			_tempFiles.Remove(callbackId);
		}

		[Foreign(Language.Java)]
		static void DeleteFileImpl(string path)
		@{
			try {
				java.io.File file = new java.io.File(path);
				if (file.exists()) file.delete();
			} catch (Exception e) {
				// Ignore cleanup errors
			}
		@}

		public static bool Resume(object handle, double rate)
		{
			var player = handle as Java.Object;
			if (player == null)
				return false;

			return ResumeImpl(player, (float)rate);
		}

		[Foreign(Language.Java)]
		static bool ResumeImpl(Java.Object playerHandle, float rate)
		@{
			try {
				android.media.MediaPlayer player = (android.media.MediaPlayer)playerHandle;

				if (rate != 1.0f && android.os.Build.VERSION.SDK_INT >= 23) {
					android.media.PlaybackParams parameters = new android.media.PlaybackParams();
					parameters.setSpeed(rate);
					player.setPlaybackParams(parameters);
				}

				player.start();
				return true;
			} catch (Exception e) {
				return false;
			}
		@}

		public static void SetRate(object handle, double rate)
		{
			var player = handle as Java.Object;
			if (player == null)
				return;

			SetRateImpl(player, (float)rate);
		}

		[Foreign(Language.Java)]
		static void SetRateImpl(Java.Object playerHandle, float rate)
		@{
			try {
				android.media.MediaPlayer player = (android.media.MediaPlayer)playerHandle;
				// Changing playback params on a paused player would start playback
				if (player.isPlaying() && android.os.Build.VERSION.SDK_INT >= 23) {
					android.media.PlaybackParams parameters = new android.media.PlaybackParams();
					parameters.setSpeed(rate);
					player.setPlaybackParams(parameters);
				}
			} catch (Exception e) {
				// Ignore errors
			}
		@}

		public static void SetLoop(object handle, bool loop)
		{
			var player = handle as Java.Object;
			if (player == null)
				return;

			SetLoopImpl(player, loop);
		}

		[Foreign(Language.Java)]
		static void SetLoopImpl(Java.Object playerHandle, bool loop)
		@{
			try {
				android.media.MediaPlayer player = (android.media.MediaPlayer)playerHandle;
				player.setLooping(loop);
			} catch (Exception e) {
				// Ignore errors
			}
		@}

		public static bool Pause(object handle)
		{
			var player = handle as Java.Object;
			if (player == null)
				return false;

			return PauseImpl(player);
		}

		[Foreign(Language.Java)]
		static bool PauseImpl(Java.Object playerHandle)
		@{
			try {
				android.media.MediaPlayer player = (android.media.MediaPlayer)playerHandle;
				if (player.isPlaying()) {
					player.pause();
					return true;
				}
				return false;
			} catch (Exception e) {
				return false;
			}
		@}

		public static void Stop(object handle)
		{
			var player = handle as Java.Object;
			if (player == null)
				return;

			StopImpl(player);
		}

		[Foreign(Language.Java)]
		static void StopImpl(Java.Object playerHandle)
		@{
			try {
				android.media.MediaPlayer player = (android.media.MediaPlayer)playerHandle;
				// Pause instead of stop: after stop() the player has to be prepared again,
				// which would restart loading and re-trigger the prepared callback.
				if (player.isPlaying())
					player.pause();
				player.seekTo(0);
			} catch (Exception e) {
				// Ignore errors during stop
			}
		@}

		public static void SetVolume(object handle, float volume, float balance)
		{
			var player = handle as Java.Object;
			if (player == null)
				return;

			SetVolumeImpl(player, volume, balance);
		}

		[Foreign(Language.Java)]
		static void SetVolumeImpl(Java.Object playerHandle, float volume, float balance)
		@{
			try {
				android.media.MediaPlayer player = (android.media.MediaPlayer)playerHandle;

				// MediaPlayer only has per-channel volume, so balance is a pan
				float left = volume;
				float right = volume;
				if (balance < 0.0f)
					right = volume * (1.0f + balance);
				else if (balance > 0.0f)
					left = volume * (1.0f - balance);

				player.setVolume(left, right);
			} catch (Exception e) {
				// Ignore errors
			}
		@}

		public static void SetPosition(object handle, double positionInSeconds)
		{
			var player = handle as Java.Object;
			if (player == null)
				return;

			SetPositionImpl(player, (int)(positionInSeconds * 1000.0));
		}

		[Foreign(Language.Java)]
		static void SetPositionImpl(Java.Object playerHandle, int positionMs)
		@{
			try {
				android.media.MediaPlayer player = (android.media.MediaPlayer)playerHandle;
				player.seekTo(positionMs);
			} catch (Exception e) {
				// Ignore errors
			}
		@}

		public static double GetCurrentPosition(object handle)
		{
			var player = handle as Java.Object;
			if (player == null)
				return -1.0;

			return GetCurrentPositionImpl(player) / 1000.0;
		}

		[Foreign(Language.Java)]
		static int GetCurrentPositionImpl(Java.Object playerHandle)
		@{
			try {
				android.media.MediaPlayer player = (android.media.MediaPlayer)playerHandle;
				return player.getCurrentPosition();
			} catch (Exception e) {
				return -1;
			}
		@}

		public static double GetDuration(object handle)
		{
			var player = handle as Java.Object;
			if (player == null)
				return -1.0;

			var milliseconds = GetDurationImpl(player);
			if (milliseconds <= 0)
				return -1.0;

			return milliseconds / 1000.0;
		}

		[Foreign(Language.Java)]
		static int GetDurationImpl(Java.Object playerHandle)
		@{
			try {
				android.media.MediaPlayer player = (android.media.MediaPlayer)playerHandle;
				return player.getDuration();
			} catch (Exception e) {
				return -1;
			}
		@}

		/** Gets the number of seconds buffered, or -1 when unknown (local files report full length) */
		public static double GetBuffered(object handle, int callbackId)
		{
			int percent;
			if (!_bufferedPercent.TryGetValue(callbackId, out percent))
				return -1.0;

			double duration;
			if (!_durations.TryGetValue(callbackId, out duration) || duration <= 0.0)
				return -1.0;

			return duration * percent / 100.0;
		}

		/** Gets whether playback is waiting for buffered data */
		public static bool IsBuffering(object handle, int callbackId)
		{
			bool buffering;
			return _buffering.TryGetValue(callbackId, out buffering) && buffering;
		}

		/** MediaPlayer reports playback errors through its listener, not by polling */
		public static string GetError(object handle)
		{
			return "";
		}

		/** Releases the native player, its cache file and its visualizer */
		public static void Release(object handle, int callbackId)
		{
			var player = handle as Java.Object;
			if (player == null)
				return;

			StopSamplingImpl(callbackId);
			ReleaseImpl(player);
			DeleteTempFileForPlayer(callbackId);

			_durations.Remove(callbackId);
			_bufferedPercent.Remove(callbackId);
			_buffering.Remove(callbackId);
		}

		[Foreign(Language.Java)]
		static void ReleaseImpl(Java.Object playerHandle)
		@{
			try {
				android.media.MediaPlayer player = (android.media.MediaPlayer)playerHandle;
				player.reset();
				player.release();
			} catch (Exception e) {
				// Ignore errors during release
			}
		@}

		[Foreign(Language.Java)]
		static void ReleasePlayer(Java.Object playerHandle)
		@{
			try {
				android.media.MediaPlayer player = (android.media.MediaPlayer)playerHandle;
				player.reset();
				player.release();
			} catch (Exception e) {
				// Ignore errors during release
			}
		@}

		// ---- Audio focus ----

		public static void ActivateAudioSession()
		{
			if (_audioFocusHeld)
				return;

			_audioFocusHeld = AcquireAudioFocusImpl();
		}

		public static void DeactivateAudioSession()
		{
			if (!_audioFocusHeld)
				return;

			_audioFocusHeld = false;
			AbandonAudioFocusImpl();
		}

		static void SetFocusListener(Java.Object listener)
		{
			_audioFocusListener = listener;
		}

		static void SetFocusRequest(Java.Object request)
		{
			_audioFocusRequest = request;
		}

		[Foreign(Language.Java)]
		static bool AcquireAudioFocusImpl()
		@{
			try {
				Context context = com.fuse.Activity.getRootActivity();
				AudioManager audioManager = (AudioManager)context.getSystemService(Context.AUDIO_SERVICE);
				if (audioManager == null)
					return false;

				AudioManager.OnAudioFocusChangeListener listener = new AudioManager.OnAudioFocusChangeListener() {
					public void onAudioFocusChange(int focusChange) {
						int change;
						switch (focusChange) {
							case AudioManager.AUDIOFOCUS_GAIN:
								change = 3; // Gained
								break;
							case AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK:
								change = 2; // CanDuck
								break;
							case AudioManager.AUDIOFOCUS_LOSS_TRANSIENT:
								change = 1; // LostTransient
								break;
							default:
								change = 0; // Lost
								break;
						}
						@{NativeAudioFocusChanged(int):call(change)};
					}
				};
				@{SetFocusListener(Java.Object):call(listener)};

				if (Build.VERSION.SDK_INT >= 26) {
					AudioAttributes attributes = new AudioAttributes.Builder()
						.setUsage(AudioAttributes.USAGE_MEDIA)
						.setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
						.build();

					AudioFocusRequest request = new AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
						.setAudioAttributes(attributes)
						.setOnAudioFocusChangeListener(listener)
						.build();

					@{SetFocusRequest(Java.Object):call(request)};

					return audioManager.requestAudioFocus(request) == AudioManager.AUDIOFOCUS_REQUEST_GRANTED;
				}

				return audioManager.requestAudioFocus(listener, AudioManager.STREAM_MUSIC,
					AudioManager.AUDIOFOCUS_GAIN) == AudioManager.AUDIOFOCUS_REQUEST_GRANTED;
			} catch (Exception e) {
				return false;
			}
		@}

		[Foreign(Language.Java)]
		static void AbandonAudioFocusImpl()
		@{
			try {
				Context context = com.fuse.Activity.getRootActivity();
				AudioManager audioManager = (AudioManager)context.getSystemService(Context.AUDIO_SERVICE);
				if (audioManager == null)
					return;

				if (Build.VERSION.SDK_INT >= 26) {
					AudioFocusRequest request = (AudioFocusRequest)@{_audioFocusRequest:get()};
					if (request != null)
						audioManager.abandonAudioFocusRequest(request);
					@{SetFocusRequest(Java.Object):call(null)};
				} else {
					AudioManager.OnAudioFocusChangeListener listener =
						(AudioManager.OnAudioFocusChangeListener)@{_audioFocusListener:get()};
					if (listener != null)
						audioManager.abandonAudioFocus(listener);
				}

				@{SetFocusListener(Java.Object):call(null)};
			} catch (Exception e) {
				// Ignore errors while abandoning focus
			}
		@}

		// ---- Audio sampling ----

		public static void StartAudioSampling(object handle, int callbackId, int sampleRate, int channelCount,
		                                      int format, int bufferSize, int updateIntervalMs)
		{
			var player = handle as Java.Object;
			if (player == null)
				return;

			if (_visualizers.ContainsKey(callbackId))
				return;

			StartAudioSamplingImpl(player, callbackId, sampleRate, channelCount, format, bufferSize, updateIntervalMs);
		}

		[Foreign(Language.Java)]
		static void StartAudioSamplingImpl(Java.Object playerHandle, int callbackId, int sampleRate, int channelCount,
		                                   int format, int bufferSize, int updateIntervalMs)
		@{
			try {
				android.media.MediaPlayer player = (android.media.MediaPlayer)playerHandle;
				Visualizer visualizer = new Visualizer(player.getAudioSessionId());

				// Capture size must be a power of two between 128 and 1024
				int captureSize = Math.min(1024, Math.max(128, bufferSize));
				captureSize = Integer.highestOneBit(captureSize);
				visualizer.setCaptureSize(captureSize);

				final int cbId = callbackId;

				// getMaxCaptureRate() is in milliHertz (20000 = 20 Hz). Aim for one callback
				// per update interval, clamped to what the device supports.
				int rateMilliHz = Math.min(Visualizer.getMaxCaptureRate(),
					1000000 / Math.max(10, updateIntervalMs));

				visualizer.setDataCaptureListener(new Visualizer.OnDataCaptureListener() {
					public void onWaveFormDataCapture(Visualizer v, byte[] waveform, int samplingRate) {
						// The visualizer reports unsigned 8-bit samples. Convert them to
						// 16-bit PCM so AudioSample's amplitude helpers are meaningful.
						byte[] pcm = new byte[waveform.length * 2];
						for (int i = 0; i < waveform.length; i++) {
							int value = ((waveform[i] & 0xFF) - 128) << 8;
							pcm[i * 2] = (byte)(value & 0xFF);
							pcm[i * 2 + 1] = (byte)((value >> 8) & 0xFF);
						}
						@{NativeSample(int,int,int,int,byte[],double):call(cbId, samplingRate, 1, 0, waveform.length, pcm, System.currentTimeMillis())};
					}

					public void onFftDataCapture(Visualizer v, byte[] fft, int samplingRate) {
						// Waveform data is used for amplitude metering
					}
				}, rateMilliHz, true, false);

				visualizer.setEnabled(true);
				@{SetVisualizer(int,Java.Object):call(callbackId, visualizer)};
			} catch (Exception e) {
				// The visualizer is not supported on all devices
			}
		@}

		static void SetVisualizer(int callbackId, Java.Object visualizer)
		{
			_visualizers[callbackId] = visualizer;
		}

		public static void StopAudioSampling(object handle, int callbackId)
		{
			StopSamplingImpl(callbackId);
		}

		static void StopSamplingImpl(int callbackId)
		{
			Java.Object visualizer;
			if (!_visualizers.TryGetValue(callbackId, out visualizer))
				return;

			_visualizers.Remove(callbackId);
			ReleaseVisualizerImpl(visualizer);
		}

		[Foreign(Language.Java)]
		static void ReleaseVisualizerImpl(Java.Object visualizerHandle)
		@{
			try {
				Visualizer visualizer = (Visualizer)visualizerHandle;
				visualizer.setEnabled(false);
				visualizer.release();
			} catch (Exception e) {
				// Ignore errors during cleanup
			}
		@}
	}
}
