using Uno;
using Uno.UX;
using Fuse.Maps;

namespace Fuse.Maps.Google
{
	/**
		Google Maps provider for @MapView.

		On iOS this uses the Google Maps SDK for iOS. On Android it delegates to
		the platform's native provider, which already uses Google Maps.

		Register it by referencing `Fuse.Maps.Google` in your project. The provider
		is registered automatically and can then be selected per map:

		```XML
		<MapView Provider="Google" />
		```

		*Note:* On iOS the Google Maps SDK requires a CocoaPods build. Set the API
		key with `GoogleMapProvider.ApiKey` before the map is created, or add
		`GoogleMapsAPIKey` to your `Info.plist`.

		@seealso Fuse.Controls.MapView
	*/
	public class GoogleMapProvider : IMapProvider
	{
		/**
			The Google Maps API key used on iOS.

			When this is not set, `GoogleMapsAPIKey` is read from `Info.plist`.
		*/
		public static string ApiKey;

		public string Name
		{
			get { return "Google"; }
		}

		public IMapView Create(IMapViewHost host)
		{
			if defined(iOS)
				return Fuse.Maps.Google.iOS.GoogleMapView.Create(host);
			else
			{
				var native = MapProviders.Get("Native");
				return native != null ? native.Create(host) : null;
			}
		}
	}

	/**
		Registers the Google Maps provider when `Fuse.Maps.Google` is referenced.
	*/
	[UXGlobalModule]
	public class GoogleMapsBootstrap
	{
		public GoogleMapsBootstrap()
		{
			MapProviders.Register(new GoogleMapProvider());
		}
	}
}
