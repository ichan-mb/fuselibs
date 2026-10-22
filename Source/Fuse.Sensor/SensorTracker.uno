using Uno;
using Uno.Collections;
using Uno.Threading;

namespace Fuse.Sensor
{
	/**
		Platform specific implementation of a single sensor.

		Providers are created by @SensorTracker, which owns them and wires up their callbacks.
		Implement this interface to add a new platform or to provide fake sensor data.
	*/
	public interface ISensorProvider
	{
		/**
			Wires the callbacks that receive data and errors from the sensor. Called once, before
			the first call to StartListening.
		*/
		void Init(Action<SensorType, object> onDataChanged, Action<SensorType, string> onDataError);

		/**
			Starts the sensor.

			@param intervalMs desired sampling interval in milliseconds. Use 0 for the platform default.
		*/
		void StartListening(int intervalMs);

		void StopListening();

		bool IsSensing();
	}

	/**
		Owns the platform specific providers and exposes a single API for every @SensorType.

		There is exactly one provider per sensor type, created lazily the first time the type is
		used. This keeps the module from creating native sensor objects for sensors the app never
		asks for, and guarantees that the callbacks of every provider are wired to this instance.
	*/
	public class SensorTracker
	{
		/** Every sensor type supported by this package, in the order of @SensorType. */
		public static readonly SensorType[] AllTypes = new SensorType[]
		{
			SensorType.ACCELEROMETER,
			SensorType.GYROSCOPE,
			SensorType.MAGNETOMETER,
			SensorType.GRAVITY,
			SensorType.USER_ACCELERATION,
			SensorType.ROTATION,
			SensorType.STEP_COUNTER,
			SensorType.PRESSURE,
			SensorType.BATTERY,
			SensorType.CONNECTION_STATE
		};

		readonly Dictionary<SensorType, ISensorProvider> _providers = new Dictionary<SensorType, ISensorProvider>();
		readonly Dictionary<SensorType, List<Promise<object>>> _onceRequests = new Dictionary<SensorType, List<Promise<object>>>();
		readonly HashSet<SensorType> _stopAfterFirst = new HashSet<SensorType>();
		readonly Func<SensorType, ISensorProvider> _createProvider;

		// Guards _providers, _onceRequests and _stopAfterFirst. Reads and writes happen from the
		// JavaScript thread (start/stop/getOnce) and from the native sensor thread (data/error
		// callbacks), so all access has to be synchronized.
		readonly object _lock = new object();

		public event Action<SensorType, object> DataChanged;

		public event Action<string> DataError;

		public SensorTracker()
		{
			_createProvider = CreateProvider;
		}

		/**
			@param createProvider factory used to create providers. Useful for tests and for
				providing simulated sensor data.
		*/
		public SensorTracker(Func<SensorType, ISensorProvider> createProvider)
		{
			if (createProvider == null)
				throw new ArgumentNullException("createProvider");

			_createProvider = createProvider;
		}

		/** Whether @type is a sensor type supported by this package. */
		public static bool IsSupported(SensorType type)
		{
			for (int i = 0; i < AllTypes.Length; i++)
				if (AllTypes[i] == type)
					return true;

			return false;
		}

		/** Whether the device has the hardware (or the platform support) for @type. */
		public static bool IsAvailable(SensorType type)
		{
			if (!IsSupported(type))
				return false;

			if defined(Android)
				return AndroidSensorProvider.IsAvailable(type);
			else if defined(iOS)
				return IOSSensorProvider.IsAvailable(type);
			else
				// Targets without native sensors get simulated data, see @SpoofSensorProvider.
				return true;
		}

		/** The display name of @type, used in error messages. */
		public static string GetSensorName(SensorType type)
		{
			switch (type)
			{
				case SensorType.ACCELEROMETER: return "Accelerometer";
				case SensorType.GYROSCOPE: return "Gyroscope";
				case SensorType.MAGNETOMETER: return "Magnetometer";
				case SensorType.GRAVITY: return "Gravity";
				case SensorType.USER_ACCELERATION: return "User Acceleration";
				case SensorType.ROTATION: return "Rotation";
				case SensorType.STEP_COUNTER: return "Step Counter";
				case SensorType.PRESSURE: return "Pressure";
				case SensorType.BATTERY: return "Battery";
				case SensorType.CONNECTION_STATE: return "Connection State";
				default: return "Sensor";
			}
		}

		/** The name of the per sensor JavaScript event that carry data of @type. */
		public static string GetEventName(SensorType type)
		{
			switch (type)
			{
				case SensorType.ACCELEROMETER: return "accelerometer";
				case SensorType.GYROSCOPE: return "gyroscope";
				case SensorType.MAGNETOMETER: return "magnetometer";
				case SensorType.GRAVITY: return "gravity";
				case SensorType.USER_ACCELERATION: return "user_acceleration";
				case SensorType.ROTATION: return "rotation";
				case SensorType.STEP_COUNTER: return "step_counter";
				case SensorType.PRESSURE: return "pressure";
				case SensorType.BATTERY: return "battery";
				case SensorType.CONNECTION_STATE: return "connection_state";
				default: return "";
			}
		}

