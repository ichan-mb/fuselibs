using Uno;

namespace Fuse.Maps
{
	/** A snapshot of the properties of a @MapMarker, used to diff markers against the native map. */
	internal class MarkerState
	{
		public double Latitude;
		public double Longitude;
		public string Label;
		public string Snippet;
		public string IconPath;
		public float IconAnchorX;
		public float IconAnchorY;
		public float4 Color;
		public bool Draggable;

		public static MarkerState From(Fuse.Controls.MapMarker marker, string iconPath)
		{
			var state = new MarkerState();
			state.Latitude = marker.Latitude;
			state.Longitude = marker.Longitude;
			state.Label = marker.Label;
			state.Snippet = marker.Snippet;
			state.IconPath = iconPath;
			state.IconAnchorX = marker.IconAnchorX;
			state.IconAnchorY = marker.IconAnchorY;
			state.Color = marker.Color;
			state.Draggable = marker.Draggable;
			return state;
		}

		public bool Differs(MarkerState other)
		{
			if (other == null) return true;

			return Latitude != other.Latitude
				|| Longitude != other.Longitude
				|| Label != other.Label
				|| Snippet != other.Snippet
				|| IconPath != other.IconPath
				|| IconAnchorX != other.IconAnchorX
				|| IconAnchorY != other.IconAnchorY
				|| Color.X != other.Color.X
				|| Color.Y != other.Color.Y
				|| Color.Z != other.Color.Z
				|| Color.W != other.Color.W
				|| Draggable != other.Draggable;
		}

		/** Whether the change requires the native annotation view to be recreated. */
		public bool NeedsNewView(MarkerState other)
		{
			if (other == null) return true;

			return IconPath != other.IconPath
				|| IconAnchorX != other.IconAnchorX
				|| IconAnchorY != other.IconAnchorY
				|| Color.X != other.Color.X
				|| Color.Y != other.Color.Y
				|| Color.Z != other.Color.Z
				|| Color.W != other.Color.W
				|| Draggable != other.Draggable;
		}
	}
}
