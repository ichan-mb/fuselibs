using Uno;

namespace Fuse.Sensor
{
	/**
		Timestamps for sensor samples.

		All timestamps are milliseconds since the Unix epoch, so they can be compared directly with
		JavaScript's `Date.now()` and converted with `new Date(timestamp)`.
	*/
	public static class SensorTimestamp
	{
		// .NET tick (100 ns) count at 1970-01-01T00:00:00Z.
		const long UnixEpochTicks = 621355968000000000L;

		/**
			The current time in milliseconds since the Unix epoch.

			This is captured when the sample reaches the app, not on the sensor hardware, so it
			includes a small, roughly constant delivery delay. Use differences between timestamps to
			measure sample intervals and to correlate samples from different sensors.
		*/
		public static double Now()
		{
			return (DateTime.UtcNow.Ticks - UnixEpochTicks) / 10000.0;
		}
	}

	public class SensorData
	{
		int _type;
		float3 _data;
		double _timestamp;
		double _elapsed;

		public int Type { get { return _type; } }

		public float3 Data { get { return _data; } }

		/** Milliseconds since the Unix epoch, captured when the sample arrived. */
		public double Timestamp { get { return _timestamp; } }

		/**
			Seconds on the device's monotonic clock, as reported by the sensor hardware. Unlike
			`Timestamp` this never jumps when the wall clock is adjusted, so it is the right value
			for measuring intervals between samples. It is 0 when the platform does not provide a
			sensor timestamp.
		*/
		public double Elapsed { get { return _elapsed; } }

		public SensorData(int type, float3 data)
			: this(type, data, SensorTimestamp.Now(), 0.0)
		{
		}

		public SensorData(int type, float3 data, double timestamp, double elapsed)
		{
			_type = type;
			_data = data;
			_timestamp = timestamp;
			_elapsed = elapsed;
		}
	}

	public class BatteryData
	{
		float _level;
		float _levelPercent;
		float _levelRatio;
		string _state;
		double _timestamp;

		/**
			The battery level exactly as reported by the platform. Android reports a raw
			percentage, iOS a 0.0-1.0 ratio. Prefer LevelPercent or LevelRatio for code that needs
			to work on both platforms.
		*/
		public float Level { get { return _level; } }

		/** The battery level in percent (0-100) on all platforms. */
		public float LevelPercent { get { return _levelPercent; } }

		/** The battery level as a ratio (0.0-1.0) on all platforms. */
		public float LevelRatio { get { return _levelRatio; } }

		/**
			The battery state. One of "charging", "full", "unplugged", "not_charging",
			"unknown" or "unsupported".
		*/
		public string State { get { return _state; } }

		/** Milliseconds since the Unix epoch, captured when the sample arrived. */
		public double Timestamp { get { return _timestamp; } }

		/** Always 0: battery level has no sensor timestamp. */
		public double Elapsed { get { return 0.0; } }

		/** Kept for source compatibility. `level` is interpreted as a 0.0-1.0 ratio. */
		public BatteryData(float level, string state)
			: this(level, level * 100.0f, level, state)
		{
		}

		public BatteryData(float level, float levelPercent, float levelRatio, string state)
			: this(level, levelPercent, levelRatio, state, SensorTimestamp.Now())
		{
		}

		public BatteryData(float level, float levelPercent, float levelRatio, string state, double timestamp)
		{
			_level = level;
			_levelPercent = levelPercent;
			_levelRatio = levelRatio;
			_state = state;
			_timestamp = timestamp;
		}
	}

	public class ConnectionStateData
	{
		bool _connectionStatus;
		string _connectionStatusString;
		double _timestamp;

		public bool ConnectionStatus { get { return _connectionStatus; } }

		public string ConnectionStatusString { get { return _connectionStatusString; } }

		/** Milliseconds since the Unix epoch, captured when the sample arrived. */
		public double Timestamp { get { return _timestamp; } }

		/** Always 0: connectivity has no sensor timestamp. */
		public double Elapsed { get { return 0.0; } }

		public ConnectionStateData(bool connectionStatus, string connectionStatusString)
			: this(connectionStatus, connectionStatusString, SensorTimestamp.Now())
		{
		}

		public ConnectionStateData(bool connectionStatus, string connectionStatusString, double timestamp)
		{
			_connectionStatus = connectionStatus;
			_connectionStatusString = connectionStatusString;
			_timestamp = timestamp;
		}
	}

}
