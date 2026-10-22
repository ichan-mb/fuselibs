using Uno;
using Uno.Compiler.ExportTargetInterop;

namespace Fuse.Sensor
{
	[ForeignInclude(Language.Java, "com.fuse.sensorkit.SensorData", "com.fuse.sensorkit.BatteryData", "com.fuse.sensorkit.ConnectionStateData")]
	public extern(Android) class SensorDataHelpers
	{
		[Foreign(Language.Java)]
		public static float[] GetData(this Java.Object handle)
		@{
			return new FloatArray(((SensorData)handle).getData());
		@}

		[Foreign(Language.Java)]
		public static int GetSensorType(this Java.Object handle)
		@{
			return ((SensorData)handle).getSensorType().code;
		@}

		[Foreign(Language.Java)]
		public static double GetElapsed(this Java.Object handle)
		@{
			return ((SensorData)handle).getElapsed();
		@}

		[Foreign(Language.Java)]
		public static float GetBatteryLevel(this Java.Object handle)
		@{
			return ((BatteryData)handle).getLevel();
		@}

		[Foreign(Language.Java)]
		public static float GetBatteryLevelRatio(this Java.Object handle)
		@{
			return ((BatteryData)handle).getLevelRatio();
		@}

		[Foreign(Language.Java)]
		public static string GetBatteryState(this Java.Object handle)
		@{
			return ((BatteryData)handle).getBatteryStatusString();
		@}

		[Foreign(Language.Java)]
		public static bool GetConnectionStatus(this Java.Object handle)
		@{
			return ((ConnectionStateData)handle).getStatus();
		@}

		[Foreign(Language.Java)]
		public static string GetConnectionStatusString(this Java.Object handle)
		@{
			return ((ConnectionStateData)handle).getStatusString();
		@}

		public static SensorData ConvertSensorData(Java.Object obj)
		{
			float[] data = SensorDataHelpers.GetData(obj);
			return new SensorData(SensorDataHelpers.GetSensorType(obj), float3(data[0], data[1], data[2]), SensorTimestamp.Now(), SensorDataHelpers.GetElapsed(obj));
		}

		public static BatteryData ConvertBatteryData(Java.Object obj)
		{
			var ratio = SensorDataHelpers.GetBatteryLevelRatio(obj);
			return new BatteryData(SensorDataHelpers.GetBatteryLevel(obj), ratio * 100.0f, ratio, SensorDataHelpers.GetBatteryState(obj));
		}

		public static ConnectionStateData ConvertConnectionStateData(Java.Object obj)
		{
			return new ConnectionStateData(SensorDataHelpers.GetConnectionStatus(obj), SensorDataHelpers.GetConnectionStatusString(obj));
		}
	}
}