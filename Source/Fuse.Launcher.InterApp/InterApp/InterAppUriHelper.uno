using Uno;
using Uno.Collections;

namespace Fuse
{
	/**
		Pure helpers shared by the inter-app launchers.

		Keeping this logic free of platform interop makes it testable on the
		desktop test runner.
	*/
	internal static class InterAppUriHelper
	{
		/**
			Whether a string looks like an Android application id rather than a
			URI.

			Application ids contain no scheme separator (`:`), no path
			separator (`/`) and no whitespace. Everything else is treated as a
			URI, which keeps URIs such as `myapp://host` and `mailto:user@example.com`
			out of the package launch path.
		*/
		public static bool IsApplicationId(string value)
		{
			if (string.IsNullOrEmpty(value))
				return false;

			for (int i = 0; i < value.Length; i++)
			{
				var c = value[i];
				if (c == ':' || c == '/' || char.IsWhiteSpace(c))
					return false;
			}

			return true;
		}

		/** A `market:` URI for an Android package, or the supplied store URI. */
		public static string AndroidStoreUri(string packageOrUri)
		{
			if (string.IsNullOrEmpty(packageOrUri))
				return null;

			if (IsUrl(packageOrUri))
				return packageOrUri;

			return "market://details?id=" + packageOrUri.Trim();
		}

		/** A Play Store web URI for an Android package, or the supplied store URI. */
		public static string AndroidStoreWebUri(string packageOrUri)
		{
			if (string.IsNullOrEmpty(packageOrUri))
				return null;

			if (IsUrl(packageOrUri))
				return packageOrUri;

			return "https://play.google.com/store/apps/details?id=" + packageOrUri.Trim();
		}

		/** An `itms-apps:` URI for an App Store id, or the supplied store URI. */
		public static string AppleStoreUri(string appStoreIdOrUri)
		{
			if (string.IsNullOrEmpty(appStoreIdOrUri))
				return null;

			if (IsUrl(appStoreIdOrUri))
				return appStoreIdOrUri;

			return "itms-apps://itunes.apple.com/app/id" + NormalizeAppStoreId(appStoreIdOrUri);
		}

		/** An App Store web URI for an App Store id, or the supplied store URI. */
		public static string AppleStoreWebUri(string appStoreIdOrUri)
		{
			if (string.IsNullOrEmpty(appStoreIdOrUri))
				return null;

			if (IsUrl(appStoreIdOrUri))
				return appStoreIdOrUri;

			return "https://apps.apple.com/app/id" + NormalizeAppStoreId(appStoreIdOrUri);
		}

		static string NormalizeAppStoreId(string value)
		{
			var id = value.Trim();
			if (id.StartsWith("id"))
				id = id.Substring(2);
			return id;
		}

		static bool IsUrl(string value)
		{
			return value.StartsWith("http://") ||
				value.StartsWith("https://") ||
				value.StartsWith("market://") ||
				value.StartsWith("itms://") ||
				value.StartsWith("itms-apps://");
		}

		/**
			Normalizes Android intent flag names to their canonical form.

			Returns `null` for an empty list and throws `ArgumentException` for an
			unknown flag name.
		*/
		public static string[] NormalizeAndroidFlags(string[] flags)
		{
			if (flags == null || flags.Length == 0)
				return null;

			var result = new string[flags.Length];
			for (int i = 0; i < flags.Length; i++)
			{
				var normalized = NormalizeAndroidFlag(flags[i]);
				if (normalized == null)
					throw new ArgumentException("Unknown Android intent flag: " + flags[i]);
				result[i] = normalized;
			}

			return result;
		}

		/** Splits a comma-separated flag list, as used by the trigger actions. */
		public static string[] SplitAndroidFlags(string value)
		{
			return string.IsNullOrEmpty(value) ? null : value.Split(',');
		}

		static string NormalizeAndroidFlag(string value)
		{
			if (string.IsNullOrEmpty(value))
				return null;

			var flag = value.Trim().ToLower();

			if (flag == "newtask") return "newTask";
			if (flag == "cleartop") return "clearTop";
			if (flag == "singletop") return "singleTop";
			if (flag == "cleartask") return "clearTask";
			if (flag == "nohistory") return "noHistory";
			if (flag == "excludefromrecents") return "excludeFromRecents";
			if (flag == "reordertofront") return "reorderToFront";
			if (flag == "launchadjacent") return "launchAdjacent";
			if (flag == "multipletask") return "multipleTask";
			if (flag == "noanimation") return "noAnimation";
			if (flag == "retaininrecents") return "retainInRecents";
			if (flag == "newdocument") return "newDocument";
			if (flag == "taskonhome") return "taskOnHome";
			if (flag == "resettaskifneeded") return "resetTaskIfNeeded";
			if (flag == "nouseraction") return "noUserAction";

			return null;
		}

		/**
			Flattens string extras into alternating key/value pairs for the
			Android foreign layer.
		*/
		public static string[] FlattenExtras(Dictionary<string, string> extras)
		{
			if (extras == null || extras.Count == 0)
				return null;

			var result = new string[extras.Count * 2];
			var index = 0;
			foreach (var pair in extras)
			{
				result[index++] = pair.Key;
				result[index++] = pair.Value;
			}

			return result;
		}
	}
}
