using Uno;
using Uno.Compiler.ExportTargetInterop;

namespace Fuse.Sensor
{
	/**
		Android implementation of every sensor type.

		All native handles implement `com.fuse.sensorkit.SensorHandle`, so starting, stopping and
		querying a sensor is shared regardless of how it is backed (SensorManager or a broadcast
		receiver).
	*/
	extern(Android) class AndroidSensorProvider : ISensorProvider
	{
		readonly SensorType _sensorType;
		Java.Object _sensor;
		Action<SensorType, object> _onDataChanged;
		Action<SensorType, string> _onDataError;

		public AndroidSensorProvider(SensorType sensorType)
		{
			_sensorType = sensorType;
		}

		public void Init(Action<SensorType, object> onDataChanged, Action<SensorType, string> onDataError)
		{
			_onDataChanged = onDataChanged;
			_onDataError = onDataError;
			_sensor = InitSensor((int)_sensorType, OnDataChanged);
		}

		public void StartListening(int intervalMs)
		{
			if (_sensor == null)
			{
				ReportError(SensorTracker.GetSensorName(_sensorType) + " sensor is not available.");
				return;
			}

			StartSensor(_sensor, intervalMs);
		}

		public void StopListening()
		{
			if (_sensor != null)
				StopSensor(_sensor);
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

		[Foreign(Language.Java)]
		extern(Android) Java.Object InitSensor(int sensorType, Action<Java.Object> onDataChanged)
		@{
			com.fuse.sensorkit.SensorType moduleType = com.fuse.sensorkit.SensorType.fromCode(sensorType);
			if (moduleType == null)
				return null;

			switch (moduleType) {
				case ACCELEROMETER:     return new com.fuse.sensorkit.AccelerometerSensor(onDataChanged);
				case GYROSCOPE:         return new com.fuse.sensorkit.GyroscopeSensor(onDataChanged);
				case MAGNETOMETER:      return new com.fuse.sensorkit.MagnetometerSensor(onDataChanged);
				case GRAVITY:           return new com.fuse.sensorkit.GravitySensor(onDataChanged);
				case USER_ACCELERATION: return new com.fuse.sensorkit.UserAccelerationSensor(onDataChanged);
				case ROTATION:          return new com.fuse.sensorkit.RotationSensor(onDataChanged);
				case STEP_COUNTER:      return new com.fuse.sensorkit.PedometerSensor(onDataChanged);
				case PRESSURE:          return new com.fuse.sensorkit.PressureSensor(onDataChanged);
				case BATTERY:           return new com.fuse.sensorkit.BatterySensor(onDataChanged);
				case CONNECTION_STATE:  return new com.fuse.sensorkit.ConnectionStateSensor(onDataChanged);
			}
			return null;
		@}

		[Foreign(Language.Java)]
		extern(Android) static bool IsSensorAvailable(int sensorType)
		@{
			return com.fuse.sensorkit.AbstractSensor.isAvailable(com.fuse.sensorkit.SensorType.fromCode(sensorType));
		@}

		[Foreign(Language.Java)]
		extern(Android) void StartSensor(Java.Object handle, int intervalMs)
		@{
			try {
				((com.fuse.sensorkit.SensorHandle)handle).start(intervalMs);
			} catch (Exception e) {
				@{AndroidSensorProvider:of(_this).ReportError(string):call(e.getMessage())};
			}
		@}

		[Foreign(Language.Java)]
		extern(Android) void StopSensor(Java.Object handle)
		@{
			try {
				((com.fuse.sensorkit.SensorHandle)handle).stop();
			} catch (Exception e) {
				@{AndroidSensorProvider:of(_this).ReportError(string):call(e.getMessage())};
			}
		@}

		[Foreign(Language.Java)]
		extern(Android) bool IsSensorSensing(Java.Object handle)
		@{
			return handle != null && ((com.fuse.sensorkit.SensorHandle)handle).isSensing();
		@}

		void OnDataChanged(Java.Object newData)
		{
			if (_onDataChanged == null)
				return;

			if (_sensorType == SensorType.BATTERY)
				_onDataChanged(_sensorType, SensorDataHelpers.ConvertBatteryData(newData));
			else if (_sensorType == SensorType.CONNECTION_STATE)
				_onDataChanged(_sensorType, SensorDataHelpers.ConvertConnectionStateData(newData));
			else
				_onDataChanged(_sensorType, SensorDataHelpers.ConvertSensorData(newData));
		}

		void ReportError(string error)
		{
			if (_onDataError != null)
				_onDataError(_sensorType, error);
		}
	}
}
