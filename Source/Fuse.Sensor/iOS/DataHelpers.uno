using Uno;
using Uno.Compiler.ExportTargetInterop;

namespace Fuse.Sensor
{
	[ForeignInclude(Language.ObjC, "iOS/data/FOBatteryData.h", "iOS/data/FOConnectionStateData.h")]
	public extern(iOS) class SensorDataHelpers
	{
		[Foreign(Language.ObjC)]
		public static float GetBatteryLevel(this ObjC.Object handle)
		@{
			return [handle getLevel];
		@}

		[Foreign(Language.ObjC)]
		public static string GetBatteryState(this ObjC.Object handle)
		@{
			return [handle stateString];
		@}

		[Foreign(Language.ObjC)]
		public static bool GetConnectionState(this ObjC.Object handle)
		@{
			return [handle getStatus];
		@}

		[Foreign(Language.ObjC)]
		public static string GetConnectionStateString(this ObjC.Object handle)
		@{
			return [handle getStatusString];
		@}

		public static SensorData ConvertSensorData(int sensorType, float x, float y, float z, double elapsed)
		{
			return new SensorData(sensorType, float3(x,y,z), SensorTimestamp.Now(), elapsed);
		}

		public static BatteryData ConvertBatteryData(ObjC.Object data)
		{
			var level = SensorDataHelpers.GetBatteryLevel(data);
			return new BatteryData(level, level * 100.0f, level, SensorDataHelpers.GetBatteryState(data));
		}

		public static ConnectionStateData ConvertConnectionState(ObjC.Object data)
		{
			return new ConnectionStateData(SensorDataHelpers.GetConnectionState(data), SensorDataHelpers.GetConnectionStateString(data));
		}
	}
}