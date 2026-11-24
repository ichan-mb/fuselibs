using Uno;
using Uno.Collections;
using Uno.Testing;
using Uno.Time;
using Fuse;
using Fuse.GeoLocation;

namespace Fuse.GeoLocation.Tests
{
	public class GeoLocationTest
	{
		static LocationTracker _tracker;

		static LocationTracker Tracker
		{
			get
			{
				if (_tracker == null)
				{
					_tracker = new LocationTracker();
					UpdateManager.Update();
				}

				return _tracker;
			}
		}

		[Test]
		public void DistanceTo()
		{
			var oslo = new GeoCoordinates(59.9139, 10.7522);
			var bergen = new GeoCoordinates(60.3913, 5.3221);
			var distance = oslo.DistanceTo(bergen);
			Assert.IsTrue(distance > 295000 && distance < 315000);
		}

		[Test]
		public void BearingTo()
		{
			var oslo = new GeoCoordinates(59.9139, 10.7522);
			var bergen = new GeoCoordinates(60.3913, 5.3221);
			var bearing = oslo.BearingTo(bergen);
			Assert.IsTrue(bearing > 270 && bearing < 310);
		}

		[Test]
		public void IsValid()
		{
			Assert.IsTrue(new GeoCoordinates(0, 0).IsValid);
			Assert.IsFalse(new GeoCoordinates(91, 0).IsValid);
			Assert.IsFalse(new GeoCoordinates(0, 181).IsValid);
			Assert.IsFalse(new GeoCoordinates(double.NaN, 0).IsValid);
		}

		[Test]
		public void CoordinateEquality()
		{
			var a = new GeoCoordinates(59.9, 10.7);
			var b = new GeoCoordinates(59.9, 10.7);
			Assert.IsTrue(a.Equals(b));
			Assert.AreEqual(a.GetHashCode(), b.GetHashCode());
		}

		[Test]
		public void LocationPayload()
		{
			var instant = Instant.FromUtc(2020, 1, 2, 3, 4, 5);
			var dateTime = new LocalDateTime(instant, CalendarSystem.Iso);
			var location = new Location(
				new GeoCoordinates(59.9, 10.7),
				5, 12, 1.5, dateTime,
				2, 90, 0.5, true, "gps", true, true, true);

			Assert.AreEqual(5.0, location.Accuracy);
			Assert.AreEqual(2.0, location.VerticalAccuracy);
			Assert.AreEqual(90.0, location.Heading);
			Assert.AreEqual(0.5, location.SpeedAccuracy);
			Assert.IsTrue(location.IsMock);
			Assert.AreEqual("gps", location.Provider);
			Assert.IsTrue(location.HasAltitude);
			Assert.IsTrue(location.HasSpeed);
			Assert.IsTrue(location.HasHeading);
			Assert.AreEqual(1577934245000L, location.Timestamp);
		}

		[Test]
		public void GeoAddressDefaults()
		{
			var address = new GeoAddress(null, null, null, null, null, null, null, null, null, null, null, null);
			Assert.AreEqual("", address.Name);
			Assert.AreEqual("", address.City);
			Assert.AreEqual("", address.Country);
			Assert.AreEqual("", address.FormattedAddress);
			Assert.IsTrue(address.Coordinates == null);
		}

		[Test]
		public void HeadingModel()
		{
			var heading = new Heading(90, 5, 123);
			Assert.AreEqual(90.0, heading.Degrees);
			Assert.AreEqual(5.0, heading.Accuracy);
			Assert.AreEqual(123L, heading.Timestamp);
		}

		[Test]
		public void GeoFenceModel()
		{
			var fence = new GeoFence(1, new GeoCoordinates(59.9, 10.7), 100, "home");
			Assert.AreEqual(1, fence.Id);
			Assert.AreEqual("home", fence.Identifier);
			Assert.AreEqual(100.0, fence.Radius);
		}

		[Test]
		public void SpoofLocationIsAvailable()
		{
			Assert.IsTrue(Tracker.IsLocationEnabled());
			Assert.AreEqual("authorizedWhenInUse", Tracker.GetAuthorizationStatus());
			Assert.IsTrue(Tracker.Location != null);
		}

		[Test]
		public void GetLocationResolves()
		{
			Location result = null;
			Tracker.GetLocationAsync().Then(l => result = l, null);
			Assert.IsTrue(result != null);
		}

