using Uno;
using Uno.Collections;
using Uno.Threading;
using Uno.Time;

namespace Fuse.GeoLocation
{
	interface ILocationTracker
	{
		Location GetLastKnownPosition();

		void GetLocation(Promise<Location> promise, double timeout);

		void Geocode(string address, int maxResults, Promise<IList<GeoAddress>> promise);

		void ReverseGeocode(GeoCoordinates coordinates, int maxResults, Promise<IList<GeoAddress>> promise);

		void StartUpdatingHeading(Action<Heading> onHeadingChanged, Action<Exception> onHeadingError, int minimumReportInterval);

		void StopUpdatingHeading();

		void AddGeofence(int id, GeoCoordinates center, double radius, Action<int, bool> onTransition, Action<int, Exception> onError);

		void RemoveGeofence(int id);

		void RemoveAllGeofences();

		void StartListening(Action<Location> onLocationChanged, Action<Exception> onLocationError, int minimumReportInterval, double desiredAccuracyInMeters, double minDistanceMeters);

		void StopListening();

		bool IsLocationEnabled();
		string GetAuthorizationStatus();

		void RequestAuthorization(GeoLocationAuthorizationType type, Promise<string> promise);

		void Init(Action onReady, Action<string> onAuthorizationStatusChanged);
	}

	public enum GeoLocationAuthorizationType
	{
		Never = 0,
		WhenInUse,
		Always
	}

	public partial class LocationTracker
	{
		class Watch
		{
			public readonly int Id;
			public readonly Action<Location> LocationChanged;
			public readonly Action<Exception> LocationError;
			public readonly int MinimumReportInterval;
			public readonly double DesiredAccuracyInMeters;
			public readonly double MinDistanceMeters;

			public Watch(int id, Action<Location> locationChanged, Action<Exception> locationError, int minimumReportInterval, double desiredAccuracyInMeters, double minDistanceMeters)
			{
				Id = id;
				LocationChanged = locationChanged;
				LocationError = locationError;
				MinimumReportInterval = minimumReportInterval;
				DesiredAccuracyInMeters = desiredAccuracyInMeters;
				MinDistanceMeters = minDistanceMeters;
			}
		}

		class LastKnownLocationCall
		{
			readonly LocationTracker _owner;
			readonly Action<Location> _callback;
			readonly Location _location;
			readonly int _watchId;

			public LastKnownLocationCall(LocationTracker owner, Action<Location> callback, Location location, int watchId)
			{
				_owner = owner;
				_callback = callback;
				_location = location;
				_watchId = watchId;
			}

			public void Run()
			{
				bool stillWatched = false;
				lock (_owner._watchMutex)
					stillWatched = _owner._watches.ContainsKey(_watchId);

				if (stillWatched)
					_callback(_location);
			}
		}

		static ILocationTracker _locationTracker;
		IList<BufferedCall> _bufferedCalls;

		readonly object _watchMutex = new object();
		readonly object _platformMutex = new object();
		readonly Dictionary<int, Watch> _watches = new Dictionary<int, Watch>();
		int _nextWatchId = 1;

		bool _legacyListening;
		int _legacyMinimumReportInterval = 500;
		double _legacyDesiredAccuracyInMeters = 10;
		double _legacyMinDistanceMeters = 0;

		bool _platformListening;
		bool _updatingPlatform;
		bool _platformUpdatePending;
		int _platformMinimumReportInterval;
		double _platformDesiredAccuracyInMeters;
		double _platformMinDistanceMeters;

		public LocationTracker()
		{
			_bufferedCalls = new List<BufferedCall>();
			AuthorizationType = GeoLocationAuthorizationType.WhenInUse;
			UpdateManager.Dispatcher.Invoke(Init);
		}

		void Init()
		{
			if(_locationTracker != null) return;

			if defined(Android)
				_locationTracker = new AndroidLocationProvider();
			else if defined(iOS)
				_locationTracker = new IOSLocationProvider();
			else
				_locationTracker = new SpoofLocationProvider();

			_locationTracker.Init(FlushBufferedCalls, OnAuthorizationStatusChanged);
		}

		void FlushBufferedCalls()
		{
			_isReady = true;
			var bufferedCalls = _bufferedCalls;
			_bufferedCalls = null;

			foreach(var call in bufferedCalls)
				call.Apply(_locationTracker);

			UpdatePlatformListener();
		}

		void OnAuthorizationStatusChanged(string status)
		{
			if (AuthorizationStatusChanged != null)
				AuthorizationStatusChanged(status);
		}

		public event Action<Location> LocationChanged;

		public event Action<string> LocationError;

		/**
			Raised when the platform authorization status changes.

			The parameter is one of `"notDetermined"`, `"restricted"`, `"denied"`,
			`"authorizedWhenInUse"` or `"authorizedAlways"`.
		*/
		public event Action<string> AuthorizationStatusChanged;

