using Uno;
using Uno.Collections;
using Uno.Testing;
using Uno.Threading;

namespace Fuse.Sensor.Tests
{
	public class SensorTrackerTest
	{
		SensorType _changedType;
		object _changedData;
		SensorData _onceResult;
		string _error;

		void OnDataChanged(SensorType type, object data)
		{
			_changedType = type;
			_changedData = data;
		}

		void OnOnceResolved(object data)
		{
			_onceResult = (SensorData)data;
		}

		void OnDataError(string message)
		{
			_error = message;
		}

		[Test]
		public void AllTypesAreSupported()
		{
			Assert.AreEqual(10, SensorTracker.AllTypes.Length);

			for (int i = 0; i < SensorTracker.AllTypes.Length; i++)
				Assert.IsTrue(SensorTracker.IsSupported(SensorTracker.AllTypes[i]));
		}

		[Test]
		public void UnknownTypeIsNotSupported()
		{
			Assert.IsFalse(SensorTracker.IsSupported((SensorType)100));
		}

		[Test]
		public void EventNamesAreUniqueAndNonEmpty()
		{
			var seen = new Dictionary<string, bool>();

			for (int i = 0; i < SensorTracker.AllTypes.Length; i++)
			{
				var name = SensorTracker.GetEventName(SensorTracker.AllTypes[i]);
				Assert.IsTrue(name != null && name.Length > 0);
				Assert.IsFalse(seen.ContainsKey(name));
				seen.Add(name, true);
			}
		}

		[Test]
		public void SensorNamesAreUniqueAndNonEmpty()
		{
			var seen = new Dictionary<string, bool>();

			for (int i = 0; i < SensorTracker.AllTypes.Length; i++)
			{
				var name = SensorTracker.GetSensorName(SensorTracker.AllTypes[i]);
				Assert.IsTrue(name != null && name.Length > 0);
				Assert.IsFalse(seen.ContainsKey(name));
				seen.Add(name, true);
			}
		}

		[Test]
		public void ProvidersAreCreatedLazily()
		{
			var factory = new FakeProviderFactory();
			var tracker = new SensorTracker(factory.Create);

			Assert.AreEqual(0, factory.CreateCount);

			// Querying a sensor that was never started must not create a native provider.
			Assert.IsFalse(tracker.IsSensing(SensorType.ACCELEROMETER));
			Assert.AreEqual(0, factory.CreateCount);
		}

		[Test]
		public void StartListeningIsIdempotent()
		{
			var factory = new FakeProviderFactory();
			var tracker = new SensorTracker(factory.Create);

			tracker.StartListening(SensorType.ACCELEROMETER, 16);
			tracker.StartListening(SensorType.ACCELEROMETER, 32);

			Assert.AreEqual(1, factory.CreateCount);
			Assert.AreEqual(1, factory.Providers[SensorType.ACCELEROMETER].StartCount);
			Assert.AreEqual(16, factory.Providers[SensorType.ACCELEROMETER].LastIntervalMs);
			Assert.IsTrue(tracker.IsSensing(SensorType.ACCELEROMETER));
		}

		[Test]
		public void StopListeningOnlyStopsThatSensor()
		{
			var factory = new FakeProviderFactory();
			var tracker = new SensorTracker(factory.Create);

			tracker.StartListening(SensorType.ACCELEROMETER, 0);
			tracker.StartListening(SensorType.GYROSCOPE, 0);
			tracker.StopListening(SensorType.ACCELEROMETER);

			Assert.AreEqual(1, factory.Providers[SensorType.ACCELEROMETER].StopCount);
			Assert.AreEqual(0, factory.Providers[SensorType.GYROSCOPE].StopCount);
			Assert.IsFalse(tracker.IsSensing(SensorType.ACCELEROMETER));
			Assert.IsTrue(tracker.IsSensing(SensorType.GYROSCOPE));
		}

