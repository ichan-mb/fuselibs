using Uno;
using Uno.UX;
using Fuse;
using Fuse.Triggers.Actions;

namespace Fuse.Controls
{
	/**
		Push a new view onto the native navigation stack.

		Usage:
		```xml
		<Button Text="Go to Details">
			<Clicked>
				<PushView To="Details" Navigation="nav" />
			</Clicked>
		</Button>
		```
	*/
	public class PushView : TriggerAction
	{
		/**
			The name of the template to navigate to
		*/
		public string To { get; set; }

		/**
			Reference to the NativeNavigationView to perform the navigation on
		*/
		public NativeNavigationView Navigation { get; set; }

		protected override void Perform(Node target)
		{
			if (string.IsNullOrEmpty(To))
			{
				Fuse.Diagnostics.UserError("PushView requires a 'To' property specifying the template name", this);
				return;
			}

			var navigation = Navigation;
			if (navigation == null)
			{
				// Try to find navigation in parent hierarchy
				navigation = target.FindByType<NativeNavigationView>();
			}

			if (navigation == null)
			{
				Fuse.Diagnostics.UserError("PushView requires a 'Navigation' property or NativeNavigationView in parent hierarchy", this);
				return;
			}

			navigation.PushTemplate(To);
		}
	}

	/**
		Pop the current view from the native navigation stack.

		Usage:
		```xml
		<Button Text="Back">
			<Clicked>
				<PopView Navigation="nav" />
			</Clicked>
		</Button>
		```
	*/
	public class PopView : TriggerAction
	{
		/**
			Reference to the NativeNavigationView to perform the navigation on
		*/
		public NativeNavigationView Navigation { get; set; }

		protected override void Perform(Node target)
		{
			var navigation = Navigation;
			if (navigation == null)
			{
				// Try to find navigation in parent hierarchy
				navigation = target.FindByType<NativeNavigationView>();
			}

			if (navigation == null)
			{
				Fuse.Diagnostics.UserError("PopView requires a 'Navigation' property or NativeNavigationView in parent hierarchy", this);
				return;
			}

			navigation.PopTemplate();
		}
	}
}
