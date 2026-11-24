using Uno;
using Uno.Collections;
using Uno.UX;
using Uno.Text;
using Uno.Threading;
using Fuse.Scripting;
using Fuse.GeoLocation;

namespace Fuse.GeoLocation
{
	[UXGlobalModule]
	/**
		@scriptmodule FuseJS/GeoLocation

		Provides geolocation services.

		Using geolocation services requires device authorization. Including the `Fuse.GeoLocation` package
		in your project will trigger a prompt for this authorization when the app is launched.

		Use [startListening](api:fuse/geolocation/geolocation/startlistening_bbef95e2.json)
		to get continual location updates. Use
		[watchPosition](api:fuse/geolocation/geolocation/watchposition.json) to register
		one or more independent watchers. Use
		[location](api:fuse/geolocation/geolocation/getlocation.json)
		or [getLocation](api:fuse/geolocation/geolocation/getlocationasync_95a738ba.json) for one-time location requests.
		Use [geocode](api:fuse/geolocation/geolocation/geocode.json) and
		[reverseGeocode](api:fuse/geolocation/geolocation/reversegeocode.json) to look up addresses.
		Use [startUpdatingHeading](api:fuse/geolocation/geolocation/startupdatingheading.json)
		and [stopUpdatingHeading](api:fuse/geolocation/geolocation/stopupdatingheading.json)
		for compass heading updates. Use [addGeofence](api:fuse/geolocation/geolocation/addgeofence.json)
		and the `geofenceEntered` / `geofenceExited` events for geofencing.

		You need to add a reference to `"Fuse.GeoLocation"` in your project file to use this feature.

		This module is an @EventEmitter, so the methods from @EventEmitter can be used to listen to events.

		## Example

		The following example shows how the different modes of operation can be used:
		```xml
			<JavaScript>
				var Observable = require("FuseJS/Observable");
				var GeoLocation = require("FuseJS/GeoLocation");

				// Immediate
				var immediateLocation = JSON.stringify(GeoLocation.location);

				// Timeout
				var timeoutLocation = Observable("");
				var timeoutMs = 5000;
				GeoLocation.getLocation(timeoutMs).then(function(location) {
					timeoutLocation.value = JSON.stringify(location);
				}).catch(function(fail) {
					console.log("getLocation fail " + fail);
				});

				// Continuous
				var continuousLocation = GeoLocation.observe("changed").map(JSON.stringify);

				GeoLocation.on("error", function(fail) {
					console.log("GeoLocation error " + fail);
				});

				function startContinuousListener() {
					var intervalMs = 1000;
					var desiredAccuracyInMeters = 10;
					var minDistanceMeters = 10;
					GeoLocation.startListening(intervalMs, desiredAccuracyInMeters, minDistanceMeters);
				}

				function stopContinuousListener() {
					GeoLocation.stopListening();
				}

				module.exports = {
					immediateLocation: immediateLocation,
					timeoutLocation: timeoutLocation,
					continuousLocation: continuousLocation,

					startContinuousListener: startContinuousListener,
					stopContinuousListener: stopContinuousListener
				};
			</JavaScript>

			<StackPanel>
				<Text>Immediate:</Text>
				<Text Value="{immediateLocation}" />

				<Text>Timeout:</Text>
				<Text Value="{timeoutLocation}" />

				<Text>Continuous:</Text>
				<Text Value="{continuousLocation}" />

				<Button Text="Start continuous listener" Clicked="{startContinuousListener}" />
				<Button Text="Stop continuous listener" Clicked="{stopContinuousListener}" />
			</StackPanel>
		```xml
		In the above example we're using the @EventEmitter `observe` method to create an @Observable from the
		`"changed"` event. We can also listen to changes by using the `on` method, as follows:

			GeoLocation.on("changed", function(location) { ... })

		Locations returned by this module are JavaScript objects of the following form:
		```json
			{
				latitude: a number measured in decimal degrees,
				longitude: a number measured in decimal degrees,
				accuracy: a number measured in meters,
				altitude: altitude measured in meters,
				hasAltitude: whether the altitude value is valid,
				altitudeAccuracy: vertical accuracy measured in meters (-1 when unavailable),
				heading: direction of travel measured in degrees from true north (-1 when unavailable),
				hasHeading: whether the heading value is valid,
				speed: speed measured in meters per second,
				hasSpeed: whether the speed value is valid,
				speedAccuracy: speed accuracy measured in meters per second (-1 when unavailable),
				timestamp: milliseconds since the Unix epoch,
				isMock: whether the location was reported by a mock provider,
				provider: the name of the provider that produced the location
			}
		```
		To handle errors from GeoLocation we can listen to the `"error"` event, as follows:

			GeoLocation.on("error", function(err) { ... })

		To be notified when the user changes the authorization status, use the
		`"authorizationStatusChanged"` event:

			GeoLocation.on("authorizationStatusChanged", function(status) { ... })
	*/
	public sealed class GeoLocation : NativeEventEmitterModule
	{
		LocationTracker _locationTracker;
		static readonly GeoLocation _instance;

