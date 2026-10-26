using Uno;
using Uno.UX;
using Fuse.Scripting;

namespace Fuse.Controls
{
	/** A geographical rectangle described by its south-west and north-east corners.

		Used by @MapView.ShowBounds and @MapView.VisibleBounds.
	*/
	public class MapBounds : PropertyObject
	{
		static Selector _minLatitudeName = "MinLatitude";
		static Selector _minLongitudeName = "MinLongitude";
		static Selector _maxLatitudeName = "MaxLatitude";
		static Selector _maxLongitudeName = "MaxLongitude";

		double _minLatitude;
		/** The latitude of the south-west corner. */
		public double MinLatitude
		{
			get { return _minLatitude; }
			set
			{
				if (_minLatitude == value) return;
				_minLatitude = value;
				OnPropertyChanged(_minLatitudeName);
			}
		}

		double _minLongitude;
		/** The longitude of the south-west corner. */
		public double MinLongitude
		{
			get { return _minLongitude; }
			set
			{
				if (_minLongitude == value) return;
				_minLongitude = value;
				OnPropertyChanged(_minLongitudeName);
			}
		}

		double _maxLatitude;
		/** The latitude of the north-east corner. */
		public double MaxLatitude
		{
			get { return _maxLatitude; }
			set
			{
				if (_maxLatitude == value) return;
				_maxLatitude = value;
				OnPropertyChanged(_maxLatitudeName);
			}
		}

		double _maxLongitude;
		/** The longitude of the north-east corner. */
		public double MaxLongitude
		{
			get { return _maxLongitude; }
			set
			{
				if (_maxLongitude == value) return;
				_maxLongitude = value;
				OnPropertyChanged(_maxLongitudeName);
			}
		}

		public MapBounds() {}

		public MapBounds(double minLatitude, double minLongitude, double maxLatitude, double maxLongitude)
		{
			_minLatitude = minLatitude;
			_minLongitude = minLongitude;
			_maxLatitude = maxLatitude;
			_maxLongitude = maxLongitude;
		}

		public override string ToString()
		{
			return "[MapBounds MinLatitude:" + _minLatitude
				+ " MinLongitude:" + _minLongitude
				+ " MaxLatitude:" + _maxLatitude
				+ " MaxLongitude:" + _maxLongitude + "]";
		}
	}

	public delegate void MapBoundsEventHandler(object sender, MapBoundsEventArgs args);

	/** Event arguments describing the currently visible geographical area of a @MapView. */
	public sealed class MapBoundsEventArgs : EventArgs, IScriptEvent
	{
		public readonly double MinLatitude;
		public readonly double MinLongitude;
		public readonly double MaxLatitude;
		public readonly double MaxLongitude;

		public MapBoundsEventArgs(double minLatitude, double minLongitude, double maxLatitude, double maxLongitude)
		{
			MinLatitude = minLatitude;
			MinLongitude = minLongitude;
			MaxLatitude = maxLatitude;
			MaxLongitude = maxLongitude;
		}

		public MapBoundsEventArgs(MapBounds bounds)
		{
			MinLatitude = bounds.MinLatitude;
			MinLongitude = bounds.MinLongitude;
			MaxLatitude = bounds.MaxLatitude;
			MaxLongitude = bounds.MaxLongitude;
		}

		void IScriptEvent.Serialize(IEventSerializer s)
		{
			s.AddDouble("minLatitude", MinLatitude);
			s.AddDouble("minLongitude", MinLongitude);
			s.AddDouble("maxLatitude", MaxLatitude);
			s.AddDouble("maxLongitude", MaxLongitude);
		}
	}
}
