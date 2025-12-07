using Uno;
using Uno.IO;
using Uno.UX;
using Uno.Threading;
using Uno.Compiler.ExportTargetInterop;

namespace Fuse.Audio
{
	[Require("source.include", "Apple/AudioHelper.h")]
	[Set("fileExtension", "mm")]
	internal extern(iOS) class AudioRecorderImpl
	{
		static string _currentRecordingPath = "";

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
				config.Channels
			);
		}

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

		public static void RequestRecordingPermission()
		{
			RequestRecordingPermissionNative();
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

		[Foreign(Language.ObjC)]
		static bool StartRecordingNative(string outputPath, int format, int sampleRate, int bitRate, int channels)
		@{
			return [[AudioHelper getInstance] startRecordingWithPath:outputPath
															  format:format
														  sampleRate:sampleRate
															 bitRate:bitRate
															channels:channels];
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
		static void RequestRecordingPermissionNative()
		@{
			[[AudioHelper getInstance] requestRecordingPermission];
		@}
	}
}