		public GeoLocation()
			: base(false,
				"changed",
				"authorizationStatusChanged",
				"headingChanged",
				"geofenceEntered",
				"geofenceExited")
		{
			if(_instance != null) return;
			Resource.SetGlobalKey(_instance = this, "FuseJS/GeoLocation");
			_locationTracker = new LocationTracker();

			// Old-style events for backwards compatibility
			var onChangedEvent = new NativeEvent("onChanged");
			var onErrorEvent = new NativeEvent("onError");
			var onAuthorizationStatusChangedEvent = new NativeEvent("onAuthorizationStatusChanged");
			var onHeadingChangedEvent = new NativeEvent("onHeadingChanged");
			var onGeofenceEnteredEvent = new NativeEvent("onGeofenceEntered");
			var onGeofenceExitedEvent = new NativeEvent("onGeofenceExited");

			On("changed", onChangedEvent);
			On("authorizationStatusChanged", onAuthorizationStatusChangedEvent);
			On("headingChanged", onHeadingChangedEvent);
			On("geofenceEntered", onGeofenceEnteredEvent);
			On("geofenceExited", onGeofenceExitedEvent);
			// Note: If we decide to remove these old-style events in the future, the
			// "error" event will no longer have a listener by default, meaning that the
			// module will then throw an exception on "error" (as per the way
			// EventEmitter works), unlike the current behaviour.  To retain the current
			// behaviour we might then want to add a dummy listener to the "error"
			// event.
			On("error", onErrorEvent);

			AddMember(onChangedEvent);
			AddMember(onErrorEvent);
			AddMember(onAuthorizationStatusChangedEvent);
			AddMember(onHeadingChangedEvent);
			AddMember(onGeofenceEnteredEvent);
			AddMember(onGeofenceExitedEvent);

			AddMember(new NativeFunction("isLocationEnabled", (NativeCallback)IsLocationEnabled));
			AddMember(new NativeProperty<string, object>("authorizationStatus", GetAuthorizationStatus));
			AddMember(new NativeProperty<Fuse.GeoLocation.Location, Scripting.Object>("location", GetLocation, null, Converter));
			AddMember(new NativePromise<Fuse.GeoLocation.Location, Scripting.Object>("getLocation", GetLocationAsync, Converter));
			AddMember(new NativePromise<string, string>("requestAuthorization", RequestAuthorizationAsync, null));
			AddMember(new NativeProperty<Fuse.GeoLocation.GeoLocationAuthorizationType, int>("authorizationRequest", GetAuthorizationRequest, SetAuthorizationRequest, AuthorizationRequestConverter));
			AddMember(new NativeFunction("startListening", (NativeCallback)StartListening));
			AddMember(new NativeFunction("stopListening", (NativeCallback)StopListening));
			AddMember(new NativeFunction("watchPosition", (NativeCallback)WatchPosition));
			AddMember(new NativeFunction("clearWatch", (NativeCallback)ClearWatch));
			AddMember(new NativeFunction("startUpdatingHeading", (NativeCallback)StartUpdatingHeading));
			AddMember(new NativeFunction("stopUpdatingHeading", (NativeCallback)StopUpdatingHeading));
			AddMember(new NativeFunction("addGeofence", (NativeCallback)AddGeofence));
			AddMember(new NativeFunction("removeGeofence", (NativeCallback)RemoveGeofence));
			AddMember(new NativeFunction("removeAllGeofences", (NativeCallback)RemoveAllGeofences));
			AddMember(new NativePromise<IList<GeoAddress>, Scripting.Array>("geocode", GeocodeAsync, AddressesConverter));
			AddMember(new NativePromise<IList<GeoAddress>, Scripting.Array>("reverseGeocode", ReverseGeocodeAsync, AddressesConverter));

			_locationTracker.LocationChanged += LocationChanged;
			_locationTracker.LocationError += LocationError;
			_locationTracker.AuthorizationStatusChanged += AuthorizationStatusChanged;
			_locationTracker.HeadingChanged += HeadingChanged;
			_locationTracker.HeadingError += HeadingError;
			_locationTracker.GeofenceEntered += GeofenceEntered;
			_locationTracker.GeofenceExited += GeofenceExited;
			_locationTracker.GeofenceError += GeofenceError;
			Reset += ResetGeoLocation;
		}

