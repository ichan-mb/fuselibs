using Uno;

namespace Fuse.Platform
{
	/** InterApp events.

		@seealso Fuse.Reactive.FuseJS.InterApp
	*/
	public static class InterApp
	{
		/** Triggered when the application receives an URI from another app. */
		public static event Action<string> ReceivedURI;

		/**
			Triggered with the URI and the metadata reported by the platform.

			The arguments include the source application when available, whether
			the URI arrived as a universal link or Android App Link, whether it
			was opened in place, and whether the app was starting.
		*/
		public static event Action<Uno.Platform.EventSources.InterAppInvokeArgs> ReceivedURIData;

		static InterApp()
		{
			Uno.Platform.EventSources.InterAppInvoke.ReceivedURIData += OnReceivedURIData;
		}

		static void OnReceivedURIData(object sender, Uno.Platform.EventSources.InterAppInvokeArgs args)
		{
			var legacy = ReceivedURI;
			if (legacy != null)
				legacy(args.Uri);

			var handler = ReceivedURIData;
			if (handler != null)
				handler(args);
		}
	}
}
