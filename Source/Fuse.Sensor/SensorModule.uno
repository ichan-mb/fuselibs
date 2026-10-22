using Uno;
using Uno.Collections;
using Uno.Threading;
using Uno.UX;
using Fuse.Scripting;

namespace Fuse.Sensor
{

	[UXGlobalModule]
	/**
		@scriptmodule FuseJS/Sensor

		This module provides easy access to sensors on the device. There are 8 types of sensors supported by this module, namely:
		* Accelerometer Sensor
		* Gyroscope sensor
		* Magnetometer sensor
		* Gravity Sensor
		* User Acceleration Sensor
		* Rotation sensor
		* Step Counter Sensor
		* Pressure sensor

		Besides being able to read sensor data, this module can also monitor changes in state of the battery and network connectivity

		Use [startListening](api:fuse/sensor/sensormodule/startlistening_bbef95e2.json) to get continual sensor data updates.
		 And use [stopListening](api:fuse/sensor/sensormodule/stoplistening_bbef95e2.json) to stop getting continual sensor data updates.
		 Use `isAvailable` to check whether the device has a sensor before starting it, and `getOnce`
		 for a single reading.

		You need to add a reference to `"Fuse.Sensor"` in your project file to use this feature.

		This module is an @EventEmitter, so the methods from @EventEmitter can be used to listen to events.
		Besides the `"changed"` event, every sensor type has its own event (`"accelerometer"`,
		`"gyroscope"`, `"magnetometer"`, `"gravity"`, `"user_acceleration"`, `"rotation"`,
		`"step_counter"`, `"pressure"`, `"battery"` and `"connection_state"`).

		> When running on the device, not all devices have a complete sensor hardware,
		>  so not all sensor output data can be obtained, it all depends on the availability of sensors on the device.
		>  Make sure to check "error" event for possible error that encounter.
		>
		> On Desktop Preview simulated sensor data is produced, so layouts can be developed without a device.

		## iOS requirements

		`STEP_COUNTER` and `PRESSURE` read CoreMotion data that iOS protects with a usage description. The
		app must declare `NSMotionUsageDescription` in its own project file, otherwise iOS terminates the
		app as soon as one of those sensors is used:

		```json
			"ios": {
				"pList": {
					"NSMotionUsageDescription": "Explain here why the app reads motion data"
				}
			}
		```

		Declaring it in `Fuse.Sensor.unoproj` is not enough: the build only applies `ios.pList` from the
		app project, not from referenced libraries.

		## Example

		The following example shows how to access accelerometer sensor:
		```xml
			<JavaScript>
				var Observable = require("FuseJS/Observable");
				var Sensor = require("FuseJS/Sensor");
				var accelerometerData = Observable("")
				var errorMessage = Observable("")

				Sensor.on("error", function(failMessage) {
					errorMessage.value = failMessage;
				});

				Sensor.on("changed", function(data) {
					if (data.type == Sensor.ACCELEROMETER) {
						accelerometerData.value = "X axis : " + data.x + " Y axis : " + data.y + " Z axis : " + data.z;
					}
				});

				function startAccelerometerContinuousListener() {
					Sensor.startListening(Sensor.ACCELEROMETER);
				}

				function stopAccelerometerContinuousListener() {
					Sensor.stopListening(Sensor.ACCELEROMETER);
				}

				module.exports = {
					startAccelerometerContinuousListener,
					stopAccelerometerContinuousListener,
					accelerometerData,
					errorMessage
				};
			</JavaScript>

			<StackPanel ItemSpacing="5" Margin="0,30,0,0">
				<Text>Accelerometer data :</Text>
				<Text Value="{accelerometerData}" />
				<Text Value="{errorMessage}" Color="Red" />

				<Button Text="Start continuous Accelerometer listener" Clicked="{startAccelerometerContinuousListener}" />
				<Button Text="Stop continuous Accelerometer listener" Clicked="{stopAccelerometerContinuousListener}" />
			</StackPanel>
		```
		In the above example we're using `"changed"` event. Data returned by this module are JavaScript objects of the following form:
		```json
			{
				type: sensor type (in this case is Sensor.ACCELEROMETER),
				x: value of x axis,
				y: value of y axis,
				z: value of z axis,
				timestamp: milliseconds since the Unix epoch,
				elapsed: seconds on the sensor's monotonic clock, or 0 when unavailable,
			}
		```
		## Output

		Data returned on the "changed" event argument are JavaScript objects with always have `type` property.
		 Value of `type` property determine what type sensor data it contains.

		## Timestamps

		Every reading has two time values.

		`timestamp` is milliseconds since the Unix epoch, captured when the sample reached the app.
		It can be compared directly with `Date.now()` and converted with `new Date(data.timestamp)`.
		Use it to relate readings to wall clock time and to other events in the app.

		`elapsed` is seconds on the sensor's own monotonic clock (time since the device booted). It is
		taken from the platform's sensor timestamp, so it does not jump when the wall clock is adjusted
		and has no delivery delay. Use it to measure intervals and, for example, to integrate
		acceleration over time. `elapsed` is `0` for readings that have no sensor timestamp (battery,
		connectivity, and the iOS step counter).
		```js
			var Sensor = require("FuseJS/Sensor")
			var lastElapsed = 0;

			Sensor.on("accelerometer", function(data) {
				if (lastElapsed !== 0 && data.elapsed !== 0)
					console.log("interval: " + ((data.elapsed - lastElapsed) * 1000).toFixed(1) + " ms");

				if (data.elapsed !== 0)
					lastElapsed = data.elapsed;
			});
		```
		`elapsed` is comparable between sensors on the same device, but not between devices. Battery
		and connectivity readings carry a `timestamp` too, so they can still be ordered against
		sensor readings.

		Accelerometer, Gyroscope, Magnetometer, Gravity, User Acceleration and Rotation data all have same form of JavaScript object as desribed in the example below:
		```js
			var Sensor = require("FuseJS/Sensor")
			Sensor.on('changed', function(data) {
				switch (data.type) {
					case Sensor.ACCELEROMETER:
						console.log("X axis : " + data.x + " Y axis : " + data.y + " Z axis : " + data.z);
						break;
					case Sensor.GYROSCOPE:
						console.log("X axis : " + data.x + " Y axis : " + data.y + " Z axis : " + data.z);
						break;
					case Sensor.MAGNETOMETER:
						console.log("X axis : " + data.x + " Y axis : " + data.y + " Z axis : " + data.z);
						break;
					case Sensor.GRAVITY:
						console.log("X axis : " + data.x + " Y axis : " + data.y + " Z axis : " + data.z);
						break;
					case Sensor.USER_ACCELERATION:
						console.log("X axis : " + data.x + " Y axis : " + data.y + " Z axis : " + data.z);
						break;
					case Sensor.ROTATION:
						console.log("X axis : " + data.x + " Y axis : " + data.y + " Z axis : " + data.z);
						break;
				}
			});

			function startListeningSensor() {
				Sensor.startListening(Sensor.ACCELEROMETER);
				Sensor.startListening(Sensor.GYROSCOPE);
				Sensor.startListening(Sensor.MAGNETOMETER);
				Sensor.startListening(Sensor.GRAVITY);
				Sensor.startListening(Sensor.USER_ACCELERATION);
				Sensor.startListening(Sensor.ROTATION);
			}

			function stopListeningSensor() {
				Sensor.stopListening(Sensor.ACCELEROMETER);
				Sensor.stopListening(Sensor.GYROSCOPE);
				Sensor.stopListening(Sensor.MAGNETOMETER);
				Sensor.stopListening(Sensor.GRAVITY);
				Sensor.stopListening(Sensor.USER_ACCELERATION);
				Sensor.stopListening(Sensor.ROTATION);
			}
		```
		Step counter and pressure data has slightly different output JavaScript object as described in the example below:
		```js
			var Sensor = require("FuseJS/Sensor")
			Sensor.on('changed', function(data) {
				switch (data.type) {
					case Sensor.STEP_COUNTER:
						console.log("Num Steps taken : " + data.x);
						break;
					case Sensor.PRESSURE:
						console.log("Pressure in hPa / mbar : " + data.x);
						console.log("Relative Altitude (iOS only) in meters : " + data.y);
						break;
				}
			});

			function startListeningSensor() {
				Sensor.startListening(Sensor.STEP_COUNTER);
				Sensor.startListening(Sensor.PRESSURE);
			}

			function stopListeningSensor() {
				Sensor.stopListening(Sensor.STEP_COUNTER);
				Sensor.stopListening(Sensor.PRESSURE);
			}
		```
		Lastly, monitoring state changes of battery or network connectivity has output JavaScript object as follow:
		```js
			var Sensor = require("FuseJS/Sensor")
			Sensor.on('changed', function(data) {
				switch (data.type) {
					case Sensor.BATTERY:
						console.log("Battery level : " + data.level); // platform specific, prefer levelPercent or levelRatio
						console.log("Battery level percent : " + data.levelPercent); // 0-100 on both platforms
						console.log("Battery level ratio : " + data.levelRatio); // 0.0-1.0 on both platforms
						console.log("Battery state : " + data.state); // possible values : charging, full, unplugged, not_charging, unknown, unsupported
						break;
					case Sensor.CONNECTION_STATE:
						console.log("connection state : " + data.state); // boolean value : true connected, false disconnected
						console.log("connection state string : " + data.stateString); // possible values : 'connected' or 'disconnected'
						break;
				}
			});

			function startMonitoringState() {
				Sensor.startListening(Sensor.BATTERY);
				Sensor.startListening(Sensor.CONNECTION_STATE);
			}

			function stopMonitoringState() {
				Sensor.stopListening(Sensor.BATTERY);
				Sensor.stopListening(Sensor.CONNECTION_STATE);
			}
		```
		To handle errors from Sensor we can listen to the `"error"` event, as follows:
		```js
			var Sensor = require("FuseJS/Sensor")
			Sensor.on("error", function(err) { ... })
		```

		## Availability

		Not every device has every sensor, and the app should check before starting one:
		```js
			var Sensor = require("FuseJS/Sensor")

			if (Sensor.isAvailable(Sensor.STEP_COUNTER)) {
				Sensor.startListening(Sensor.STEP_COUNTER);
			}

			console.log("Available sensors: " + Sensor.getAvailable().join(", "));
		```
		`getAvailable()` returns an array of the `Sensor` constants that this device supports.

		## One-shot reads

		`getOnce(sensorType)` returns a promise that resolves with a single reading, in the same form
		as the `"changed"` event. If the sensor is not already listening it is started for that one
		reading and stopped again afterwards.
		```js
			var Sensor = require("FuseJS/Sensor")

			Sensor.getOnce(Sensor.PRESSURE).then(function(data) {
				console.log("Pressure: " + data.x + " hPa");
			}).catch(function(err) {
				console.log("Could not read the pressure sensor: " + err);
			});
		```

		## Sampling rate

		`startListening(sensorType, interval)` accepts an optional interval in milliseconds. It is a
		hint: the actual rate also depends on the device, and some sensors (battery, connectivity, step
		counter) are paced by the system.
		```js
			Sensor.startListening(Sensor.ACCELEROMETER, 16); // request roughly 60 Hz
		```

		## Per-sensor events

		In addition to `"changed"`, every sensor type has its own event, so listeners do not have to
		filter on `data.type`:
		```js
			var Sensor = require("FuseJS/Sensor")

			Sensor.on("accelerometer", function(data) {
				console.log("X axis : " + data.x + " Y axis : " + data.y + " Z axis : " + data.z);
			});
		```
		@scriptproperty (int) ACCELEROMETER track accelerometer sensor.
		@scriptproperty (int) GYROSCOPE track gyroscope sensor.
		@scriptproperty (int) MAGNETOMETER track magnetometer sensor.
		@scriptproperty (int) GRAVITY track gravity sensor.
		@scriptproperty (int) USER_ACCELERATION track user acceleration sensor.
		@scriptproperty (int) ROTATION track rotation sensor.
		@scriptproperty (int) STEP_COUNTER track step counter sensor.
		@scriptproperty (int) PRESSURE track pressure sensor.
		@scriptproperty (int) BATTERY track battery states.
		@scriptproperty (int) CONNECTION_STATE track network connectivity states.

	*/
	public class SensorModule : NativeEventEmitterModule
	{
		static readonly SensorModule _instance;
		SensorTracker _tracker;