		/** @scriptmethod isLocationEnabled()
		Returns whether or not the device has Geolocation enabled.
		*/
		object IsLocationEnabled(Context context, object[] args)
		{
			return _locationTracker.IsLocationEnabled();
		}

		/**
			@scriptproperty authorizationStatus
			@readonly

			The current authorization status, one of `"notDetermined"`,
			`"restricted"`, `"denied"`, `"authorizedWhenInUse"` or
			`"authorizedAlways"`.

			Use [requestAuthorization](api:fuse/geolocation/geolocation/requestauthorization.json)
			to ask the user for permission.
		*/
		string GetAuthorizationStatus()
		{
			return _locationTracker.GetAuthorizationStatus();
		}


		/**
			@scriptmethod startListening(minimumReportInterval, desiredAccuracy, distanceFilter)

			Starts the GeoLocation listening service.

			[onChanged](api:fuse/geolocation/geolocation/locationchanged_adbb1cba.json)
			events will be generated as the location changes.


			Use [stopListening](api:fuse/geolocation/geolocation/stoplistening_bbef95e2.json) to stop the service.

			The parameters here are desired values; the actual interval, accuracy and distance
			filter are dependent on the device.

			The method also accepts an options object:
			```js
				GeoLocation.startListening({
					interval: 1000,
					accuracy: 10,
					distanceFilter: 5
				});
			```

			See [the GeoLocation module](api:fuse/geolocation/geolocation) for an example.

			@param minimumReportInterval how often the position should be updated. Value in milliseconds
			@param desiredAccuracy how accurate, in meters, should the values be
			@param distanceFilter the minimum distance, in meters, between location updates

		*/
		object StartListening(Context c, object[] args)
		{
			int minimumReportInterval = 500;
			double desiredAccuracyInMeters = 10;
			double minDistanceMeters = 0;

			if (args.Length > 0)
			{
				var options = args[0] as Fuse.Scripting.Object;
				if (options != null)
				{
					if (options.ContainsKey("interval"))
						minimumReportInterval = Marshal.ToInt(options["interval"]);
					if (options.ContainsKey("accuracy"))
						desiredAccuracyInMeters = Marshal.ToDouble(options["accuracy"]);
					if (options.ContainsKey("distanceFilter"))
						minDistanceMeters = Marshal.ToDouble(options["distanceFilter"]);
				}
				else
				{
					minimumReportInterval = Marshal.ToInt(args[0]);
					if (args.Length > 1)
						desiredAccuracyInMeters = Marshal.ToDouble(args[1]);
					if (args.Length > 2)
						minDistanceMeters = Marshal.ToDouble(args[2]);
				}
			}

			_locationTracker.StartListening(minimumReportInterval, desiredAccuracyInMeters, minDistanceMeters);
			return null;
		}

		/**
			@scriptmethod stopListening()

			Stops the GeoLocation listening service.

			See [the GeoLocation module](api:fuse/geolocation/geolocation) for an example.
		*/
		object StopListening(Context c, object[] args)
		{
			_locationTracker.StopListening();
			return null;
		}

