using Uno;
using Uno.Testing;
using Fuse;
using FuseTest;

namespace Fuse.LauncherTest
{
	public class MapsUriHelperTest : TestBase
	{
		[Test]
		public void BuildGeoUri_LocationOnly_ReturnsCoordinatePin()
		{
			var uri = MapsUriHelper.BuildGeoUri(new MapLaunchOptions
			{
				Location = new MapLocation(59.5, 10.25)
			});
			Assert.AreEqual("geo:0,0?q=59.5,10.25", uri);
		}

		[Test]
		public void BuildGeoUri_LocationWithLabelAndZoom_ReturnsLabeledPin()
		{
			var uri = MapsUriHelper.BuildGeoUri(new MapLaunchOptions
			{
				Location = new MapLocation(59.5, 10.25, "Fuse"),
				Zoom = 15
			});
			Assert.AreEqual("geo:0,0?q=59.5,10.25(Fuse)&z=15", uri);
		}

		[Test]
		public void BuildGeoUri_LabelIsEscaped()
		{
			var uri = MapsUriHelper.BuildGeoUri(new MapLaunchOptions
			{
				Location = new MapLocation(59.5, 10.25, "A & B")
			});
			Assert.AreEqual("geo:0,0?q=59.5,10.25(A%20%26%20B)", uri);
		}

		[Test]
		public void BuildGeoUri_QueryOnly_ReturnsSearch()
		{
			var uri = MapsUriHelper.BuildGeoUri(new MapLaunchOptions
			{
				Query = "pizza restaurant"
			});
			Assert.AreEqual("geo:0,0?q=pizza%20restaurant", uri);
		}

		[Test]
		public void BuildGeoUri_QueryAndLocation_SearchesNearLocation()
		{
			var uri = MapsUriHelper.BuildGeoUri(new MapLaunchOptions
			{
				Location = new MapLocation(59.5, 10.25),
				Query = "pizza"
			});
			Assert.AreEqual("geo:59.5,10.25?q=pizza", uri);
		}

		[Test]
		public void BuildGeoUri_QueryAndLocationWithZoom_AppendsZoom()
		{
			var uri = MapsUriHelper.BuildGeoUri(new MapLaunchOptions
			{
				Location = new MapLocation(59.5, 10.25),
				Query = "pizza",
				Zoom = 15
			});
			Assert.AreEqual("geo:59.5,10.25?q=pizza&z=15", uri);
		}

		[Test]
		public void BuildGeoUri_SearchNearOnly_SearchesNearLocation()
		{
			var uri = MapsUriHelper.BuildGeoUri(new MapLaunchOptions
			{
				SearchNear = new MapLocation(59.5, 10.25),
				Query = "pizza"
			});
			Assert.AreEqual("geo:59.5,10.25?q=pizza", uri);
		}

		[Test]
		public void BuildGeoUri_WhitespaceQueryWithLocation_ReturnsPin()
		{
			var uri = MapsUriHelper.BuildGeoUri(new MapLaunchOptions
			{
				Location = new MapLocation(59.5, 10.25),
				Query = "   "
			});
			Assert.AreEqual("geo:0,0?q=59.5,10.25", uri);
		}

		[Test]
		public void BuildGeoUri_QueryIsEscaped()
		{
			var uri = MapsUriHelper.BuildGeoUri(new MapLaunchOptions
			{
				Query = "pizza & pasta"
			});
			Assert.AreEqual("geo:0,0?q=pizza%20%26%20pasta", uri);
		}

		[Test]
		public void BuildGeoUri_Destination_Throws()
		{
			Assert.Throws<ArgumentException>(BuildGeoUriWithDestination);
		}

		[Test]
		public void BuildAppleMapsUri_LocationOnly_ReturnsPinAndCenter()
		{
			var uri = MapsUriHelper.BuildAppleMapsUri(new MapLaunchOptions
			{
				Location = new MapLocation(59.5, 10.25)
			});
			Assert.AreEqual("https://maps.apple.com/?ll=59.5,10.25&q=59.5,10.25", uri);
		}

		[Test]
		public void BuildAppleMapsUri_LocationWithLabelZoomAndMapType()
		{
			var uri = MapsUriHelper.BuildAppleMapsUri(new MapLaunchOptions
			{
				Location = new MapLocation(59.5, 10.25, "Fuse"),
				Zoom = 15,
				MapType = MapType.Satellite
			});
			Assert.AreEqual(
				"https://maps.apple.com/?ll=59.5,10.25&q=Fuse&z=15&t=k",
				uri);
		}