		[Test]
		public void StopAllStopsEverySensor()
		{
			var factory = new FakeProviderFactory();
			var tracker = new SensorTracker(factory.Create);

			tracker.StartListening(SensorType.ACCELEROMETER, 0);
			tracker.StartListening(SensorType.GYROSCOPE, 0);
			tracker.StartListening(SensorType.BATTERY, 0);
			tracker.StopAll();

			Assert.AreEqual(1, factory.Providers[SensorType.ACCELEROMETER].StopCount);
			Assert.AreEqual(1, factory.Providers[SensorType.GYROSCOPE].StopCount);
			Assert.AreEqual(1, factory.Providers[SensorType.BATTERY].StopCount);
		}

		[Test]
		public void DataChangedCarriesSensorType()
		{
			var factory = new FakeProviderFactory();
			var tracker = new SensorTracker(factory.Create);
			tracker.DataChanged += OnDataChanged;

			tracker.StartListening(SensorType.GYROSCOPE, 0);
			factory.Providers[SensorType.GYROSCOPE].Emit(1, 2, 3);

			Assert.AreEqual(SensorType.GYROSCOPE, _changedType);
			Assert.IsTrue(_changedData is SensorData);

			var data = (SensorData)_changedData;
			Assert.AreEqual(1.0f, data.Data[0]);
			Assert.AreEqual(2.0f, data.Data[1]);
			Assert.AreEqual(3.0f, data.Data[2]);
		}

		[Test]
		public void BatteryDataIsForwardedUnchanged()
		{
			var factory = new FakeProviderFactory();
			var tracker = new SensorTracker(factory.Create);
			tracker.DataChanged += OnDataChanged;

			tracker.StartListening(SensorType.BATTERY, 0);
			factory.Providers[SensorType.BATTERY].EmitBattery(0.25f);

			Assert.AreEqual(SensorType.BATTERY, _changedType);

			var data = (BatteryData)_changedData;
			Assert.AreEqual(0.25f, data.Level);
			Assert.AreEqual(25.0f, data.LevelPercent);
			Assert.AreEqual(0.25f, data.LevelRatio);
			Assert.AreEqual("charging", data.State);
		}

		[Test]
		public void GetOnceResolvesWithFirstReadingAndStops()
		{
			var factory = new FakeProviderFactory();
			var tracker = new SensorTracker(factory.Create);

			var promise = new Promise<object>();
			promise.Then(OnOnceResolved);

			tracker.GetOnce(SensorType.ACCELEROMETER, promise);

			var provider = factory.Providers[SensorType.ACCELEROMETER];
			Assert.IsTrue(provider.IsSensing());
			Assert.AreEqual(FutureState.Pending, promise.State);

			provider.Emit(4, 5, 6);

			Assert.AreEqual(FutureState.Resolved, promise.State);
			Assert.AreEqual(4.0f, _onceResult.Data[0]);
			Assert.AreEqual(5.0f, _onceResult.Data[1]);
			Assert.AreEqual(6.0f, _onceResult.Data[2]);

			// The sensor was not listening before, so it is stopped again.
			Assert.AreEqual(1, provider.StopCount);
			Assert.IsFalse(provider.IsSensing());
		}

		[Test]
		public void GetOnceKeepsAnAlreadyRunningSensor()
		{
			var factory = new FakeProviderFactory();
			var tracker = new SensorTracker(factory.Create);

			tracker.StartListening(SensorType.ACCELEROMETER, 0);

			var promise = new Promise<object>();
			tracker.GetOnce(SensorType.ACCELEROMETER, promise);
			factory.Providers[SensorType.ACCELEROMETER].Emit(1, 1, 1);

			Assert.AreEqual(FutureState.Resolved, promise.State);
			Assert.AreEqual(0, factory.Providers[SensorType.ACCELEROMETER].StopCount);
			Assert.IsTrue(tracker.IsSensing(SensorType.ACCELEROMETER));
		}

