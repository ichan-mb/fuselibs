using Uno;
using Uno.UX;

using Fuse;

namespace Fuse.Controls
{
	/**
		Describes a tab: its title and icon. Place it inside the template the tab shows. A tab without a
		`TabConfig`, or whose config leaves `Title` unset, is titled with its template name.

		```xml
		<Page ux:Template="Home">
			<TabConfig Navigation="tabs" Title="Home" Symbols="house" />
			...
		</Page>
		```
	*/
	public class TabConfig : Behavior
	{
		/**
			The view this tab belongs to; falls back to the one the template was created by.
		*/
		public NativeTabNavigationView Navigation { get; set; }

		string _title;
		/** The tab's title; when unset, the template name is used. */
		public string Title
		{
			get { return _title; }
			set
			{
				if (_title != value)
				{
					_title = value;
					Notify();
				}
			}
		}

		string _symbols;
		/**
			An icon drawn from a symbol: SF Symbols on iOS, Material Symbols on Android.
		*/
		public string Symbols
		{
			get { return _symbols; }
			set
			{
				if (_symbols != value)
				{
					_symbols = value;
					Notify();
				}
			}
		}

		bool _isFilled;
		/** Whether the `Symbols` icon uses its filled variant, when it has one. */
		public bool IsFilled
		{
			get { return _isFilled; }
			set
			{
				if (_isFilled != value)
				{
					_isFilled = value;
					Notify();
				}
			}
		}

		string _accessibilityLabel;
		/** Screen-reader name for the tab; falls back to `Title`. */
		public string AccessibilityLabel
		{
			get { return _accessibilityLabel; }
			set
			{
				if (_accessibilityLabel != value)
				{
					_accessibilityLabel = value;
					Notify();
				}
			}
		}

		bool _autoAdd = true;
		/**
			Whether the tab is added when the view roots. Set false to declare a template that is only shown
			when `AddTab` adds it (e.g. a tab that depends on sign-in).
		*/
		public bool AutoAdd
		{
			get { return _autoAdd; }
			set
			{
				if (_autoAdd != value)
				{
					_autoAdd = value;
					Notify();
				}
			}
		}

		float4 _color;
		bool _hasColor;
		/** The colour of this tab's icon (and its title on Android); falls back to the bar's `TintColor`. */
		public float4 Color
		{
			get { return _color; }
			set
			{
				if (!_hasColor || _color != value)
				{
					_color = value;
					_hasColor = true;
					Notify();
				}
			}
		}

		/** Whether `Color` was explicitly set. */
		public bool HasColor { get { return _hasColor; } }

		float4 _selectedColor;
		bool _hasSelectedColor;
		/** The colour of this tab's icon (and its title on Android) when selected; falls back to the bar's `SelectedTintColor`. */
		public float4 SelectedColor
		{
			get { return _selectedColor; }
			set
			{
				if (!_hasSelectedColor || _selectedColor != value)
				{
					_selectedColor = value;
					_hasSelectedColor = true;
					Notify();
				}
			}
		}

		/** Whether `SelectedColor` was explicitly set. */
		public bool HasSelectedColor { get { return _hasSelectedColor; } }

		TabPlacement _placement = TabPlacement.Automatic;
		/**
			Where the tab sits in the bar. `Pinned` places it at the trailing side of the bar (iOS 18+;
			on Android it is separated at the trailing edge with a gap). `Search` is the separate trailing
			search button on iOS 26+ and a round, elevated button on Android. `SidebarOnly` is for a sidebar;
			on Android it is hidden, while iOS shows it as a normal tab when there is no sidebar (iPhone).
		*/
		public TabPlacement Placement
		{
			get { return _placement; }
			set
			{
				if (_placement != value)
				{
					_placement = value;
					Notify();
				}
			}
		}

		bool _enabled = true;
		/** Whether the user can select the tab. Defaults to true. */
		public bool Enabled
		{
			get { return _enabled; }
			set
			{
				if (_enabled != value)
				{
					_enabled = value;
					Notify();
				}
			}
		}

		string _badge;
		/**
			Badge text: a count (`"3"`, `"99+"`), an empty string for a dot, or null for no badge (the
			default). The badge is hidden when set to null.
		*/
		public string Badge
		{
			get { return _badge; }
			set
			{
				if (_badge != value)
				{
					_badge = value;
					Notify();
				}
			}
		}

		float4 _badgeColor = float4(0.96f, 0.26f, 0.21f, 1);
		/** The badge's background colour. */
		public float4 BadgeColor
		{
			get { return _badgeColor; }
			set
			{
				if (_badgeColor != value)
				{
					_badgeColor = value;
					Notify();
				}
			}
		}

		float4 _badgeTextColor = float4(1);
		/** The badge's text colour. */
		public float4 BadgeTextColor
		{
			get { return _badgeTextColor; }
			set
			{
				if (_badgeTextColor != value)
				{
					_badgeTextColor = value;
					Notify();
				}
			}
		}

		NativeTabNavigationView _navigation;
		string _templateName;

		protected override void OnRooted()
		{
			base.OnRooted();

			_navigation = Navigation != null ? Navigation : TabNavigationLocator.Find(this);
			if (_navigation == null)
			{
				Fuse.Diagnostics.UserError("TabConfig is not inside a NativeTabNavigationView", this);
				return;
			}

			_templateName = GetTemplateName();
			if (string.IsNullOrEmpty(_templateName))
			{
				Fuse.Diagnostics.UserWarning("Could not determine the template name for TabConfig", this);
				return;
			}

			Notify();
		}

		protected override void OnUnrooted()
		{
			_navigation = null;
			_templateName = null;
			base.OnUnrooted();
		}

		void Notify()
		{
			// Resolve lazily: a lazy tab's config is not rooted, but its properties can still change.
			if (_navigation == null)
				_navigation = Navigation != null ? Navigation : TabNavigationLocator.Find(this);
			if (string.IsNullOrEmpty(_templateName))
				_templateName = GetTemplateName();

			if (_navigation != null && !string.IsNullOrEmpty(_templateName))
				_navigation.OnTabConfigChanged(_templateName, _navigation.CreateTabProps(this, _templateName));
		}

		/** The name of the template this config is inside (the nearest named parent). */
		string GetTemplateName()
		{
			var current = Parent;
			while (current != null)
			{
				if (!string.IsNullOrEmpty(current.Name))
					return current.Name;
				current = current.Parent;
			}
			return null;
		}
	}

	/**
		Finds the view a page belongs to. A tab is rendered in its own context, so the view is not a Fuse
		ancestor; the template instance carries the association instead (see `CreateTabContext`).
	*/
	internal static class TabNavigationLocator
	{
		static readonly PropertyHandle _navigationHandle = Fuse.Properties.CreateHandle();

		internal static void SetNavigation(Visual visual, NativeTabNavigationView navigation)
		{
			visual.Properties.Set(_navigationHandle, navigation);
		}

		internal static NativeTabNavigationView Find(Node node)
		{
			var current = node;
			while (current != null)
			{
				var visual = current as Visual;
				if (visual != null)
				{
					object value;
					if (visual.Properties.TryGet(_navigationHandle, out value))
					{
						var navigation = value as NativeTabNavigationView;
						if (navigation != null)
							return navigation;
					}
				}
				current = current.Parent;
			}
			return null;
		}
	}
}
