using Uno.Collections;
using Uno.Compiler.ExportTargetInterop;
using Uno.Threading;
using Uno;

namespace Fuse.GeoLocation
{
	[Require("xcode.framework", "CoreLocation")]
	[ForeignInclude(Language.ObjC, "CoreLocation/CoreLocation.h")]
	[ForeignInclude(Language.ObjC, "iOS/LocationManagerDelegate.h")]
	extern(iOS) class IOSLocationProvider : ILocationTracker
	{
		const int NotDetermined = 0;
		const int Restricted = 1;
		const int Denied = 2;
		const int AuthorizedAlways = 3;
		const int AuthorizedWhenInUse = 4;

		ObjC.Object _lm; // CLLocationManager*
		ObjC.Object _lmDelegate; // LocationManagerDelegate*
		Action<Location> _continuousLocationListener;
		Action<Exception> _continuousErrorListener;
		Action<Heading> _headingChanged;
		Action<Exception> _headingError;
		readonly Dictionary<int, Action<int, bool>> _geofenceTransitions = new Dictionary<int, Action<int, bool>>();
		readonly Dictionary<int, Action<int, Exception>> _geofenceErrors = new Dictionary<int, Action<int, Exception>>();
		readonly Dictionary<int, ObjC.Object> _geofenceRegions = new Dictionary<int, ObjC.Object>();
		Action<string> _authorizationStatusChanged;
		Queue<Promise<Location>> _waitingPromises = new Queue<Promise<Location>>();
		IList<PendingLocationRequest> _pendingAuthorizationRequests = new List<PendingLocationRequest>();
		IList<Promise<string>> _authorizationPromises = new List<Promise<string>>();
		double _desiredAccuracyInMeters;
		double _minDistanceMeters;

		[Foreign(Language.ObjC)]
		public IOSLocationProvider()
		@{
			CLLocationManager* lm = [[CLLocationManager alloc] init];
			NSArray* backgroundModes  = [[NSBundle mainBundle].infoDictionary objectForKey:@"UIBackgroundModes"];

		    if(backgroundModes && [backgroundModes containsObject:@"location"]) {
		        if([lm respondsToSelector:@selector(setAllowsBackgroundLocationUpdates:)]) {
		            // We now have iOS9 and the right capabilities to set this:
					lm.allowsBackgroundLocationUpdates = true;
		        }
		    }

			lm.pausesLocationUpdatesAutomatically = false;
			LocationManagerDelegate* lmDelegate = [[LocationManagerDelegate alloc] initWithBlock: ^void (CLLocation* location)
			{
				@{IOSLocationProvider:of(_this).OnLocationChanged(ObjC.Object):call(location)};
			}
			error: ^void (NSError* err)
			{
				@{IOSLocationProvider:of(_this).OnError(string):call(err.localizedDescription)};
			}
			changeAuthorizationStatus: ^void (int status)
			{
				@{IOSLocationProvider:of(_this).OnChangeAuthorizationStatus(int):call(status)};
			}
			heading: ^void (CLHeading* heading)
			{
				@{IOSLocationProvider:of(_this).OnHeadingChanged(ObjC.Object):call(heading)};
			}
			regionEvent: ^void (CLRegion* region, int event, NSError* error)
			{
				@{IOSLocationProvider:of(_this).OnRegionEvent(ObjC.Object,int,string):call(region, event, error != nil ? error.localizedDescription : @"")};
			}
			];

			lm.delegate = lmDelegate;

			@{IOSLocationProvider:of(_this)._lm:set(lm)};
			@{IOSLocationProvider:of(_this)._lmDelegate:set(lmDelegate)};
		@}

		void OnLocationChanged(ObjC.Object clLocation)
		{
			var location = ConvertLocation(clLocation);
			if (location == null)
				return;

			if (_continuousLocationListener != null)
				_continuousLocationListener(location);

			var promisesResolved = _waitingPromises.Count > 0;
			while (_waitingPromises.Count > 0)
			{
				var p = _waitingPromises.Dequeue();
				if (p.State == FutureState.Pending)
					p.Resolve(location);
			}
			if (promisesResolved)
				OnListenerRemoved();
		}

		void OnError(string errorString)
		{
			var exception = new Exception(errorString);

			if (_continuousErrorListener != null)
				_continuousErrorListener(exception);

			if (_headingError != null)
				_headingError(exception);

			var promisesResolved = _waitingPromises.Count > 0;
			while (_waitingPromises.Count > 0)
			{
				var p = _waitingPromises.Dequeue();
				if (p.State == FutureState.Pending)
					p.Reject(exception);
			}
			if (promisesResolved)
				OnListenerRemoved();
		}

		void OnListenerRemoved()
		{
			// Restore the desired accuracy in case it was set from GetLocation
			if (_continuousLocationListener != null || _continuousErrorListener != null)
			{
				SetCLLocationManagerParams(_lm, _desiredAccuracyInMeters, _minDistanceMeters);
			}
			else if (_waitingPromises.Count == 0)
			{
				StopUpdatingLocation(_lm);
			}
		}

		public void StartListening(
			Action<Location> onLocationChanged,
			Action<Exception> onLocationError,
			int minimumReportInterval,
			double desiredAccuracyInMeters,
			double minDistanceMeters)
		{
			_desiredAccuracyInMeters = desiredAccuracyInMeters;
			_minDistanceMeters = minDistanceMeters;
			_continuousLocationListener = onLocationChanged;
			_continuousErrorListener = onLocationError;
			// There's no setting for report interval on iOS, so we ignore it
			SetCLLocationManagerParams(_lm, _desiredAccuracyInMeters, _minDistanceMeters);
			StartUpdatingLocation(_lm);
		}


		[Foreign(Language.ObjC)]
		public bool IsLocationEnabled()
		@{
			//check is hardware enabled
			if ([CLLocationManager locationServicesEnabled]) {

				//check user authorization
				switch ([CLLocationManager authorizationStatus]) {
					case kCLAuthorizationStatusAuthorizedAlways:
					case kCLAuthorizationStatusAuthorizedWhenInUse: return true;
						break;
					default: return false;
						break;
				}
			} else {
				return false;
			}
		@}

		[Foreign(Language.ObjC)]
		static int GetCLLocationAuthorizationStatus()
		@{
			return (int)[CLLocationManager authorizationStatus];
		@}

		static string NormalizeAuthorizationStatus(int status)
		{
			switch (status)
			{
				case NotDetermined: return "notDetermined";
				case Restricted: return "restricted";
				case Denied: return "denied";
				case AuthorizedAlways: return "authorizedAlways";
				case AuthorizedWhenInUse: return "authorizedWhenInUse";
				default: return "notDetermined";
			}
		}

		public string GetAuthorizationStatus()
		{
			return NormalizeAuthorizationStatus(GetCLLocationAuthorizationStatus());
		}

		[Foreign(Language.ObjC)]
		static void SetCLLocationManagerParams(
			ObjC.Object handle,
			double desiredAccuracyInMeters,
			double minDistanceMeters)
		@{
			CLLocationManager* lm = (CLLocationManager*)handle;
			lm.desiredAccuracy = desiredAccuracyInMeters > 0 ? desiredAccuracyInMeters : kCLLocationAccuracyBest;
			lm.distanceFilter = minDistanceMeters > 0 ? minDistanceMeters : kCLDistanceFilterNone;
		@}

		[Foreign(Language.ObjC)]
		static void StartUpdatingLocation(ObjC.Object handle)
		@{
			CLLocationManager* lm = (CLLocationManager*)handle;
			[lm startUpdatingLocation];
		@}

		public void StopListening()
		{
			_continuousLocationListener = null;
			_continuousErrorListener = null;
			OnListenerRemoved();
		}

		public void StartUpdatingHeading(Action<Heading> onHeadingChanged, Action<Exception> onHeadingError, int minimumReportInterval)
		{
			_headingChanged = onHeadingChanged;
			_headingError = onHeadingError;
			StartUpdatingHeadingNative(_lm);
		}

		public void StopUpdatingHeading()
		{
			_headingChanged = null;
			_headingError = null;
			StopUpdatingHeadingNative(_lm);
		}

		void OnHeadingChanged(ObjC.Object clHeading)
		{
			if (_headingChanged == null)
				return;

			double degrees, accuracy, timestamp;
			GetHeadingProperties(clHeading, out degrees, out accuracy, out timestamp);
			_headingChanged(new Heading(degrees, accuracy, (long)(timestamp * 1000)));
		}

		[Foreign(Language.ObjC)]
		static void StartUpdatingHeadingNative(ObjC.Object handle)
		@{
			CLLocationManager* lm = (CLLocationManager*)handle;
			[lm startUpdatingHeading];
		@}

		[Foreign(Language.ObjC)]
		static void StopUpdatingHeadingNative(ObjC.Object handle)
		@{
			CLLocationManager* lm = (CLLocationManager*)handle;
			[lm stopUpdatingHeading];
		@}

		[Foreign(Language.ObjC)]
		static void GetHeadingProperties(ObjC.Object handle, out double degrees, out double accuracy, out double timestamp)
		@{
			CLHeading* heading = (CLHeading*)handle;
			*degrees = heading.trueHeading >= 0 ? heading.trueHeading : heading.magneticHeading;
			*accuracy = heading.headingAccuracy;
			*timestamp = heading.timestamp.timeIntervalSince1970;
		@}

		public void AddGeofence(int id, GeoCoordinates center, double radius, Action<int, bool> onTransition, Action<int, Exception> onError)
		{
			if (_geofenceRegions.Count >= 20)
			{
				if (onError != null)
					onError(id, new Exception("The platform supports at most 20 monitored regions"));
				return;
			}

			var maximumRadius = GetMaximumRegionMonitoringDistance(_lm);
			if (maximumRadius > 0 && radius > maximumRadius)
			{
				if (onError != null)
					onError(id, new Exception("The geofence radius exceeds the platform maximum of " + maximumRadius + " meters"));
				return;
			}

			_geofenceTransitions[id] = onTransition;
			_geofenceErrors[id] = onError;

			var region = CreateGeofenceRegion(id, center.Latitude, center.Longitude, radius);
			_geofenceRegions[id] = region;
			StartMonitoringRegion(_lm, region);
		}

		public void RemoveGeofence(int id)
		{
			_geofenceTransitions.Remove(id);
			_geofenceErrors.Remove(id);

			ObjC.Object region = null;
			if (_geofenceRegions.TryGetValue(id, out region))
			{
				_geofenceRegions.Remove(id);

				if (region != null)
					StopMonitoringRegion(_lm, region);
			}
		}

		public void RemoveAllGeofences()
		{
			var ids = new int[_geofenceRegions.Count];
			int i = 0;
			foreach (var id in _geofenceRegions.Keys)
				ids[i++] = id;

			for (int j = 0; j < ids.Length; j++)
				RemoveGeofence(ids[j]);

			_geofenceTransitions.Clear();
			_geofenceErrors.Clear();
		}

		void OnRegionEvent(ObjC.Object region, int eventType, string error)
		{
			var identifier = GetRegionIdentifier(region);
			if (identifier == null)
				return;

			const string prefix = "fuse-geofence-";
			if (!identifier.StartsWith(prefix))
				return;

			int id = -1;
			if (!Int.TryParse(identifier.Substring(prefix.Length), out id))
				return;

			if (eventType == 3)
			{
				Action<int, Exception> onError = null;
				if (_geofenceErrors.TryGetValue(id, out onError) && onError != null)
					onError(id, new Exception(error != null && error.Length > 0 ? error : "Geofence monitoring failed"));
				return;
			}

			Action<int, bool> onTransition = null;
			if (_geofenceTransitions.TryGetValue(id, out onTransition) && onTransition != null)
				onTransition(id, eventType == 1);
		}

		[Foreign(Language.ObjC)]
		static double GetMaximumRegionMonitoringDistance(ObjC.Object handle)
		@{
			return ((CLLocationManager*)handle).maximumRegionMonitoringDistance;
		@}

		[Foreign(Language.ObjC)]
		static ObjC.Object CreateGeofenceRegion(int id, double latitude, double longitude, double radius)
		@{
			CLLocationCoordinate2D center = CLLocationCoordinate2DMake(latitude, longitude);
			NSString* identifier = [NSString stringWithFormat:@"fuse-geofence-%d", id];
			return [[CLCircularRegion alloc] initWithCenter:center radius:radius identifier:identifier];
		@}

		[Foreign(Language.ObjC)]
		static void StartMonitoringRegion(ObjC.Object handle, ObjC.Object region)
		@{
			[(CLLocationManager*)handle startMonitoringForRegion:(CLRegion*)region];
		@}

		[Foreign(Language.ObjC)]
		static void StopMonitoringRegion(ObjC.Object handle, ObjC.Object region)
		@{
			[(CLLocationManager*)handle stopMonitoringForRegion:(CLRegion*)region];
		@}

		[Foreign(Language.ObjC)]
		static string GetRegionIdentifier(ObjC.Object region)
		@{
			NSString* identifier = ((CLRegion*)region).identifier;
			return identifier != nil ? identifier : @"";
		@}

		[Foreign(Language.ObjC)]
		static void StopUpdatingLocation(ObjC.Object handle)
		@{
			CLLocationManager* lm = (CLLocationManager*)handle;
			[lm stopUpdatingLocation];
		@}

		public void RequestAuthorization(GeoLocationAuthorizationType type, Promise<string> promise)
		{
			var status = GetAuthorizationStatus();
			if (type == GeoLocationAuthorizationType.Never || status != "notDetermined")
			{
				if (promise != null)
					promise.Resolve(status);
				return;
			}

			if (promise != null)
				_authorizationPromises.Add(promise);

			RequestNativeAuthorization(_lm, type);
		}

		[Foreign(Language.ObjC)]
		static void RequestNativeAuthorization(ObjC.Object handle, GeoLocationAuthorizationType type)
		@{
			CLLocationManager* lm = (CLLocationManager*)handle;

			if (type == @{GeoLocationAuthorizationType.WhenInUse} &&
				[lm respondsToSelector:@selector(requestWhenInUseAuthorization)])
					[lm requestWhenInUseAuthorization];

			if (type == @{GeoLocationAuthorizationType.Always} &&
				[lm respondsToSelector:@selector(requestAlwaysAuthorization)])
					[lm requestAlwaysAuthorization];
		@}

		public Location GetLastKnownPosition()
		{
			var position = GetLastKnownPosition(_lm);
			if (position == null)
				return null;

			return ConvertLocation(position);
		}

		[Foreign(Language.ObjC)]
		static ObjC.Object GetLastKnownPosition(ObjC.Object handle)
		@{
			return ((CLLocationManager*)handle).location;
		@}

		public void GetLocation(Promise<Location> promise, double timeout)
		{
			var status = GetAuthorizationStatus();
			if (status == "denied" || status == "restricted")
			{
				StopUpdatingLocation(_lm);
				promise.Reject(new Exception("Location authorization denied"));
				return;
			}

			SetCLLocationManagerParams(_lm, 0, 0);
			// Stopping and starting triggers a new callback
			StopUpdatingLocation(_lm);
			StartUpdatingLocation(_lm);
			if (IsLocationPermitted())
			{
				PublishLocationPromise(promise, timeout);
			}
			else
			{
				_pendingAuthorizationRequests.Add(new PendingLocationRequest(promise, timeout));
				Timer.Wait(timeout / 1000, new The(promise).TimedOut);
				RequestNativeAuthorization(_lm, GeoLocationAuthorizationType.WhenInUse);
			}
		}

		public void Geocode(string address, int maxResults, Promise<IList<GeoAddress>> promise)
		{
			var runner = new GeocodeRunner(promise, maxResults);
			GeocodeNative(address, runner.OnSuccess, runner.OnError);
		}

		public void ReverseGeocode(GeoCoordinates coordinates, int maxResults, Promise<IList<GeoAddress>> promise)
		{
			var runner = new GeocodeRunner(promise, maxResults);
			ReverseGeocodeNative(coordinates.Latitude, coordinates.Longitude, runner.OnSuccess, runner.OnError);
		}

		class GeocodeRunner
		{
			readonly Promise<IList<GeoAddress>> _promise;
			readonly int _maxResults;

			public GeocodeRunner(Promise<IList<GeoAddress>> promise, int maxResults)
			{
				_promise = promise;
				_maxResults = maxResults;
			}

			public void OnSuccess(ObjC.Object placemarks)
			{
				try
				{
					_promise.Resolve(ConvertPlacemarks(placemarks, _maxResults));
				}
				catch (Exception e)
				{
					_promise.Reject(e);
				}
			}

			public void OnError(string message)
			{
				_promise.Reject(new Exception(message));
			}
		}

		static IList<GeoAddress> ConvertPlacemarks(ObjC.Object placemarks, int maxResults)
		{
			var result = new List<GeoAddress>();
			if (placemarks == null)
				return result;

			int count = GetPlacemarkCount(placemarks);
			if (maxResults > 0 && count > maxResults)
				count = maxResults;

			for (int i = 0; i < count; i++)
				result.Add(ConvertPlacemark(GetPlacemarkAt(placemarks, i)));

			return result;
		}

		static GeoAddress ConvertPlacemark(ObjC.Object handle)
		{
			var name = GetPlacemarkName(handle);
			var street = GetPlacemarkStreet(handle);
			var streetNumber = GetPlacemarkStreetNumber(handle);
			var city = GetPlacemarkCity(handle);
			var subLocality = GetPlacemarkSubLocality(handle);
			var region = GetPlacemarkRegion(handle);
			var subRegion = GetPlacemarkSubRegion(handle);
			var country = GetPlacemarkCountry(handle);
			var countryCode = GetPlacemarkCountryCode(handle);
			var postalCode = GetPlacemarkPostalCode(handle);

			var formatted = FormatAddress(name, street, streetNumber, city, region, postalCode, country);
			var coordinates = HasPlacemarkLocation(handle)
				? new GeoCoordinates(GetPlacemarkLatitude(handle), GetPlacemarkLongitude(handle))
				: null;

			return new GeoAddress(
				name, street, streetNumber, city, subLocality,
				region, subRegion, country, countryCode, postalCode,
				formatted, coordinates);
		}

		static string FormatAddress(string name, string street, string streetNumber, string city, string region, string postalCode, string country)
		{
			var parts = new List<string>();
			AddPart(parts, name);

			var streetLine = street;
			if (streetNumber.Length > 0)
				streetLine = streetLine.Length > 0 ? streetNumber + " " + streetLine : streetNumber;
			AddPart(parts, streetLine);

			AddPart(parts, city);
			AddPart(parts, region);
			AddPart(parts, postalCode);
			AddPart(parts, country);

			return string.Join(", ", parts.ToArray());
		}

		static void AddPart(IList<string> parts, string value)
		{
			if (value == null || value.Length == 0)
				return;

			foreach (var part in parts)
				if (part == value)
					return;

			parts.Add(value);
		}

		[Foreign(Language.ObjC)]
		static void GeocodeNative(string address, Action<ObjC.Object> onSuccess, Action<string> onError)
		@{
			#pragma clang diagnostic push
			#pragma clang diagnostic ignored "-Wdeprecated-declarations"

			static NSMutableArray* activeGeocoders = nil;
			if (activeGeocoders == nil)
				activeGeocoders = [[NSMutableArray alloc] init];

			CLGeocoder* geocoder = [[CLGeocoder alloc] init];
			[activeGeocoders addObject:geocoder];
			[geocoder geocodeAddressString:address completionHandler:^(NSArray<CLPlacemark*>* placemarks, NSError* error) {
				[activeGeocoders removeObject:geocoder];

				if (error != nil)
				{
					onError(error.localizedDescription);
					return;
				}
				onSuccess(placemarks);
			}];

			#pragma clang diagnostic pop
		@}

		[Foreign(Language.ObjC)]
		static void ReverseGeocodeNative(double latitude, double longitude, Action<ObjC.Object> onSuccess, Action<string> onError)
		@{
			#pragma clang diagnostic push
			#pragma clang diagnostic ignored "-Wdeprecated-declarations"

			static NSMutableArray* activeGeocoders = nil;
			if (activeGeocoders == nil)
				activeGeocoders = [[NSMutableArray alloc] init];

			CLLocation* location = [[CLLocation alloc] initWithLatitude:latitude longitude:longitude];
			CLGeocoder* geocoder = [[CLGeocoder alloc] init];
			[activeGeocoders addObject:geocoder];
			[geocoder reverseGeocodeLocation:location completionHandler:^(NSArray<CLPlacemark*>* placemarks, NSError* error) {
				[activeGeocoders removeObject:geocoder];

				if (error != nil)
				{
					onError(error.localizedDescription);
					return;
				}
				onSuccess(placemarks);
			}];

			#pragma clang diagnostic pop
		@}

		[Foreign(Language.ObjC)]
		static int GetPlacemarkCount(ObjC.Object placemarks)
		@{
			return (int)((NSArray*)placemarks).count;
		@}

		[Foreign(Language.ObjC)]
		static ObjC.Object GetPlacemarkAt(ObjC.Object placemarks, int index)
		@{
			return ((NSArray*)placemarks)[index];
		@}

		[Foreign(Language.ObjC)]
		static string GetPlacemarkName(ObjC.Object handle)
		@{
			NSString* value = ((CLPlacemark*)handle).name;
			return value != nil ? value : @"";
		@}

		[Foreign(Language.ObjC)]
		static string GetPlacemarkStreet(ObjC.Object handle)
		@{
			NSString* value = ((CLPlacemark*)handle).thoroughfare;
			return value != nil ? value : @"";
		@}

		[Foreign(Language.ObjC)]
		static string GetPlacemarkStreetNumber(ObjC.Object handle)
		@{
			NSString* value = ((CLPlacemark*)handle).subThoroughfare;
			return value != nil ? value : @"";
		@}

		[Foreign(Language.ObjC)]
		static string GetPlacemarkCity(ObjC.Object handle)
		@{
			NSString* value = ((CLPlacemark*)handle).locality;
			return value != nil ? value : @"";
		@}

		[Foreign(Language.ObjC)]
		static string GetPlacemarkSubLocality(ObjC.Object handle)
		@{
			NSString* value = ((CLPlacemark*)handle).subLocality;
			return value != nil ? value : @"";
		@}

		[Foreign(Language.ObjC)]
		static string GetPlacemarkRegion(ObjC.Object handle)
		@{
			NSString* value = ((CLPlacemark*)handle).administrativeArea;
			return value != nil ? value : @"";
		@}

		[Foreign(Language.ObjC)]
		static string GetPlacemarkSubRegion(ObjC.Object handle)
		@{
			NSString* value = ((CLPlacemark*)handle).subAdministrativeArea;
			return value != nil ? value : @"";
		@}

		[Foreign(Language.ObjC)]
		static string GetPlacemarkCountry(ObjC.Object handle)
		@{
			NSString* value = ((CLPlacemark*)handle).country;
			return value != nil ? value : @"";
		@}

		[Foreign(Language.ObjC)]
		static string GetPlacemarkCountryCode(ObjC.Object handle)
		@{
			NSString* value = ((CLPlacemark*)handle).ISOcountryCode;
			return value != nil ? value : @"";
		@}

		[Foreign(Language.ObjC)]
		static string GetPlacemarkPostalCode(ObjC.Object handle)
		@{
			NSString* value = ((CLPlacemark*)handle).postalCode;
			return value != nil ? value : @"";
		@}

		[Foreign(Language.ObjC)]
		static bool HasPlacemarkLocation(ObjC.Object handle)
		@{
			return ((CLPlacemark*)handle).location != nil;
		@}

		[Foreign(Language.ObjC)]
		static double GetPlacemarkLatitude(ObjC.Object handle)
		@{
			CLLocation* location = ((CLPlacemark*)handle).location;
			return location != nil ? location.coordinate.latitude : 0;
		@}

		[Foreign(Language.ObjC)]
		static double GetPlacemarkLongitude(ObjC.Object handle)
		@{
			CLLocation* location = ((CLPlacemark*)handle).location;
			return location != nil ? location.coordinate.longitude : 0;
		@}

		void OnChangeAuthorizationStatus(int clAuthorizationStatus)
		{
			var status = NormalizeAuthorizationStatus(clAuthorizationStatus);

			if (_authorizationStatusChanged != null)
				_authorizationStatusChanged(status);

			if (status != "notDetermined")
			{
				foreach (var p in _authorizationPromises)
					if (p.State == FutureState.Pending)
						p.Resolve(status);
				_authorizationPromises.Clear();
			}

			if (clAuthorizationStatus == AuthorizedWhenInUse || clAuthorizationStatus == AuthorizedAlways)
			{
				StartUpdatingLocation(_lm);

				foreach (var request in _pendingAuthorizationRequests)
					if (request.Promise.State == FutureState.Pending)
						PublishLocationPromise(request.Promise, request.Timeout);
				_pendingAuthorizationRequests.Clear();
			}
			else if (clAuthorizationStatus == Denied || clAuthorizationStatus == Restricted)
			{
				foreach (var request in _pendingAuthorizationRequests)
					if (request.Promise.State == FutureState.Pending)
						request.Promise.Reject(new Exception("Location authorization denied"));
				_pendingAuthorizationRequests.Clear();
			}
		}

		private void PublishLocationPromise(Promise<Location> promise, double timeout)
		{
			Timer.Wait(timeout / 1000, new The(promise).TimedOut);
			_waitingPromises.Enqueue(promise);
		}

		[Foreign(Language.ObjC)]
		private bool IsLocationPermitted()
		@{
			CLAuthorizationStatus status = [CLLocationManager authorizationStatus];
			return status == kCLAuthorizationStatusAuthorizedWhenInUse || status == kCLAuthorizationStatusAuthorizedAlways;
		@}

		class PendingLocationRequest
		{
			public readonly Promise<Location> Promise;
			public readonly double Timeout;

			public PendingLocationRequest(Promise<Location> promise, double timeout)
			{
				Promise = promise;
				Timeout = timeout;
			}
		}

		class The
		{
			readonly Promise<Location> _promise;

			public The(Promise<Location> promise)
			{
				_promise = promise;
			}

			public void TimedOut()
			{
				if (_promise.State == FutureState.Pending)
					_promise.Reject(new Exception("Location request timed out"));
			}
		}

		static Location ConvertLocation(ObjC.Object location)
		{
			if (location == null)
				return null;

			double timeIntervalSince1970, latitude, longitude, horizontalAccuracy, verticalAccuracy, altitude, speed, speedAccuracy, course;
			bool isMock;
			GetCLLocationProperties(
				location,
				out timeIntervalSince1970,
				out latitude,
				out longitude,
				out horizontalAccuracy,
				out verticalAccuracy,
				out altitude,
				out speed,
				out speedAccuracy,
				out course,
				out isMock);

			var instant = Uno.Time.Instant.FromMillisecondsSinceUnixEpoch((long)(timeIntervalSince1970 * 1000));
			var dateTime = new Uno.Time.LocalDateTime(instant, Uno.Time.CalendarSystem.Iso);
			return new Location(
				new GeoCoordinates(latitude, longitude),
				horizontalAccuracy,
				altitude,
				speed,
				dateTime,
				verticalAccuracy,
				course,
				speedAccuracy,
				isMock,
				"corelocation",
				true,
				speed >= 0,
				course >= 0);
		}

		[Foreign(Language.ObjC)]
		static void GetCLLocationProperties(
			ObjC.Object handle,
			out double timeIntervalSince1970,
			out double latitude,
			out double longitude,
			out double horizontalAccuracy,
			out double verticalAccuracy,
			out double altitude,
			out double speed,
			out double speedAccuracy,
			out double course,
			out bool isMock)
		@{
			CLLocation* location = (CLLocation*)handle;
			*timeIntervalSince1970 = location.timestamp.timeIntervalSince1970;
			*latitude = location.coordinate.latitude;
			*longitude = location.coordinate.longitude;
			*horizontalAccuracy = location.horizontalAccuracy;
			*verticalAccuracy = location.verticalAccuracy;
			*altitude = location.altitude;
			*speed = location.speed;
			*course = location.course;

			*speedAccuracy = -1;
			if (@available(iOS 13.4, *))
				*speedAccuracy = location.speedAccuracy;

			*isMock = false;
			if (@available(iOS 15.0, *))
			{
				CLLocationSourceInformation* sourceInfo = location.sourceInformation;
				if (sourceInfo != nil)
					*isMock = sourceInfo.isSimulatedBySoftware;
			}
		@}

		public void Init(Action onReady, Action<string> onAuthorizationStatusChanged)
		{
			_authorizationStatusChanged = onAuthorizationStatusChanged;
			onReady();
		}
	}
}
