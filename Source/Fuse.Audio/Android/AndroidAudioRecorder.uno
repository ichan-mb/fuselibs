using Uno;
using Uno.IO;
using Uno.UX;
using Uno.Threading;
using Fuse.Android.Bindings;
using Uno.Compiler.ExportTargetInterop;

namespace Fuse.Audio
{
	[ForeignInclude(Language.Java,
					"java.io.File",
					"java.io.IOException",
					"android.media.MediaRecorder",
					"android.os.Environment",
					"android.content.Context",
					"android.content.pm.PackageManager",
					"android.Manifest",
					"androidx.core.app.ActivityCompat",
					"androidx.core.content.ContextCompat",
					"android.app.Activity")]
	internal extern(Android) class AudioRecorderImpl
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
			if (StopRecordingNative())
			{
				return _currentRecordingPath;
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
		static bool StartRecordingNative(string outputPath, int format, int sampleRate, int bitRate, int channels)
		@{
			try {
				Context context = com.fuse.Activity.getRootActivity();

				// Stop any existing recording
				StopRecordingNative();

				// Create new MediaRecorder instance
				AudioRecorderState.mediaRecorder = new MediaRecorder();

				// Set audio source
				AudioRecorderState.mediaRecorder.setAudioSource(MediaRecorder.AudioSource.MIC);

				// Set output format based on the format parameter
				switch (format) {
					case 0: // WAV - not directly supported by MediaRecorder, use AAC
					case 1: // AAC
						AudioRecorderState.mediaRecorder.setOutputFormat(MediaRecorder.OutputFormat.AAC_ADTS);
						AudioRecorderState.mediaRecorder.setAudioEncoder(MediaRecorder.AudioEncoder.AAC);
						break;
					case 2: // MP3 - not directly supported by MediaRecorder, use AAC
						AudioRecorderState.mediaRecorder.setOutputFormat(MediaRecorder.OutputFormat.AAC_ADTS);
						AudioRecorderState.mediaRecorder.setAudioEncoder(MediaRecorder.AudioEncoder.AAC);
						break;
					case 3: // M4A
					default:
						AudioRecorderState.mediaRecorder.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4);
						AudioRecorderState.mediaRecorder.setAudioEncoder(MediaRecorder.AudioEncoder.AAC);
						break;
				}

				// Set recording parameters
				AudioRecorderState.mediaRecorder.setAudioSamplingRate(sampleRate);
				AudioRecorderState.mediaRecorder.setAudioEncodingBitRate(bitRate);
				AudioRecorderState.mediaRecorder.setAudioChannels(channels);

				// Set output file
				AudioRecorderState.mediaRecorder.setOutputFile(outputPath);

				// Prepare and start
				AudioRecorderState.mediaRecorder.prepare();
				AudioRecorderState.mediaRecorder.start();

				return true;
			} catch (Exception e) {
				e.printStackTrace();
				StopRecordingNative();
				return false;
			}
		@}

		[Foreign(Language.Java)]
		static bool StopRecordingNative()
		@{
			try {
				if (AudioRecorderState.mediaRecorder != null) {
					AudioRecorderState.mediaRecorder.stop();
					AudioRecorderState.mediaRecorder.release();
					AudioRecorderState.mediaRecorder = null;
					return true;
				}
				return false;
			} catch (Exception e) {
				e.printStackTrace();
				if (AudioRecorderState.mediaRecorder != null) {
					try {
						AudioRecorderState.mediaRecorder.release();
					} catch (Exception ex) {
						ex.printStackTrace();
					}
					AudioRecorderState.mediaRecorder = null;
				}
				return false;
			}
		@}

		[Foreign(Language.Java)]
		static bool PauseRecordingNative()
		@{
			try {
				if (AudioRecorderState.mediaRecorder != null && android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.N) {
					AudioRecorderState.mediaRecorder.pause();
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
				if (AudioRecorderState.mediaRecorder != null && android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.N) {
					AudioRecorderState.mediaRecorder.resume();
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
			int permissionCheck = ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO);
			int storagePermissionCheck = ContextCompat.checkSelfPermission(context, Manifest.permission.WRITE_EXTERNAL_STORAGE);
			return permissionCheck == PackageManager.PERMISSION_GRANTED &&
				   storagePermissionCheck == PackageManager.PERMISSION_GRANTED;
		@}

		[Foreign(Language.Java)]
		static void RequestRecordingPermissionNative()
		@{
			Activity activity = com.fuse.Activity.getRootActivity();
			String[] permissions = {
				Manifest.permission.RECORD_AUDIO,
				Manifest.permission.WRITE_EXTERNAL_STORAGE
			};
			ActivityCompat.requestPermissions(activity, permissions, 1001);
		@}
	}

	[Foreign(Language.Java)]
	extern(Android) static class AudioRecorderState
	{
		[Foreign(Language.Java)]
		public static void Initialize()
		@{
			// Static MediaRecorder instance holder
			public static android.media.MediaRecorder mediaRecorder = null;
		@}
	}
}