		public SensorModule()
			: base(false,
				"changed", "error",
				// One event per sensor type, see @SensorTracker.GetEventName. Every event name has to be
				// registered here, otherwise emitting it throws in the JS EventEmitter.
				"accelerometer", "gyroscope", "magnetometer", "gravity", "user_acceleration",
				"rotation", "step_counter", "pressure", "battery", "connection_state")
		{
			if (_instance != null) return;

			_instance = this;
			Resource.SetGlobalKey(_instance, "FuseJS/Sensor");

			// Keep an internal listener registered on "error". The JS EventEmitter throws when
			// "error" is emitted without a listener, which would turn a recoverable sensor error
			// (unsupported sensor, desktop preview, ...) into an uncaught JavaScript exception.
			On("error", new NativeEvent("sensorError"));

			_tracker = new SensorTracker();
			_tracker.DataChanged += DataChanged;
			_tracker.DataError += OnError;

			AddMember(new NativeProperty<int, int>("ACCELEROMETER", SensorType.ACCELEROMETER));
			AddMember(new NativeProperty<int, int>("GYROSCOPE", SensorType.GYROSCOPE));
			AddMember(new NativeProperty<int, int>("MAGNETOMETER", SensorType.MAGNETOMETER));
			AddMember(new NativeProperty<int, int>("GRAVITY", SensorType.GRAVITY));
			AddMember(new NativeProperty<int, int>("USER_ACCELERATION", SensorType.USER_ACCELERATION));
			AddMember(new NativeProperty<int, int>("ROTATION", SensorType.ROTATION));
			AddMember(new NativeProperty<int, int>("STEP_COUNTER", SensorType.STEP_COUNTER));
			AddMember(new NativeProperty<int, int>("PRESSURE", SensorType.PRESSURE));
			AddMember(new NativeProperty<int, int>("BATTERY", SensorType.BATTERY));
			AddMember(new NativeProperty<int, int>("CONNECTION_STATE", SensorType.CONNECTION_STATE));
			AddMember(new NativeFunction("startListening", (NativeCallback)StartListening));
			AddMember(new NativeFunction("isSensing", (NativeCallback)IsSensing));
			AddMember(new NativeFunction("stopListening", (NativeCallback)StopListening));
			AddMember(new NativeFunction("isAvailable", (NativeCallback)IsAvailable));
			AddMember(new NativeFunction("getAvailable", (NativeCallback)GetAvailable));
			AddMember(new NativePromise<object, Scripting.Object>("getOnce", (FutureFactory2<object>)GetOnce, ConvertData));
		}

