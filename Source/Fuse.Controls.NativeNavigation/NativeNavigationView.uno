using Uno;
using Uno.Collections;
using Uno.UX;
using Fuse.Controls;
using Fuse.Controls.Native;
using Fuse.Elements;
using Fuse.Triggers;

namespace Fuse.Controls
{
	/**
		A native navigation container that wraps platform-specific navigation controls.

		On iOS, this wraps UINavigationController.
		On Android, this will wrap native Fragment navigation (to be implemented).

		Usage:
		```xml
		<NativeNavigationView ux:Name="nav">
			<Panel ux:Template="Home">
				<Text>Home Page</Text>
				<Button Text="Go to Details">
					<Clicked>
						<PushView To="Details" Navigation="nav" />
					</Clicked>
				</Button>
			</Panel>
			<Panel ux:Template="Details">
				<Text>Details Page</Text>
				<Button Text="Back">
					<Clicked>
						<PopView Navigation="nav" />
					</Clicked>
				</Button>
			</Panel>
		</NativeNavigationView>
		```
	*/
	public partial class NativeNavigationView : Panel
	{
		static readonly Selector _templateSelector = "Template";

		Stack<string> _navigationStack = new Stack<string>();
		Stack<ViewControllerContext> _viewControllerStack = new Stack<ViewControllerContext>();
		string _currentTemplate;
		ViewControllerContext _currentViewController;
		INativeNavigationView _nativeImpl;

		/**
			Internal class to manage each view controller's rendering context
		*/
		class ViewControllerContext
		{
			public string TemplateName { get; set; }
			public Visual TemplateInstance { get; set; }
			public ViewControllerRoot RenderingRoot { get; set; }

			public ViewControllerContext(string templateName, Visual templateInstance)
			{
				TemplateName = templateName;
				TemplateInstance = templateInstance;
				RenderingRoot = new ViewControllerRoot();
				RenderingRoot.SetContent(templateInstance);
			}

			public void Dispose()
			{
				if (RenderingRoot != null)
				{
					RenderingRoot.Dispose();
					RenderingRoot = null;
				}
				TemplateInstance = null;
			}
		}

		/**
			Specifies the default template to use as the root view controller.
			If not specified, the first available template will be used.
		*/
		public string DefaultTemplate { get; set; }

		public override VisualContext VisualContext
		{
			get { return VisualContext.Native; }
		}

		public NativeNavigationView()
		{
		}

		protected override void OnRooted()
		{
			base.OnRooted();

			// Initialize native implementation
			_nativeImpl = (INativeNavigationView)NativeView;

			// Show default template or first available template
			var initialTemplate = GetInitialTemplate();
			if (!string.IsNullOrEmpty(initialTemplate))
			{
				NavigateToTemplate(initialTemplate, false);
			}
		}

		protected override void OnUnrooted()
		{
			// Clean up all template instances
			CleanupAllTemplateInstances();
			base.OnUnrooted();
		}

		string GetInitialTemplate()
		{
			// Use DefaultTemplate if specified and exists
			if (!string.IsNullOrEmpty(DefaultTemplate))
			{
				var defaultTemplate = FindTemplate(DefaultTemplate);
				if (defaultTemplate != null)
				{
					return DefaultTemplate;
				}
				else
				{
					Fuse.Diagnostics.UserWarning("DefaultTemplate not found, using first available template", this);
				}
			}

			// Fall back to first available template
			for (int i = 0; i < Templates.Count; i++)
			{
				var tpl = Templates[i];
				if (!string.IsNullOrEmpty(tpl.Key))
				{
					return tpl.Key;
				}
			}
			return null;
		}

		/**
			Navigate to a specific template by name
		*/
		public void PushTemplate(string templateName)
		{
			NavigateToTemplate(templateName, true);
		}

		/**
			Go back to the previous template
		*/
		public void PopTemplate()
		{
			if (_navigationStack.Count > 0)
			{
				_navigationStack.Pop(); // Remove current

				if (_navigationStack.Count > 0)
				{
					var previousTemplate = _navigationStack.Peek();
					NavigateToTemplate(previousTemplate, false, true);
				}
			}
		}

		void CleanupAllTemplateInstances()
		{
			// Clean up current view controller
			if (_currentViewController != null)
			{
				_currentViewController.Dispose();
				_currentViewController = null;
			}

			// Clean up all stacked view controllers
			while (_viewControllerStack.Count > 0)
			{
				var viewController = _viewControllerStack.Pop();
				viewController.Dispose();
			}

			// Clear stacks
			_navigationStack.Clear();
			_viewControllerStack.Clear();
		}

		void NavigateToTemplate(string templateName, bool isPush, bool isPop = false)
		{
			var tpl = FindTemplate(templateName);
			if (tpl == null)
			{
				Fuse.Diagnostics.UserError("Template '{templateName}' not found in NativeNavigationView", this);
				return;
			}

			var instance = tpl.New() as Visual;
			if (instance == null)
			{
				Fuse.Diagnostics.UserError("Template '{templateName}' did not produce a Visual", this);
				return;
			}

			// Set the template name on the instance for identification
			instance.Name = templateName;

			// Create separate rendering context for this view controller
			// This avoids the double-parent issue by not adding to NativeNavigationView.Children
			var viewControllerContext = new ViewControllerContext(templateName, instance);

			// Defer navigation to ensure rendering context is properly established
			UpdateManager.AddDeferredAction(() => {
				CompleteNavigation(viewControllerContext, isPush, isPop);
			});
		}

		void CompleteNavigation(ViewControllerContext viewControllerContext, bool isPush, bool isPop)
		{
			// Update navigation stacks
			if (isPush && !isPop)
			{
				_navigationStack.Push(viewControllerContext.TemplateName);
				if (_currentViewController != null)
					_viewControllerStack.Push(_currentViewController);
			}
			else if (isPop && _viewControllerStack.Count > 0)
			{
				// Clean up current view controller
				if (_currentViewController != null)
				{
					_currentViewController.Dispose();
				}

				// Restore previous view controller
				_currentViewController = _viewControllerStack.Pop();
			}

			if (!isPop)
			{
				_currentViewController = viewControllerContext;
			}

			_currentTemplate = viewControllerContext.TemplateName;

			// Use native implementation with the isolated native view
			if (_nativeImpl != null)
			{
				var nativeHandle = viewControllerContext.RenderingRoot.GetNativeHandle();
				_nativeImpl.NavigateToView(nativeHandle, viewControllerContext.TemplateName, isPush, isPop);
			}
		}

		protected override Fuse.Controls.Native.IView CreateNativeView()
		{
			if defined(iOS)
			{
				return Fuse.Controls.iOS.NativeNavigationViewFactory.Create(this);
			}
			else
			{
				return NativeNavigationViewFactory.Create(this);
			}
		}

		// Internal method to get or create the native implementation
		INativeNavigationView GetOrCreateNativeImpl()
		{
			if defined(iOS)
			{
				_nativeImpl = Fuse.Controls.iOS.NativeNavigationViewFactory.CreateNativeImpl(this);
				return _nativeImpl;
			}
			else
			{
				_nativeImpl = NativeNavigationViewFactory.CreateNativeImpl(this);
				return _nativeImpl;
			}
		}

		/**
			Get the native implementation for advanced customization.
			This is used by behaviors like NavigationBar to customize native appearance.
		*/
		public INativeNavigationView GetNativeImplementation()
		{
			return _nativeImpl;
		}
	}
}