		/**
			@scriptmethod watchPosition(onLocation, onError, options)

			@param onLocation a function called with the latest location
			@param onError an optional function called when an error occurs
			@param options an optional object with `interval`, `accuracy` and `distanceFilter`
			@return an integer watch id

			Starts a continuous location watcher. Unlike [startListening](api:fuse/geolocation/geolocation/startlistening_bbef95e2.json),
			multiple watchers can be active at the same time, each with its own callback.
			The platform listener is shared, using the most demanding settings across all
			active watchers.

			```js
				var watchId = GeoLocation.watchPosition(function(location) {
					console.log(JSON.stringify(location));
				}, function(error) {
					console.log("GeoLocation error " + error);
				}, {
					interval: 1000,
					accuracy: 10,
					distanceFilter: 10
				});

				GeoLocation.clearWatch(watchId);
			```
		*/
		object WatchPosition(Context context, object[] args)
		{
			var onLocation = (args.Length > 0) ? args[0] as Scripting.Function : null;
			var onError = (args.Length > 1) ? args[1] as Scripting.Function : null;

			int minimumReportInterval = 500;
			double desiredAccuracyInMeters = 10;
			double minDistanceMeters = 0;

			if (args.Length > 2)
			{
				var options = args[2] as Fuse.Scripting.Object;
				if (options != null)
				{
					if (options.ContainsKey("interval"))
						minimumReportInterval = Marshal.ToInt(options["interval"]);
					if (options.ContainsKey("accuracy"))
						desiredAccuracyInMeters = Marshal.ToDouble(options["accuracy"]);
					if (options.ContainsKey("distanceFilter"))
						minDistanceMeters = Marshal.ToDouble(options["distanceFilter"]);
				}
				else
				{
					minimumReportInterval = Marshal.ToInt(args[2]);
					if (args.Length > 3)
						desiredAccuracyInMeters = Marshal.ToDouble(args[3]);
					if (args.Length > 4)
						minDistanceMeters = Marshal.ToDouble(args[4]);
				}
			}

			return _locationTracker.WatchPosition(
				new WatchLocationCallback(context, onLocation).OnLocation,
				new WatchErrorCallback(context, onError).OnError,
				minimumReportInterval, desiredAccuracyInMeters, minDistanceMeters);
		}

		/**
			@scriptmethod clearWatch(watchId)

			@param watchId the id returned by [watchPosition](api:fuse/geolocation/geolocation/watchposition.json)

			Stops the watcher with the given id.
		*/
		object ClearWatch(Context c, object[] args)
		{
			if (args.Length > 0)
				_locationTracker.ClearWatch(Marshal.ToInt(args[0]));
			return null;
		}

		/**
			@scriptmethod startUpdatingHeading(options)

			@param options an optional object with an `interval` field in milliseconds

			Starts compass heading updates. Listen to the
			[headingChanged](api:fuse/geolocation/geolocation/headingchanged.json) event
			to receive them.

			```js
				GeoLocation.on("headingChanged", function(heading) {
					console.log(heading.degrees + " degrees");
				});

				GeoLocation.startUpdatingHeading({ interval: 100 });
			```
		*/
		object StartUpdatingHeading(Context c, object[] args)
		{
			int minimumReportInterval = 0;

			if (args.Length > 0)
			{
				var options = args[0] as Fuse.Scripting.Object;
				if (options != null)
				{
					if (options.ContainsKey("interval"))
						minimumReportInterval = Marshal.ToInt(options["interval"]);
				}
				else
				{
					minimumReportInterval = Marshal.ToInt(args[0]);
				}
			}

			_locationTracker.StartUpdatingHeading(minimumReportInterval);
			return null;
		}

		/**
			@scriptmethod stopUpdatingHeading()

			Stops compass heading updates.
		*/
		object StopUpdatingHeading(Context c, object[] args)
		{
			_locationTracker.StopUpdatingHeading();
			return null;
		}

		/**
			@scriptevent headingChanged(heading)

			Raised when the compass heading changes.

			The parameter object is of the following form:
			```json
				{
					degrees: heading in degrees clockwise from north (0-360),
					accuracy: accuracy in degrees (-1 when unavailable),
					timestamp: milliseconds since the Unix epoch
				}
			```
		*/
		void HeadingChanged(Fuse.GeoLocation.Heading heading)
		{
			EmitFactory(HeadingChangedArgsFactory, heading);
		}

		static object[] HeadingChangedArgsFactory(Context context, Fuse.GeoLocation.Heading heading)
		{
			return new object[] { "headingChanged", HeadingConverter(context, heading) };
		}

