using Uno;
using Uno.Threading;
using Uno.Time;
using Uno.Collections;
using Fuse.Android.Permissions;
using Uno.Compiler.ExportTargetInterop;
using Fuse.GeoLocation.Android;

namespace Fuse.GeoLocation
{
	[ForeignInclude(Language.Java,
		"androidx.core.content.ContextCompat",
		"android.content.pm.PackageManager",
		"android.Manifest",
		"android.location.LocationManager",
		"android.location.Location",
		"android.location.Geocoder",
		"android.location.Address",
		"android.hardware.SensorManager",
		"android.hardware.Sensor",
		"android.hardware.SensorEvent",
		"fuse.geolocation.HeadingListener",
		"fuse.geolocation.GeofenceReceiver",
		"android.app.PendingIntent",
		"android.provider.Settings",
		"android.util.Log",
		"java.util.List",
		"fuse.geolocation.UpdateListener",
		"fuse.geolocation.BackgroundService",
		"android.content.Intent",
		"android.os.Looper",
		"android.content.Context",
		"com.uno.StringArray")]
	extern(Android) class AndroidLocationProvider :  ILocationTracker
	{

		bool _authorized;
		bool _started;
		Action<Location> _onLocationChanged;
		Action<string> _onAuthorizationStatusChanged;
		Java.Object _locationManager;
		Java.Object _updateListener;
		Java.Object _sensorManager;
		Java.Object _headingSensor;
		Java.Object _headingListener;
		Action<Heading> _headingChanged;
		Action<Exception> _headingError;
		readonly Dictionary<int, Action<int, bool>> _geofenceTransitions = new Dictionary<int, Action<int, bool>>();
		readonly Dictionary<int, Action<int, Exception>> _geofenceErrors = new Dictionary<int, Action<int, Exception>>();
		readonly Dictionary<int, Java.Object> _geofenceIntents = new Dictionary<int, Java.Object>();
		readonly object _geofenceMutex = new object();
		Action _onReady;
		IList<Promise<string>> _authorizationPromises = new List<Promise<string>>();

		Action<Location> startListening_onLocationChanged;
		Action<Exception> startListening_onLocationError;
		int startListening_minimumReportInterval;
		double startListening_minDistanceMeters;

		public AndroidLocationProvider() { }

		bool _hasRequestedPermissions;
		bool _requestingPermissions;
		IList<PendingLocationRequest> _pendingLocationRequests = new List<PendingLocationRequest>();

		public void Init(Action onReady, Action<string> onAuthorizationStatusChanged)
		{
			_onReady = onReady;
			_onAuthorizationStatusChanged = onAuthorizationStatusChanged;
			_locationManager = GetLocationManager();
			_updateListener = GetUpdateListener(OnLocationChanged);
			SetGeofenceCallback(OnGeofenceIntent);

			if (@(project.android.geoLocation.requestPermissionsOnLaunch:toLower) == "false")
			{
				_authorized = false;
				_onReady();
				_onReady = null;
			}
			else
			{
				RequestPermissions();
			}

		}


		[Foreign(Language.Java)]
		static int checkPermissions()
		@{
			//check if background location is explicitly requested (not enabled by default since Android Q)
			if ("@(project.android.geoLocation.backgroundLocation.enabled:toLower)" == "true"
				&& android.os.Build.VERSION.SDK_INT >= 29)
			{
				if (ContextCompat.checkSelfPermission(com.fuse.Activity.getRootActivity(), android.Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
					&& ContextCompat.checkSelfPermission(com.fuse.Activity.getRootActivity(), android.Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED)
				{
					if (ContextCompat.checkSelfPermission(com.fuse.Activity.getRootActivity(), android.Manifest.permission.ACCESS_BACKGROUND_LOCATION) == PackageManager.PERMISSION_GRANTED)
					{
						//already have all access
						return 0;
					}
					else
					{
						//request background permission
						return 1;
					}
				}
				else
				{
					//request all permissions
					return 2;
				}
			}
			else
			{
				//request regular permissions
				return 3;
			}
		@}

		void RequestPermissions()
		{
			_hasRequestedPermissions = true;

			if (_requestingPermissions)
				return;
			_requestingPermissions = true;

			int permissionState = checkPermissions();

			try
			{
				switch (permissionState) {
				case 3:
					var permissions = new PlatformPermission[]
					{
						Permissions.Android.INTERNET,
						Permissions.Android.ACCESS_COARSE_LOCATION,
						Permissions.Android.ACCESS_FINE_LOCATION
					};
					Permissions.Request(permissions).Then(OnPermissionsResult, OnPermissionsError);
					break;
				case 2:
					var permissions = new PlatformPermission[]
					{
						Permissions.Android.INTERNET,
						Permissions.Android.ACCESS_COARSE_LOCATION,
						Permissions.Android.ACCESS_FINE_LOCATION,
						Permissions.Android.ACCESS_BACKGROUND_LOCATION
					};
					Permissions.Request(permissions).Then(OnPermissionsResult, OnPermissionsError);
					break;
				case 1:
					var permissions = new PlatformPermission[]
					{
						Permissions.Android.INTERNET,
						Permissions.Android.ACCESS_BACKGROUND_LOCATION
					};
					Permissions.Request(permissions).Then(OnPermissionsResult, OnPermissionsError);
					break;
				case 0:
					_requestingPermissions = false;
					FlushPendingLocationRequests();
					NotifyAuthorizationResolved();
					CompleteReady();
					break;
				}
			}
			catch (Exception e)
			{
				_requestingPermissions = false;
				OnPermissionsError(e);
			}
		}

		void OnPermissionsResult(PlatformPermission[] grantedPermissions)
		{
			_requestingPermissions = false;
			_authorized = true;

			FlushPendingLocationRequests();
			NotifyAuthorizationResolved();

			if (startListening_onLocationChanged != null && !_started)
			{
				if (IsLocationEnabled())
					startListening();
				else if (startListening_onLocationError != null)
					startListening_onLocationError(new Exception("Location services are disabled"));
			}

			CompleteReady();
		}

		void CompleteReady()
		{
			if (_onReady != null)
			{
				_onReady();
				_onReady = null;
			}
		}

		void FlushPendingLocationRequests()
		{
			if (_locationManager == null)
			{
				var error = new Exception("Location manager is not available");
				foreach (var request in _pendingLocationRequests)
					if (request.Promise.State == FutureState.Pending)
						request.Promise.Reject(error);
				_pendingLocationRequests.Clear();
				return;
			}

			foreach (var request in _pendingLocationRequests)
				if (request.Promise.State == FutureState.Pending)
				{
					try
					{
						new PromiseListener(_locationManager, request.Timeout, request.Promise);
					}
					catch (Exception e)
					{
						request.Promise.Reject(e);
					}
				}
			_pendingLocationRequests.Clear();
		}

		void NotifyAuthorizationResolved()
		{
			var status = GetAuthorizationStatus();
			if (_onAuthorizationStatusChanged != null)
				_onAuthorizationStatusChanged(status);

			foreach (var promise in _authorizationPromises)
				if (promise.State == FutureState.Pending)
					promise.Resolve(status);
			_authorizationPromises.Clear();
		}

		void OnPermissionsError(Exception e)
		{
			_requestingPermissions = false;
			_authorized = false;

			if (_onAuthorizationStatusChanged != null)
				_onAuthorizationStatusChanged(GetAuthorizationStatus());

			var authorizationStatus = GetAuthorizationStatus();
			foreach (var promise in _authorizationPromises)
				if (promise.State == FutureState.Pending)
					promise.Resolve(authorizationStatus);
			_authorizationPromises.Clear();

			foreach (var request in _pendingLocationRequests)
				if (request.Promise.State == FutureState.Pending)
					request.Promise.Reject(e);
			_pendingLocationRequests.Clear();

			if (startListening_onLocationChanged != null && !_started && startListening_onLocationError != null)
				startListening_onLocationError(e);

			CompleteReady();
		}

		[Foreign(Language.Java)]
		static Java.Object GetLocationManager()
		@{
			return com.fuse.Activity.getRootActivity().getSystemService(Context.LOCATION_SERVICE);
		@}

		[Foreign(Language.Java)]
		static bool HasLocationPermission()
		@{
			return ContextCompat.checkSelfPermission(com.fuse.Activity.getRootActivity(), android.Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
				|| ContextCompat.checkSelfPermission(com.fuse.Activity.getRootActivity(), android.Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED;
		@}

		[Foreign(Language.Java)]
		static Java.Object GetUpdateListener(Action<Java.Object> onLocationChanged)
		@{
			return new UpdateListener(onLocationChanged);
		@}

		public void RequestAuthorization(GeoLocationAuthorizationType type, Promise<string> promise)
		{
			if (type == GeoLocationAuthorizationType.Never)
			{
				if (promise != null)
					promise.Resolve(GetAuthorizationStatus());
				return;
			}

			if (HasLocationPermission()
				&& !(type == GeoLocationAuthorizationType.Always
					&& @(project.android.geoLocation.backgroundLocation.enabled:toLower) == "true"))
			{
				if (promise != null)
					promise.Resolve(GetAuthorizationStatus());
				return;
			}

			if (promise != null)
				_authorizationPromises.Add(promise);

			RequestPermissions();
		}

		[Foreign(Language.Java)]
		public bool IsLocationEnabled()
		@{
			android.location.LocationManager locationManager = (LocationManager)com.fuse.Activity.getRootActivity().getSystemService(Context.LOCATION_SERVICE);

			if (locationManager != null)
			{
				if (android.os.Build.VERSION.SDK_INT >= 23)
				{
					//check if background location is explicitly requested (not enabled by default since Android Q)
					if ("@(project.android.geoLocation.backgroundLocation.enabled:toLower)" == "true"
						&& android.os.Build.VERSION.SDK_INT >= 29)
					{
						//check if hardware enabled
						if (locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER)||locationManager.isProviderEnabled(LocationManager.NETWORK_PROVIDER))
						{
							//check user authorization
							if (ContextCompat.checkSelfPermission(com.fuse.Activity.getRootActivity(), android.Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED
								&& ContextCompat.checkSelfPermission(com.fuse.Activity.getRootActivity(), android.Manifest.permission.ACCESS_COARSE_LOCATION) != PackageManager.PERMISSION_GRANTED
								&& ContextCompat.checkSelfPermission(com.fuse.Activity.getRootActivity(), android.Manifest.permission.ACCESS_BACKGROUND_LOCATION) != PackageManager.PERMISSION_GRANTED)
							{
								return false;
							}
							else
							{
								return true;
							}
						}
						else
						{
							return false;
						}
					}
					else
					{
						//check if hardware enabled
						if (locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER)||locationManager.isProviderEnabled(LocationManager.NETWORK_PROVIDER))
						{
							//check user authorization
							if (ContextCompat.checkSelfPermission(com.fuse.Activity.getRootActivity(), android.Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED
								&& ContextCompat.checkSelfPermission(com.fuse.Activity.getRootActivity(), android.Manifest.permission.ACCESS_COARSE_LOCATION) != PackageManager.PERMISSION_GRANTED)
							{
								return false;
							}
							else
							{
								return true;
							}
						}
						else
						{
							return false;
						}
					}
				}
				else
				{
					//legacy fallback
					try
					{
						locationManager.getLastKnownLocation(LocationManager.GPS_PROVIDER);
						return true;
					}
					catch (SecurityException e)
					{
						return false;
					}
				}
			}
			else
			{
				return false;
			}
		@}

		[Foreign(Language.Java)]
		static bool HasBackgroundPermission()
		@{
			if (android.os.Build.VERSION.SDK_INT < 29)
				return false;

			return ContextCompat.checkSelfPermission(com.fuse.Activity.getRootActivity(), android.Manifest.permission.ACCESS_BACKGROUND_LOCATION) == PackageManager.PERMISSION_GRANTED;
		@}

		[Foreign(Language.Java)]
		static bool ShouldShowLocationRationale()
		@{
			return androidx.core.app.ActivityCompat.shouldShowRequestPermissionRationale(
				com.fuse.Activity.getRootActivity(), android.Manifest.permission.ACCESS_FINE_LOCATION);
		@}

		public string GetAuthorizationStatus()
		{
			if (!HasLocationPermission())
				return (_hasRequestedPermissions || ShouldShowLocationRationale()) ? "denied" : "notDetermined";

			//check if background location is explicitly requested (not enabled by default since Android Q)
			if (@(project.android.geoLocation.backgroundLocation.enabled:toLower) == "true"
				&& HasBackgroundPermission())
				return "authorizedAlways";

			return "authorizedWhenInUse";
		}

		[Foreign(Language.Java)]
		static bool IsNetworkEnabled(Java.Object locationManager)
		@{
			return ((LocationManager)locationManager).isProviderEnabled(LocationManager.NETWORK_PROVIDER);
		@}

		[Foreign(Language.Java)]
		static bool IsGPSEnabled(Java.Object locationManager)
		@{
			return ((LocationManager)locationManager).isProviderEnabled(LocationManager.GPS_PROVIDER);
		@}


		[Foreign(Language.Java)]
		static int GetNumProviders(Java.Object handle)
		@{
			return ((LocationManager)handle).getAllProviders().size();
		@}

		[Foreign(Language.Java)]
		static void ListProviders(Java.Object handle, string[] output)
		@{
			List<String> l = ((LocationManager)handle).getAllProviders();
			for(int i = 0; i<l.size(); i++)
				output.set(i, l.get(i));
		@}

		void OnLocationChanged(Java.Object location)
		{
			if(_onLocationChanged != null)
				_onLocationChanged(LocationHelpers.ConvertLocation(location));
		}

		public void GetLocation(Promise<Location> promise, double timeout)
		{
			if (!HasLocationPermission())
			{
				_pendingLocationRequests.Add(new PendingLocationRequest(promise, timeout));
				RequestPermissions();
				return;
			}

			if (!IsLocationEnabled())
			{
				promise.Reject(new Exception("Location services are disabled"));
				return;
			}

			if (_locationManager == null)
			{
				_pendingLocationRequests.Add(new PendingLocationRequest(promise, timeout));
				RequestPermissions();
				return;
			}

			try
			{
				new PromiseListener(_locationManager, timeout, promise);
			}
			catch (Exception e)
			{
				promise.Reject(e);
			}
		}

		[Foreign(Language.Java)]
		static Java.Object GetLastKnownLocationFromProvider(Java.Object handle, string provider)
		@{
			return ((LocationManager)handle).getLastKnownLocation(provider);
		@}

		public Location GetLastKnownPosition()
		{
			if (!IsLocationEnabled())
			{
				RequestPermissions();
				return null;
			}

			if (_locationManager != null)
			{
				var locations = new List<Location>();
				string[] providers = new string[GetNumProviders(_locationManager)];
				ListProviders(_locationManager, providers);
				foreach(var provider in providers)
				{
					var lo = GetLastKnownLocationFromProvider(_locationManager, provider);
					if(lo != null)
						locations.Add(LocationHelpers.ConvertLocation(lo));
				}
				var minTime = ZonedDateTime.Now.WithZone(DateTimeZone.Utc).Minus(Duration.FromHours(1)).ToInstant();
				return ChooseBestLocation(locations, 100, minTime);
			}
			return null;
		}

		Location ChooseBestLocation(IList<Location> locations, int minDistance, Instant minTime)
		{
			Location bestResult = null;
			double bestAccuracy = double.MaxValue;
			var bestTime = new Instant();

			foreach(var location in locations)
			{
				var accuracy = location.Accuracy;
				var time = location.DateTime.InUtc().ToInstant();

				if (time > minTime && accuracy < bestAccuracy)
				{
					bestResult = location;
					bestAccuracy = accuracy;
					bestTime = time;
				}
				else if (time < minTime && bestAccuracy == double.MaxValue && time > bestTime)
				{
					bestResult = location;
					bestTime = time;
				}
			}

			if (bestResult == null) {
				bestAccuracy = minDistance;

				foreach(var location in locations)
				{
					if (location.Accuracy < bestAccuracy) {
						bestResult = location;
						bestAccuracy = location.Accuracy;
					}
				}
			}

			return bestResult;
		}

		[Foreign(Language.Java)]
		static void RequestNetworkLocationUpdates(Java.Object handle, int minimumReportInterval, double minDistanceMeters, Java.Object listener)
		@{
			((LocationManager)handle).requestLocationUpdates(LocationManager.NETWORK_PROVIDER, (long)minimumReportInterval, (float)minDistanceMeters, (UpdateListener)listener, Looper.getMainLooper());
		@}

		[Foreign(Language.Java)]
		static void RequestGPSLocationUpdates(Java.Object handle, int minimumReportInterval, double minDistanceMeters, Java.Object listener)
		@{
			((LocationManager)handle).requestLocationUpdates(LocationManager.GPS_PROVIDER, (long)minimumReportInterval, (float)minDistanceMeters, (UpdateListener)listener, Looper.getMainLooper());
		@}

		[Foreign(Language.Java)]
		static void StartForegroundService()
		@{
			Intent intent = new Intent(com.fuse.Activity.getRootActivity(), BackgroundService.class);
			intent.setAction(BackgroundService.ACTION_START_FOREGROUND_SERVICE);
			ContextCompat.startForegroundService(com.fuse.Activity.getRootActivity(), intent);
		@}

		[Foreign(Language.Java)]
		static void StopForegroundService()
		@{
			Intent intent = new Intent(com.fuse.Activity.getRootActivity(), BackgroundService.class);
			intent.setAction(BackgroundService.ACTION_STOP_FOREGROUND_SERVICE);
			ContextCompat.startForegroundService(com.fuse.Activity.getRootActivity(), intent);
		@}

		public void StartListening(Action<Location> onLocationChanged, Action<Uno.Exception> onLocationError, int minimumReportInterval, double desiredAccuracyInMeters, double minDistanceMeters)
		{

			startListening_onLocationChanged = onLocationChanged;
			startListening_onLocationError = onLocationError;
			startListening_minimumReportInterval = minimumReportInterval;
			startListening_minDistanceMeters = minDistanceMeters;

			if (!IsLocationEnabled()) {

				if (HasLocationPermission())
				{
					// Permission is granted but location services are disabled.
					if (startListening_onLocationError != null)
						startListening_onLocationError(new Exception("Location services are disabled"));
					return;
				}

				RequestPermissions();

			} else {
				startListening();
			}


		}

		void startListening() {

			if (_locationManager != null && !_started)
			{
				_onLocationChanged = startListening_onLocationChanged;

				if(IsNetworkEnabled(_locationManager))
					RequestNetworkLocationUpdates(_locationManager, startListening_minimumReportInterval, startListening_minDistanceMeters, _updateListener);

				if(IsGPSEnabled(_locationManager))
					RequestGPSLocationUpdates(_locationManager, startListening_minimumReportInterval, startListening_minDistanceMeters, _updateListener);

				if (@(project.android.geoLocation.backgroundLocation.enabled:toLower) == "true")
				{
					StartForegroundService();
				}

				_started = true;
			}
			else if (_locationManager == null && startListening_onLocationError != null)
			{
				startListening_onLocationError(new Exception("Location manager is not available"));
			}
		}

		[Foreign(Language.Java)]
		static void RemoveUpdates(Java.Object manager, Java.Object listener)
		@{
			((LocationManager)manager).removeUpdates((UpdateListener)listener);
		@}

		public void StopListening()
		{
			startListening_onLocationChanged = null;
			startListening_onLocationError = null;

			if (_locationManager != null && _updateListener != null)
				RemoveUpdates(_locationManager, _updateListener);

			if (@(project.android.geoLocation.backgroundLocation.enabled:toLower) == "true")
			{
				StopForegroundService();
			}

			_started = false;
		}

		public void StartUpdatingHeading(Action<Heading> onHeadingChanged, Action<Exception> onHeadingError, int minimumReportInterval)
		{
			_headingChanged = onHeadingChanged;
			_headingError = onHeadingError;

			if (_sensorManager == null)
				_sensorManager = GetSensorManager();

			if (_sensorManager == null)
			{
				if (_headingError != null)
					_headingError(new Exception("Sensor manager is not available"));
				return;
			}

			if (_headingSensor == null)
				_headingSensor = GetRotationVectorSensor(_sensorManager);

			if (_headingSensor == null)
			{
				if (_headingError != null)
					_headingError(new Exception("Heading sensor is not available"));
				return;
			}

			if (_headingListener == null)
				_headingListener = GetHeadingListener(OnHeadingChanged);

			RegisterHeadingListener(_sensorManager, _headingListener, _headingSensor, minimumReportInterval);
		}

		public void StopUpdatingHeading()
		{
			_headingChanged = null;
			_headingError = null;

			if (_sensorManager != null && _headingListener != null)
				UnregisterHeadingListener(_sensorManager, _headingListener);
		}

		void OnHeadingChanged(Java.Object sensorEvent)
		{
			if (_headingChanged == null)
				return;

			var values = new double[3];
			GetHeadingValues(sensorEvent, values);
			_headingChanged(new Heading(values[0], values[1], (long)values[2]));
		}

		[Foreign(Language.Java)]
		static Java.Object GetSensorManager()
		@{
			return com.fuse.Activity.getRootActivity().getSystemService(Context.SENSOR_SERVICE);
		@}

		[Foreign(Language.Java)]
		static Java.Object GetRotationVectorSensor(Java.Object sensorManager)
		@{
			return ((SensorManager)sensorManager).getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR);
		@}

		[Foreign(Language.Java)]
		static Java.Object GetHeadingListener(Action<Java.Object> onHeadingChanged)
		@{
			return new HeadingListener(onHeadingChanged);
		@}

		[Foreign(Language.Java)]
		static void RegisterHeadingListener(Java.Object sensorManager, Java.Object listener, Java.Object sensor, int minimumReportInterval)
		@{
			int samplingPeriodUs = minimumReportInterval > 0
				? (int)Math.min((long)minimumReportInterval * 1000, Integer.MAX_VALUE)
				: 0;
			((SensorManager)sensorManager).registerListener((HeadingListener)listener, (Sensor)sensor, samplingPeriodUs, 0);
		@}

		[Foreign(Language.Java)]
		static void UnregisterHeadingListener(Java.Object sensorManager, Java.Object listener)
		@{
			((SensorManager)sensorManager).unregisterListener((HeadingListener)listener);
		@}

		[Foreign(Language.Java)]
		static void GetHeadingValues(Java.Object sensorEvent, double[] output)
		@{
			SensorEvent e = (SensorEvent)sensorEvent;
			float[] rotationMatrix = new float[9];
			SensorManager.getRotationMatrixFromVector(rotationMatrix, e.values);
			float[] orientation = new float[3];
			SensorManager.getOrientation(rotationMatrix, orientation);

			double d = Math.toDegrees(orientation[0]);
			if (d < 0)
				d += 360;
			output.set(0, d);

			double accuracy = -1;
			switch (e.accuracy)
			{
				case SensorManager.SENSOR_STATUS_ACCURACY_HIGH: accuracy = 5; break;
				case SensorManager.SENSOR_STATUS_ACCURACY_MEDIUM: accuracy = 10; break;
				case SensorManager.SENSOR_STATUS_ACCURACY_LOW: accuracy = 15; break;
			}
			output.set(1, accuracy);

			output.set(2, (double)System.currentTimeMillis());
		@}

		public void AddGeofence(int id, GeoCoordinates center, double radius, Action<int, bool> onTransition, Action<int, Exception> onError)
		{
			if (_locationManager == null)
				_locationManager = GetLocationManager();

			if (_locationManager == null)
			{
				if (onError != null)
					onError(id, new Exception("Location manager is not available"));
				return;
			}

			if (!HasFineLocationPermission())
			{
				if (onError != null)
					onError(id, new Exception("Fine location permission is required for geofencing"));
				return;
			}

			lock (_geofenceMutex)
			{
				_geofenceTransitions[id] = onTransition;
				_geofenceErrors[id] = onError;
			}

			try
			{
				var pendingIntent = CreateGeofenceIntent(id);
				lock (_geofenceMutex)
					_geofenceIntents[id] = pendingIntent;
				AddProximityAlert(_locationManager, center.Latitude, center.Longitude, radius, pendingIntent);
			}
			catch (Exception e)
			{
				lock (_geofenceMutex)
				{
					_geofenceTransitions.Remove(id);
					_geofenceErrors.Remove(id);
					_geofenceIntents.Remove(id);
				}

				if (onError != null)
					onError(id, e);
			}
		}

		public void RemoveGeofence(int id)
		{
			Java.Object pendingIntent = null;
			lock (_geofenceMutex)
			{
				_geofenceTransitions.Remove(id);
				_geofenceErrors.Remove(id);

				if (_geofenceIntents.TryGetValue(id, out pendingIntent))
					_geofenceIntents.Remove(id);
			}

			if (_locationManager != null && pendingIntent != null)
				RemoveProximityAlert(_locationManager, pendingIntent);
		}

		public void RemoveAllGeofences()
		{
			int[] ids = null;
			lock (_geofenceMutex)
			{
				ids = new int[_geofenceIntents.Count];
				int i = 0;
				foreach (var id in _geofenceIntents.Keys)
					ids[i++] = id;
			}

			for (int j = 0; j < ids.Length; j++)
				RemoveGeofence(ids[j]);

			lock (_geofenceMutex)
			{
				_geofenceTransitions.Clear();
				_geofenceErrors.Clear();
			}
		}

		void OnGeofenceIntent(Java.Object intent)
		{
			int id = GetGeofenceIntentId(intent);

			Action<int, bool> callback = null;
			lock (_geofenceMutex)
				_geofenceTransitions.TryGetValue(id, out callback);

			if (callback != null)
				callback(id, IsGeofenceEntering(intent));
		}

		[Foreign(Language.Java)]
		static bool HasFineLocationPermission()
		@{
			return ContextCompat.checkSelfPermission(com.fuse.Activity.getRootActivity(), android.Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED;
		@}

		[Foreign(Language.Java)]
		static void SetGeofenceCallback(Action<Java.Object> callback)
		@{
			GeofenceReceiver.Callback = callback;
		@}

		[Foreign(Language.Java)]
		static Java.Object CreateGeofenceIntent(int id)
		@{
			Intent intent = new Intent(com.fuse.Activity.getRootActivity(), GeofenceReceiver.class);
			intent.setAction(GeofenceReceiver.ACTION_GEOFENCE_TRANSITION);
			intent.putExtra(GeofenceReceiver.EXTRA_ID, id);

			int flags = PendingIntent.FLAG_UPDATE_CURRENT;
			if (android.os.Build.VERSION.SDK_INT >= 23)
				flags |= PendingIntent.FLAG_IMMUTABLE;

			return PendingIntent.getBroadcast(com.fuse.Activity.getRootActivity(), id, intent, flags);
		@}

		[Foreign(Language.Java)]
		static void AddProximityAlert(Java.Object locationManager, double latitude, double longitude, double radius, Java.Object pendingIntent)
		@{
			((LocationManager)locationManager).addProximityAlert(latitude, longitude, (float)radius, -1, (PendingIntent)pendingIntent);
		@}

		[Foreign(Language.Java)]
		static void RemoveProximityAlert(Java.Object locationManager, Java.Object pendingIntent)
		@{
			((LocationManager)locationManager).removeProximityAlert((PendingIntent)pendingIntent);
		@}

		[Foreign(Language.Java)]
		static int GetGeofenceIntentId(Java.Object intent)
		@{
			return ((Intent)intent).getIntExtra(GeofenceReceiver.EXTRA_ID, -1);
		@}

		[Foreign(Language.Java)]
		static bool IsGeofenceEntering(Java.Object intent)
		@{
			return ((Intent)intent).getBooleanExtra(LocationManager.KEY_PROXIMITY_ENTERING, false);
		@}

		public void Geocode(string address, int maxResults, Promise<IList<GeoAddress>> promise)
		{
			if (!IsGeocoderPresent())
			{
				promise.Reject(new Exception("Geocoding is not available on this device"));
				return;
			}

			try
			{
				new Thread(new GeocodeRunner(address, maxResults, promise).Run).Start();
			}
			catch (Exception e)
			{
				promise.Reject(e);
			}
		}

		public void ReverseGeocode(GeoCoordinates coordinates, int maxResults, Promise<IList<GeoAddress>> promise)
		{
			if (!IsGeocoderPresent())
			{
				promise.Reject(new Exception("Geocoding is not available on this device"));
				return;
			}

			try
			{
				new Thread(new ReverseGeocodeRunner(coordinates.Latitude, coordinates.Longitude, maxResults, promise).Run).Start();
			}
			catch (Exception e)
			{
				promise.Reject(e);
			}
		}

		class GeocodeRunner
		{
			readonly string _address;
			readonly int _maxResults;
			readonly Promise<IList<GeoAddress>> _promise;

			public GeocodeRunner(string address, int maxResults, Promise<IList<GeoAddress>> promise)
			{
				_address = address;
				_maxResults = maxResults;
				_promise = promise;
			}

			public void Run()
			{
				try
				{
					GeocodeNative(_address, _maxResults, OnSuccess, OnError);
				}
				catch (Exception e)
				{
					_promise.Reject(e);
				}
			}

			void OnSuccess(Java.Object addresses)
			{
				try
				{
					_promise.Resolve(ConvertAddresses(addresses));
				}
				catch (Exception e)
				{
					_promise.Reject(e);
				}
			}

			void OnError(string message)
			{
				_promise.Reject(new Exception(message));
			}
		}

		class ReverseGeocodeRunner
		{
			readonly double _latitude;
			readonly double _longitude;
			readonly int _maxResults;
			readonly Promise<IList<GeoAddress>> _promise;

			public ReverseGeocodeRunner(double latitude, double longitude, int maxResults, Promise<IList<GeoAddress>> promise)
			{
				_latitude = latitude;
				_longitude = longitude;
				_maxResults = maxResults;
				_promise = promise;
			}

			public void Run()
			{
				try
				{
					ReverseGeocodeNative(_latitude, _longitude, _maxResults, OnSuccess, OnError);
				}
				catch (Exception e)
				{
					_promise.Reject(e);
				}
			}

			void OnSuccess(Java.Object addresses)
			{
				try
				{
					_promise.Resolve(ConvertAddresses(addresses));
				}
				catch (Exception e)
				{
					_promise.Reject(e);
				}
			}

			void OnError(string message)
			{
				_promise.Reject(new Exception(message));
			}
		}

		static IList<GeoAddress> ConvertAddresses(Java.Object addresses)
		{
			var result = new List<GeoAddress>();
			if (addresses == null)
				return result;

			int count = GetAddressCount(addresses);
			for (int i = 0; i < count; i++)
				result.Add(ConvertAddress(GetAddressAt(addresses, i)));

			return result;
		}

		static GeoAddress ConvertAddress(Java.Object handle)
		{
			var fields = new string[11];
			GetAddressFields(handle, fields);

			var coordinates = HasAddressLocation(handle)
				? new GeoCoordinates(GetAddressLatitude(handle), GetAddressLongitude(handle))
				: null;

			return new GeoAddress(
				fields[0], fields[1], fields[2], fields[3], fields[4],
				fields[5], fields[6], fields[7], fields[8], fields[9], fields[10],
				coordinates);
		}

		[Foreign(Language.Java)]
		static bool IsGeocoderPresent()
		@{
			return Geocoder.isPresent();
		@}

		[Foreign(Language.Java)]
		static void GeocodeNative(string address, int maxResults, Action<Java.Object> onSuccess, Action<string> onError)
		@{
			try
			{
				Geocoder geocoder = new Geocoder(com.fuse.Activity.getRootActivity());
				List<Address> results = geocoder.getFromLocationName(address, maxResults);
				onSuccess.run(results);
			}
			catch (Exception e)
			{
				onError.run(e.getMessage());
			}
		@}

		[Foreign(Language.Java)]
		static void ReverseGeocodeNative(double latitude, double longitude, int maxResults, Action<Java.Object> onSuccess, Action<string> onError)
		@{
			try
			{
				Geocoder geocoder = new Geocoder(com.fuse.Activity.getRootActivity());
				List<Address> results = geocoder.getFromLocation(latitude, longitude, maxResults);
				onSuccess.run(results);
			}
			catch (Exception e)
			{
				onError.run(e.getMessage());
			}
		@}

		[Foreign(Language.Java)]
		static int GetAddressCount(Java.Object addresses)
		@{
			return ((List<Address>)addresses).size();
		@}

		[Foreign(Language.Java)]
		static Java.Object GetAddressAt(Java.Object addresses, int index)
		@{
			return ((List<Address>)addresses).get(index);
		@}

		[Foreign(Language.Java)]
		static void GetAddressFields(Java.Object handle, string[] output)
		@{
			Address a = (Address)handle;
			output.set(0, a.getFeatureName() != null ? a.getFeatureName() : "");
			output.set(1, a.getThoroughfare() != null ? a.getThoroughfare() : "");
			output.set(2, a.getSubThoroughfare() != null ? a.getSubThoroughfare() : "");
			output.set(3, a.getLocality() != null ? a.getLocality() : "");
			output.set(4, a.getSubLocality() != null ? a.getSubLocality() : "");
			output.set(5, a.getAdminArea() != null ? a.getAdminArea() : "");
			output.set(6, a.getSubAdminArea() != null ? a.getSubAdminArea() : "");
			output.set(7, a.getCountryName() != null ? a.getCountryName() : "");
			output.set(8, a.getCountryCode() != null ? a.getCountryCode() : "");
			output.set(9, a.getPostalCode() != null ? a.getPostalCode() : "");

			java.lang.StringBuilder builder = new java.lang.StringBuilder();
			int maxLine = a.getMaxAddressLineIndex();
			for (int i = 0; i <= maxLine; i++)
			{
				String line = a.getAddressLine(i);
				if (line == null || line.length() == 0)
					continue;
				if (builder.length() > 0)
					builder.append(", ");
				builder.append(line);
			}
			output.set(10, builder.toString());
		@}

		[Foreign(Language.Java)]
		static bool HasAddressLocation(Java.Object handle)
		@{
			Address a = (Address)handle;
			if (android.os.Build.VERSION.SDK_INT >= 29)
				return a.hasLatitude() && a.hasLongitude();
			return true;
		@}

		[Foreign(Language.Java)]
		static double GetAddressLatitude(Java.Object handle)
		@{
			return ((Address)handle).getLatitude();
		@}

		[Foreign(Language.Java)]
		static double GetAddressLongitude(Java.Object handle)
		@{
			return ((Address)handle).getLongitude();
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
	}
}