		/**
			@scriptmethod startListening(sensorType, interval)

			Starts the Sensor listening service.

			[onChanged](api:fuse/sensor/sensormodule/datachanged_a09c80e3.json)
			events will be generated as the sensor changes.


			Use [stopListening](api:fuse/sensor/sensormodule/stoplistening_bbef95e2.json) to stop the service.

			@param sensorType what type sensor that want to listen. see @SensorType for details
			@param interval Optional desired sampling interval in milliseconds. Defaults to the platform
				default. This is a hint; the actual rate also depends on the device.

		*/
		object StartListening(Context c, object[] args)
		{
			SensorType sensorType;
			if (!TryGetSensorType(args, out sensorType))
			{
				EmitError("Please Specify SensorType");
				return null;
			}
			if (!SensorTracker.IsSupported(sensorType))
			{
				EmitError("Unknown SensorType");
				return null;
			}

			int intervalMs = 0;
			if (args.Length > 1)
			{
				double interval;
				if (!Marshal.TryToDouble(args[1], out interval) || interval < 0 || interval > 60000)
				{
					EmitError("Please Specify a valid interval in milliseconds");
					return null;
				}
				intervalMs = (int)interval;
			}

			_tracker.StartListening(sensorType, intervalMs);
			return null;
		}

		/**
			@scriptmethod stopListening(sensorType)

			Stops the Sensor listening service.

			Calling this without a sensor type stops every sensor that is currently listening.

			@param sensorType what type sensor that want to stop listen. see @SensorType for details
		*/
		object StopListening(Context c, object[] args)
		{
			if (args.Length == 0)
			{
				_tracker.StopAll();
				return null;
			}

