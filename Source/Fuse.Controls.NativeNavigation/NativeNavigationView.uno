using Uno;
using Uno.Collections;
using Uno.UX;
using Fuse.Controls;
using Fuse.Controls.Native;
using Fuse.Elements;
using Fuse.Navigation;
using Fuse.Triggers;
using Fuse.Reactive;

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
	public class NativeNavigationView : Panel, INavigation, Fuse.Reactive.IObserver, Node.ISubtreeDataProvider
	{
		static readonly Selector _templateSelector = "Template";

		// Mapping from template names to view controller contexts
		Dictionary<string, ViewControllerContext> _viewControllerContexts = new Dictionary<string, ViewControllerContext>();

		// Flag to prevent recursive navigation updates
		bool _isUpdatingFromDelegate = false;
		INativeNavigationView _nativeImpl;

		// Pages array support for FuseJS models
		IArray _pages;
		int _curPageIndex = -1;
		// Navigation state for INavigation interface
		NavigationState _navigationState = NavigationState.Stable;
		Visual _activePage;
		double _pageProgress = 0.0;

		/**
			Internal class to manage each view controller's rendering context
		*/
		class ViewControllerContext
		{
			public string TemplateName { get; set; }
			public Visual TemplateInstance { get; set; }
			public ViewControllerRoot RenderingRoot { get; set; }

			public ViewControllerContext(string templateName, Visual templateInstance, NativeNavigationView navigation)
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

		/**
			The stack of pages that controls the navigation history for this NativeNavigationView.

			This should be bound to a JavaScript observable array. The highest index page will always be the active page.
			As pages are added/removed from this array the navigation state will change.

			The items in the array are objects that should contain the `$path` property which specifies
			the template name to use. The object itself will be added to the data context for the page.

			Example JavaScript:
			```javascript
			exports.pages = Observable({
				$path: "Home",
				title: "Welcome"
			});

			// Navigate to details
			exports.pages.add({
				$path: "Details",
				item: selectedItem
			});
			```
		*/
		public IArray Pages
		{
			get { return _pages; }
			set
			{
				if (_pages != value)
				{
					DetachPages();
					_pages = value;
					if (IsRootingStarted)
					{
						AttachPages();
						UpdatePagesNavigation(true);
					}
				}
			}
		}

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
			if defined(iOS)
			{
				_nativeImpl.SetNavigationChangeCallback(OnNativeNavigationChanged);
			}

			// Initialize Pages array if set
			AttachPages();

			// Show default template or first available template (if no Pages array)
			if (_pages == null)
			{
				var initialTemplate = GetInitialTemplate();
				if (!string.IsNullOrEmpty(initialTemplate))
				{
					NavigateToTemplate(initialTemplate, false);
				}
			}
			else
			{
				// Use Pages array for navigation
				UpdatePagesNavigation(true);
			}

			// Fire initial navigation events
			UpdateManager.AddDeferredAction(() => {
				FirePageCountChanged();
			});
		}

		protected override void OnUnrooted()
		{
			// Detach from Pages array
			DetachPages();
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
			if (!_isUpdatingFromDelegate)
			{
				NavigateToTemplate(templateName, true);
				// Fire history changed event for programmatic navigation
				if (HistoryChanged != null)
				{
					HistoryChanged(this);
				}
			}
		}

		/**
			Go back to the previous template
		*/
		public void PopTemplate()
		{
			if (_isUpdatingFromDelegate)
			{
				return;
			}

			// Get current native stack count as source of truth
			var nativeStackCount = _nativeImpl.GetNativeStackCount();

			if (nativeStackCount <= 1)
			{
				return;
			}

			// Use native implementation to pop
			_nativeImpl.PopFromNativeStack();
		}

		/**
			Called by native implementation when navigation stack changes due to native back button
		*/
		public void OnNativeNavigationChanged(string currentTemplateName, int nativeStackCount, bool appear)
		{
			_isUpdatingFromDelegate = true;

			try
			{
				// Update navigation state and fire events
				SetNavigationState(NavigationState.Stable);

				// Update active page
				ViewControllerContext activeContext = null;
				if (!string.IsNullOrEmpty(currentTemplateName) &&
					_viewControllerContexts.TryGetValue(currentTemplateName, out activeContext))
				{
					if (activeContext != null && appear)
					{
						SetActivePage(activeContext.TemplateInstance);
					}
				}
				else
				{
					SetActivePage(null);
				}

				// Fire page count changed event
				FirePageCountChanged();
				UpdateManager.AddDeferredAction(() => {
					// Synchronize our contexts based on native stack
					SynchronizeWithNativeStack(currentTemplateName, nativeStackCount);
				});
			}
			finally
			{
				_isUpdatingFromDelegate = false;
			}
		}

		/**
			Synchronize our view controller contexts with the native stack.
			The native stack is the single source of truth.
		*/
		void SynchronizeWithNativeStack(string currentTemplateName, int nativeStackCount)
		{
			// Get the current navigation stack from native implementation
			var nativeStack = _nativeImpl.GetNativeStackTemplates();

			// Clean up contexts that are no longer in the native stack
			var contextsToRemove = new List<string>();
			foreach (var kvp in _viewControllerContexts)
			{
				var templateName = kvp.Key;
				if (!nativeStack.Contains(templateName))
				{
					contextsToRemove.Add(templateName);
				}
			}

			foreach (var templateName in contextsToRemove)
			{
				var context = _viewControllerContexts[templateName];
				context.Dispose();
				_viewControllerContexts.Remove(templateName);
			}
		}

		void CleanupAllTemplateInstances()
		{
			// Clean up all view controller contexts
			foreach (var kvp in _viewControllerContexts)
			{
				kvp.Value.Dispose();
			}
			_viewControllerContexts.Clear();
		}

		void NavigateToTemplate(string templateName, bool isPush, bool isPop = false)
		{
			var tpl = FindTemplate(templateName);
			if (tpl == null)
			{
				Fuse.Diagnostics.UserError("Template '" + templateName + "' not found in NativeNavigationView", this);
				return;
			}

			// Check if we already have a context for this template
			ViewControllerContext viewControllerContext;
			if (!_viewControllerContexts.TryGetValue(templateName, out viewControllerContext))
			{
				// Create new context
				var instance = tpl.New() as Visual;
				if (instance == null)
				{
					Fuse.Diagnostics.UserError("Template '" + templateName + "' did not produce a Visual", this);
					return;
				}

				// Set the template name on the instance for identification
				instance.Name = templateName;

				// Set navigation property BEFORE creating the context
				// This ensures triggers can find navigation during rooting
				SetActivePage(instance);
				Fuse.Navigation.Navigation.SetNativeNavigation(instance, this);

				// Create separate rendering context for this view controller
				viewControllerContext = new ViewControllerContext(templateName, instance, this);
				_viewControllerContexts[templateName] = viewControllerContext;
			}

			// Defer navigation to ensure rendering context is properly established
			UpdateManager.AddDeferredAction(() => {
				CompleteNavigation(viewControllerContext, isPush, isPop);
			});
		}

		void CompleteNavigation(ViewControllerContext viewControllerContext, bool isPush, bool isPop)
		{
			// Set navigation state to transitioning
			SetNavigationState(NavigationState.Transition);
			SetActivePage(viewControllerContext.TemplateInstance);

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

		/**
			Get the native implementation for advanced customization.
			This is used by behaviors like NavigationBar to customize native appearance.
		*/
		public INativeNavigationView GetNativeImplementation()
		{
			return _nativeImpl;
		}

		/**
			Get current navigation stack (derived from native stack)
		*/
		public string[] GetNavigationStack()
		{
			if (_nativeImpl != null)
			{
				return _nativeImpl.GetNativeStackTemplates();
			}
			return new string[0];
		}

		/**
			Get current navigation stack count (from native stack)
		*/
		public int GetNavigationStackCount()
		{
			if (_nativeImpl != null)
			{
				return _nativeImpl.GetNativeStackCount();
			}
			return 0;
		}

		// INavigation interface implementation
		public int PageCount
		{
			get { return GetNavigationStackCount(); }
		}

		public double PageProgress
		{
			get { return _pageProgress; }
		}

		public Visual GetPage(int index)
		{
			var stack = GetNavigationStack();
			if (index >= 0 && index < stack.Length)
			{
				var templateName = stack[index];
				ViewControllerContext context;
				if (_viewControllerContexts.TryGetValue(templateName, out context))
				{
					return context.TemplateInstance;
				}
			}
			return null;
		}

		public Visual ActivePage
		{
			get { return _activePage; }
		}

		public NavigationPageState GetPageState(Visual page)
		{
			// For native navigation, pages are either fully active (1.0) or inactive (0.0)
			if (page == _activePage)
			{
				return new NavigationPageState { Progress = 0.0f, PreviousProgress = 1.0f };
			}
			return new NavigationPageState { Progress = 1.0f, PreviousProgress = 0.0f };
		}

		public NavigationState State
		{
			get { return _navigationState; }
		}

		// Navigation events
		public event NavigationPageCountHandler PageCountChanged;
		public event NavigationHandler PageProgressChanged;
		public event NavigatedHandler Navigated;
		public event ActivePageChangedHandler ActivePageChanged;
		public event ValueChangedHandler<NavigationState> StateChanged;
		public event HistoryChangedHandler HistoryChanged;

		// IBaseNavigation implementation
		public void GoForward()
		{
			// Native navigation doesn't have a concept of "forward" - no-op
		}

		public void GoBack()
		{
			PopTemplate();
		}

		public bool CanGoBack
		{
			get { return GetNavigationStackCount() > 1; }
		}

		public bool CanGoForward
		{
			get { return false; } // Native navigation doesn't support forward
		}

		public void Goto(Visual node, NavigationGotoMode mode = NavigationGotoMode.Transition)
		{
			// Find the template name for this node
			var templateName = node.Name;
			if (!string.IsNullOrEmpty(templateName))
			{
				PushTemplate(templateName);
			}
		}

		public void Toggle(Visual node)
		{
			// For native navigation, toggle means go to the page if not active, or go back if active
			if (node == _activePage)
			{
				GoBack();
			}
			else
			{
				Goto(node);
			}
		}

		// Internal methods to fire navigation events
		void SetNavigationState(NavigationState newState)
		{
			if (_navigationState != newState)
			{
				_navigationState = newState;
				if (StateChanged != null)
				{
					StateChanged(this, new ValueChangedArgs<NavigationState>(newState));
				}
			}
		}

		void SetActivePage(Visual newActivePage)
		{
			if (_activePage != newActivePage)
			{
				_activePage = newActivePage;

				// Fire events
				if (ActivePageChanged != null)
				{
					ActivePageChanged(this, newActivePage);
				}
				if (newActivePage != null)
				{
					if (Navigated != null)
					{
						Navigated(this, new NavigatedArgs(newActivePage));
					}
				}

				// Update page progress
				var oldProgress = _pageProgress;
				_pageProgress = newActivePage != null ? 0.0 : 1.0;
				if (PageProgressChanged != null)
				{
					PageProgressChanged(this, new NavigationArgs(_pageProgress, oldProgress, NavigationMode.Switch));
				}
			}
		}

		void FirePageCountChanged()
		{
			if (PageCountChanged != null)
			{
				PageCountChanged(this);
			}
			if (HistoryChanged != null)
			{
				HistoryChanged(this);
			}
		}



		// Pages array management
		IDisposable _subscription;
		void AttachPages()
		{
			if (_pages == null)
				return;

			var obs = _pages as IObservableArray;
			if (obs != null)
			{
				_subscription = obs.Subscribe(this);
			}
			else
			{
				Fuse.Diagnostics.UserWarning("Pages expects an observable array. Navigation may not work correctly otherwise.", this);
			}
		}

		void DetachPages()
		{
			if (_pages == null || _subscription == null)
				return;

			_subscription.Dispose();
			_subscription = null;
		}

		void UpdatePagesNavigation(bool isInitial = false)
		{
			if (_pages == null || _pages.Length == 0)
			{
				_curPageIndex = -1;
				return;
			}

			int targetIndex = _pages.Length - 1;
			var pageObj = _pages[targetIndex];

			// Extract $path from the page object
			string templateName = ExtractTemplatePath(pageObj);
			if (string.IsNullOrEmpty(templateName))
			{
				Fuse.Diagnostics.UserError("Page object must contain a '$path' property specifying the template name", this);
				return;
			}

			bool isPush = targetIndex > _curPageIndex;
			bool isPop = targetIndex < _curPageIndex;

			// Navigate to the template with the page object as data context
			NavigateToTemplateWithContext(templateName, pageObj, isPush, isPop, isInitial);

			_curPageIndex = targetIndex;
		}

		string ExtractTemplatePath(object pageObj)
		{
			// Try to get the $path property from the page object
			var obj = pageObj as IObject;
			if (obj != null && obj.ContainsKey("$path"))
			{
				return obj["$path"] as string;
			}

			if (obj != null && obj.ContainsKey("$__fuse_classname"))
			{
				return obj["$__fuse_classname"] as string;
			}

			// Fallback: try dynamic property access
			var dict = pageObj as IDictionary<string, object>;
			if (dict != null && dict.ContainsKey("$path"))
			{
				return dict["$path"] as string;
			}

			if (dict != null && dict.ContainsKey("$__fuse_classname"))
			{
				return dict["$__fuse_classname"] as string;
			}

			return null;
		}

		void NavigateToTemplateWithContext(string templateName, object context, bool isPush, bool isPop, bool isInitial)
		{
			var tpl = FindTemplate(templateName);
			if (tpl == null)
			{
				Fuse.Diagnostics.UserError("Template '" + templateName + "' not found in NativeNavigationView", this);
				return;
			}

			ViewControllerContext viewControllerContext;
			if (!_viewControllerContexts.TryGetValue(templateName, out viewControllerContext))
			{
				// Create new context
				var instance = tpl.New() as Visual;
				if (instance == null)
				{
					Fuse.Diagnostics.UserError("Template '" + templateName + "' did not produce a Visual", this);
					return;
				}

				// Set the template name on the instance for identification
				instance.Name = templateName;

				// Set data context BEFORE creating the rendering context
				SetDataContext(instance, context);

				// Set navigation property BEFORE creating the context
				SetActivePage(instance);
				Fuse.Navigation.Navigation.SetNativeNavigation(instance, this);

				// Create separate rendering context for this view controller
				viewControllerContext = new ViewControllerContext(templateName, instance, this);
				_viewControllerContexts[templateName] = viewControllerContext;
			}
			else
			{
				// Update existing context's data
				SetDataContext(viewControllerContext.TemplateInstance, context);
			}

			// Defer navigation to ensure rendering context is properly established
			if (isInitial)
			{
				// For initial navigation, bypass animation
				CompleteNavigation(viewControllerContext, false, false);
			}
			else
			{
				UpdateManager.AddDeferredAction(() => {
					CompleteNavigation(viewControllerContext, isPush, isPop);
				});
			}
		}

		void SetDataContext(Visual visual, object context)
		{
			if (context != null)
			{
				// Use PageData system to attach context to the visual
				var pageData = PageData.GetOrCreate(visual);
				pageData.SetContext(context);
			}
		}

		// IObserver implementation for Pages array monitoring
		void Fuse.Reactive.IObserver.OnSet(object newValue)
		{
			UpdatePagesNavigation();
		}

		void Fuse.Reactive.IObserver.OnFailed(string message)
		{
			Fuse.Diagnostics.UserError("Pages binding failed: " + message, this);
		}

		void Fuse.Reactive.IObserver.OnAdd(object value)
		{
			UpdatePagesNavigation();
		}

		void Fuse.Reactive.IObserver.OnRemoveAt(int index)
		{
			if (index <= _curPageIndex)
			{
				if (index == _curPageIndex && _pages.Length > 0)
				{
					// Current page was removed, navigate to new top page
					UpdatePagesNavigation();
				}
				else
				{
					// Page before current was removed, adjust index
					_curPageIndex--;
				}
			}
		}

		void Fuse.Reactive.IObserver.OnInsertAt(int index, object value)
		{
			if (index <= _curPageIndex)
			{
				_curPageIndex++;
			}
			else
			{
				// New page added at top, navigate to it
				UpdatePagesNavigation();
			}
		}

		void Fuse.Reactive.IObserver.OnNewAt(int index, object value)
		{
			if (index == _curPageIndex || index == _pages.Length - 1)
			{
				// Current page or top page was replaced
				UpdatePagesNavigation();
			}
		}

		void Fuse.Reactive.IObserver.OnNewAll(IArray values)
		{
			UpdatePagesNavigation();
		}

		void Fuse.Reactive.IObserver.OnClear()
		{
			_curPageIndex = -1;
			// Navigate back to default or clear navigation
			var initialTemplate = GetInitialTemplate();
			if (!string.IsNullOrEmpty(initialTemplate))
			{
				NavigateToTemplate(initialTemplate, false);
			}
		}

		// ISubtreeDataProvider implementation to provide data context
		Node.ContextDataResult ISubtreeDataProvider.TryGetDataProvider(Node n, Node.DataType type, out object provider)
		{
			provider = null;
			var v = n as Visual;
			if (v == null)
				return Node.ContextDataResult.Continue;

			// Check if this visual has a data context from Pages
			var pd = PageData.Get(v);
			if (pd != null)
			{
				provider = pd.Context;
				return type == Node.DataType.Prime ? Node.ContextDataResult.NullProvider : Node.ContextDataResult.Continue;
			}

			return Node.ContextDataResult.Continue;
		}

		// Static method to help with navigation discovery for template instances
		public static NativeNavigationView GetNavigationFromTemplate(Visual tpl)
		{
			return Fuse.Navigation.Navigation.GetNativeNavigation(tpl) as NativeNavigationView;
		}

	}
}
