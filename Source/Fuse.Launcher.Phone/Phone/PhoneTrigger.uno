using Uno;
using Uno.Collections;

namespace Fuse.Triggers.Actions
{
	/** Calls a phone number

		You'll find this trigger action in the `Fuse.Launcher` or
		`Fuse.Launcher.Phone` package, which has to be referenced from your Uno
		project.
		For example:
		```json
			{
				"references": [
					"Fuse",
					"FuseJS",
					"Fuse.Launcher"
				]
			}
		```
		## Example
		```xml
			<StackPanel Margin="20">
				<TextInput PlaceholderText="Enter the number here" ux:Name="numberInput" />
				<Button Margin="10" Text="Call" Alignment="Bottom">
					<Clicked>
						<Call Number="{ReadProperty numberInput.Value}" />
					</Clicked>
				</Button>
			</StackPanel>
		```
	*/
	public class Call : TriggerAction
	{
		public string Number {get; set;}

		/**
			Whether to open the dialer or place the call directly.

			Defaults to `Dial`, which does not require any permissions. `Call`
			requires the `CALL_PHONE` permission on Android and falls back to
			the dialer when it is denied.
		*/
		public PhoneCallMode Mode {get; set;}

		/** An Android package to target, for example `"com.android.dialer"`. */
		public string AndroidPackage {get; set;}

		/** Launch a FaceTime call instead of a phone call. iOS only. */
		public bool FaceTime {get; set;}

		/** Launch a FaceTime audio call. Implies `FaceTime`. */
		public bool FaceTimeAudioOnly {get; set;}

		protected override void Perform(Node target)
		{
			Fuse.LauncherImpl.PhoneLauncher.LaunchCall(new PhoneCallOptions
			{
				Number = Number,
				Mode = Mode,
				AndroidPackage = AndroidPackage,
				FaceTime = FaceTime,
				FaceTimeAudioOnly = FaceTimeAudioOnly
			}).Catch(e => { });
		}
	}

	/** Send a message to a phone number

		You'll find this trigger action in the `Fuse.Launcher` or
		`Fuse.Launcher.Phone` package, which has to be referenced from your Uno
		project.
		For example:
		```json
			{
				"references": [
					"Fuse",
					"FuseJS",
					"Fuse.Launcher"
				]
			}
		```
		## Example
		```xml
			<StackPanel Margin="20">
				<TextInput PlaceholderText="Enter the number here" ux:Name="numberInput" />
				<Button Margin="10" Text="Call" Alignment="Bottom">
					<Clicked>
						<Sms Number="{ReadProperty numberInput.Value}" Body="Hi there" />
					</Clicked>
				</Button>
			</StackPanel>
		```
	*/
	public class Sms : TriggerAction
	{
		public string Number {get; set;}

		public string Body {get; set;}

		/**
			The message subject.

			Requires the iOS in-app composer. Ignored on Android.
		*/
		public string Subject {get; set;}

		/** A single file path to attach. */
		public string Attachment {get; set;}

		/**
			File paths to attach.

			Requires the iOS in-app composer and iOS 14 or later. Ignored on
			Android.
		*/
		public string[] Attachments {get; set;}

		/**
			Use the iOS in-app composer instead of the `sms:` link.

			This is automatically enabled when `Subject` or `Attachments` is set.
		*/
		public bool PreferInAppComposer {get; set;}

		/** An Android package to target, for example `"com.google.android.apps.messaging"`. */
		public string AndroidPackage {get; set;}

		/** The title of the Android chooser shown when no `AndroidPackage` is set. */
		public string ChooserTitle {get; set;}

		protected override void Perform(Node target)
		{
			Fuse.LauncherImpl.PhoneLauncher.LaunchSms(new SmsMessage
			{
				Recipients = new[] { Number },
				Body = Body,
				Subject = Subject,
				Attachments = CollectAttachments(),
				PreferInAppComposer = PreferInAppComposer,
				AndroidPackage = AndroidPackage,
				ChooserTitle = ChooserTitle
			}).Catch(e => { });
		}

		string[] CollectAttachments()
		{
			var attachments = new List<string>();

			if (!string.IsNullOrEmpty(Attachment))
				attachments.Add(Attachment.Trim());

			if (Attachments != null)
			{
				foreach (var path in Attachments)
				{
					if (!string.IsNullOrEmpty(path))
						attachments.Add(path.Trim());
				}
			}

			return attachments.ToArray();
		}
	}
}
