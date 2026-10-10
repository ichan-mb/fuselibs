using Uno;
using Uno.UX;
using Fuse;
using Fuse.Scripting;


namespace Fuse.Controls
{
	/**
		Represents a toolbar item that can be added to a NavigationBarConfig to display buttons in the navigation bar.

		This class supports JavaScript function binding for click events using the VisualEventHandler pattern.
		ToolbarItems are added as child elements to NavigationBarConfig using the [UXContent] pattern.
		The ToolbarItem will appear as a native button in the navigation bar with the specified title.

		Usage:
		```xml
		<NavigationBarConfig Navigation="nav" Title="Home">
			<ToolbarItem Title="Add" Position="Right" Clicked="{addClicked}" />
			<ToolbarItem Title="Edit" Position="Right" Clicked="{editClicked}" />
		</NavigationBarConfig>
		```
	*/
	public class ToolbarItem : Behavior
	{
		string _title;
		/**
			The title/text to display on the toolbar item button.
		*/
		public string Title
		{
			get { return _title; }
			set
			{
				if (_title != value)
				{
					_title = value;
					OnPropertyChanged();
				}
			}
		}

		/**
			The JavaScript function to be called when the toolbar item is clicked.
			This uses the VisualEventHandler pattern similar to Callback actions.
		*/
		public event VisualEventHandler Clicked;

		bool _enabled = true;
		/**
			Whether the toolbar item is enabled and can be clicked.
		*/
		public bool Enabled
		{
			get { return _enabled; }
			set
			{
				if (_enabled != value)
				{
					_enabled = value;
					OnPropertyChanged();
				}
			}
		}

		Visual visualParent;
		/**
			The navigation object to be used when the toolbar item is clicked.
		*/
		public Visual VisualParent
		{
			get { return visualParent; }
			set
			{
				if (visualParent != value)
				{
					visualParent = value;
					OnPropertyChanged();
				}
			}
		}

		ToolbarItemPosition _position = ToolbarItemPosition.Right;
		/**
			The position where the toolbar item should appear in the navigation bar.
		*/
		public ToolbarItemPosition Position
		{
			get { return _position; }
			set
			{
				if (_position != value)
				{
					_position = value;
					OnPropertyChanged();
				}
			}
		}

		/**
			Internal method to trigger the clicked event
		*/
		internal void TriggerClicked()
		{
			if (!_enabled)
				return;

			// Trigger JavaScript event handler if bound
			if (Clicked != null)
			{
				if (visualParent != null)
				{
					Clicked(visualParent, new VisualEventArgs(visualParent));
				}
			}
		}

		/**
			Called when properties change to update the navigation bar.
		*/
		void OnPropertyChanged()
		{
			// Find the parent NavigationBarConfig and notify it of changes
			Node current = Parent;
			while (current != null)
			{
				var navBarConfig = current as NavigationBarConfig;
				if (navBarConfig != null && navBarConfig.IsRootingCompleted)
				{
					navBarConfig.OnToolbarItemChanged();
					break;
				}
				current = current.Parent;
			}
		}
	}

	/**
		Enum defining the position of toolbar items in the navigation bar.
	*/
	public enum ToolbarItemPosition
	{
		Left,
		Right
	}

	/**
		Data transfer object for toolbar item properties used by native implementations.
	*/
	public class ToolbarItemProps
	{
		public string Title { get; set; }
		public bool Enabled { get; set; }
		public ToolbarItemPosition Position { get; set; }
		public ToolbarItem Source { get; set; }  // Reference to the original ToolbarItem for event handling
	}
}
