using Uno;
using Uno.Threading;
using Fuse.Scripting;

namespace Fuse.Share
{
	class ShareResult
	{
		public bool Completed;
		public string ActivityType;

		public static Scripting.Object Converter(Context context, ShareResult result)
		{
			var obj = context.NewObject();
			obj["completed"] = result.Completed;
			obj["activityType"] = result.ActivityType;
			return obj;
		}
	}

	/**
		Guards the native callback paths so the promise settles exactly once,
		regardless of how many platform callbacks fire.
	*/
	class ShareResultCallback
	{
		readonly Promise<ShareResult> _promise;
		readonly object _mutex = new object();
		bool _settled;

		public ShareResultCallback(Promise<ShareResult> promise)
		{
			_promise = promise;
		}

		public void OnChosen(string activityType)
		{
			if (!TrySettle())
				return;

			_promise.Resolve(new ShareResult
			{
				Completed = true,
				ActivityType = activityType != null && activityType.Length > 0 ? activityType : null
			});
		}

		public void OnCancelled()
		{
			if (!TrySettle())
				return;

			_promise.Resolve(new ShareResult { Completed = false });
		}

		public void OnError(string message)
		{
			if (!TrySettle())
				return;

			_promise.Reject(new Exception(message != null && message.Length > 0 ? message : "Share failed."));
		}

		bool TrySettle()
		{
			lock (_mutex)
			{
				if (_settled)
					return false;

				_settled = true;
				ShareSessionGuard.End();
				return true;
			}
		}
	}
}
