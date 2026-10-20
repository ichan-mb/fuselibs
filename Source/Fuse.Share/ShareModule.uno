using Uno;
using Uno.UX;
using Uno.Threading;
using Fuse.Scripting;

namespace Fuse.Share
{
	/**
	@scriptmodule FuseJS/Share

	Cross-app content sharing API for mobile targets.
	Supports sharing of raw text, URLs, and one or more files with an associated
	[mimetype](http://www.iana.org/assignments/media-types/media-types.xhtml).

	Uses `UIActivityViewController` on iOS and `ACTION_SEND` / `ACTION_SEND_MULTIPLE`
	intents on Android.

	The `share` and `shareFiles` methods return a Promise that resolves when the
	share operation finishes. The result is an object with a `completed` boolean
	and an `activityType` string identifying the target that was used. `activityType`
	is `null` when the platform cannot report it.

	NB: on iPad, iOS design guidelines requires a point on screen as the origin for
	the share popover. You can do this by passing a reference to a UX element.

	You need to add a reference to "Fuse.Share" in your project file to use this feature.

	## Example
	```xml
		<JavaScript>
			var Share = require("FuseJS/Share")
			var Camera = require("FuseJS/Camera")
			module.exports = {
				shareFile : function()
				{
					Camera.takePicture(320,240)
					.then(function(image) {
						Share.share({
							files: [image.path],
							subject: "Photo from Fuse"
						}).then(function(result) {
							console.log("Shared: " + result.completed);
						});
					});
				},
				shareText : function()
				{
					Share.share({
						text: "The link to Fuse Open website",
						url: "https://fuseopen.com/",
						subject: "Fuse Open"
					});
				}
			}
		</JavaScript>
	```
	## iPad example
	```xml
		<Panel>
			<Button Text="Share" Clicked="{shareText}"/>
			<Panel ux:Name="ShareOrigin" Alignment="Center" Width="1" Height="1" />
			<JavaScript>
				var Share = require("FuseJS/Share")
				module.exports = {
					shareText : function()
					{
						// The iOS popover will use the position of ShareOrigin as its spawn origin
						Share.share({
							text: "The link to Fuse Open website",
							url: "https://fuseopen.com/",
							origin: ShareOrigin
						});
					}
				}
			</JavaScript>
		</Panel>
	```
	*/
	[UXGlobalModule]
	public class ShareModule : NativeModule
	{
		static readonly ShareModule _instance;

		public ShareModule() : base()
		{
			if(_instance != null) return;
			Resource.SetGlobalKey(_instance = this, "FuseJS/Share");

			AddMember(new NativeFunction("shareText", ShareText));
			AddMember(new NativeFunction("shareFile", ShareFile));
			AddMember(new NativePromise<ShareResult, Scripting.Object>("share", ShareInterface, ShareResult.Converter));
			AddMember(new NativePromise<ShareResult, Scripting.Object>("shareFiles", ShareFilesInterface, ShareResult.Converter));
		}

		/**
			Share content to another application.

			At least one of `text`, `url` or `files` must be provided.

			@scriptmethod share(options)

			@param options.text (string) Text to share.
			@param options.url (string) A URL to share. On iOS it is shared as a link, on Android it is appended to the shared text.
			@param options.files (array) An array of file paths to share.
			@param options.mimeType (string) Optional data format mimetype (eg. 'image/jpeg', 'text/plain' etc). Detected from the file extension when omitted. A wildcard type is used when multiple files have different types.
			@param options.subject (string) A subject line for targets that support one, such as e-mail.
			@param options.chooserTitle (string) The title of the Android chooser. Ignored on iOS.
			@param options.origin (Element) Optional iPad popover anchor, usually a UX element.

			@return (Promise) A promise that resolves to an object with `completed` (bool) and `activityType` (string or null) properties.
		*/
		static Future<ShareResult> ShareInterface(Context context, object[] args)
		{
			var promise = new Promise<ShareResult>();

			if (!ShareSessionGuard.TryBegin())
			{
				promise.Reject(new Exception("A share is already in progress."));
				return promise;
			}

			try
			{
				ShareInternal(ShareRequestParser.FromOptions(args), promise);
			}
			catch (Exception e)
			{
				ShareSessionGuard.End();
				promise.Reject(e);
			}

			return promise;
		}