		void HeadingError(string error)
		{
			EmitError(error);
		}

		static Scripting.Object HeadingConverter(Context context, Fuse.GeoLocation.Heading heading)
		{
			var obj = context.NewObject();
			if (heading != null)
			{
				obj["degrees"] = heading.Degrees;
				obj["accuracy"] = heading.Accuracy;
				obj["timestamp"] = (double)heading.Timestamp;
			}
			return obj;
		}

		/**
			@scriptmethod addGeofence(options)

			@param options an object with `latitude`, `longitude`, `radius` and an optional `identifier`
			@return the integer geofence id

			Starts monitoring a circular geofence. Listen to the
			[geofenceEntered](api:fuse/geolocation/geolocation/geofenceentered.json) and
			[geofenceExited](api:fuse/geolocation/geolocation/geofenceexited.json) events.

			```js
				var id = GeoLocation.addGeofence({
					latitude: 59.91,
					longitude: 10.75,
					radius: 100,
					identifier: "home"
				});
			```
		*/
		object AddGeofence(Context c, object[] args)
		{
			var options = (args.Length > 0) ? args[0] as Fuse.Scripting.Object : null;
			if (options == null)
				throw new Fuse.Scripting.Error("addGeofence(): an options object is required");

			if (!options.ContainsKey("latitude") || !options.ContainsKey("longitude") || !options.ContainsKey("radius"))
				throw new Fuse.Scripting.Error("addGeofence(): latitude, longitude and radius are required");

			var latitude = Marshal.ToDouble(options["latitude"]);
			var longitude = Marshal.ToDouble(options["longitude"]);
			var radius = Marshal.ToDouble(options["radius"]);
			var identifier = options.ContainsKey("identifier") ? options["identifier"] as string : null;

			var fence = _locationTracker.AddGeofence(new GeoCoordinates(latitude, longitude), radius, identifier);
			return fence.Id;
		}

		/**
			@scriptmethod removeGeofence(id)

			@param id the id returned by [addGeofence](api:fuse/geolocation/geolocation/addgeofence.json)

			Stops monitoring the given geofence.
		*/
		object RemoveGeofence(Context c, object[] args)
		{
			if (args.Length > 0)
				_locationTracker.RemoveGeofence(Marshal.ToInt(args[0]));
			return null;
		}

		/**
			@scriptmethod removeAllGeofences()

			Stops monitoring all geofences.
		*/
		object RemoveAllGeofences(Context c, object[] args)
		{
			_locationTracker.RemoveAllGeofences();
			return null;
		}

		/**
			@scriptevent geofenceEntered(fence)

			Raised when the device enters a geofence.

			@param fence an object with `id`, `identifier`, `latitude`, `longitude` and `radius`
		*/
		void GeofenceEntered(Fuse.GeoLocation.GeoFence fence)
		{
			EmitFactory(GeofenceEnteredArgsFactory, fence);
		}

		static object[] GeofenceEnteredArgsFactory(Context context, Fuse.GeoLocation.GeoFence fence)
		{
			return new object[] { "geofenceEntered", GeofenceConverter(context, fence) };
		}

		/**
			@scriptevent geofenceExited(fence)

			Raised when the device exits a geofence.

			@param fence an object with `id`, `identifier`, `latitude`, `longitude` and `radius`
		*/
		void GeofenceExited(Fuse.GeoLocation.GeoFence fence)
		{
			EmitFactory(GeofenceExitedArgsFactory, fence);
		}

		static object[] GeofenceExitedArgsFactory(Context context, Fuse.GeoLocation.GeoFence fence)
		{
			return new object[] { "geofenceExited", GeofenceConverter(context, fence) };
		}

		void GeofenceError(string error)
		{
			EmitError(error);
		}

		static Scripting.Object GeofenceConverter(Context context, Fuse.GeoLocation.GeoFence fence)
		{
			var obj = context.NewObject();
			if (fence != null)
			{
				obj["id"] = fence.Id;
				obj["identifier"] = fence.Identifier;
				obj["latitude"] = fence.Center.Latitude;
				obj["longitude"] = fence.Center.Longitude;
				obj["radius"] = fence.Radius;
			}
			return obj;
		}

