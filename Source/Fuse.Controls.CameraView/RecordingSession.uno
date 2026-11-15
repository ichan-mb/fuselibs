using Uno;
using Uno.Threading;
using Fuse.Scripting;

namespace Fuse.Controls
{
	public abstract class RecordingSession
	{
		public abstract Future<Recording> Stop();
		public abstract Future<bool> Pause();
		public abstract Future<bool> Resume();
		public abstract Future<int> GetDuration();

		static RecordingSession()
		{
			ScriptClass.Register(typeof(RecordingSession),
				new ScriptPromise<RecordingSession,Recording,object>("stop", ExecutionThread.MainThread, stop, ConvertRecording),
				new ScriptPromise<RecordingSession,bool,object>("pause", ExecutionThread.MainThread, pause, ConvertBool),
				new ScriptPromise<RecordingSession,bool,object>("resume", ExecutionThread.MainThread, resume, ConvertBool),
				new ScriptPromise<RecordingSession,int,object>("getDuration", ExecutionThread.MainThread, getDuration, ConvertInt));
		}

		/**
			Stop recording video

			@scriptmethod stop()

			Returns a Promise that resloves to a @Recording
			```xml
				<CameraView ux:Name="Camera" />
				<JavaScript>
					Camera.startRecording()
						.then(function(recordingSession) {
							recordingSession.stop()
								.then(function(recording) { })
								.catch(function(err) { });
						})
						.catch(function(err) { }):
				</JavaScript>
			```
		*/
		static Future<Recording> stop(Context context, RecordingSession recordingSession, object[] args)
		{
			return recordingSession.Stop();
		}

		/**
			Pause the current recording

			@scriptmethod pause()

			Returns a promise that resolves to `true` when the recording was paused.
			Resolves to `false` when the recording cannot be paused (for example when
			it is already paused).
		*/
		static Future<bool> pause(Context context, RecordingSession recordingSession, object[] args)
		{
			return recordingSession.Pause();
		}

		/**
			Resume a paused recording

			@scriptmethod resume()

			Returns a promise that resolves to `true` when the recording was resumed.
			Resolves to `false` when the recording is not paused.
		*/
		static Future<bool> resume(Context context, RecordingSession recordingSession, object[] args)
		{
			return recordingSession.Resume();
		}

		/**
			Get the current recording duration

			@scriptmethod getDuration()

			Returns a promise that resolves to the duration in milliseconds.
		*/
		static Future<int> getDuration(Context context, RecordingSession recordingSession, object[] args)
		{
			return recordingSession.GetDuration();
		}

		static object ConvertBool(Context c, bool value)
		{
			return value;
		}

		static object ConvertInt(Context c, int value)
		{
			return value;
		}

		static object ConvertRecording(Context c, Recording recording)
		{
			return c.Unwrap(recording);
		}
	}
}
