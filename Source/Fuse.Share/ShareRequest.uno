using Uno;
using Fuse.Scripting;
using Fuse.Elements;

namespace Fuse.Share
{
	class ShareRequest
	{
		public string Text;
		public string Url;
		public string[] Files;
		public string MimeType;
		public string Subject;
		public string ChooserTitle;
		public bool HasOrigin;
		public float2 Origin;

		public bool HasText { get { return Text != null && Text.Length > 0; } }
		public bool HasUrl { get { return Url != null && Url.Length > 0; } }
		public bool HasFiles { get { return Files != null && Files.Length > 0; } }
		public bool HasContent { get { return HasText || HasUrl || HasFiles; } }

		public void SetOriginFrom(object arg)
		{
			float2 position = float2(0);
			if (ShareRequestParser.TryGetOrigin(arg, out position))
			{
				HasOrigin = true;
				Origin = position;
			}
		}
	}

	static class ShareRequestParser
	{
		public static ShareRequest FromOptions(object[] args)
		{
			if (args.Length < 1)
				throw new Exception("share requires an options object.");

			var options = args[0] as Scripting.Object;
			if (options == null)
				throw new Exception("share requires an options object.");

			var request = new ShareRequest
			{
				Text = GetString(options, "text"),
				Url = GetString(options, "url"),
				MimeType = GetString(options, "mimeType"),
				Subject = GetString(options, "subject"),
				ChooserTitle = GetString(options, "chooserTitle")
			};

			if (options.ContainsKey("files"))
				request.Files = ToPathArray(options["files"]);
			else if (options.ContainsKey("file"))
				request.Files = ToPathArray(options["file"]);

			if (options.ContainsKey("origin"))
				request.SetOriginFrom(options["origin"]);

			if (!request.HasContent)
				throw new Exception("share requires at least one of 'text', 'url' or 'files'.");

			return request;
		}

		public static string GetStringArg(object[] args, int index)
		{
			if (index >= args.Length || args[index] == null)
				return null;

			var value = args[index] as string;
			if (value == null)
				throw new Exception("Argument " + (index + 1) + " must be a string.");

			return value;
		}

		public static string[] ToPathArray(object value)
		{
			var array = value as Scripting.Array;
			if (array != null)
			{
				var files = new string[array.Length];
				for (int i = 0; i < array.Length; i++)
				{
					var path = array[i] as string;
					if (path == null)
						throw new Exception("The file list must contain only strings.");
					files[i] = path;
				}
				return files;
			}

			var single = value as string;
			if (single != null)
				return new string[] { single };

			return null;
		}

		public static bool TryGetOrigin(object arg, out float2 position)
		{
			position = float2(0.0f);

			var obj = arg as Scripting.Object;
			if (obj == null || !obj.ContainsKey("external_object"))
				return false;

			var external = obj["external_object"] as Scripting.External;
			if (external == null)
				return false;

			var element = external.Object as Element;
			if (element == null)
				return false;

			// The iOS popover expects root-window coordinates. Convert the
			// element center from its local space using the world transform.
			var localCenter = float3(element.ActualSize.X * 0.5f, element.ActualSize.Y * 0.5f, 0);
			var worldCenter = Vector.Transform(localCenter, element.WorldTransform);
			position = float2(worldCenter.X, worldCenter.Y);
			return true;
		}

		static string GetString(Scripting.Object obj, string key)
		{
			if (obj == null || !obj.ContainsKey(key))
				return null;

			var value = obj[key];
			if (value == null)
				return null;

			var str = value as string;
			return str != null ? str : value.ToString();
		}
	}
}
