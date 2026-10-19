using Uno;

using Fuse;
using Fuse.Triggers.Actions;

namespace Fuse.Controls
{
	/** Base class for the tab navigation actions. */
	public abstract class TabNavigationAction : TriggerAction
	{
		/** The view to act on; when unset, the one the target's page belongs to is used. */
		public NativeTabNavigationView Navigation { get; set; }

		/** The receiver for the action, or null (having reported an error) when none was found. */
		protected NativeTabNavigationView FindNavigation(Node target, string action)
		{
			var navigation = Navigation;
			if (navigation == null)
				navigation = target.FindByType<NativeTabNavigationView>();
			if (navigation == null)
				navigation = TabNavigationLocator.Find(target);

			if (navigation == null)
				Fuse.Diagnostics.UserError(action + " requires a 'Navigation' property or NativeTabNavigationView in parent hierarchy", this);

			return navigation;
		}
	}

	/**
		Adds a tab from a declared template.

		```xml
		<Clicked><AddTab To="Settings" Navigation="tabs" /></Clicked>
		```
	*/
	public class AddTab : TabNavigationAction
	{
		/** The name of the template to add as a tab. */
		public string To { get; set; }

		protected override void Perform(Node target)
		{
			if (string.IsNullOrEmpty(To))
			{
				Fuse.Diagnostics.UserError("AddTab requires a 'To' property specifying the template name", this);
				return;
			}

			var navigation = FindNavigation(target, "AddTab");
			if (navigation != null)
				navigation.AddTab(To);
		}
	}

	/**
		Removes a tab by template name.

		```xml
		<Clicked><RemoveTab To="Settings" Navigation="tabs" /></Clicked>
		```
	*/
	public class RemoveTab : TabNavigationAction
	{
		/** The name of the template whose tab to remove. */
		public string To { get; set; }

		protected override void Perform(Node target)
		{
			if (string.IsNullOrEmpty(To))
			{
				Fuse.Diagnostics.UserError("RemoveTab requires a 'To' property specifying the template name", this);
				return;
			}

			var navigation = FindNavigation(target, "RemoveTab");
			if (navigation != null)
				navigation.RemoveTab(To);
		}
	}

	/**
		Selects the tab with the given template name.

		```xml
		<Clicked><SelectTab To="Search" Navigation="tabs" /></Clicked>
		```
	*/
	public class SelectTab : TabNavigationAction
	{
		/** The name of the template whose tab to select. */
		public string To { get; set; }

		protected override void Perform(Node target)
		{
			if (string.IsNullOrEmpty(To))
			{
				Fuse.Diagnostics.UserError("SelectTab requires a 'To' property specifying the template name", this);
				return;
			}

			var navigation = FindNavigation(target, "SelectTab");
			if (navigation != null)
				navigation.SelectTab(To);
		}
	}
}