		/**
			Raised when the compass heading changes.
		*/
		public event Action<Heading> HeadingChanged;

		/**
			Raised when heading updates fail.
		*/
		public event Action<string> HeadingError;

		/**
			Raised when a geofence is entered.
		*/
		public event Action<GeoFence> GeofenceEntered;

		/**
			Raised when a geofence is exited.
		*/
		public event Action<GeoFence> GeofenceExited;

		/**
			Raised when geofence monitoring fails.
		*/
		public event Action<string> GeofenceError;

		bool _isReady;

		Location _lastLocation;

		public GeoLocationAuthorizationType AuthorizationType { get; set; }

		public Location Location
		{
			get
			{
				if(_lastLocation == null && _isReady)
				{
					_locationTracker.RequestAuthorization(AuthorizationType, null);
					_lastLocation = _locationTracker.GetLastKnownPosition();
				}

				return _lastLocation;
			}
		}

		public bool IsLocationEnabled()
		{
			if (!_isReady) return false;
			return _locationTracker.IsLocationEnabled();
		}

		public string GetAuthorizationStatus()
		{
			if (!_isReady) return "notDetermined";
			return _locationTracker.GetAuthorizationStatus();
		}

		/**
			Registers a continuous location watcher.

			Returns an id that can be passed to `ClearWatch`. Multiple watchers share
			a single platform listener; the most demanding interval, accuracy and
			distance filter across all active watchers are used.
		*/
		public int WatchPosition(Action<Location> onLocationChanged, Action<Exception> onLocationError, int minimumReportInterval = 500, double desiredAccuracyInMeters = 10, double minDistanceMeters = 0)
		{
			Watch watch = null;
			lock (_watchMutex)
			{
				var id = _nextWatchId++;
				watch = new Watch(id, onLocationChanged, onLocationError, minimumReportInterval, desiredAccuracyInMeters, minDistanceMeters);
				_watches.Add(id, watch);
			}

			// Deliver the last known location immediately when we have one.
			if (_lastLocation != null && watch.LocationChanged != null)
			{
				var location = _lastLocation;
				var callback = watch.LocationChanged;
				var watchId = watch.Id;
				UpdateManager.Dispatcher.Invoke(new LastKnownLocationCall(this, callback, location, watchId).Run);
			}

			if (_isReady)
				UpdatePlatformListener();

			return watch.Id;
		}

		public void ClearWatch(int watchId)
		{
			bool removed = false;
			lock (_watchMutex)
				removed = _watches.Remove(watchId);

			if (removed && _isReady)
				UpdatePlatformListener();
		}

		public void ClearAllWatches()
		{
			lock (_watchMutex)
				_watches.Clear();

			if (_isReady)
				UpdatePlatformListener();
		}

		void OnLocationChanged(Location newLocation)
		{
			_lastLocation = newLocation;

			List<Watch> watches = new List<Watch>();
			bool legacyListening = false;
			lock (_watchMutex)
			{
				legacyListening = _legacyListening;
				foreach (var watch in _watches.Values)
					watches.Add(watch);
			}

			if(legacyListening && LocationChanged != null)
				LocationChanged(newLocation);

			foreach (var watch in watches)
			{
				bool stillWatched = false;
				lock (_watchMutex)
					stillWatched = _watches.ContainsKey(watch.Id);

				if (stillWatched && watch.LocationChanged != null)
					watch.LocationChanged(newLocation);
			}
		}

		void OnLocationError(Exception error)
		{
			List<Watch> watches = new List<Watch>();
			bool legacyListening = false;
			lock (_watchMutex)
			{
				legacyListening = _legacyListening;
				foreach (var watch in _watches.Values)
					watches.Add(watch);
			}

			if(legacyListening && LocationError != null)
				LocationError(error.Message);

			foreach (var watch in watches)
			{
				bool stillWatched = false;
				lock (_watchMutex)
					stillWatched = _watches.ContainsKey(watch.Id);

				if (stillWatched && watch.LocationError != null)
					watch.LocationError(error);
			}
		}

		public void StartListening(int minimumReportInterval = 500, double desiredAccuracyInMeters = 10, double minDistanceMeters = 0)
		{
			lock (_watchMutex)
			{
				_legacyListening = true;
				_legacyMinimumReportInterval = minimumReportInterval;
				_legacyDesiredAccuracyInMeters = desiredAccuracyInMeters;
				_legacyMinDistanceMeters = minDistanceMeters;
			}

			if (_isReady)
				UpdatePlatformListener();
		}

		public void StopListening()
		{
			lock (_watchMutex)
				_legacyListening = false;

			if (_isReady)
				UpdatePlatformListener();
		}