		[Test]
		public void GetLocationUsesFreshCache()
		{
			Location first = null, second = null;
			Tracker.GetLocationAsync().Then(l => first = l, null);
			Tracker.GetLocationAsync(20000, 60000).Then(l => second = l, null);
			Assert.IsTrue(first != null);
			Assert.IsTrue(second != null);
		}

		[Test]
		public void WatchPositionDeliversLocation()
		{
			Location received = null;
			var id = Tracker.WatchPosition(l => received = l, null);
			UpdateManager.Update();

			Assert.IsTrue(id > 0);
			Assert.IsTrue(received != null);
			Tracker.ClearWatch(id);
		}

		[Test]
		public void MultipleWatchersReceiveLocation()
		{
			Location first = null, second = null;
			int id1 = Tracker.WatchPosition(l => first = l, null);
			int id2 = Tracker.WatchPosition(l => second = l, null);
			UpdateManager.Update();

			Assert.IsTrue(first != null);
			Assert.IsTrue(second != null);
			Assert.IsTrue(id1 != id2);

			Tracker.ClearWatch(id1);
			Tracker.ClearWatch(id2);
		}

		[Test]
		public void ClearWatchStopsWatcher()
		{
			int cleared = 0, active = 0;
			int id1 = Tracker.WatchPosition(l => cleared++, null);
			UpdateManager.Update();
			Tracker.ClearWatch(id1);
			int clearedAfterClear = cleared;

			int id2 = Tracker.WatchPosition(l => active++, null);
			UpdateManager.Update();

			Assert.AreEqual(clearedAfterClear, cleared);
			Assert.IsTrue(active > 0);
			Tracker.ClearWatch(id2);
		}

		Heading _heading;

		void OnHeading(Heading heading)
		{
			_heading = heading;
		}

		[Test]
		public void HeadingUpdatesResolve()
		{
			_heading = null;
			Tracker.HeadingChanged += OnHeading;
			Tracker.StartUpdatingHeading(100);
			Tracker.HeadingChanged -= OnHeading;
			Tracker.StopUpdatingHeading();

			Assert.IsTrue(_heading != null);
		}

		int _geofenceEvents;
		int _geofenceExits;

		void OnGeofenceEntered(GeoFence fence)
		{
			_geofenceEvents++;
		}

		void OnGeofenceExited(GeoFence fence)
		{
			_geofenceExits++;
		}

		[Test]
		public void GeofenceEnteredForSpoofLocation()
		{
			_geofenceEvents = 0;
			Tracker.GeofenceEntered += OnGeofenceEntered;
			var fence = Tracker.AddGeofence(new GeoCoordinates(59.9115546, 10.73888), 1000, "home");
			Tracker.RemoveGeofence(fence.Id);
			Tracker.GeofenceEntered -= OnGeofenceEntered;

			Assert.AreEqual(1, _geofenceEvents);
		}

		[Test]
		public void GeofenceOutsideDoesNotEnter()
		{
			_geofenceEvents = 0;
			_geofenceExits = 0;
			Tracker.GeofenceEntered += OnGeofenceEntered;
			Tracker.GeofenceExited += OnGeofenceExited;
			var fence = Tracker.AddGeofence(new GeoCoordinates(0, 0), 100, "far");
			Tracker.RemoveGeofence(fence.Id);
			Tracker.GeofenceEntered -= OnGeofenceEntered;
			Tracker.GeofenceExited -= OnGeofenceExited;

			Assert.AreEqual(0, _geofenceEvents);
			Assert.AreEqual(0, _geofenceExits);
		}

		[Test]
		public void RemoveAllGeofences()
		{
			var fence = Tracker.AddGeofence(new GeoCoordinates(59.9115546, 10.73888), 1000, "home");
			Tracker.RemoveAllGeofences();
			var second = Tracker.AddGeofence(new GeoCoordinates(59.9115546, 10.73888), 1000, "home2");
			Assert.IsTrue(second.Id != fence.Id);
			Tracker.RemoveAllGeofences();
		}

		[Test]
		public void GeocodeResolves()
		{
			IList<GeoAddress> result = null;
			Tracker.GeocodeAsync("Oslo", 5).Then(r => result = r, null);
			Assert.IsTrue(result != null);
			Assert.AreEqual(1, result.Count);
		}

		[Test]
		public void ReverseGeocodeResolves()
		{
			IList<GeoAddress> result = null;
			Tracker.ReverseGeocodeAsync(new GeoCoordinates(59.9, 10.7), 1).Then(r => result = r, null);
			Assert.IsTrue(result != null);
			Assert.AreEqual(1, result.Count);
		}
	}
}
