using Uno;
using Uno.Compiler.ExportTargetInterop;

namespace Fuse.Sensor
{
	/**
		iOS implementation of every sensor type.

		The concrete wrappers all implement the `FOSensor` protocol, so starting, stopping and
		querying a sensor is shared. Only the creation of the wrapper and the shape of its data
		depend on the sensor type.
	*/
	[Require("xcode.framework", "CoreMotion")]
	[Require("xcode.framework", "SystemConfiguration")]
	[ForeignInclude(Language.ObjC,
		"iOS/sensors/FOSensor.h",
		"iOS/sensors/FOSensorConfig.h",
		"iOS/sensors/FOAccelerometer.h",
		"iOS/sensors/FOGyroscope.h",
		"iOS/sensors/FOMagnetometer.h",
		"iOS/sensors/FODeviceMotion.h",
		"iOS/sensors/FOPedometer.h",
		"iOS/sensors/FOPressure.h",
		"iOS/sensors/FOBattery.h",
		"iOS/sensors/FOConnection.h",
		"iOS/data/FOBatteryData.h",
		"iOS/data/FOConnectionStateData.h")]
	extern(iOS) class IOSSensorProvider : ISensorProvider
	{
		readonly SensorType _sensorType;
		ObjC.Object _sensor;
		Action<SensorType, object> _onDataChanged;
		Action<SensorType, string> _onDataError;

		public IOSSensorProvider(SensorType sensorType)
		{
			_sensorType = sensorType;
		}

		public void Init(Action<SensorType, object> onDataChanged, Action<SensorType, string> onDataError)
		{
			_onDataChanged = onDataChanged;
			_onDataError = onDataError;
			_sensor = InitSensor((int)_sensorType);
		}

		public void StartListening(int intervalMs)
		{
			if (_sensor == null)
			{
				ReportError(SensorTracker.GetSensorName(_sensorType) + " sensor is not available.");
				return;
			}

			// 100 Hz is the default rate of the CoreMotion wrappers.
			SetSensorUpdateInterval((int)_sensorType, intervalMs > 0 ? intervalMs / 1000.0 : 0.01);

			if (!StartSensor(_sensor))
				ReportError(SensorTracker.GetSensorName(_sensorType) + " sensor is not available.");
		}

		public void StopListening()
		{
			if (_sensor != null && !StopSensor(_sensor))
				ReportError("Stopping " + SensorTracker.GetSensorName(_sensorType) + " failed.");
		}

		public bool IsSensing()
		{
			return _sensor != null && IsSensorSensing(_sensor);
		}

		/** Whether the device has hardware for @type. */
		public static bool IsAvailable(SensorType type)
		{
			if (!SensorTracker.IsSupported(type))
				return false;

			return IsSensorAvailable((int)type);
		}

		[Foreign(Language.ObjC)]
		extern(iOS) static bool IsSensorAvailable(int sensorType)
		@{
			return [FOSensorConfig isAvailable:sensorType];
		@}

		[Foreign(Language.ObjC)]
		extern(iOS) void SetSensorUpdateInterval(int sensorType, double intervalSeconds)
		@{
			[FOSensorConfig setUpdateInterval:intervalSeconds forSensorType:sensorType];
		@}

		[Foreign(Language.ObjC)]
		extern(iOS) ObjC.Object InitSensor(int sensorType)
		@{
			// The case values must match Fuse.Sensor.SensorType.
			switch (sensorType)
			{
				case 0: // ACCELEROMETER
					return [[FOAccelerometer alloc] initWithBlock:^void (CMAccelerometerData* accelerometerData)
					{
						// Normalize acceleration to match Android.
						float x = accelerometerData.acceleration.x * -9.81f;
						float y = accelerometerData.acceleration.y * -9.81f;
						float z = accelerometerData.acceleration.z * -9.81f;
						@{IOSSensorProvider:of(_this).OnVectorDataChanged(float,float,float,double):call(x,y,z,accelerometerData.timestamp)};
					}
					error:^void (NSError* err)
					{
						if (err != nil)
							@{IOSSensorProvider:of(_this).ReportError(string):call(err.localizedDescription)};
					}
					];

				case 1: // GYROSCOPE
					return [[FOGyroscope alloc] initWithBlock:^void (CMGyroData* gyroData)
					{
						@{IOSSensorProvider:of(_this).OnVectorDataChanged(float,float,float,double):call(gyroData.rotationRate.x,gyroData.rotationRate.y,gyroData.rotationRate.z,gyroData.timestamp)};
					}
					error:^void (NSError* err)
					{
						if (err != nil)
							@{IOSSensorProvider:of(_this).ReportError(string):call(err.localizedDescription)};
					}
					];

				case 2: // MAGNETOMETER
					return [[FOMagnetometer alloc] initWithBlock:^void (CMMagnetometerData* magnetoData)
					{
						@{IOSSensorProvider:of(_this).OnVectorDataChanged(float,float,float,double):call(magnetoData.magneticField.x,magnetoData.magneticField.y,magnetoData.magneticField.z,magnetoData.timestamp)};
					}
					error:^void (NSError* err)
					{
						if (err != nil)
							@{IOSSensorProvider:of(_this).ReportError(string):call(err.localizedDescription)};
					}
					];

				case 3: // GRAVITY
					return [[FODeviceMotion alloc] initWithBlock:^void (CMDeviceMotion* deviceMotionData)
					{
						// deviceMotion.gravity is expressed in g, while Android reports m/s2.
						// It is also sign-inverted compared to Android's TYPE_GRAVITY.
						float x = deviceMotionData.gravity.x * -9.81f;
						float y = deviceMotionData.gravity.y * -9.81f;
						float z = deviceMotionData.gravity.z * -9.81f;
						@{IOSSensorProvider:of(_this).OnVectorDataChanged(float,float,float,double):call(x,y,z,deviceMotionData.timestamp)};
					}
					error:^void (NSError* err)
					{
						if (err != nil)
							@{IOSSensorProvider:of(_this).ReportError(string):call(err.localizedDescription)};
					}
					];

				case 4: // USER_ACCELERATION
					return [[FODeviceMotion alloc] initWithBlock:^void (CMDeviceMotion* deviceMotionData)
					{
						// userAcceleration is expressed in g, while Android reports m/s2.
						float x = deviceMotionData.userAcceleration.x * -9.81f;
						float y = deviceMotionData.userAcceleration.y * -9.81f;
						float z = deviceMotionData.userAcceleration.z * -9.81f;
						@{IOSSensorProvider:of(_this).OnVectorDataChanged(float,float,float,double):call(x,y,z,deviceMotionData.timestamp)};
					}
					error:^void (NSError* err)
					{
						if (err != nil)
							@{IOSSensorProvider:of(_this).ReportError(string):call(err.localizedDescription)};
					}
					];

				case 5: // ROTATION
					return [[FODeviceMotion alloc] initWithBlock:^void (CMDeviceMotion* deviceMotionData)
					{
						// The vector part of the attitude quaternion has the same shape as Android's
						// TYPE_ROTATION_VECTOR. The reference frame differs: iOS uses a Z-vertical
						// frame, Android an East-North-Up frame.
						CMQuaternion q = deviceMotionData.attitude.quaternion;
						@{IOSSensorProvider:of(_this).OnVectorDataChanged(float,float,float,double):call(q.x,q.y,q.z,deviceMotionData.timestamp)};
					}
					error:^void (NSError* err)
					{
						if (err != nil)
							@{IOSSensorProvider:of(_this).ReportError(string):call(err.localizedDescription)};
					}
					];

				case 6: // STEP_COUNTER
					return [[FOPedometer alloc] initWithBlock:^void (CMPedometerData* pedometerData)
					{
						@{IOSSensorProvider:of(_this).OnVectorDataChanged(float,float,float,double):call([pedometerData.numberOfSteps floatValue],0.0f,0.0f,0.0)};
					}
					error:^void (NSError* err)
					{
						if (err != nil)
							@{IOSSensorProvider:of(_this).ReportError(string):call(err.localizedDescription)};
					}
					];

				case 7: // PRESSURE
					return [[FOPressure alloc] initWithBlock:^void (CMAltitudeData* altitudeData)
					{
						// CoreMotion reports pressure in kPa; normalize it to hPa / mbar, like Android.
						float pressure = [altitudeData.pressure floatValue]*10;
						@{IOSSensorProvider:of(_this).OnVectorDataChanged(float,float,float,double):call(pressure,[altitudeData.relativeAltitude floatValue],0.0f,altitudeData.timestamp)};
					}
					error:^void (NSError* err)
					{
						if (err != nil)
							@{IOSSensorProvider:of(_this).ReportError(string):call(err.localizedDescription)};
					}
					];

				case 8: // BATTERY
					return [[FOBattery alloc] initWithBlock:^void (FOBatteryData* batteryData)
					{
						@{IOSSensorProvider:of(_this).OnObjectDataChanged(ObjC.Object):call(batteryData)};
					}
					error:^void (NSError* err)
					{
						if (err != nil)
							@{IOSSensorProvider:of(_this).ReportError(string):call(err.localizedDescription)};
					}
					];

				case 9: // CONNECTION_STATE
					return [[FOConnection alloc] initWithBlock:^void (FOConnectionStateData* status)
					{
						@{IOSSensorProvider:of(_this).OnObjectDataChanged(ObjC.Object):call(status)};
					}
					error:^void (NSError* err)
					{
						if (err != nil)
							@{IOSSensorProvider:of(_this).ReportError(string):call(err.localizedDescription)};
					}
					];
			}

			return nil;
		@}

		[Foreign(Language.ObjC)]
		extern(iOS) bool StartSensor(ObjC.Object handle)
		@{
			return [(id<FOSensor>)handle startSensing];
		@}

		[Foreign(Language.ObjC)]
		extern(iOS) bool StopSensor(ObjC.Object handle)
		@{
			return [(id<FOSensor>)handle stopSensing];
		@}

		[Foreign(Language.ObjC)]
		extern(iOS) bool IsSensorSensing(ObjC.Object handle)
		@{
			return [(id<FOSensor>)handle isSensing];
		@}

		void OnVectorDataChanged(float x, float y, float z, double elapsed)
		{
			if (_onDataChanged != null)
				_onDataChanged(_sensorType, SensorDataHelpers.ConvertSensorData((int)_sensorType, x, y, z, elapsed));
		}

		void OnObjectDataChanged(ObjC.Object data)
		{
			if (_onDataChanged == null)
				return;

			if (_sensorType == SensorType.BATTERY)
				_onDataChanged(_sensorType, SensorDataHelpers.ConvertBatteryData(data));
			else
				_onDataChanged(_sensorType, SensorDataHelpers.ConvertConnectionState(data));
		}

		void ReportError(string error)
		{
			if (_onDataError != null)
				_onDataError(_sensorType, error);
		}
	}
}