		void UpdatePlatformListener()
		{
			lock (_platformMutex)
			{
				if (_updatingPlatform)
				{
					_platformUpdatePending = true;
					return;
				}

				_updatingPlatform = true;
				try
				{
					do
					{
						_platformUpdatePending = false;
						UpdatePlatformListenerCore();
					}
					while (_platformUpdatePending);
				}
				finally
				{
					_updatingPlatform = false;
				}
			}
		}

		void UpdatePlatformListenerCore()
		{
			bool shouldListen = false;
			int minimumReportInterval = 500;
			double desiredAccuracyInMeters = 10;
			double minDistanceMeters = 0;

			lock (_watchMutex)
			{
				shouldListen = _legacyListening || _watches.Count > 0;

				bool hasSource = false;

				if (_legacyListening)
				{
					minimumReportInterval = _legacyMinimumReportInterval;
					desiredAccuracyInMeters = _legacyDesiredAccuracyInMeters;
					minDistanceMeters = _legacyMinDistanceMeters;
					hasSource = true;
				}

				foreach (var watch in _watches.Values)
				{
					if (!hasSource)
					{
						minimumReportInterval = watch.MinimumReportInterval;
						desiredAccuracyInMeters = watch.DesiredAccuracyInMeters;
						minDistanceMeters = watch.MinDistanceMeters;
						hasSource = true;
						continue;
					}

					if (watch.MinimumReportInterval == 0 || minimumReportInterval == 0)
						minimumReportInterval = 0;
					else
						minimumReportInterval = Math.Min(minimumReportInterval, watch.MinimumReportInterval);

					if (watch.DesiredAccuracyInMeters <= 0 || desiredAccuracyInMeters <= 0)
						desiredAccuracyInMeters = 0;
					else
						desiredAccuracyInMeters = Math.Min(desiredAccuracyInMeters, watch.DesiredAccuracyInMeters);

					if (watch.MinDistanceMeters <= 0 || minDistanceMeters <= 0)
						minDistanceMeters = 0;
					else
						minDistanceMeters = Math.Min(minDistanceMeters, watch.MinDistanceMeters);
				}
			}

			if (!shouldListen)
			{
				if (_platformListening)
				{
					_platformListening = false;
					_locationTracker.StopListening();
				}
				return;
			}

			if (_platformListening
				&& minimumReportInterval == _platformMinimumReportInterval
				&& desiredAccuracyInMeters == _platformDesiredAccuracyInMeters
				&& minDistanceMeters == _platformMinDistanceMeters)
				return;

			if (_platformListening)
				_locationTracker.StopListening();

			_platformListening = true;
			_platformMinimumReportInterval = minimumReportInterval;
			_platformDesiredAccuracyInMeters = desiredAccuracyInMeters;
			_platformMinDistanceMeters = minDistanceMeters;

			_locationTracker.RequestAuthorization(AuthorizationType, null);
			_locationTracker.StartListening(OnLocationChanged, OnLocationError, minimumReportInterval, desiredAccuracyInMeters, minDistanceMeters);
		}

		public Future<Location> GetLocationAsync(double timeout = 20000, double maximumAge = 0)
		{
			var promise = new Promise<Location>();

			// Return a cached location when it is recent enough.
			if (maximumAge > 0 && _lastLocation != null && IsFresh(_lastLocation, maximumAge))
			{
				promise.Resolve(_lastLocation);
				return promise;
			}

			try
			{
				if(!_isReady)
				{
					_bufferedCalls.Add(new GetLocationCall(promise, timeout, OnLocationFetched));
					return promise;
				}
				_locationTracker.RequestAuthorization(AuthorizationType, null);
				_locationTracker.GetLocation(promise, timeout);
				promise.Then(OnLocationFetched, null);
			}
			catch (Exception e)
			{
				promise.Reject(e);
			}

			return promise;
		}

		public Future<string> RequestAuthorizationAsync(GeoLocationAuthorizationType type)
		{
			var promise = new Promise<string>();

			if (!_isReady)
			{
				_bufferedCalls.Add(new RequestAuthorizationCall(promise, type));
				return promise;
			}

			_locationTracker.RequestAuthorization(type, promise);
			return promise;
		}

		/**
			Resolves with the addresses matching the given text query.
		*/
		public Future<IList<GeoAddress>> GeocodeAsync(string address, int maxResults = 5)
		{
			var promise = new Promise<IList<GeoAddress>>();

			if (address == null || address.Length == 0)
			{
				promise.Reject(new Exception("Address is required"));
				return promise;
			}

			if (maxResults <= 0)
				maxResults = 5;

			if (!_isReady)
			{
				_bufferedCalls.Add(new GeocodeCall(address, maxResults, promise));
				return promise;
			}

			try
			{
				_locationTracker.Geocode(address, maxResults, promise);
			}
			catch (Exception e)
			{
				promise.Reject(e);
			}

			return promise;
		}

