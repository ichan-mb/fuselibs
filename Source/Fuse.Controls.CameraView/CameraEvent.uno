using Uno;

namespace Fuse.Controls
{
	/**
		An event reported while monitoring the camera state.

		Use `CameraView.startErrorMonitoring()` to receive these events.
	*/
	public class CameraEvent
	{
		public const string TypeName = "type";
		public const string ReasonName = "reason";
		public const string MessageName = "message";

		/** The camera reported a problem and may not be usable. */
		public const string TypeError = "error";
		/** The camera session was interrupted, for example by a phone call or another app. */
		public const string TypeInterrupted = "interrupted";
		/** A previous interruption ended and the camera is available again. */
		public const string TypeResumed = "resumed";

		public readonly string Type;
		public readonly string Reason;
		public readonly string Message;

		public CameraEvent(string type, string reason, string message)
		{
			Type = type;
			Reason = reason;
			Message = message;
		}
	}
}
