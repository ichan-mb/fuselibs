using Uno;
using Uno.Collections;
using Uno.Threading;
using Fuse.Controls;
using Fuse.Controls.Native;

namespace Fuse.Maps
{
	/**
		The host side of a map. A provider calls these methods to report changes and
		user interaction back to the @MapView that owns it.
	*/
	public interface IMapViewHost
	{
		ObservableList<MapMarker> Markers { get; }
		ObservableList<MapOverlay> Overlays { get; }
		ObservableList<MapRoute> Routes { get; }

		/** Called when the provider is disposed, so the host can release it. */
		void OnViewDisposed(IMapView view);

		/** Called when the camera has settled and the host should refresh its camera state and bounds. */
		void OnCameraChanged();

		void OnMarkerTapped(int id, string label);
		void OnMarkerSelected(int id);
		void OnMarkerDeselected(int id);
		void OnMarkerDragStarted(int id);
		void OnMarkerDragging(int id, double latitude, double longitude);
		void OnMarkerDragEnded(int id, double latitude, double longitude);
		void OnOverlayTapped(int id);
		void OnLocationTapped(double latitude, double longitude);
		void OnLocationLongPress(double latitude, double longitude);
		void OnRouteResult(int uid, int generation, string encoded);
		void OnRouteError(int uid, int generation, string message);
	}

	/**
		The native map implementation contract.

		Implement this interface to add a map provider that is not the platform's
		default, and register it with @MapProviders. A provider is responsible for
		creating and owning the native view, applying the camera and configuration
		properties, and reporting events through the @IMapViewHost it was given.

		@advanced
	*/
	public interface IMapView : IView
	{
		MapStyle Style { get; set; }

		double Latitude { get; }
		double Longitude { get; }
		double Bearing { get; }
		double Tilt { get; }
		double Zoom { get; }
		bool IsReady { get; }

		void SetLocation(double latitude, double longitude);
		void MoveTo(double latitude, double longitude, double zoomlevel, double tilt, double orientation);

		bool ShowMyLocation { get; set; }
		bool ShowMyLocationButton { get; set; }
		bool ShowCompass { get; set; }
		bool AllowZoom { get; set; }
		bool AllowTilt { get; set; }
		bool AllowRotate { get; set; }
		bool AllowScroll { get; set; }
		float4 Padding { get; set; }
		double MinZoom { get; set; }
		double MaxZoom { get; set; }

		void UpdateMarkers();
		void UpdateOverlays();
		void UpdateRoutes();
		void ShowAllMarkers();
		void Snapshot(Action<string> onSuccess, Action<string> onError);

		void AnimateTo(double latitude, double longitude, double zoomlevel, double tilt, double orientation, double duration);
		void CancelAnimation();
		void ShowBounds(double minLatitude, double minLongitude, double maxLatitude, double maxLongitude);
		MapBounds GetVisibleBounds();
		void ZoomBy(double delta, double duration);
		void ScrollBy(float dx, float dy, double duration);

		Future<MapPlace[]> Geocode(string query);
		Future<MapPlace[]> ReverseGeocode(double latitude, double longitude);
		Future<MapRouteResult> CalculateRoute(double fromLatitude, double fromLongitude, double toLatitude, double toLongitude, RouteMode mode);

		void SelectMarker(int id);
		void DeselectMarker(int id);

		Action OnReady { get; set; }
	}

	/**
		Creates the native map implementation used by a @MapView.

		@advanced
	*/
	public interface IMapProvider
	{
		/** The name used to select this provider with `MapView.Provider`. */
		string Name { get; }

		/** Creates the native map for the given host. Return `null` if the provider is not available. */
		IMapView Create(IMapViewHost host);
	}

	/**
		Registry of map providers.

		`Fuse.Maps` registers the platform's native provider automatically. Additional
		providers can be added before any @MapView is created:

		```csharp
		MapProviders.Register(new MyMapProvider());
		```

		and selected per map with `MapView.Provider`:

		```xml
		<MapView Provider="MyProvider" />
		```

		@advanced
	*/
	public static class MapProviders
	{
		static readonly List<IMapProvider> _providers = new List<IMapProvider>();
		static string _default;

		/** The name of the provider used when `MapView.Provider` is not set. */
		public static string Default
		{
			get { return _default; }
			set { _default = value; }
		}

		/** Registers a provider, replacing any existing provider with the same name. */
		public static void Register(IMapProvider provider)
		{
			if (provider == null)
				throw new ArgumentNullException(nameof(provider));
			if (provider.Name == null)
				throw new ArgumentException("A map provider must have a name", nameof(provider));

			for (int i = 0; i < _providers.Count; i++)
			{
				if (_providers[i].Name == provider.Name)
				{
					_providers[i] = provider;
					return;
				}
			}

			_providers.Add(provider);
		}

		/** Returns the provider with the given name, or `null`. */
		public static IMapProvider Get(string name)
		{
			if (name == null)
				return null;

			for (int i = 0; i < _providers.Count; i++)
			{
				if (_providers[i].Name == name)
					return _providers[i];
			}

			return null;
		}

		internal static IMapProvider Resolve(string name)
		{
			if (name != null)
				return Get(name);

			if (_default != null)
				return Get(_default);

			return _providers.Count > 0 ? _providers[0] : null;
		}
	}
}