		static ISensorProvider CreateProvider(SensorType type)
		{
			if defined(Android)
				return new AndroidSensorProvider(type);
			else if defined(iOS)
				return new IOSSensorProvider(type);
			else
				return new SpoofSensorProvider(type);
		}

		/**
			Starts listening for @type.

			@param intervalMs desired sampling interval in milliseconds, or 0 for the platform default.
				The interval is a hint: the actual rate depends on the device.
		*/
		public void StartListening(SensorType type, int intervalMs)
		{
			ISensorProvider provider = null;

			lock (_lock)
			{
				// An explicit start means the app wants continuous data, so a pending one shot read
				// must no longer stop the sensor when the first sample arrives.
				_stopAfterFirst.Remove(type);
				provider = GetOrCreateProvider(type);
			}

			if (provider != null && !provider.IsSensing())
				provider.StartListening(intervalMs);
		}

		public void StopListening(SensorType type)
		{
			ISensorProvider provider = null;

			lock (_lock)
			{
				if (!_providers.TryGetValue(type, out provider))
					provider = null;
			}

			if (provider != null && provider.IsSensing())
				provider.StopListening();
		}

		/** Stops every sensor that is currently listening. */
		public void StopAll()
		{
			var providers = new List<ISensorProvider>();

			lock (_lock)
			{
				foreach (var pair in _providers)
					providers.Add(pair.Value);
			}

			for (int i = 0; i < providers.Count; i++)
				if (providers[i].IsSensing())
					providers[i].StopListening();
		}

		public bool IsSensing(SensorType type)
		{
			ISensorProvider provider = null;

			lock (_lock)
			{
				if (!_providers.TryGetValue(type, out provider))
					provider = null;
			}

			return provider != null && provider.IsSensing();
		}

		/**
			Resolves @result with the first reading of @type.

			If the sensor was not already listening it is started for this single reading and
			stopped again once the reading arrives.
		*/
		public void GetOnce(SensorType type, Promise<object> result)
		{
			ISensorProvider provider = null;
			bool start = false;

			lock (_lock)
			{
				provider = GetOrCreateProvider(type);

				if (provider == null)
				{
					start = false;
				}
				else
				{
					List<Promise<object>> requests;
					if (!_onceRequests.TryGetValue(type, out requests))
					{
						requests = new List<Promise<object>>();
						_onceRequests.Add(type, requests);
					}
					requests.Add(result);

					start = !provider.IsSensing();
					if (start)
						_stopAfterFirst.Add(type);
				}
			}

			if (provider == null)
			{
				result.Reject(new Exception("Unknown SensorType"));
				return;
			}

			if (start)
				provider.StartListening(0);
		}

		ISensorProvider GetOrCreateProvider(SensorType type)
		{
			ISensorProvider provider = null;
			if (_providers.TryGetValue(type, out provider))
				return provider;

			provider = _createProvider(type);
			if (provider == null)
				return null;

			provider.Init(OnProviderData, OnProviderError);
			_providers.Add(type, provider);
			return provider;
		}

		void OnProviderData(SensorType type, object data)
		{
			ResolveOnceRequests(type, data);

			if (DataChanged != null)
				DataChanged(type, data);
		}

		void ResolveOnceRequests(SensorType type, object data)
		{
			List<Promise<object>> pending = null;
			bool stop = false;
			ISensorProvider provider = null;

			lock (_lock)
			{
				List<Promise<object>> requests;
				if (_onceRequests.TryGetValue(type, out requests) && requests.Count > 0)
				{
					pending = requests;
					_onceRequests.Remove(type);
				}

				if (_stopAfterFirst.Contains(type))
				{
					_stopAfterFirst.Remove(type);
					stop = true;
					_providers.TryGetValue(type, out provider);
				}
			}

			if (pending != null)
				for (int i = 0; i < pending.Count; i++)
					pending[i].Resolve(data);

			if (stop && provider != null && provider.IsSensing())
				provider.StopListening();
		}

		void OnProviderError(SensorType type, string error)
		{
			List<Promise<object>> pending = null;

			lock (_lock)
			{
				List<Promise<object>> requests;
				if (_onceRequests.TryGetValue(type, out requests) && requests.Count > 0)
				{
					pending = requests;
					_onceRequests.Remove(type);
				}

				// The sensor is not running, so there is nothing to stop for pending one shot reads.
				_stopAfterFirst.Remove(type);
			}

			if (pending != null)
				for (int i = 0; i < pending.Count; i++)
					pending[i].Reject(new Exception(error));

			if (DataError != null)
				DataError(error);
		}
	}
}
