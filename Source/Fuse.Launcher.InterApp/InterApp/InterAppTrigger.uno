using Uno;

namespace Fuse.Triggers.Actions
{
	/** Launch the default browser for an URL or open files with its corresponding default application

		You'll find this trigger action in the Fuse.Launcher package, which have to be referenced from your uno project.
		For example:
		```JSON
			{
				"references": [
					"Fuse",
					"FuseJS",
					"Fuse.Launcher"
				]
			}
		```

		## Example
		```XML
			<StackPanel Margin="20">
				<Button Margin="10" Text="Go to Fuse Open">
					<Clicked>
						<LaunchUri Uri="https://fuseopen.com/" />
					</Clicked>
				</Button>
			</StackPanel>
		```

		Note: you can pass any URI string to `LaunchUri`, but how it is handled will depend on the target platform and particular device settings.

		There are several common URI schemes that you can use on both Android and iOS:
			http://<website address>
			https://<website address>
			tel:<phone number>
			sms:<phone number>

		Other platform-specific URI schemes are known to be working fine, for example `geo:<parameters>` launches Maps application on Android
		and `facetime:<parameters>` launches a Facetime video call on iOS.
		More information on supported URI schemes: [on Android](https://developer.android.com/guide/components/intents-common.html) and [on iOS](https://developer.apple.com/library/content/featuredarticles/iPhoneURLScheme_Reference/Introduction/Introduction.html).
	*/
	public class LaunchUri : TriggerAction
	{
		public string Uri {get; set;}

		/** An Android package to target. */
		public string AndroidPackage {get; set;}

		/** An explicit Android activity class. Requires `AndroidPackage`. */
		public string AndroidClassName {get; set;}

		/** A MIME type for the intent data, for example `"text/plain"`. */
		public string MimeType {get; set;}

		/** Comma-separated Android intent flag names, for example `"newTask,clearTop"`. */
		public string AndroidFlags {get; set;}

		protected override void Perform(Node target)
		{
			Fuse.LauncherImpl.InterAppLauncher.LaunchUri(new InterAppLaunchOptions
			{
				Uri = this.Uri,
				AndroidPackage = this.AndroidPackage,
				AndroidClassName = this.AndroidClassName,
				MimeType = this.MimeType,
				AndroidFlags = InterAppUriHelper.SplitAndroidFlags(this.AndroidFlags)
			}).Catch(e => { debug_log("InterApp.LaunchUri - " + e.Message); });
		}
	}

	public class LaunchApp : TriggerAction
	{
		public string Uri {get; set;}
		public string AppStoreUri {get; set;}

		protected override void Perform(Node target)
		{
			Fuse.LauncherImpl.InterAppLauncher.LaunchApp(this.Uri, this.AppStoreUri);
		}
	}

	/** Launch an Android application by package id. */
	public class LaunchPackage : TriggerAction
	{
		public string ApplicationId {get; set;}
		public string AppStoreUri {get; set;}

		/** Comma-separated Android intent flag names, for example `"newTask,clearTop"`. */
		public string AndroidFlags {get; set;}

		protected override void Perform(Node target)
		{
			Fuse.LauncherImpl.InterAppLauncher.LaunchPackage(this.ApplicationId, new InterAppLaunchOptions
			{
				AppStoreUri = this.AppStoreUri,
				AndroidFlags = InterAppUriHelper.SplitAndroidFlags(this.AndroidFlags)
			}).Catch(e => { debug_log("InterApp.LaunchPackage - " + e.Message); });
		}
	}

	/** Open the operating system's settings page for this application. */
	public class OpenSettings : TriggerAction
	{
		protected override void Perform(Node target)
		{
			Fuse.LauncherImpl.InterAppLauncher.OpenSettings()
				.Catch(e => { debug_log("InterApp.OpenSettings - " + e.Message); });
		}
	}

	/** Open the store page for an application. */
	public class OpenStore : TriggerAction
	{
		/** The Android package whose Play Store page should be opened. */
		public string AndroidPackage {get; set;}

		/** The iOS App Store id, with or without the `id` prefix. */
		public string AppStoreId {get; set;}

		/** An explicit store URI that overrides the platform defaults. */
		public string StoreUri {get; set;}

		protected override void Perform(Node target)
		{
			Fuse.LauncherImpl.InterAppLauncher.OpenStore(new InterAppStoreOptions
			{
				AndroidPackage = this.AndroidPackage,
				AppStoreId = this.AppStoreId,
				StoreUri = this.StoreUri
			}).Catch(e => { debug_log("InterApp.OpenStore - " + e.Message); });
		}
	}
}
