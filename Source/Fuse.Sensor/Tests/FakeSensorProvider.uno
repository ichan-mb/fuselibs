using Uno;
using Uno.Collections;

namespace Fuse.Sensor.Tests
{
	/**
		A minimal @ISensorProvider that records calls and lets a test push data or errors through
		the callbacks the tracker installed.
	*/
	class FakeSensorProvider : ISensorProvider
	{
		public readonly SensorType Type;
		public bool FailOnStart;
		public bool Sensing;
		public int StartCount;
		public int StopCount;
		public int LastIntervalMs;

		Action<SensorType, object> _onDataChanged;
		Action<SensorType, string> _onDataError;

		public FakeSensorProvider(SensorType type)
		{
			Type = type;
		}

		public void Init(Action<SensorType, object> onDataChanged, Action<SensorType, string> onDataError)
		{
			_onDataChanged = onDataChanged;
			_onDataError = onDataError;
		}

		public void StartListening(int intervalMs)
		{
			StartCount++;
			LastIntervalMs = intervalMs;

			if (FailOnStart)
			{
				_onDataError(Type, "not available");
				return;
			}

			Sensing = true;
		}

		public void StopListening()
		{
			StopCount++;
			Sensing = false;
		}

		public bool IsSensing()
		{
			return Sensing;
		}

		public void Emit(float x, float y, float z)
		{
			_onDataChanged(Type, new SensorData((int)Type, float3(x, y, z)));
		}

		public void EmitBattery(float level)
		{
			_onDataChanged(Type, new BatteryData(level, level * 100.0f, level, "charging"));
		}

		public void EmitError(string error)
		{
			_onDataError(Type, error);
		}
	}

	/** Creates @FakeSensorProvider instances and counts how many were requested. */
	class FakeProviderFactory
	{
		public readonly Dictionary<SensorType, FakeSensorProvider> Providers = new Dictionary<SensorType, FakeSensorProvider>();
		public int CreateCount;
		public bool FailOnStart;

		public ISensorProvider Create(SensorType type)
		{
			CreateCount++;

			var provider = new FakeSensorProvider(type);
			provider.FailOnStart = FailOnStart;
			Providers.Add(type, provider);
			return provider;
		}
	}
}