		void ResetGeoLocation(object sender, EventArgs args)
		{
			_locationTracker.ClearAllWatches();
			_locationTracker.StopListening();
			_locationTracker.StopUpdatingHeading();
			_locationTracker.RemoveAllGeofences();
		}

		class WatchLocationCallback
		{
			readonly Context _context;
			readonly Scripting.Function _callback;

			public WatchLocationCallback(Context context, Scripting.Function callback)
			{
				_context = context;
				_callback = callback;
			}

			public void OnLocation(Fuse.GeoLocation.Location location)
			{
				if (_callback != null)
					_context.ThreadWorker.Invoke(new WatchLocationClosure(_callback, location).Run);
			}
		}

		class WatchLocationClosure
		{
			readonly Scripting.Function _callback;
			readonly Fuse.GeoLocation.Location _location;

			public WatchLocationClosure(Scripting.Function callback, Fuse.GeoLocation.Location location)
			{
				_callback = callback;
				_location = location;
			}

			public void Run(Context context)
			{
				_callback.Call(context, Converter(context, _location));
			}
		}

		class WatchErrorCallback
		{
			readonly Context _context;
			readonly Scripting.Function _callback;

			public WatchErrorCallback(Context context, Scripting.Function callback)
			{
				_context = context;
				_callback = callback;
			}

			public void OnError(Exception error)
			{
				if (_callback != null)
					_context.ThreadWorker.Invoke(new WatchErrorClosure(_callback, error.Message).Run);
			}
		}

		class WatchErrorClosure
		{
			readonly Scripting.Function _callback;
			readonly string _message;

			public WatchErrorClosure(Scripting.Function callback, string message)
			{
				_callback = callback;
				_message = message;
			}

			public void Run(Context context)
			{
				_callback.Call(context, _message);
			}
		}

		/**
			@scriptevent changed(location)

			Raised when the location changes.

			Use [startListening](api:fuse/geolocation/geolocation/startlistening_bbef95e2.json) to get these events.

			The parameter object is of the following form:
			```json
				{
					latitude, longitude, accuracy, altitude, hasAltitude, altitudeAccuracy,
					heading, hasHeading, speed, hasSpeed, speedAccuracy, timestamp, isMock, provider
				}
			```
			See [the GeoLocation module](api:fuse/geolocation/geolocation) for an example.

			@param location will contain the new location, see @location
		*/
		void LocationChanged(Fuse.GeoLocation.Location location)
		{
			EmitFactory(ChangedArgsFactory, location);
		}

		static object[] ChangedArgsFactory(Context context, Fuse.GeoLocation.Location location)
		{
			return new object[] { "changed", Converter(context, location) };
		}

		/**
			@scriptevent error(error)

			Raised when an error occurs.

			@param error a string describing the error
		*/
		void LocationError(string error)
		{
			EmitError(error);
		}

		/**
			@scriptevent authorizationStatusChanged(status)

			Raised when the platform authorization status changes.

			@param status one of `"notDetermined"`, `"restricted"`, `"denied"`,
			`"authorizedWhenInUse"` or `"authorizedAlways"`
		*/
		void AuthorizationStatusChanged(string status)
		{
			EmitFactory(AuthorizationStatusChangedArgsFactory, status);
		}

		static object[] AuthorizationStatusChangedArgsFactory(Context context, string status)
		{
			return new object[] { "authorizationStatusChanged", status };
		}

		static int AuthorizationRequestConverter(Context context, Fuse.GeoLocation.GeoLocationAuthorizationType type)
		{
			return (int)type;
		}

		/**
			@scriptproperty authorizationRequest

			@param value (int) Set the authorization request type
				1 = When in use (default)
				2 = Always

			The type of authorization request to make to the user.


			This property determines the type of authorization requested by the rest of the
			GeoLocation API. On Android, `Always` also requests background location access
			when background location is enabled for the project. It should be set before
			using the rest of the GeoLocation API.

			Setting this property to `1`, which is also the
			default, for example as follows:
			```json
				var GeoLocation = require("FuseJS/GeoLocation");
				GeoLocation.authorizationRequest = 1;
			```
			Means that the app should request permission from the
			user to use location services while the app is in the
			foreground. Setting it to `2`, as follows:
			```json
				GeoLocation.authorizationRequest = 2;
			```
			Means that the app should request permission from the
			user to use location services whenever the app is
			running.
		*/
		void SetAuthorizationRequest(int value)
		{
			_locationTracker.AuthorizationType = (GeoLocationAuthorizationType)value;
		}

