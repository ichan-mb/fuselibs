using Uno;
using Uno.Diagnostics;

namespace Fuse.Sensor
{
	/**
		Provides simulated sensor data on targets without native sensor support, mainly desktop
		preview.

		This lets layouts and JavaScript consume sensor data without a device. The data is
		deterministic and smooth (sine waves), so it is useful for building and testing sensor
		driven UI.
	*/
	public class SpoofSensorProvider : ISensorProvider
	{
		readonly SensorType _sensorType;
		readonly Action _update;
		Action<SensorType, object> _onDataChanged;

		bool _sensing;
		bool _updating;
		int _intervalMs = 100;
		double _startedAt;
		double _lastEmit;

		public SpoofSensorProvider(SensorType sensorType)
		{
			_sensorType = sensorType;
			_update = Update;
		}

		public void Init(Action<SensorType, object> onDataChanged, Action<SensorType, string> onDataError)
		{
			_onDataChanged = onDataChanged;
			// Simulated data never fails, so onDataError is not used.
		}

		public void StartListening(int intervalMs)
		{
			if (_sensing)
				return;

			_intervalMs = intervalMs > 0 ? intervalMs : 100;
			_startedAt = Clock.GetSeconds();
			_lastEmit = _startedAt - _intervalMs / 1000.0;

			_sensing = true;

			if (!_updating)
			{
				UpdateManager.AddAction(_update);
				_updating = true;
			}

			// Emit one sample right away so that getOnce resolves without waiting for a frame.
			Update();
		}

		public void StopListening()
		{
			if (!_sensing)
				return;

			_sensing = false;

			if (_updating)
			{
				UpdateManager.RemoveAction(_update);
				_updating = false;
			}
		}

		public bool IsSensing()
		{
			return _sensing;
		}

		void Update()
		{
			if (!_sensing || _onDataChanged == null)
				return;

			var now = Clock.GetSeconds();
			if (now - _lastEmit < _intervalMs / 1000.0)
				return;

			_lastEmit = now;
			var t = now - _startedAt;

			switch (_sensorType)
			{
				case SensorType.ACCELEROMETER:
					// Resting at 9.81 m/s2 on z, with a little motion on x and y.
					Emit(2.0f * (float)Math.Sin(t * 1.5), 2.0f * (float)Math.Cos(t * 1.1), 9.81f + 0.5f * (float)Math.Sin(t * 2.0));
					break;

				case SensorType.GYROSCOPE:
					Emit(0.2f * (float)Math.Sin(t), 0.2f * (float)Math.Cos(t * 1.3), 0.1f * (float)Math.Sin(t * 0.7));
					break;

				case SensorType.MAGNETOMETER:
					Emit(20.0f + 5.0f * (float)Math.Sin(t * 0.3), 10.0f * (float)Math.Cos(t * 0.3), -40.0f);
					break;

				case SensorType.GRAVITY:
					Emit(0.0f, 0.0f, 9.81f);
					break;

				case SensorType.USER_ACCELERATION:
					Emit(2.0f * (float)Math.Sin(t * 1.5), 2.0f * (float)Math.Cos(t * 1.1), 0.5f * (float)Math.Sin(t * 2.0));
					break;

				case SensorType.ROTATION:
					Emit(0.1f * (float)Math.Sin(t), 0.1f * (float)Math.Cos(t), 0.0f);
					break;

				case SensorType.STEP_COUNTER:
					// Roughly a walking pace, in steps since startListening.
					Emit((float)(t * 1.5), 0.0f, 0.0f);
					break;

				case SensorType.PRESSURE:
					Emit(1013.25f + 3.0f * (float)Math.Sin(t * 0.2), 0.0f, 0.0f);
					break;

				case SensorType.BATTERY:
				{
					// Cycles so battery UI can be exercised. Values are 0.0 - 1.0, like iOS.
					var level = 0.75f + 0.2f * (float)Math.Sin(t * 0.05);
					_onDataChanged(_sensorType, new BatteryData(level, level * 100.0f, level, "charging"));
					break;
				}

				case SensorType.CONNECTION_STATE:
				{
					// Flips every 10 seconds so offline UI can be exercised.
					var connected = ((int)(t / 10.0)) % 2 == 0;
					_onDataChanged(_sensorType, new ConnectionStateData(connected, connected ? "connected" : "disconnected"));
					break;
				}
			}
		}

		void Emit(float x, float y, float z)
		{
			var elapsed = Clock.GetSeconds();
			_onDataChanged(_sensorType, new SensorData((int)_sensorType, float3(x, y, z), SensorTimestamp.Now(), elapsed));
		}
	}
}
