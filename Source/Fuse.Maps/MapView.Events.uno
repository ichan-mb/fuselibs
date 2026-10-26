using Uno;
using Fuse.Scripting;
namespace Fuse.Controls
{
	public delegate void MapEventHandler(object sender, MapEventArgs args);
	public delegate void MarkerEventHandler(object sender, MarkerEventArgs args);
	public delegate void MapPositionEventHandler(double latitude, double longitude);

	public sealed class MarkerEventArgs : EventArgs, Fuse.Scripting.IScriptEvent
	{
		public readonly string Label;
		/** The unique id of the marker. */
		public readonly int Id;
		public readonly double Latitude;
		public readonly double Longitude;
		/** The @MapMarker this event belongs to, if it is still on the map. */
		public readonly MapMarker Marker;

		public MarkerEventArgs(string label)
		{
			Label = label;
		}

		public MarkerEventArgs(MapMarker marker)
		{
			Marker = marker;
			if (marker == null) return;

			Label = marker.Label;
			Id = marker.uid;
			Latitude = marker.Latitude;
			Longitude = marker.Longitude;
		}

		public MarkerEventArgs(MapMarker marker, int id, string label)
		{
			Marker = marker;
			Id = id;
			Label = label;

			if (marker == null) return;

			Latitude = marker.Latitude;
			Longitude = marker.Longitude;
		}

		void Fuse.Scripting.IScriptEvent.Serialize(IEventSerializer s)
		{
			s.AddString("label", Label);
			s.AddInt("id", Id);
			s.AddDouble("latitude", Latitude);
			s.AddDouble("longitude", Longitude);
		}
	}

	public sealed class MapEventArgs : EventArgs, Fuse.Scripting.IScriptEvent
	{
		public readonly double Latitude;
		public readonly double Longitude;

		public MapEventArgs(double latitude, double longitude) : base()
		{
			Latitude = latitude;
			Longitude = longitude;
		}

		void Fuse.Scripting.IScriptEvent.Serialize(IEventSerializer s)
		{
			s.AddDouble("latitude", Latitude);
			s.AddDouble("longitude", Longitude);
		}
	}

}