		/**
			Resolves with the addresses describing the given coordinates.
		*/
		public Future<IList<GeoAddress>> ReverseGeocodeAsync(GeoCoordinates coordinates, int maxResults = 1)
		{
			var promise = new Promise<IList<GeoAddress>>();

			if (coordinates == null)
			{
				promise.Reject(new Exception("Coordinates are required"));
				return promise;
			}

			if (maxResults <= 0)
				maxResults = 1;

			if (!_isReady)
			{
				_bufferedCalls.Add(new ReverseGeocodeCall(coordinates, maxResults, promise));
				return promise;
			}

			try
			{
				_locationTracker.ReverseGeocode(coordinates, maxResults, promise);
			}
			catch (Exception e)
			{
				promise.Reject(e);
			}

			return promise;
		}

		public void StartUpdatingHeading(int minimumReportInterval = 0)
		{
			if (!_isReady)
			{
				_bufferedCalls.Add(new StartUpdatingHeadingCall(OnHeadingChanged, OnHeadingError, minimumReportInterval));
				return;
			}

			_locationTracker.StartUpdatingHeading(OnHeadingChanged, OnHeadingError, minimumReportInterval);
		}

		public void StopUpdatingHeading()
		{
			if (!_isReady)
			{
				_bufferedCalls.Add(new StopUpdatingHeadingCall());
				return;
			}

			_locationTracker.StopUpdatingHeading();
		}

		void OnHeadingChanged(Heading heading)
		{
			if (HeadingChanged != null)
				HeadingChanged(heading);
		}

		void OnHeadingError(Exception error)
		{
			if (HeadingError != null)
				HeadingError(error.Message);
		}

		readonly object _geofenceMutex = new object();
		readonly Dictionary<int, GeoFence> _fences = new Dictionary<int, GeoFence>();
		readonly Dictionary<int, bool> _fenceStates = new Dictionary<int, bool>();
		int _nextFenceId = 1;

		public GeoFence AddGeofence(GeoCoordinates center, double radius, string identifier)
		{
			if (center == null)
				throw new ArgumentNullException("center");
			if (radius <= 0)
				throw new ArgumentException("radius must be greater than zero", "radius");

			GeoFence fence = null;
			lock (_geofenceMutex)
			{
				fence = new GeoFence(_nextFenceId++, center, radius, identifier);
				_fences.Add(fence.Id, fence);
				_fenceStates[fence.Id] = false;
			}

			if (!_isReady)
			{
				_bufferedCalls.Add(new AddGeofenceCall(fence.Id, center, radius, OnGeofenceTransition, OnGeofenceError));
				return fence;
			}

			try
			{
				_locationTracker.AddGeofence(fence.Id, center, radius, OnGeofenceTransition, OnGeofenceError);
			}
			catch (Exception e)
			{
				OnGeofenceError(fence.Id, e);
			}

			return fence;
		}

		public void RemoveGeofence(int id)
		{
			lock (_geofenceMutex)
			{
				_fences.Remove(id);
				_fenceStates.Remove(id);
			}

			if (!_isReady)
			{
				_bufferedCalls.Add(new RemoveGeofenceCall(id));
				return;
			}

			_locationTracker.RemoveGeofence(id);
		}

		public void RemoveAllGeofences()
		{
			lock (_geofenceMutex)
			{
				_fences.Clear();
				_fenceStates.Clear();
			}

			if (!_isReady)
			{
				_bufferedCalls.Add(new RemoveAllGeofencesCall());
				return;
			}

			_locationTracker.RemoveAllGeofences();
		}

		void OnGeofenceTransition(int id, bool entered)
		{
			GeoFence fence = null;
			lock (_geofenceMutex)
			{
				if (!_fences.TryGetValue(id, out fence))
					return;

				bool previous = false;
				bool hasPrevious = _fenceStates.TryGetValue(id, out previous);
				if (hasPrevious && previous == entered)
					return;

				_fenceStates[id] = entered;
			}

			if (entered)
			{
				if (GeofenceEntered != null)
					GeofenceEntered(fence);
			}
			else
			{
				if (GeofenceExited != null)
					GeofenceExited(fence);
			}
		}

		void OnGeofenceError(int id, Exception error)
		{
			if (GeofenceError != null)
				GeofenceError("Geofence " + id + ": " + error.Message);
		}

		void OnLocationFetched(Location location)
		{
			_lastLocation = location;
		}

		bool IsFresh(Location location, double maximumAgeInMilliseconds)
		{
			var age = ZonedDateTime.Now.WithZone(DateTimeZone.Utc).ToInstant()
				- location.DateTime.InUtc().ToInstant();
			return age <= Duration.FromMilliseconds((long)maximumAgeInMilliseconds);
		}
	}
}