			SensorType sensorType;
			if (!TryGetSensorType(args, out sensorType))
			{
				EmitError("Please Specify SensorType");
				return null;
			}
			if (!SensorTracker.IsSupported(sensorType))
			{
				EmitError("Unknown SensorType");
				return null;
			}
			_tracker.StopListening(sensorType);
			return null;
		}

		/**
			@scriptmethod isSensing(sensorType)

			check whether sensor module is sensing for particular sensor.

			@param sensorType what type sensor that want to check. see @SensorType for details
		*/
		object IsSensing(Context c, object[] args)
		{
			SensorType sensorType;
			if (!TryGetSensorType(args, out sensorType))
			{
				EmitError("Please Specify SensorType");
				return false;
			}
			if (!SensorTracker.IsSupported(sensorType))
			{
				EmitError("Unknown SensorType");
				return false;
			}
			return _tracker.IsSensing(sensorType);
		}

		/**
			@scriptmethod isAvailable(sensorType)

			Returns whether the device has the hardware (or platform support) for the sensor.

			@param sensorType what type sensor that want to check. see @SensorType for details
			@return true if the sensor can be used on this device
		*/
		object IsAvailable(Context c, object[] args)
		{
			SensorType sensorType;
			if (!TryGetSensorType(args, out sensorType))
			{
				EmitError("Please Specify SensorType");
				return false;
			}