		[Test]
		public void BuildAppleMapsUri_HybridMapType_UsesHybridFlag()
		{
			var uri = MapsUriHelper.BuildAppleMapsUri(new MapLaunchOptions
			{
				Location = new MapLocation(59.5, 10.25),
				MapType = MapType.Hybrid
			});
			Assert.AreEqual(
				"https://maps.apple.com/?ll=59.5,10.25&q=59.5,10.25&t=h",
				uri);
		}

		[Test]
		public void BuildAppleMapsUri_ZoomIsClampedTo20()
		{
			var uri = MapsUriHelper.BuildAppleMapsUri(new MapLaunchOptions
			{
				Location = new MapLocation(59.5, 10.25),
				Zoom = 23
			});
			Assert.AreEqual(
				"https://maps.apple.com/?ll=59.5,10.25&q=59.5,10.25&z=20",
				uri);
		}

		[Test]
		public void BuildAppleMapsUri_QueryOnly_ReturnsSearch()
		{
			var uri = MapsUriHelper.BuildAppleMapsUri(new MapLaunchOptions
			{
				Query = "pizza restaurant"
			});
			Assert.AreEqual("https://maps.apple.com/?q=pizza%20restaurant", uri);
		}

		[Test]
		public void BuildAppleMapsUri_QueryAndSearchNear_ReturnsSearchOrigin()
		{
			var uri = MapsUriHelper.BuildAppleMapsUri(new MapLaunchOptions
			{
				SearchNear = new MapLocation(59.5, 10.25),
				Query = "pizza"
			});
			Assert.AreEqual("https://maps.apple.com/?q=pizza&sll=59.5,10.25", uri);
		}

		[Test]
		public void BuildAppleMapsUri_Directions_ReturnsOriginAndDestination()
		{
			var uri = MapsUriHelper.BuildAppleMapsUri(new MapLaunchOptions
			{
				Origin = new MapLocation(59.5, 10.25),
				Destination = new MapLocation(59.6, 10.3),
				TravelMode = MapTravelMode.Walking
			});
			Assert.AreEqual(
				"https://maps.apple.com/?saddr=59.5,10.25&daddr=59.6,10.3&dirflg=w",
				uri);
		}

		[Test]
		public void BuildAppleMapsUri_DirectionsFromCurrentLocation_UsesEmptySaddr()
		{
			var uri = MapsUriHelper.BuildAppleMapsUri(new MapLaunchOptions
			{
				Destination = new MapLocation(59.6, 10.3),
				TravelMode = MapTravelMode.Driving
			});
			Assert.AreEqual(
				"https://maps.apple.com/?saddr=&daddr=59.6,10.3&dirflg=d",
				uri);
		}

		[Test]
		public void BuildAppleMapsUri_DirectionsToAddress_EscapesAddress()
		{
			var uri = MapsUriHelper.BuildAppleMapsUri(new MapLaunchOptions
			{
				DestinationAddress = "Some Street 1, Oslo",
				TravelMode = MapTravelMode.Transit
			});
			Assert.AreEqual(
				"https://maps.apple.com/?saddr=&daddr=Some%20Street%201%2C%20Oslo&dirflg=r",
				uri);
		}

		[Test]
		public void BuildGoogleMapsUrl_LocationOnly_ReturnsMapUrl()
		{
			var uri = MapsUriHelper.BuildGoogleMapsUrl(new MapLaunchOptions
			{
				Location = new MapLocation(59.5, 10.25)
			});
			Assert.AreEqual(
				"https://www.google.com/maps/@?api=1&map_action=map&center=59.5,10.25",
				uri);
		}

		[Test]
		public void BuildGoogleMapsUrl_LocationWithZoomAndSatellite()
		{
			var uri = MapsUriHelper.BuildGoogleMapsUrl(new MapLaunchOptions
			{
				Location = new MapLocation(59.5, 10.25),
				Zoom = 15,
				MapType = MapType.Satellite
			});
			Assert.AreEqual(
				"https://www.google.com/maps/@?api=1&map_action=map&center=59.5,10.25&zoom=15&basemap=satellite",
				uri);
		}

		[Test]
		public void BuildGoogleMapsUrl_ZoomIsClampedTo21()
		{
			var uri = MapsUriHelper.BuildGoogleMapsUrl(new MapLaunchOptions
			{
				Location = new MapLocation(59.5, 10.25),
				Zoom = 23
			});
			Assert.AreEqual(
				"https://www.google.com/maps/@?api=1&map_action=map&center=59.5,10.25&zoom=21",
				uri);
		}

		[Test]
		public void BuildGoogleMapsUrl_QueryOnly_ReturnsSearchUrl()
		{
			var uri = MapsUriHelper.BuildGoogleMapsUrl(new MapLaunchOptions
			{
				Query = "pizza restaurant"
			});
			Assert.AreEqual(
				"https://www.google.com/maps/search/?api=1&query=pizza%20restaurant",
				uri);
		}