		Fuse.GeoLocation.GeoLocationAuthorizationType GetAuthorizationRequest()
		{
			return _locationTracker.AuthorizationType;
		}

		/**
			@scriptproperty location
			@readonly

			The last known location.

			The returned object is of the following form:
			```json
				{
					latitude: a number measured in decimal degrees,
					longitude: a number measured in decimal degrees,
					accuracy: a number measured in meters,
					altitude: altitude measured in meters,
					hasAltitude: whether the altitude value is valid,
					altitudeAccuracy: vertical accuracy measured in meters (-1 when unavailable),
					heading: direction of travel measured in degrees from true north (-1 when unavailable),
					hasHeading: whether the heading value is valid,
					speed: speed measured in meters per second,
					hasSpeed: whether the speed value is valid,
					speedAccuracy: speed accuracy measured in meters per second (-1 when unavailable),
					timestamp: milliseconds since the Unix epoch,
					isMock: whether the location was reported by a mock provider,
					provider: the name of the provider that produced the location
				}
			```
			See [the GeoLocation module](api:fuse/geolocation/geolocation) for an example.
		*/
		Fuse.GeoLocation.Location GetLocation()
		{
			return _locationTracker.Location;
		}

		/**
			@scriptmethod getLocation(options)

			@param options (object) Optional `timeout` and `maximumAge` values in milliseconds
			@return a promise

			Gets the current location as a promise.

			Accepts either a timeout (in milliseconds), or an options object:
			```js
				GeoLocation.getLocation({ timeout: 20000, maximumAge: 60000 });
			```

			When `maximumAge` is greater than zero and a cached location is younger than
			that value, the promise resolves immediately with the cached location.

			If successful, the promise is resolved with an object of the following form:
			```json
				{
					latitude, longitude, accuracy, altitude, hasAltitude, altitudeAccuracy,
					heading, hasHeading, speed, hasSpeed, speedAccuracy, timestamp, isMock, provider
				}
			```
			See [the GeoLocation module](api:fuse/geolocation/geolocation) for an example.
		*/
		Future<Fuse.GeoLocation.Location> GetLocationAsync(Context c, object[] args)
		{
			double timeout = 20000;
			double maximumAge = 0;

			if (args.Length > 0)
			{
				var options = args[0] as Fuse.Scripting.Object;
				if (options != null)
				{
					if (options.ContainsKey("timeout"))
						timeout = Marshal.ToDouble(options["timeout"]);
					if (options.ContainsKey("maximumAge"))
						maximumAge = Marshal.ToDouble(options["maximumAge"]);
				}
				else
				{
					timeout = Marshal.ToDouble(args[0]);
					if (args.Length > 1)
						maximumAge = Marshal.ToDouble(args[1]);
				}
			}

			return _locationTracker.GetLocationAsync(timeout, maximumAge);
		}

		/**
			@scriptmethod requestAuthorization(type)

			@param type (int) Optional authorization type: 1 = when in use (default), 2 = always
			@return a promise resolving to the resulting authorization status

			Requests location authorization from the user and resolves with one of
			`"notDetermined"`, `"restricted"`, `"denied"`, `"authorizedWhenInUse"`
			or `"authorizedAlways"`.

			```js
				GeoLocation.requestAuthorization().then(function(status) {
					console.log("GeoLocation authorization: " + status);
				});
			```
		*/
		Future<string> RequestAuthorizationAsync(Context c, object[] args)
		{
			var type = (args.Length > 0)
				? (GeoLocationAuthorizationType)Marshal.ToInt(args[0])
				: _locationTracker.AuthorizationType;
			return _locationTracker.RequestAuthorizationAsync(type);
		}

