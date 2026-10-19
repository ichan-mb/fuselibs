using Uno;
using Uno.Collections;
using Uno.UX;

using Fuse;
using Fuse.Resources;

namespace Fuse.Controls
{
	/**
		Common state for `ToolbarItem` and `ToolbarMenuItem`: a title, an optional icon (`Symbols`, `File`,
		`Url` or `Source`), `Enabled`/`Visible` flags and a `Clicked` event.

		Both are `NodeGroup`s so that a `ToolbarItem` can contain `ToolbarMenuItem` children.
	*/
	public abstract class ToolbarEntry : NodeGroup
	{
		string _title;
		/**
			The text shown for this entry.
		*/
		public string Title
		{
			get { return _title; }
			set
			{
				if (_title != value)
				{
					_title = value;
					NotifyOwner();
				}
			}
		}

		string _accessibilityLabel;
		/**
			The name screen readers announce for this entry. Needed for an item that shows only an icon (a
			`Symbols`/image button has no text); when unset, `Title` is used.
		*/
		public string AccessibilityLabel
		{
			get { return _accessibilityLabel; }
			set
			{
				if (_accessibilityLabel != value)
				{
					_accessibilityLabel = value;
					NotifyOwner();
				}
			}
		}

		bool _enabled = true;
		/**
			Whether this entry is enabled and can be clicked.
		*/
		public bool Enabled
		{
			get { return _enabled; }
			set
			{
				if (_enabled != value)
				{
					_enabled = value;
					NotifyOwner();
				}
			}
		}

		bool _visible = true;
		/**
			Whether this entry is shown. A hidden entry takes no room in the bar (and is not in a pull-down
			menu), and can be changed while the page is up with `<Set myItem.Visible="false" />`.
		*/
		public bool Visible
		{
			get { return _visible; }
			set
			{
				if (_visible != value)
				{
					_visible = value;
					NotifyOwner();
				}
			}
		}

		/**
			The JavaScript function called when this entry is clicked: bind it with `Clicked="{handler}"` (a
			`VisualEventHandler`; a `<Clicked>` action child is not supported).
		*/
		public event VisualEventHandler Clicked;

		Visual _visualParent;
		/**
			The `Visual` passed to the `Clicked` event. Set by the containing element; not meant to be set
			directly.
		*/
		public Visual VisualParent
		{
			get { return _visualParent; }
			set
			{
				if (_visualParent != value)
				{
					_visualParent = value;
					NotifyOwner();
				}
			}
		}

		string _symbols;
		/**
			An icon drawn from a symbol: SF Symbols on iOS, Material Symbols on Android. Only one of `Symbols`,
			`File`, `Url` or `Source` should be set; with no icon the entry shows `Title`.
		*/
		public string Symbols
		{
			get { return _symbols; }
			set
			{
				if (_symbols != value)
				{
					_symbols = value;
					NotifyOwner();
				}
			}
		}

		bool _isFilled;
		/**
			Whether the `Symbols` icon should use its filled variant, when the symbol provides one.
		*/
		public bool IsFilled
		{
			get { return _isFilled; }
			set
			{
				if (_isFilled != value)
				{
					_isFilled = value;
					NotifyOwner();
				}
			}
		}

		FileSource _file;
		/**
			An icon loaded from a file. Only one of `Symbols`, `File`, `Url` or `Source` should be specified.
		*/
		public FileSource File
		{
			get { return _file; }
			set
			{
				if (_file != value)
				{
					_file = value;
					NotifyOwner();
				}
			}
		}

		string _url;
		/**
			An icon loaded from a URL. Only one of `Symbols`, `File`, `Url` or `Source` should be specified.
		*/
		public string Url
		{
			get { return _url; }
			set
			{
				if (_url != value)
				{
					_url = value;
					NotifyOwner();
				}
			}
		}

		ImageSource _source;
		/**
			The source of the icon. Only one of `Symbols`, `File`, `Url` or `Source` should be specified.
		*/
		public ImageSource Source
		{
			get { return _source; }
			set
			{
				if (_source != value)
				{
					_source = value;
					NotifyOwner();
				}
			}
		}

		/** Raises `Clicked`, unless the entry is disabled. */
		internal void TriggerClicked()
		{
			if (!_enabled)
				return;

			if (Clicked != null && _visualParent != null)
				Clicked(_visualParent, new VisualEventArgs(_visualParent));
		}

		/**
			Notifies the owning element that a property changed: the `NavigationBarConfig` for a `ToolbarItem`,
			or the containing `ToolbarItem` for a `ToolbarMenuItem`.
		*/
		protected void NotifyOwner()
		{
			Node current = ContextParent;
			while (current != null)
			{
				if (NotifyChanged(current))
					break;
				current = current.ContextParent;
			}
		}

		/** Returns true when `node` handled the change notification, ending the walk. */
		protected abstract bool NotifyChanged(Node node);
	}

	/** Collects the `Nodes` of a `NodeGroup` that are of type `T`. */
	internal static class NodeGroupChildren
	{
		internal static List<T> OfType<T>(NodeGroup group) where T : Node
		{
			var result = new List<T>();
			var nodes = group.Nodes;
			for (int i = 0; i < nodes.Count; i++)
			{
				var item = nodes[i] as T;
				if (item != null)
					result.Add(item);
			}
			return result;
		}
	}
}