		[Test]
		public void BuildGoogleMapsUrl_Directions_StartsNavigation()
		{
			var uri = MapsUriHelper.BuildGoogleMapsUrl(new MapLaunchOptions
			{
				Origin = new MapLocation(59.5, 10.25),
				Destination = new MapLocation(59.6, 10.3),
				TravelMode = MapTravelMode.Driving,
				StartNavigation = true
			});
			Assert.AreEqual(
				"https://www.google.com/maps/dir/?api=1&origin=59.5,10.25&destination=59.6,10.3&travelmode=driving&dir_action=navigate",
				uri);
		}

		[Test]
		public void BuildGoogleMapsUrl_DirectionsFromCurrentLocation()
		{
			var uri = MapsUriHelper.BuildGoogleMapsUrl(new MapLaunchOptions
			{
				Destination = new MapLocation(59.6, 10.3),
				TravelMode = MapTravelMode.Walking
			});
			Assert.AreEqual(
				"https://www.google.com/maps/dir/?api=1&destination=59.6,10.3&travelmode=walking",
				uri);
		}

		[Test]
		public void BuildGoogleMapsUrl_TransitDoesNotStartNavigation()
		{
			var uri = MapsUriHelper.BuildGoogleMapsUrl(new MapLaunchOptions
			{
				Destination = new MapLocation(59.6, 10.3),
				TravelMode = MapTravelMode.Transit,
				StartNavigation = true
			});
			Assert.AreEqual(
				"https://www.google.com/maps/dir/?api=1&destination=59.6,10.3&travelmode=transit",
				uri);
		}

		[Test]
		public void BuildGoogleMapsUrl_DirectionsToAddress_EscapesAddress()
		{
			var uri = MapsUriHelper.BuildGoogleMapsUrl(new MapLaunchOptions
			{
				DestinationAddress = "Some Street 1, Oslo",
				TravelMode = MapTravelMode.Cycling
			});
			Assert.AreEqual(
				"https://www.google.com/maps/dir/?api=1&destination=Some%20Street%201%2C%20Oslo&travelmode=bicycling",
				uri);
		}

		[Test]
		public void BuildAndroidDirectionsUri_Driving_StartsNavigation()
		{
			var uri = MapsUriHelper.BuildAndroidDirectionsUri(new MapLaunchOptions
			{
				Origin = new MapLocation(59.5, 10.25),
				Destination = new MapLocation(59.6, 10.3),
				TravelMode = MapTravelMode.Driving,
				StartNavigation = true
			});
			Assert.AreEqual("google.navigation:q=59.6,10.3&mode=d", uri);
		}

		[Test]
		public void BuildAndroidDirectionsUri_Walking_StartsNavigation()
		{
			var uri = MapsUriHelper.BuildAndroidDirectionsUri(new MapLaunchOptions
			{
				Destination = new MapLocation(59.6, 10.3),
				TravelMode = MapTravelMode.Walking,
				StartNavigation = true
			});
			Assert.AreEqual("google.navigation:q=59.6,10.3&mode=w", uri);
		}

		[Test]
		public void BuildAndroidDirectionsUri_Cycling_StartsNavigation()
		{
			var uri = MapsUriHelper.BuildAndroidDirectionsUri(new MapLaunchOptions
			{
				Destination = new MapLocation(59.6, 10.3),
				TravelMode = MapTravelMode.Cycling,
				StartNavigation = true
			});
			Assert.AreEqual("google.navigation:q=59.6,10.3&mode=b", uri);
		}

		[Test]
		public void BuildAndroidDirectionsUri_Transit_UsesDirectionsUrl()
		{
			var uri = MapsUriHelper.BuildAndroidDirectionsUri(new MapLaunchOptions
			{
				Destination = new MapLocation(59.6, 10.3),
				TravelMode = MapTravelMode.Transit,
				StartNavigation = true
			});
			Assert.AreEqual(
				"https://www.google.com/maps/dir/?api=1&destination=59.6,10.3&travelmode=transit",
				uri);
		}

		[Test]
		public void BuildAndroidDirectionsUri_NonGooglePackage_UsesDirectionsUrl()
		{
			var uri = MapsUriHelper.BuildAndroidDirectionsUri(new MapLaunchOptions
			{
				Destination = new MapLocation(59.6, 10.3),
				TravelMode = MapTravelMode.Driving,
				StartNavigation = true,
				AndroidPackage = "com.waze"
			});
			Assert.AreEqual(
				"https://www.google.com/maps/dir/?api=1&destination=59.6,10.3&travelmode=driving&dir_action=navigate",
				uri);
		}