		[Test]
		public void StartListeningCancelsPendingGetOnceStop()
		{
			var factory = new FakeProviderFactory();
			var tracker = new SensorTracker(factory.Create);

			var promise = new Promise<object>();
			tracker.GetOnce(SensorType.ACCELEROMETER, promise);

			// The app decided it wants continuous data before the first sample arrived.
			tracker.StartListening(SensorType.ACCELEROMETER, 50);
			factory.Providers[SensorType.ACCELEROMETER].Emit(1, 1, 1);

			Assert.AreEqual(FutureState.Resolved, promise.State);
			Assert.AreEqual(0, factory.Providers[SensorType.ACCELEROMETER].StopCount);
			Assert.IsTrue(tracker.IsSensing(SensorType.ACCELEROMETER));
		}

		[Test]
		public void GetOnceRejectsWhenTheSensorFails()
		{
			var factory = new FakeProviderFactory();
			factory.FailOnStart = true;

			var tracker = new SensorTracker(factory.Create);
			var promise = new Promise<object>();

			tracker.GetOnce(SensorType.PRESSURE, promise);

			Assert.AreEqual(FutureState.Rejected, promise.State);
		}

		[Test]
		public void ErrorReachesDataError()
		{
			var factory = new FakeProviderFactory();
			var tracker = new SensorTracker(factory.Create);

			tracker.DataError += OnDataError;

			tracker.StartListening(SensorType.PRESSURE, 0);
			factory.Providers[SensorType.PRESSURE].EmitError("boom");

			Assert.AreEqual("boom", _error);
		}

		[Test]
		public void BatteryDataLegacyConstructorTreatsLevelAsRatio()
		{
			var data = new BatteryData(0.5f, "charging");

			Assert.AreEqual(0.5f, data.Level);
			Assert.AreEqual(50.0f, data.LevelPercent);
			Assert.AreEqual(0.5f, data.LevelRatio);
			Assert.AreEqual("charging", data.State);
		}

		[Test]
		public void SensorDataCapturesATimestamp()
		{
			var before = SensorTimestamp.Now();
			var data = new SensorData(0, float3(1, 2, 3));
			var after = SensorTimestamp.Now();

			Assert.IsTrue(data.Timestamp >= before);
			Assert.IsTrue(data.Timestamp <= after);

			// Milliseconds since the Unix epoch, not seconds.
			Assert.IsTrue(data.Timestamp > 1500000000000.0);
		}

		[Test]
		public void TimestampsAreNonDecreasing()
		{
			var first = new SensorData(0, float3(0, 0, 0));
			var second = new SensorData(0, float3(0, 0, 0));

			Assert.IsTrue(second.Timestamp >= first.Timestamp);
		}

		[Test]
		public void ElapsedIsPreservedAndDefaultsToZero()
		{
			var data = new SensorData(0, float3(1, 2, 3), SensorTimestamp.Now(), 1234.5);
			Assert.AreEqual(1234.5, data.Elapsed);

			// No sensor timestamp on these sources.
			Assert.AreEqual(0.0, new SensorData(0, float3(0, 0, 0)).Elapsed);
			Assert.AreEqual(0.0, new BatteryData(0.5f, "charging").Elapsed);
			Assert.AreEqual(0.0, new ConnectionStateData(true, "connected").Elapsed);
		}

		[Test]
		public void BatteryAndConnectionCarryTimestamps()
		{
			var battery = new BatteryData(0.5f, "charging");
			var connection = new ConnectionStateData(true, "connected");

			Assert.IsTrue(battery.Timestamp > 1500000000000.0);
			Assert.IsTrue(connection.Timestamp > 1500000000000.0);
		}

		[Test]
		public void EmittedDataCarriesATimestamp()
		{
			var factory = new FakeProviderFactory();
			var tracker = new SensorTracker(factory.Create);
			tracker.DataChanged += OnDataChanged;

			tracker.StartListening(SensorType.ACCELEROMETER, 0);
			factory.Providers[SensorType.ACCELEROMETER].Emit(1, 2, 3);

			Assert.IsTrue(((SensorData)_changedData).Timestamp > 1500000000000.0);
		}
	}
}