			return SensorTracker.IsAvailable(sensorType);
		}

		/**
			@scriptmethod getAvailable()

			Returns an array with every @SensorType that is available on this device.

			@return an array of sensor types
		*/
		object GetAvailable(Context c, object[] args)
		{
			var available = new List<object>();

			for (int i = 0; i < SensorTracker.AllTypes.Length; i++)
			{
				var type = SensorTracker.AllTypes[i];
				if (SensorTracker.IsAvailable(type))
					available.Add((int)type);
			}

			return c.NewArray(available.ToArray());
		}

		/**
			@scriptmethod getOnce(sensorType)

			@return a promise that resolves with a single reading of the sensor.

			The reading has the same form as the argument of the `"changed"` event. If the sensor is
			not already listening it is started for this single reading and stopped again afterwards.

			@param sensorType what type sensor that want to read. see @SensorType for details
		*/
		Future<object> GetOnce(Context c, object[] args)
		{
			var result = new Promise<object>();

			SensorType sensorType;
			if (!TryGetSensorType(args, out sensorType))
			{
				result.Reject(new Exception("Please Specify SensorType"));
				return result;
			}

			if (!SensorTracker.IsSupported(sensorType))
			{
				result.Reject(new Exception("Unknown SensorType"));
				return result;
			}

			_tracker.GetOnce(sensorType, result);
			return result;
		}

		/** Validates the sensor type argument. Using Marshal.ToInt directly would throw a
			MarshalException (or silently fall back to ACCELEROMETER) for non-numeric input. */
		static bool TryGetSensorType(object[] args, out SensorType sensorType)
		{
			sensorType = SensorType.ACCELEROMETER;
			if (args.Length == 0)
				return false;

			double value;
			if (!Marshal.TryToDouble(args[0], out value))
				return false;

			if (value < 0 || value > 100 || value != (int)value)
				return false;

			sensorType = (SensorType)(int)value;
			return true;
		}

		/**
			@scriptevent changed(data)

			Raised when the sensor changes.

			Use [startListening](api:fuse/sensor/sensormodule/startlistening_bbef95e2.json) to get these events.

			This event carries the data of every sensor type. To only receive the data of one sensor,
			listen to its own event instead (`"accelerometer"`, `"gyroscope"`, `"magnetometer"`,
			`"gravity"`, `"user_acceleration"`, `"rotation"`, `"step_counter"`, `"pressure"`,
			`"battery"` or `"connection_state"`).

			Every reading has `timestamp` (milliseconds since the Unix epoch) and `elapsed` (seconds on
			the sensor's monotonic clock) properties, see [Timestamps](#timestamps).

			@param data will contain the new data, see @SensorData or @BatteryData or @ConnectionStateData
		*/
		void DataChanged(SensorType type, object data)
		{
			EmitFactory(ChangedArgsFactory, data);
			EmitFactory(TypeChangedArgsFactory, Tuple.Create(type, data));
		}