		[Test]
		public void BuildGoogleMapsAppUri_LocationWithZoomAndSatellite()
		{
			var uri = MapsUriHelper.BuildGoogleMapsAppUri(new MapLaunchOptions
			{
				Location = new MapLocation(59.5, 10.25),
				Zoom = 15,
				MapType = MapType.Satellite
			});
			Assert.AreEqual(
				"comgooglemaps://?q=59.5,10.25&zoom=15&mapmode=satellite",
				uri);
		}

		[Test]
		public void BuildGoogleMapsAppUri_Directions()
		{
			var uri = MapsUriHelper.BuildGoogleMapsAppUri(new MapLaunchOptions
			{
				Origin = new MapLocation(59.5, 10.25),
				Destination = new MapLocation(59.6, 10.3),
				TravelMode = MapTravelMode.Walking
			});
			Assert.AreEqual(
				"comgooglemaps://?saddr=59.5,10.25&daddr=59.6,10.3&directionsmode=walking",
				uri);
		}

		[Test]
		public void BuildGoogleMapsAppUri_DirectionsFromCurrentLocation()
		{
			var uri = MapsUriHelper.BuildGoogleMapsAppUri(new MapLaunchOptions
			{
				Destination = new MapLocation(59.6, 10.3),
				TravelMode = MapTravelMode.Driving
			});
			Assert.AreEqual(
				"comgooglemaps://?saddr=&daddr=59.6,10.3&directionsmode=driving",
				uri);
		}

		[Test]
		public void Validate_NoLocationOrQuery_Throws()
		{
			Assert.Throws<ArgumentException>(ValidateEmptyOptions);
		}

		[Test]
		public void Validate_WhitespaceQueryWithoutLocation_Throws()
		{
			Assert.Throws<ArgumentException>(ValidateWhitespaceQuery);
		}

		[Test]
		public void Validate_OriginWithoutDestination_Throws()
		{
			Assert.Throws<ArgumentException>(ValidateOriginWithoutDestination);
		}

		[Test]
		public void Validate_LatitudeOutOfRange_Throws()
		{
			Assert.Throws<ArgumentOutOfRangeException>(ValidateLatitudeOutOfRange);
		}

		[Test]
		public void Validate_LongitudeOutOfRange_Throws()
		{
			Assert.Throws<ArgumentOutOfRangeException>(ValidateLongitudeOutOfRange);
		}

		[Test]
		public void Validate_DestinationOutOfRange_Throws()
		{
			Assert.Throws<ArgumentOutOfRangeException>(ValidateDestinationOutOfRange);
		}

		[Test]
		public void Validate_ZoomOutOfRange_Throws()
		{
			Assert.Throws<ArgumentOutOfRangeException>(ValidateZoomOutOfRange);
		}

		[Test]
		public void Validate_NaN_Throws()
		{
			Assert.Throws<ArgumentOutOfRangeException>(ValidateNaN);
		}

		[Test]
		public void MapLaunchOptions_UseWebFallback_DefaultsToTrue()
		{
			Assert.IsTrue(new MapLaunchOptions().UseWebFallback);
		}

		static void ValidateEmptyOptions()
		{
			MapsUriHelper.Validate(new MapLaunchOptions());
		}

		static void BuildGeoUriWithDestination()
		{
			MapsUriHelper.BuildGeoUri(new MapLaunchOptions
			{
				Destination = new MapLocation(59.6, 10.3)
			});
		}

		static void ValidateWhitespaceQuery()
		{
			MapsUriHelper.Validate(new MapLaunchOptions
			{
				Query = "   "
			});
		}

		static void ValidateOriginWithoutDestination()
		{
			MapsUriHelper.Validate(new MapLaunchOptions
			{
				Origin = new MapLocation(59.5, 10.25),
				Query = "pizza"
			});
		}

		static void ValidateLatitudeOutOfRange()
		{
			MapsUriHelper.Validate(new MapLaunchOptions
			{
				Location = new MapLocation(91, 10)
			});
		}

		static void ValidateLongitudeOutOfRange()
		{
			MapsUriHelper.Validate(new MapLaunchOptions
			{
				Location = new MapLocation(59, 181)
			});
		}

		static void ValidateDestinationOutOfRange()
		{
			MapsUriHelper.Validate(new MapLaunchOptions
			{
				Destination = new MapLocation(91, 10)
			});
		}

		static void ValidateZoomOutOfRange()
		{
			MapsUriHelper.Validate(new MapLaunchOptions
			{
				Location = new MapLocation(59.5, 10.25),
				Zoom = 24
			});
		}

		static void ValidateNaN()
		{
			MapsUriHelper.Validate(new MapLaunchOptions
			{
				Location = new MapLocation(Double.NaN, 10)
			});
		}
	}
}
