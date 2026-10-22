using Uno;
using Uno.Threading;
using Uno.Compiler.ExportTargetInterop;

namespace Fuse.LauncherImpl
{
	[ForeignInclude(Language.ObjC, "UIKit/UIKit.h", "MapKit/MapKit.h")]
	internal extern(iOS) static class MapsPlatformIOS
	{
		public static bool IsAvailable()
		{
			// Apple Maps is built into iOS.
			return true;
		}

		public static void Launch(MapLaunchOptions options, Promise<MapLaunchStatus> promise)
		{
			if (options.PreferGoogleMaps)
			{
				OpenUri(
					MapsUriHelper.BuildGoogleMapsAppUri(options),
					() => promise.Resolve(MapLaunchStatus.Opened),
					error => LaunchAppleMaps(options, promise));
				return;
			}

			LaunchAppleMaps(options, promise);
		}

		static void LaunchAppleMaps(MapLaunchOptions options, Promise<MapLaunchStatus> promise)
		{
			if (MapsUriHelper.HasDestination(options) && options.Destination != null)
			{
				LaunchDirectionsNative(
					options.Origin != null,
					options.Origin != null ? options.Origin.Latitude : 0,
					options.Origin != null ? options.Origin.Longitude : 0,
					options.Origin != null ? options.Origin.Label : null,
					options.Destination.Latitude,
					options.Destination.Longitude,
					options.Destination.Label,
					options.TravelMode.ToString(),
					options.MapType.ToString(),
					options.ShowTraffic,
					() => promise.Resolve(MapLaunchStatus.Opened),
					error => OpenFallbacks(options, promise));
				return;
			}

			OpenFallbacks(options, promise);
		}

		static void OpenFallbacks(MapLaunchOptions options, Promise<MapLaunchStatus> promise)
		{
			var uris = new string[]
			{
				MapsUriHelper.BuildAppleMapsUri(options),
				options.UseWebFallback ? MapsUriHelper.BuildGoogleMapsUrl(options) : null
			};

			OpenUriChain(uris, 0, promise);
		}

		static void OpenUriChain(string[] uris, int index, Promise<MapLaunchStatus> promise)
		{
			if (uris == null || index >= uris.Length)
			{
				promise.Reject(new Exception("No app is available to open maps."));
				return;
			}

			var uri = uris[index];
			if (string.IsNullOrEmpty(uri))
			{
				OpenUriChain(uris, index + 1, promise);
				return;
			}

			OpenUri(
				uri,
				() => promise.Resolve(MapLaunchStatus.Opened),
				error => OpenUriChain(uris, index + 1, promise));
		}

		[Foreign(Language.ObjC)]
		static void OpenUri(string uri, Action onOpened, Action<string> onError)
		@{
			dispatch_async(dispatch_get_main_queue(), ^{
				NSURL* url = [NSURL URLWithString:uri];
				if (url == nil)
				{
					onError(@"Invalid map URL.");
					return;
				}

				[[UIApplication sharedApplication] openURL:url options:[NSDictionary dictionary] completionHandler:^(BOOL success)
				{
					if (success)
						onOpened();
					else
						onError(@"No app is available to open maps.");
				}];
			});
		@}

		[Foreign(Language.ObjC)]
		static void LaunchDirectionsNative(bool hasOrigin,
			double originLat, double originLng, string originLabel,
			double destLat, double destLng, string destLabel,
			string travelMode, string mapType, bool showTraffic,
			Action onOpened, Action<string> onError)
		@{
			dispatch_async(dispatch_get_main_queue(), ^{
				MKMapItem* originItem = nil;

				if (hasOrigin)
				{
					MKPlacemark* originPlacemark = [[MKPlacemark alloc]
						initWithCoordinate:CLLocationCoordinate2DMake(originLat, originLng)];

					originItem = [[MKMapItem alloc] initWithPlacemark:originPlacemark];
					if (originLabel != nil)
						originItem.name = originLabel;
				}
				else
				{
					originItem = [MKMapItem mapItemForCurrentLocation];
				}

				MKPlacemark* destPlacemark = [[MKPlacemark alloc]
					initWithCoordinate:CLLocationCoordinate2DMake(destLat, destLng)];

				MKMapItem* destItem = [[MKMapItem alloc] initWithPlacemark:destPlacemark];
				if (destLabel != nil)
					destItem.name = destLabel;

				NSMutableDictionary* launchOptions = [NSMutableDictionary dictionary];

				NSString* directionsMode = MKLaunchOptionsDirectionsModeDriving;
				if ([travelMode isEqualToString:@"Walking"])
					directionsMode = MKLaunchOptionsDirectionsModeWalking;
				else if ([travelMode isEqualToString:@"Transit"])
					directionsMode = MKLaunchOptionsDirectionsModeTransit;
				else if ([travelMode isEqualToString:@"Cycling"])
					directionsMode = MKLaunchOptionsDirectionsModeCycling;
				launchOptions[MKLaunchOptionsDirectionsModeKey] = directionsMode;

				MKMapType type = MKMapTypeStandard;
				if ([mapType isEqualToString:@"Satellite"])
					type = MKMapTypeSatellite;
				else if ([mapType isEqualToString:@"Hybrid"])
					type = MKMapTypeHybrid;
				launchOptions[MKLaunchOptionsMapTypeKey] = [NSNumber numberWithUnsignedInteger:type];

				if (showTraffic)
					launchOptions[MKLaunchOptionsShowsTrafficKey] = @YES;

				BOOL opened = [MKMapItem openMapsWithItems:@[originItem, destItem]
					launchOptions:launchOptions];

				if (opened)
					onOpened();
				else
					onError(@"Could not open directions in Apple Maps.");
			});
		@}
	}
}
