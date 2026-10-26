using Uno;
using Uno.UX;
using Fuse.Scripting;

namespace Fuse
{
	/**
		JavaScript access to @AudioRecorder.

		Properties are not exposed directly to JavaScript; use these methods instead, and
		use `{Property recorder.X}` bindings when you need live values in UX.
	*/
	public partial class AudioRecorder
	{
		static AudioRecorder()
		{
			ScriptClass.Register(typeof(AudioRecorder),
				new ScriptMethod<AudioRecorder>("start", start),
				new ScriptMethod<AudioRecorder>("stop", stop),
				new ScriptMethod<AudioRecorder>("pause", pause),
				new ScriptMethod<AudioRecorder>("resume", resume),
				new ScriptMethod<AudioRecorder>("hasPermission", hasPermission),
				new ScriptMethod<AudioRecorder>("requestPermission", requestPermission),
				new ScriptMethod<AudioRecorder>("getDuration", getDuration),
				new ScriptMethod<AudioRecorder>("getLevel", getLevel),
				new ScriptMethod<AudioRecorder>("getState", getState));
		}

		/** Starts recording. @scriptmethod start() */
		static void start(AudioRecorder recorder)
		{
			recorder.StartRecording();
		}

		/** Stops recording. @scriptmethod stop() */
		static void stop(AudioRecorder recorder)
		{
			recorder.StopRecording();
		}

		/** Pauses recording (Android API 24+). @scriptmethod pause() */
		static void pause(AudioRecorder recorder)
		{
			recorder.PauseRecording();
		}

		/** Resumes a paused recording. @scriptmethod resume() */
		static void resume(AudioRecorder recorder)
		{
			recorder.ResumeRecording();
		}

		/** Checks whether the microphone permission is granted. @scriptmethod hasPermission() */
		static object hasPermission(Context c, AudioRecorder recorder, object[] args)
		{
			return recorder.HasRecordingPermission();
		}

		/** Requests the microphone permission. The result arrives through the PermissionChanged event. @scriptmethod requestPermission() */
		static void requestPermission(AudioRecorder recorder)
		{
			recorder.RequestRecordingPermission();
		}

		/** Gets the current (or last) recording duration in seconds. @scriptmethod getDuration() */
		static object getDuration(Context c, AudioRecorder recorder, object[] args)
		{
			return recorder.RecordingDuration;
		}

		/** Gets the latest input level, 0 to 1. @scriptmethod getLevel() */
		static object getLevel(Context c, AudioRecorder recorder, object[] args)
		{
			return (double)recorder.RecordingLevel;
		}

		/** Gets the recording state as a string: "Stopped", "Recording" or "Paused". @scriptmethod getState() */
		static object getState(Context c, AudioRecorder recorder, object[] args)
		{
			switch (recorder.CurrentState)
			{
				case RecordingState.Recording: return "Recording";
				case RecordingState.Paused: return "Paused";
				default: return "Stopped";
			}
		}
	}
}
