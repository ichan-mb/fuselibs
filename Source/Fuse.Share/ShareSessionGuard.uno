using Uno;

namespace Fuse.Share
{
	/**
		The system share sheets are modal. Allowing a second request while one is
		still open produces multiple platforms sessions/windows and unpredictable
		results, so the module allows only one active share at a time.
	*/
	static class ShareSessionGuard
	{
		static readonly object _mutex = new object();
		static bool _active;

		public static bool TryBegin()
		{
			lock (_mutex)
			{
				if (_active)
					return false;

				_active = true;
				return true;
			}
		}

		public static void End()
		{
			lock (_mutex)
			{
				_active = false;
			}
		}
	}
}
