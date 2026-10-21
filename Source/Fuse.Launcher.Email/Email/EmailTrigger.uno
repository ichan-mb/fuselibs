using Uno;
using Uno.Collections;
using Uno.UX;
using Uno.Threading;

namespace Fuse.Triggers.Actions
{
	/** Launch the default email application with an optional template

		You'll find this trigger action in the Fuse.Launcher package, which have to be referenced from your uno project.
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
		> Note it's expected that the 'To' parameter is set

		The trigger is fire-and-forget. Use the `Fuse.Launcher.LaunchEmail` C# API
		or `FuseJS/Email.compose` when you need the launch result.

		## Example
		```xml
			<StackPanel Margin="20">
				<Button Margin="10" Text="Send email">
					<Clicked>
						<LaunchEmail To="email@example.com" Subject="Test" CarbonCopy="" BlindCarbonCopy="" Message="Hello world!" />
					</Clicked>
				</Button>
			</StackPanel>
		```
	*/
	public class LaunchEmail : TriggerAction
	{
		public string To {get; set;}
		public string CarbonCopy {get; set;}
		public string BlindCarbonCopy {get; set;}
		public string Subject {get; set;}
		public string Message {get; set;}

		/**
			An HTML body.

			Requires a platform email client that supports it, or the iOS in-app
			composer with a configured Mail account.
		*/
		public string HtmlMessage {get; set;}

		/** A single file path to attach. */
		public string Attachment {get; set;}

		/**
			File paths to attach.

			On Android, `content://` URIs are accepted as well.
		*/
		public string[] Attachments {get; set;}

		/** The title of the Android chooser shown for messages with attachments or HTML. */
		public string ChooserTitle {get; set;}

		/** An Android package to target, for example `"com.google.android.gm"`. */
		public string AndroidPackage {get; set;}

		/** Use the iOS in-app composer instead of `mailto:`. */
		public bool PreferInAppComposer {get; set;}

		protected override void Perform(Node target)
		{
			var email = new EmailMessage
			{
				To = EmailUriHelper.FromString(To),
				CarbonCopy = EmailUriHelper.FromString(CarbonCopy),
				BlindCarbonCopy = EmailUriHelper.FromString(BlindCarbonCopy),
				Subject = Subject,
				Body = Message,
				HtmlBody = HtmlMessage,
				Attachments = CollectAttachments(),
				ChooserTitle = ChooserTitle,
				AndroidPackage = AndroidPackage,
				PreferInAppComposer = PreferInAppComposer
			};

			Fuse.LauncherImpl.EmailLauncher.Launch(email).Catch(e => { });
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
