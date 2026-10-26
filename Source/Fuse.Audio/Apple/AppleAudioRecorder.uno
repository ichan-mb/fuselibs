using Uno;
using Uno.IO;
using Uno.Collections;
using Uno.Compiler.ExportTargetInterop;

namespace Fuse.Audio
{
	[Require("source.include", "Apple/AudioHelper.h")]
	[Require("source.include", "Apple/AudioRecorderCallbacks.h")]
	[Set("fileExtension", "mm")]
	internal extern(iOS) class AudioRecorderImpl
	{
		static string _currentRecordingPath = "";
		static bool _samplingActive = false;

		// Pending permission requests, keyed by id so the native callback can find them
		static readonly Dictionary<int, Action<bool>> _permissionCallbacks = new Dictionary<int, Action<bool>>();
		static int _nextPermissionRequestId;

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
				config.MaxDuration
			);
		}

		/** Gets the current input peak, normalized to 0..1 */
		public static float GetAmplitude()
		{
			var recorder = GetCurrentRecorder();
			if (recorder == null)
				return 0.0f;

			return GetAmplitudeImpl(recorder);
		}

		[Foreign(Language.ObjC)]
		static float GetAmplitudeImpl(ObjC.Object recorderHandle)
		@{
			@try {
				AVAudioRecorder* recorder = (AVAudioRecorder*)recorderHandle;
				[recorder updateMeters];

				// Peak power is in dBFS (-160..0); normalize it to 0..1
				double db = [recorder peakPowerForChannel:0];
				if (db < -60.0)
					db = -60.0;

				return (float)pow(10.0, db / 20.0);
			}
			@catch (NSException* exception) {
				return 0.0f;
			}
		@}

		[Foreign(Language.ObjC)]
		static ObjC.Object GetCurrentRecorder()
		@{
			return [[AudioHelper getInstance] currentRecorder];
		@}

		static void InstallRecorderCallbacks(ObjC.Object recorder)
		{
			InstallRecorderCallbacksImpl(recorder,
				() => AudioRecorder.OnNativeRecordingCompleted(),
				message => AudioRecorder.OnNativeRecordingError(message));
		}

		[Foreign(Language.ObjC)]
		static void InstallRecorderCallbacksImpl(ObjC.Object recorderHandle, Action onCompleted, Action<string> onError)
		@{
			UnoAudioRecorderInstallCallbacks((AVAudioRecorder*)recorderHandle, onCompleted, onError);
		@}

		public static string StopRecording()
		{
			var filePath = StopRecordingNative();
			if (!string.IsNullOrEmpty(filePath))
			{
				return filePath;
			}
			return "";
		}

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
			var requestId = ++_nextPermissionRequestId;
			_permissionCallbacks[requestId] = callback;
			RequestRecordingPermissionNative(requestId);
		}

		static void NativePermissionResult(int requestId, bool granted)
		{
			Action<bool> callback;
			if (!_permissionCallbacks.TryGetValue(requestId, out callback))
				return;

			_permissionCallbacks.Remove(requestId);
			callback(granted);
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
				case AudioFormat.MP3: return "m4a"; // iOS doesn't support MP3 recording, use M4A
				case AudioFormat.M4A: return "m4a";
				default: return "m4a";
			}
		}

		[Foreign(Language.ObjC)]
		static string GetRecordingDirectory()
		@{
			NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
			NSString *documentsDirectory = [paths objectAtIndex:0];
			NSString *recordingsDirectory = [documentsDirectory stringByAppendingPathComponent:@"Recordings"];

			// Create directory if it doesn't exist
			NSFileManager *fileManager = [NSFileManager defaultManager];
			if (![fileManager fileExistsAtPath:recordingsDirectory]) {
				[fileManager createDirectoryAtPath:recordingsDirectory
					   withIntermediateDirectories:YES
									   attributes:nil
											error:nil];
			}

			return recordingsDirectory;
		@}

		static bool StartRecordingNative(string outputPath, int format, int sampleRate, int bitRate, int channels,
		                                 int source, double maxDuration)
		{
			if (!StartRecordingNativeImpl(outputPath, format, sampleRate, bitRate, channels, source, maxDuration))
				return false;

			// Report when the recorder stops itself (max duration) or fails to encode
			var recorder = GetCurrentRecorder();
			if (recorder != null)
				InstallRecorderCallbacks(recorder);

			return true;
		}

		[Foreign(Language.ObjC)]
		static bool StartRecordingNativeImpl(string outputPath, int format, int sampleRate, int bitRate, int channels,
		                                     int source, double maxDuration)
		@{
			return [[AudioHelper getInstance] startRecordingWithPath:outputPath
			                                                  format:format
			                                              sampleRate:sampleRate
			                                                 bitRate:bitRate
			                                                channels:channels
			                                                  source:source
			                                             maxDuration:maxDuration];
		@}

		[Foreign(Language.ObjC)]
		static string StopRecordingNative()
		@{
			return [[AudioHelper getInstance] stopRecording];
		@}

		[Foreign(Language.ObjC)]
		static bool PauseRecordingNative()
		@{
			return [[AudioHelper getInstance] pauseRecording];
		@}

		[Foreign(Language.ObjC)]
		static bool ResumeRecordingNative()
		@{
			return [[AudioHelper getInstance] resumeRecording];
		@}

		[Foreign(Language.ObjC)]
		static bool HasRecordingPermissionNative()
		@{
			return [[AudioHelper getInstance] hasRecordingPermission];
		@}

		[Foreign(Language.ObjC)]
		static void RequestRecordingPermissionNative(int requestId)
		@{
			[[AVAudioSession sharedInstance] requestRecordPermission:^(BOOL granted) {
				// The completion handler is not guaranteed to run on the main thread
				dispatch_async(dispatch_get_main_queue(), ^{
					@{NativePermissionResult(int,bool):call(requestId, granted != NO)};
				});
			}];
		@}

		public static void StartAudioSampling(int sampleRate, int channelCount, int format,
		                                     int bufferSize, int updateIntervalMs)
		{
			if (_samplingActive)
				return;

			StartAudioSamplingImpl(sampleRate, channelCount, format, bufferSize, updateIntervalMs);
		}

		[Foreign(Language.ObjC)]
		static void StartAudioSamplingImpl(int sampleRate, int channelCount, int format,
		                                  int bufferSize, int updateIntervalMs)
		@{
			@try {
				// Use AVAudioEngine for real-time audio sampling during recording
				AVAudioEngine* audioEngine = [[AVAudioEngine alloc] init];
				AVAudioInputNode* inputNode = [audioEngine inputNode];

				// Set up audio format for input
				AVAudioFormat* recordingFormat = [[AVAudioFormat alloc] initWithCommonFormat:format == 0 ? AVAudioPCMFormatInt16 : AVAudioPCMFormatInt32
																						sampleRate:sampleRate
																						  channels:channelCount
																						interleaved:YES];

				// Install tap on input node to capture audio samples
				[inputNode installTapOnBus:0
								bufferSize:bufferSize
									format:recordingFormat
									 block:^(AVAudioPCMBuffer* buffer, AVAudioTime* when) {
					// Extract sample data from buffer
					if (buffer.frameLength > 0) {
						int16_t* channelData = buffer.int16ChannelData[0];
						NSData* data = [NSData dataWithBytes:channelData
													  length:buffer.frameLength * sizeof(int16_t) * channelCount];

						// Get current timestamp
						double timestamp = [[NSDate date] timeIntervalSince1970] * 1000.0;
						@{OnRecordingAudioSampleCaptured(int,int,int,int,byte[],double):Call(sampleRate, channelCount, format, (int)buffer.frameLength, [::StrongUnoArray strongUnoArrayWithUnoArray: uArray::New(@{byte:typeof}->Array(), (int) data.length, data.bytes)
							getAt: ^ id (::uArray* arr, int i) { return ::uObjC::Box<uint8_t>(arr->Item<uint8_t>(i)); }
							setAt: ^ (::uArray* arr, int i, id obj) { arr->Item<uint8_t>(i) = ::uObjC::Unbox<uint8_t>(obj); }
						], timestamp)};
					}
				}];

				NSError* error = nil;
				if ([audioEngine startAndReturnError:&error]) {
					[[AudioHelper getInstance] setSamplingAudioEngine:audioEngine];
					@{SetSamplingActive(bool):call(true)};
				}
			}
			@catch (NSException* exception) {
				// Audio sampling might not be supported in all configurations
			}
		@}

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

		[Foreign(Language.ObjC)]
		static void StopAudioSamplingImpl()
		@{
			@try {
				AVAudioEngine* audioEngine = [[AudioHelper getInstance] getSamplingAudioEngine];
				if (audioEngine) {
					[[audioEngine inputNode] removeTapOnBus:0];
					[audioEngine stop];
					[[AudioHelper getInstance] setSamplingAudioEngine:nil];
				}
			}
			@catch (NSException* exception) {
				// Ignore errors during cleanup
			}
		@}
	}
}
