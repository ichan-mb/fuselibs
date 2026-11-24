using Uno.Collections;
using Uno.Threading;
using Uno;

namespace Fuse.GeoLocation
{
	public partial class LocationTracker
	{
		interface BufferedCall {
			void Apply(ILocationTracker tracker);
		}

		class GetLocationCall : BufferedCall {
			readonly Action<Location> onFetched;
			readonly Promise<Location> promise;
			readonly double timeout;
			public GetLocationCall(Promise<Location> promise, double timeout, Action<Location> onFetched)
			{
				this.promise = promise;
				this.timeout = timeout;
				this.onFetched = onFetched;
			}
			public void Apply(ILocationTracker tracker)
			{
				tracker.GetLocation(promise, timeout);
				promise.Then(onFetched, null);
			}
		}

		class RequestAuthorizationCall : BufferedCall {
			readonly Promise<string> promise;
			readonly GeoLocationAuthorizationType type;
			public RequestAuthorizationCall(Promise<string> promise, GeoLocationAuthorizationType type)
			{
				this.promise = promise;
				this.type = type;
			}
			public void Apply(ILocationTracker tracker)
			{
				tracker.RequestAuthorization(type, promise);
			}
		}

		class GeocodeCall : BufferedCall {
			readonly string address;
			readonly int maxResults;
			readonly Promise<IList<GeoAddress>> promise;
			public GeocodeCall(string address, int maxResults, Promise<IList<GeoAddress>> promise)
			{
				this.address = address;
				this.maxResults = maxResults;
				this.promise = promise;
			}
			public void Apply(ILocationTracker tracker)
			{
				tracker.Geocode(address, maxResults, promise);
			}
		}

		class ReverseGeocodeCall : BufferedCall {
			readonly GeoCoordinates coordinates;
			readonly int maxResults;
			readonly Promise<IList<GeoAddress>> promise;
			public ReverseGeocodeCall(GeoCoordinates coordinates, int maxResults, Promise<IList<GeoAddress>> promise)
			{
				this.coordinates = coordinates;
				this.maxResults = maxResults;
				this.promise = promise;
			}
			public void Apply(ILocationTracker tracker)
			{
				tracker.ReverseGeocode(coordinates, maxResults, promise);
			}
		}

		class StartUpdatingHeadingCall : BufferedCall {
			readonly Action<Heading> onHeadingChanged;
			readonly Action<Exception> onHeadingError;
			readonly int minimumReportInterval;
			public StartUpdatingHeadingCall(Action<Heading> onHeadingChanged, Action<Exception> onHeadingError, int minimumReportInterval)
			{
				this.onHeadingChanged = onHeadingChanged;
				this.onHeadingError = onHeadingError;
				this.minimumReportInterval = minimumReportInterval;
			}
			public void Apply(ILocationTracker tracker)
			{
				tracker.StartUpdatingHeading(onHeadingChanged, onHeadingError, minimumReportInterval);
			}
		}

		class StopUpdatingHeadingCall : BufferedCall {
			public void Apply(ILocationTracker tracker)
			{
				tracker.StopUpdatingHeading();
			}
		}

		class AddGeofenceCall : BufferedCall {
			readonly int id;
			readonly GeoCoordinates center;
			readonly double radius;
			readonly Action<int, bool> onTransition;
			readonly Action<int, Exception> onError;
			public AddGeofenceCall(int id, GeoCoordinates center, double radius, Action<int, bool> onTransition, Action<int, Exception> onError)
			{
				this.id = id;
				this.center = center;
				this.radius = radius;
				this.onTransition = onTransition;
				this.onError = onError;
			}
			public void Apply(ILocationTracker tracker)
			{
				tracker.AddGeofence(id, center, radius, onTransition, onError);
			}
		}

		class RemoveGeofenceCall : BufferedCall {
			readonly int id;
			public RemoveGeofenceCall(int id)
			{
				this.id = id;
			}
			public void Apply(ILocationTracker tracker)
			{
				tracker.RemoveGeofence(id);
			}
		}

		class RemoveAllGeofencesCall : BufferedCall {
			public void Apply(ILocationTracker tracker)
			{
				tracker.RemoveAllGeofences();
			}
		}
	}
}
