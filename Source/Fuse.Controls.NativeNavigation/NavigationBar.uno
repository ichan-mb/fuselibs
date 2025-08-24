using Uno;
using Uno.UX;
using Fuse;
using Fuse.Scripting;

namespace Fuse.Controls
{
	/**
		A behavior that allows customization of the navigation bar when used within a NativeNavigationView template.

		This behavior should be placed inside a template that is used with NativeNavigationView.
		It will automatically configure the navigation bar appearance when the template is displayed.

		Usage:
		```xml
		<NativeNavigationView ux:Name="nav">
			<Panel ux:Template="Home">
				<NavigationBarConfig Navigation="nav" Title="Home" BackgroundColor="#333" ForegroundColor="#fff" LargeTitle="true" />
				<Text>Home Page</Text>
				<!-- ... -->
			</Panel>
		</NativeNavigationView>
		```
	*/
	public class NavigationBarConfig : Behavior
	{
		string _title;
		/**
			The title to display in the navigation bar.
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

		float4 _backgroundColor = float4(1.0f, 1.0f, 1.0f, 1.0f);
		/**
			The background color of the navigation bar.
		*/
		public float4 BackgroundColor
		{
			get { return _backgroundColor; }
			set
			{
				if (_backgroundColor != value)
				{
					_backgroundColor = value;
					OnPropertyChanged();
				}
			}
		}

		float4 _foregroundColor = float4(0.0f, 0.0f, 0.0f, 1.0f);
		/**
			The foreground color (text and button color) of the navigation bar.
		*/
		public float4 ForegroundColor
		{
			get { return _foregroundColor; }
			set
			{
				if (_foregroundColor != value)
				{
					_foregroundColor = value;
					OnPropertyChanged();
				}
			}
		}

		bool _largeTitle = false;
		/**
			Whether to display the title in large format (iOS 11+ feature).
			On older iOS versions or other platforms, this may be ignored.
		*/
		public bool LargeTitle
		{
			get { return _largeTitle; }
			set
			{
				if (_largeTitle != value)
				{
					_largeTitle = value;
					OnPropertyChanged();
				}
			}
		}

		bool _translucent = false;
		/**
			Whether the navigation bar should be translucent.
			When false, content will not appear behind the navigation bar.
		*/
		public bool Translucent
		{
			get { return _translucent; }
			set
			{
				if (_translucent != value)
				{
					_translucent = value;
					OnPropertyChanged();
				}
			}
		}

		bool _hidden = false;
		/**
			Whether to hide the navigation bar for this view.
		*/
		public bool Hidden
		{
			get { return _hidden; }
			set
			{
				if (_hidden != value)
				{
					_hidden = value;
					OnPropertyChanged();
				}
			}
		}

		string _backButtonTitle;
		/**
			Custom title for the back button. If not set, uses default behavior.
		*/
		public string BackButtonTitle
		{
			get { return _backButtonTitle; }
			set
			{
				if (_backButtonTitle != value)
				{
					_backButtonTitle = value;
					OnPropertyChanged();
				}
			}
		}

		float4 _tintColor;
		bool _hasTintColor = false;
		/**
			The tint color for interactive elements (buttons, icons) in the navigation bar.
			If not set, falls back to ForegroundColor for consistent appearance.
		*/
		public float4 TintColor
		{
			get { return _hasTintColor ? _tintColor : _foregroundColor; }
			set
			{
				if (!_hasTintColor || _tintColor != value)
				{
					_tintColor = value;
					_hasTintColor = true;
					OnPropertyChanged();
				}
			}
		}

		/**
			Gets whether TintColor has been explicitly set.
		*/
		public bool HasTintColor
		{
			get { return _hasTintColor; }
		}

		NativeNavigationView _navigation;
		/**
			The NativeNavigationView to configure.
			This is required since NavigationBarConfig is rendered in a separate context.
		*/
		public NativeNavigationView Navigation
		{
			get { return _navigation; }
			set
			{
				_navigation = value;
				OnPropertyChanged();
			}
		}

		string _templateName;

		protected override void OnRooted()
		{
			base.OnRooted();

			if (_navigation == null)
			{
				Fuse.Diagnostics.UserError("NavigationBarConfig requires a Navigation property to be set", this);
				return;
			}

			// Get the template name from the parent visual
			_templateName = GetTemplateName();
			if (string.IsNullOrEmpty(_templateName))
			{
				Fuse.Diagnostics.UserWarning("Could not determine template name for NavigationBarConfig", this);
			}

			// Apply initial navigation bar settings
			ApplyNavigationBarSettings();
		}

		protected override void OnUnrooted()
		{
			_templateName = null;
			base.OnUnrooted();
		}



		/**
			Get the template name from the parent visual
		*/
		string GetTemplateName()
		{
			var current = Parent;
			while (current != null)
			{
				if (!string.IsNullOrEmpty(current.Name))
				{
					return current.Name;
				}
				current = current.Parent;
			}
			return null;
		}

		/**
			Apply navigation bar settings to the native implementation
		*/
		void ApplyNavigationBarSettings()
		{
			if (_navigation == null)
				return;

			// Get the native implementation from the navigation view
			var nativeImpl = _navigation.GetNativeImplementation();
			if (nativeImpl != null)
			{
				nativeImpl.ConfigureNavigationBar(_templateName, CreateNavigationBarConfig());
			}
		}

		/**
			Called when any property changes to update the navigation bar
		*/
		void OnPropertyChanged()
		{
			if (IsRootingCompleted)
			{
				ApplyNavigationBarSettings();
			}
		}

		/**
			Create a configuration object with current navigation bar settings
		*/
		NavigationBarProps CreateNavigationBarConfig()
		{
			return new NavigationBarProps
			{
				Title = _title,
				BackgroundColor = _backgroundColor,
				ForegroundColor = _foregroundColor,
				TintColor = TintColor, // Uses property to get fallback behavior
				LargeTitle = _largeTitle,
				Translucent = _translucent,
				Hidden = _hidden,
				BackButtonTitle = _backButtonTitle
			};
		}
	}
}
