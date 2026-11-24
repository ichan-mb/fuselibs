using Uno.Collections;
using Uno.Compiler.ExportTargetInterop;
using Uno.Threading;
using Uno.Time;
using Uno;

namespace Fuse.GeoLocation
{
	public class SpoofLocationProvider : ILocationTracker
	{
		Location SpoofLocation;
		Action<Location> _onLocationChanged;
		Action<string> _authorizationStatusChanged;
		Action<Heading> _headingChanged;
		Action<Exception> _headingError;
		readonly Dictionary<int, Action<int, bool>> _fenceTransitions = new Dictionary<int, Action<int, bool>>();
		readonly Dictionary<int, Action<int, Exception>> _fenceErrors = new Dictionary<int, Action<int, Exception>>();

		public SpoofLocationProvider()
		{
			SpoofLocation = new Location(new GeoCoordinates(59.9115546,10.73888), 100, 50, 0.5, ZonedDateTime.Now.LocalDateTime);
		}
		public Location GetLastKnownPosition(){
			return SpoofLocation;
		}

		public void GetLocation(Promise<Location> promise, double timeout)
		{
			promise.Resolve(SpoofLocation);
		}

		public void Geocode(string address, int maxResults, Promise<IList<GeoAddress>> promise)
		{
			var results = new List<GeoAddress>();
			results.Add(new GeoAddress(
				address,
				"Spoof Street",
				"1",
				"Spoof City",
				"",
				"Spoof Region",
				"",
				"Spoof Country",
				"XX",
				"0000",
				address + ", Spoof City, Spoof Country",
				new GeoCoordinates(59.9115546, 10.73888)));
			promise.Resolve(results);
		}

		public void ReverseGeocode(GeoCoordinates coordinates, int maxResults, Promise<IList<GeoAddress>> promise)
		{
			var results = new List<GeoAddress>();
			results.Add(new GeoAddress(
				"Spoof Location",
				"Spoof Street",
				"1",
				"Spoof City",
				"",
				"Spoof Region",
				"",
				"Spoof Country",
				"XX",
				"0000",
				"Spoof Location, Spoof City, Spoof Country",
				coordinates));
			promise.Resolve(results);
		}

		public void StartListening(Action<Location> onLocationChanged, Action<Exception> onLocationError, int minimumReportInterval, double desiredAccuracyInMeters, double minDistanceMeters)
		{
			_onLocationChanged = onLocationChanged;
			if (_onLocationChanged != null)
				_onLocationChanged(SpoofLocation);
		}

		public void StopListening()
		{
			_onLocationChanged = null;
		}

		public void StartUpdatingHeading(Action<Heading> onHeadingChanged, Action<Exception> onHeadingError, int minimumReportInterval)
		{
			_headingChanged = onHeadingChanged;
			_headingError = onHeadingError;

			if (_headingChanged != null)
			{
				var timestamp = ZonedDateTime.Now.WithZone(DateTimeZone.Utc).ToInstant().Ticks / Constants.TicksPerMillisecond;
				_headingChanged(new Heading(0, -1, timestamp));
			}
		}

		public void StopUpdatingHeading()
		{
			_headingChanged = null;
			_headingError = null;
		}

		public void AddGeofence(int id, GeoCoordinates center, double radius, Action<int, bool> onTransition, Action<int, Exception> onError)
		{
			_fenceTransitions[id] = onTransition;
			_fenceErrors[id] = onError;

			if (onTransition != null)
				onTransition(id, SpoofLocation.Coordinates.DistanceTo(center) <= radius);
		}

		public void RemoveGeofence(int id)
		{
			_fenceTransitions.Remove(id);
			_fenceErrors.Remove(id);
		}

		public void RemoveAllGeofences()
		{
			_fenceTransitions.Clear();
			_fenceErrors.Clear();
		}

		public bool IsLocationEnabled()
		{
			return true;
		}

		public string GetAuthorizationStatus()
		{
			return "authorizedWhenInUse";
		}

		public void RequestAuthorization(GeoLocationAuthorizationType type, Promise<string> promise)
		{
			var status = GetAuthorizationStatus();
			if (promise != null)
				promise.Resolve(status);

			if (_authorizationStatusChanged != null)
				_authorizationStatusChanged(status);
		}

		public void Init(Action onReady, Action<string> onAuthorizationStatusChanged)
		{
			_authorizationStatusChanged = onAuthorizationStatusChanged;
			onReady();
		}
	}
}
