using Uno;

namespace Fuse.Controls
{
	/**
		Describes a selectable camera/lens on the device.
	*/
	public class CameraLens
	{
		public const string IdName = "id";
		public const string FacingName = "facing";
		public const string NameName = "name";

		public readonly string Id;
		public readonly CameraFacing Facing;
		public readonly string Name;

		public CameraLens(string id, CameraFacing facing, string name)
		{
			Id = id;
			Facing = facing;
			Name = name;
		}
	}
}