		/**
			@scriptevent error(error)

			Raised when an error occurs.

			@param error a string describing the error
		*/
		void OnError(string error)
		{
			EmitError(error);
		}

		static object[] ChangedArgsFactory(Context context, object obj)
		{
			return new object[] { "changed", ConvertData(context, obj) };
		}

		static object[] TypeChangedArgsFactory(Context context, Tuple<SensorType, object> payload)
		{
			return new object[] { SensorTracker.GetEventName(payload.Item1), ConvertData(context, payload.Item2) };
		}

		static Scripting.Object ConvertData(Context context, object obj)
		{
			if (obj is BatteryData)
				return BatteryDataConverter(context, (BatteryData)obj);
			else if (obj is ConnectionStateData)
				return ConnectionDataConverter(context, (ConnectionStateData)obj);
			else
				return SensorDataConverter(context, (SensorData)obj);
		}

		static Scripting.Object SensorDataConverter(Context context, SensorData sensorData)
		{
			var obj = context.NewObject();
			if(sensorData != null)
			{
				obj["type"] = sensorData.Type;
				obj["x"] = sensorData.Data[0];
				obj["y"] = sensorData.Data[1];
				obj["z"] = sensorData.Data[2];
				obj["timestamp"] = sensorData.Timestamp;
				obj["elapsed"] = sensorData.Elapsed;
			}
			return obj;
		}

		static Scripting.Object BatteryDataConverter(Context context, BatteryData sensorData)
		{
			var obj = context.NewObject();
			if(sensorData != null)
			{
				obj["type"] = (int)SensorType.BATTERY;
				obj["level"] = sensorData.Level;
				obj["levelPercent"] = sensorData.LevelPercent;
				obj["levelRatio"] = sensorData.LevelRatio;
				obj["state"] = sensorData.State;
				obj["timestamp"] = sensorData.Timestamp;
				obj["elapsed"] = sensorData.Elapsed;
			}
			return obj;
		}

		static Scripting.Object ConnectionDataConverter(Context context, ConnectionStateData sensorData)
		{
			var obj = context.NewObject();
			if(sensorData != null)
			{
				obj["type"] = (int)SensorType.CONNECTION_STATE;
				obj["state"] = sensorData.ConnectionStatus;
				obj["stateString"] = sensorData.ConnectionStatusString;
				obj["timestamp"] = sensorData.Timestamp;
				obj["elapsed"] = sensorData.Elapsed;
			}
			return obj;
		}
	}

	/** Determines the sensor type available for @SensorModule. */
	public enum SensorType {
		/** Measures the acceleration force in m/s2 that is applied to a device on all three physical axes (x, y, and z), including the force of gravity (9.81 m/s2) */
		ACCELEROMETER = 0,
		/** Measures a device's rate of rotation in rad/s around each of the three physical axes (x, y, and z) */
		GYROSCOPE = 1,
		/** Measures the ambient geomagnetic field for all three physical axes (x, y, z) in μT */
		MAGNETOMETER = 2,
		/** Measures the force of gravity in m/s2 that is applied to a device on all three physical axes (x, y, z). */
		GRAVITY = 3,
		/** Measures the acceleration force in m/s2 that is applied to a device on all three physical axes (x, y, and z), excluding the force of gravity. */
		USER_ACCELERATION = 4,
		/** Measures the orientation of a device by providing the three elements of the device's rotation vector. */
		ROTATION = 5,
		/** Number of steps taken by the user since the last reboot while the sensor was activated.
			Requires the ACTIVITY_RECOGNITION permission on Android 10 and later, which can be requested
			with Fuse.Android.Permissions (Android.ACTIVITY_RECOGNITION). On iOS the app must declare
			NSMotionUsageDescription in its own project file. */
		STEP_COUNTER = 6,
		/** Measures the ambient air pressure in hPa or mbar. On iOS the app must declare
			NSMotionUsageDescription in its own project file. */
		PRESSURE = 7,
		/** Monitor battery level and state */
		BATTERY = 8,
		/** Monitor network connectivity */
		CONNECTION_STATE = 9
	}
}