		/**
			Share one or more files to another application.

			@scriptmethod shareFiles(files, mimetype, description, origin)

			@param files (array) An array of file paths to share.
			@param mimetype (string) Optional data format mimetype. Detected from the file extension when omitted.
			@param description (string) A short user-facing description used as subject and Android chooser title.
			@param origin (Element) Optional iPad popover anchor, usually a UX element.

			@return (Promise) A promise that resolves to an object with `completed` (bool) and `activityType` (string or null) properties.
		*/
		static Future<ShareResult> ShareFilesInterface(Context context, object[] args)
		{
			var promise = new Promise<ShareResult>();

			if (!ShareSessionGuard.TryBegin())
			{
				promise.Reject(new Exception("A share is already in progress."));
				return promise;
			}

			try
			{
				if (args.Length < 1)
					throw new Exception("shareFiles requires an array of file paths.");

				var files = ShareRequestParser.ToPathArray(args[0]);
				if (files == null || files.Length == 0)
					throw new Exception("shareFiles requires a non-empty array of file paths.");

				var description = ShareRequestParser.GetStringArg(args, 2);
				var request = new ShareRequest
				{
					Files = files,
					MimeType = ShareRequestParser.GetStringArg(args, 1),
					Subject = description,
					ChooserTitle = description
				};

				if (args.Length > 3)
					request.SetOriginFrom(args[3]);

				ShareInternal(request, promise);
			}
			catch (Exception e)
			{
				ShareSessionGuard.End();
				promise.Reject(e);
			}

			return promise;
		}

		/**
			Share raw text to another application.
			@scriptmethod shareText(text, description)

			This method is kept for backwards compatibility. New code should use `share`.

			@param text (string) The text to share
			@param description (string) A short user-facing description for the share dialog
		*/
		object ShareText(Context c, object[] args)
		{
			if(args.Length < 1) return false;

			if defined(android || iOS)
			{
				if (!ShareSessionGuard.TryBegin())
					return false;

				try
				{
					var description = args.Length > 1 ? "" + args[1] : null;
					var request = new ShareRequest
					{
						Text = "" + args[0],
						Subject = description,
						ChooserTitle = description
					};

					if (args.Length > 2)
						request.SetOriginFrom(args[2]);

					ShareInternal(request, new Promise<ShareResult>());
					return true;
				}
				catch
				{
					ShareSessionGuard.End();
					throw;
				}
			}

			return false;
		}

		/**
			Share a file to another application by path.
			@scriptmethod shareFile(path, mimetype, description)

			This method is kept for backwards compatibility. New code should use `share` or `shareFiles`.

			@param path (string) The path to the file to share
			@param mimetype (string) The data format mimetype (eg. 'image/jpeg', 'text/plain' etc). Detected from the file extension when omitted.
			@param description (string) A short user-facing description for the share dialog
		*/
		object ShareFile(Context c, object[] args)
		{
			if(args.Length < 1) return false;

			var path = args[0] as string;
			if (path == null)
				return false;

			if defined(android || iOS)
			{
				if (!ShareSessionGuard.TryBegin())
					return false;

				try
				{
					var description = args.Length > 2 ? "" + args[2] : null;
					var request = new ShareRequest
					{
						Files = new string[] { path },
						MimeType = ShareRequestParser.GetStringArg(args, 1),
						Subject = description,
						ChooserTitle = description
					};

					if (args.Length > 3)
						request.SetOriginFrom(args[3]);

					ShareInternal(request, new Promise<ShareResult>());
					return true;
				}
				catch
				{
					ShareSessionGuard.End();
					throw;
				}
			}
			return false;
		}

		static void ShareInternal(ShareRequest request, Promise<ShareResult> promise)
		{
			if defined(android)
			{
				AndroidShareImpl.Share(request, promise);
			}
			else if defined(iOS)
			{
				iOSShareImpl.Share(request, promise);
			}
			else
			{
				ShareSessionGuard.End();
				promise.Reject(new Exception("Share is not supported on this platform."));
			}
		}
	}
}