		/**
			@scriptmethod geocode(address, options)

			@param address the address text to look up
			@param options an optional object with a `maxResults` field
			@return a promise resolving to an array of address objects

			Looks up addresses matching the given text.

			```js
				GeoLocation.geocode("Oslo, Norway", { maxResults: 5 }).then(function(addresses) {
					console.log(addresses[0].formattedAddress);
				});
			```
		*/
		Future<IList<GeoAddress>> GeocodeAsync(Context c, object[] args)
		{
			string address = (args.Length > 0) ? args[0] as string : null;
			int maxResults = 5;

			if (args.Length > 1)
			{
				var options = args[1] as Fuse.Scripting.Object;
				if (options != null)
				{
					if (options.ContainsKey("maxResults"))
						maxResults = Marshal.ToInt(options["maxResults"]);
				}
				else
				{
					maxResults = Marshal.ToInt(args[1]);
				}
			}

			return _locationTracker.GeocodeAsync(address, maxResults);
		}

		/**
			@scriptmethod reverseGeocode(coordinates, options)

			@param coordinates an object with `latitude` and `longitude`
			@param options an optional object with a `maxResults` field
			@return a promise resolving to an array of address objects

			Looks up addresses describing the given coordinates.

			```js
				GeoLocation.reverseGeocode({ latitude: 59.91, longitude: 10.75 }).then(function(addresses) {
					console.log(addresses[0].formattedAddress);
				});
			```
		*/
		Future<IList<GeoAddress>> ReverseGeocodeAsync(Context c, object[] args)
		{
			GeoCoordinates coordinates = null;
			int maxResults = 1;

			if (args.Length > 0)
			{
				var options = args[0] as Fuse.Scripting.Object;
				if (options != null)
				{
					if (options.ContainsKey("latitude") && options.ContainsKey("longitude"))
						coordinates = new GeoCoordinates(Marshal.ToDouble(options["latitude"]), Marshal.ToDouble(options["longitude"]));
					if (options.ContainsKey("maxResults"))
						maxResults = Marshal.ToInt(options["maxResults"]);
				}
				else if (args.Length > 1)
				{
					coordinates = new GeoCoordinates(Marshal.ToDouble(args[0]), Marshal.ToDouble(args[1]));
					if (args.Length > 2)
						maxResults = Marshal.ToInt(args[2]);
				}
			}

			return _locationTracker.ReverseGeocodeAsync(coordinates, maxResults);
		}

		static Scripting.Array AddressesConverter(Context context, IList<GeoAddress> addresses)
		{
			if (addresses == null)
				return context.NewArray();

			var values = new object[addresses.Count];
			for (int i = 0; i < addresses.Count; i++)
				values[i] = AddressConverter(context, addresses[i]);

			return context.NewArray(values);
		}

		static Scripting.Object AddressConverter(Context context, GeoAddress address)
		{
			var obj = context.NewObject();
			if (address == null)
				return obj;

			obj["name"] = address.Name;
			obj["street"] = address.Street;
			obj["streetNumber"] = address.StreetNumber;
			obj["city"] = address.City;
			obj["subLocality"] = address.SubLocality;
			obj["region"] = address.Region;
			obj["subRegion"] = address.SubRegion;
			obj["country"] = address.Country;
			obj["countryCode"] = address.CountryCode;
			obj["postalCode"] = address.PostalCode;
			obj["formattedAddress"] = address.FormattedAddress;

			if (address.Coordinates != null)
			{
				obj["latitude"] = address.Coordinates.Latitude;
				obj["longitude"] = address.Coordinates.Longitude;
			}

			return obj;
		}

		static Scripting.Object Converter(Context context, Fuse.GeoLocation.Location location)
		{
			var obj = context.NewObject();
			if(location != null)
			{
				obj["latitude"] = location.Coordinates.Latitude;
				obj["longitude"] = location.Coordinates.Longitude;
				obj["accuracy"] = location.Accuracy;
				obj["altitude"] = location.Altitude;
				obj["hasAltitude"] = location.HasAltitude;
				obj["altitudeAccuracy"] = location.VerticalAccuracy;
				obj["heading"] = location.Heading;
				obj["hasHeading"] = location.HasHeading;
				obj["speed"] = location.Speed;
				obj["hasSpeed"] = location.HasSpeed;
				obj["speedAccuracy"] = location.SpeedAccuracy;
				obj["timestamp"] = (double)location.Timestamp;
				obj["isMock"] = location.IsMock;
				if (location.Provider != null)
					obj["provider"] = location.Provider;
			}
			return obj;
		}
	}
}
