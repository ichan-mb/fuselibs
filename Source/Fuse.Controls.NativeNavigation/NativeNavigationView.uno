using Uno;
using Uno.Collections;
using Uno.UX;

using Fuse.Controls.Native;
using Fuse.Elements;
using Fuse.Navigation;
using Fuse.Reactive;

namespace Fuse.Controls
{
	/**
		A navigation stack, navigation bar and modals rendered by the platform: a `UINavigationController`
		stack on iOS, a `FragmentManager` back stack with an appcompat `Toolbar` on Android.

		Each template is an isolated page. `PushView` / `PopView` (or the `Pages` array from FuseJS) drive the
		stack, and the platform's own back button, back arrow and swipe-back gesture pop it.

		```xml
		<NativeNavigationView ux:Name="nav" DefaultTemplate="Home">
			<Panel ux:Template="Home">...</Panel>
			<Panel ux:Template="Details">...</Panel>
		</NativeNavigationView>
		```
	*/
	public class NativeNavigationView : Panel, INavigation, Fuse.Reactive.IObserver, Node.ISubtreeDataProvider
	{
		// Contexts for each page currently on the native stack, bottom to top. A stack may contain the same
		// template more than once, so contexts are tracked by position rather than by template name.
		readonly List<ViewControllerContext> _viewControllerStack = new List<ViewControllerContext>();

		// Modally presented pages, bottom to top.
		readonly List<ViewControllerContext> _modalContexts = new List<ViewControllerContext>();

		// The modal that is animating out, held until the native side reports the dismissal finished.
		ViewControllerContext _dismissingModalContext;

		// The most recently rooted instance: used by the FuseJS "NativeNavigation" module.
		static readonly List<NativeNavigationView> _activeInstances = new List<NativeNavigationView>();
		internal static NativeNavigationView Active
		{
			get { return _activeInstances.Count > 0 ? _activeInstances[_activeInstances.Count - 1] : null; }
		}

		// Guards against a native callback triggering another navigation.
		bool _isUpdatingFromDelegate = false;
		INativeNavigationView _nativeImpl;

		// Set by a FuseJS `Pages` array.
		IArray _pages;
		int _curPageIndex = -1;

		NavigationState _navigationState = NavigationState.Stable;
		Visual _activePage;

		// The active page's stack index at the previous navigation, for the direction of page animations.
		int _previousActiveIndex = -1;

		double _pageProgress = 0.0;

		/**
			Internal to manage each view controller's rendering context.
		*/
		class ViewControllerContext
		{
			public string TemplateName { get; set; }
			public Visual TemplateInstance { get; set; }
			public ViewControllerRoot RenderingRoot { get; set; }

			// The Page object (from the Pages array) that provides this page's data context.
			public object PageObject { get; set; }

			public ViewControllerContext(string templateName, Visual templateInstance, NativeNavigationView navigation)
			{
				TemplateName = templateName;
				TemplateInstance = templateInstance;
				RenderingRoot = new ViewControllerRoot(navigation);
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

			/** Re-lays the page out at the size its presentation was given (see OnModalLaidOut). */
			public void SetContentSize(float2 pixelSize)
			{
				if (RenderingRoot != null)
					RenderingRoot.SetContentSize(pixelSize);
			}
		}

		/**
			Specifies the default template to use as the root view controller.
			If not specified, the first available template will be used.
		*/
		public string DefaultTemplate { get; set; }

		/**
			The navigation stack as a FuseJS observable array; the highest index is the active page. Each item
			must have a `$path` naming its template, and is used as that page's data context.

			```javascript
			exports.pages = Observable({ $path: "Home" });
			exports.pages.add({ $path: "Details" });
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
			get
			{
				// Native navigation is only implemented on mobile; other platforms use graphical rendering.
				return defined(!Android && !iOS)
					? VisualContext.Graphics
					: VisualContext.Native;
			}
		}

		public NativeNavigationView()
		{
		}

		protected override void OnRooted()
		{
			base.OnRooted();

			// On other platforms `CreateNativeView` returns a no-op stub, so navigation actions degrade
			// gracefully instead of dereferencing a null implementation.
			_nativeImpl = defined(iOS || Android)
				? (INativeNavigationView)NativeView
				: NativeNavigationViewFactory.CreateNativeImpl(this);

			if (_nativeImpl != null)
			{
				_nativeImpl.SetNavigationChangeCallback(OnNativeNavigationChanged);
				_nativeImpl.SetNavigationStartedCallback(OnNativeNavigationStarted);
				_nativeImpl.SetModalDismissedCallback(OnModalDismissed);
				_nativeImpl.SetModalLaidOutCallback(OnModalLaidOut);
			}

			AttachPages();

			// Show DefaultTemplate (or the first template) when there is no Pages array.
			if (_pages == null)
			{
				var initialTemplate = GetInitialTemplate();
				if (!string.IsNullOrEmpty(initialTemplate))
					NavigateToTemplate(initialTemplate, false);
			}
			else
			{
				UpdatePagesNavigation(true);
			}

			_activeInstances.Add(this);
			Fuse.Input.Keyboard.KeyPressed.AddGlobalHandler(OnKeyPressed);

			UpdateManager.AddDeferredAction(FirePageCountChanged);
		}

		protected override void OnUnrooted()
		{
			Fuse.Input.Keyboard.KeyPressed.RemoveGlobalHandler(OnKeyPressed);
			_activeInstances.Remove(this);
			DetachPages();

			// Dismiss what is still presented before releasing its content, or the platform would leave an
			// orphaned dialog/presented controller over a page that no longer exists.
			if (_nativeImpl != null)
				_nativeImpl.DismissAllModals();

			CleanupAllTemplateInstances();
			base.OnUnrooted();
		}

		void OnKeyPressed(object sender, Fuse.Input.KeyEventArgs args)
		{
			if (args.Key != Uno.Platform.Key.BackButton)
				return;

			// Only the most recently rooted view handles the back button.
			if (Active != this)
				return;

			if (_modalContexts.Count > 0)
			{
				DismissModal();
				args.IsHandled = true;
				return;
			}

			if (CanGoBack)
			{
				GoBack();
				args.IsHandled = true;
			}
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

			if (_nativeImpl == null)
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
			Present a template modally. Use DismissModal to close it.
		*/
		public void PresentTemplate(string templateName)
		{
			PresentTemplate(templateName, null, ModalPresentationStyle.FullScreen);
		}

		/**
			Present a template modally with a data context, which is bound to the presented content.
		*/
		public void PresentTemplate(string templateName, object context)
		{
			PresentTemplate(templateName, context, ModalPresentationStyle.FullScreen);
		}

		/**
			Present a template modally in the given style.

			`dragToDismiss` lets the user drag a sheet down to dismiss it (and shows a grabber for it), and
			`expandable` lets them drag it up to fill the screen. See `SetModalExpanded` to do that from code.
		*/
		public void PresentTemplate(string templateName, object context, ModalPresentationStyle style, bool dragToDismiss = true, bool expandable = true)
		{
			// Always create a fresh context for the presented page.
			var viewControllerContext = CreateViewControllerContext(templateName, context);
			if (viewControllerContext == null)
				return;

			UpdateManager.AddDeferredAction(() => PresentModal(viewControllerContext, style, dragToDismiss, expandable, 0));
		}

		/**
			Gives the top-most modal its expanded size (filling the screen), or the size of its own presentation
			style back (`false`), animating to either. Does nothing for a non-expandable modal.
		*/
		public void SetModalExpanded(bool expanded)
		{
			if (_nativeImpl == null || _modalContexts.Count == 0)
				return;

			_nativeImpl.SetModalExpanded(expanded);
		}

		/**
			Presents the modal once no pointer is pressed: showing a dialog window while one is down can leave
			Fuse with a pointer that is never released.
		*/
		void PresentModal(ViewControllerContext viewControllerContext, ModalPresentationStyle style, bool dragToDismiss, bool expandable, int attempt)
		{
			if (Fuse.Input.Pointer.IsPressed() && attempt < 30)
			{
				UpdateManager.AddDeferredAction(() => PresentModal(viewControllerContext, style, dragToDismiss, expandable, attempt + 1));
				return;
			}

			Fuse.Input.Pointer.ClearPointersDown();

			if (_nativeImpl != null)
			{
				// Recorded first: presenting lays the modal out, and the platform may report that before
				// PresentView returns (see OnModalLaidOut).
				_modalContexts.Add(viewControllerContext);

				// A modal keeps the app frame, which its insets are derived from; the presentation answers for
				// its size instead. Following its own view shifted the content on Android.
				viewControllerContext.RenderingRoot.SetFollowsOwnSize(false);

				_nativeImpl.PresentView(viewControllerContext.RenderingRoot.GetNativeHandle(), viewControllerContext.TemplateName, style, dragToDismiss, expandable);

				// A first guess, so the content is not drawn under the bar while the modal animates in.
				ApplyModalInsets(viewControllerContext);
			}
		}

		/**
			Dismiss the top-most modally presented template.
		*/
		public void DismissModal()
		{
			if (_modalContexts.Count == 0)
				return;

			var viewControllerContext = _modalContexts[_modalContexts.Count - 1];
			_modalContexts.RemoveAt(_modalContexts.Count - 1);

			if (_nativeImpl == null)
			{
				ReleaseModalContext(viewControllerContext);
				return;
			}

			// The dismissal animates: release the page when the platform reports it finished
			// (see OnModalDismissed), not here, or the animating content goes blank.
			_dismissingModalContext = viewControllerContext;
			_nativeImpl.DismissView();

			// Clear input state now (not on dismissal completion): a focused bar or a tracked pointer would
			// leave the page underneath needing an extra tap.
			Fuse.Input.Pointer.ClearPointersDown();
			Fuse.Input.Focus.Release();
		}

		/**
			Called by the platform with the size of the modal's content, in pixels. The page is laid out at
			it, which is what keeps a sheet's content inside the sheet.
		*/
		void OnModalLaidOut(float2 pixelSize)
		{
			if (pixelSize.X <= 0 || pixelSize.Y <= 0)
				return;

			// The modal on top is the one being reported on.
			if (_modalContexts.Count == 0)
				return;

			var viewControllerContext = _modalContexts[_modalContexts.Count - 1];
			viewControllerContext.SetContentSize(pixelSize);

			// A safety net for a platform that could not report the insets earlier; only harmless while the
			// value matches the one applied at presentation.
			ApplyModalInsets(viewControllerContext);
		}

		/** Applies the modal's safe-area insets to the presented page's template. */
		void ApplyModalInsets(ViewControllerContext viewControllerContext)
		{
			if (_nativeImpl == null)
				return;

			var insets = _nativeImpl.GetModalSafeAreaInsets();
			var element = viewControllerContext.TemplateInstance as Element;
			if (element != null)
				element.Padding = float4(insets.X, insets.Y, insets.Z, insets.W);
		}

		/**
			Called by the native implementation once a modal dismissal has finished animating.
		*/
		void OnModalDismissed()
		{
			var viewControllerContext = _dismissingModalContext;
			if (viewControllerContext == null)
				return;

			_dismissingModalContext = null;
			viewControllerContext.Dispose();
		}

		/**
			Called when the platform has already dismissed the modal (e.g. an iOS sheet dragged away), so there
			is nothing left to animate and the page is released immediately.
		*/
		internal void OnModalDismissedByPlatform()
		{
			if (_modalContexts.Count == 0)
				return;

			var viewControllerContext = _modalContexts[_modalContexts.Count - 1];
			_modalContexts.RemoveAt(_modalContexts.Count - 1);

			ReleaseModalContext(viewControllerContext);
		}

		void ReleaseModalContext(ViewControllerContext viewControllerContext)
		{
			viewControllerContext.Dispose();
			Fuse.Input.Pointer.ClearPointersDown();
			Fuse.Input.Focus.Release();
		}

		/**
			Called by the platform before a native transition runs. Moves the active page and reports the page
			progress, so `EnteringAnimation` / `ExitingAnimation` run with the transition; contexts are reconciled
			afterwards, when the navigation settles.
		*/
		void OnNativeNavigationStarted(string currentTemplateName, int nativeStackCount, bool appear)
		{
			if (!appear)
				return;

			SetNavigationState(NavigationState.Transition);

			// Resolve by position, as the same template may appear on the stack more than once.
			if (nativeStackCount < 1 || nativeStackCount > _viewControllerStack.Count)
				return;

			SetActivePage(_viewControllerStack[nativeStackCount - 1].TemplateInstance);
			NotifyPageProgressChanged();
		}

		internal void OnNativeNavigationChanged(string currentTemplateName, int nativeStackCount, bool appear)
		{
			_isUpdatingFromDelegate = true;

			try
			{
				// Update navigation state and fire events
				SetNavigationState(NavigationState.Stable);

				// Resolve by position rather than template name (see OnNativeNavigationStarted).
				if (appear)
				{
					if (nativeStackCount >= 1 && nativeStackCount <= _viewControllerStack.Count)
						SetActivePage(_viewControllerStack[nativeStackCount - 1].TemplateInstance);
					else
						SetActivePage(null);
				}

				// The active page has moved (e.g. a native back/pop), so let the page navigation animations run.
				NotifyPageProgressChanged();
			}
			finally
			{
				FirePageCountChanged();
				UpdateManager.AddDeferredAction(SynchronizeWithNativeStack);
			}
		}

		/** Aligns the context list with the native stack, the single source of truth. */
		void SynchronizeWithNativeStack()
		{
			try
			{
				var nativeStack = _nativeImpl.GetNativeStackTemplates();

				// Normally the list only shrinks (on pop); rebuild only if it cannot be trimmed into shape.
				if (!AlignViewControllerStack(nativeStack))
					RebuildViewControllerStack(nativeStack);

				SynchronizePageIndexWithNativeStack(nativeStack);
			}
			finally
			{
				// Always release the guard, or later programmatic navigation is ignored.
				_isUpdatingFromDelegate = false;
			}
		}

		/**
			Trims contexts that are no longer on the native stack, which normally only ever shrinks (a pop).
			Returns false when the list cannot be aligned by trimming alone.
		*/
		bool AlignViewControllerStack(string[] nativeStack)
		{
			while (_viewControllerStack.Count > nativeStack.Length)
			{
				var top = _viewControllerStack[_viewControllerStack.Count - 1];
				_viewControllerStack.RemoveAt(_viewControllerStack.Count - 1);
				top.Dispose();
			}

			if (_viewControllerStack.Count != nativeStack.Length)
				return false;

			for (int i = 0; i < nativeStack.Length; i++)
			{
				if (_viewControllerStack[i].TemplateName != nativeStack[i])
					return false;
			}

			return true;
		}

		/** Rebuilds the context list from the native stack names (bottom to top). */
		void RebuildViewControllerStack(string[] nativeStack)
		{
			foreach (var context in _viewControllerStack)
				context.Dispose();
			_viewControllerStack.Clear();

			for (int i = 0; i < nativeStack.Length; i++)
			{
				var context = CreateViewControllerContext(nativeStack[i], null);
				if (context != null)
					_viewControllerStack.Add(context);
			}
		}

		/** Keeps the page index, and a FuseJS `Pages` array, in step with a native-driven navigation. */
		void SynchronizePageIndexWithNativeStack(string[] nativeStack)
		{
			if (_pages == null || !_isUpdatingFromDelegate)
				return;

			_curPageIndex = Math.Max(-1, nativeStack.Length - 1);

			// A shorter native stack means pages were popped: truncate the Pages array to match.
			if (_pages.Length > nativeStack.Length)
				UpdateManager.AddDeferredAction(() => TruncatePages(nativeStack.Length));
		}

		/**
			Truncates the `Pages` array to `expectedLength`.

			`ISubscription.ReplaceAllExclusive` updates the array without notifying this subscription, so there is
			no re-entrancy; other subscribers (such as an `Each`) are still notified.
		*/
		void TruncatePages(int expectedLength)
		{
			if (_pages == null || expectedLength >= _pages.Length)
				return;

			var subscription = _subscription as Fuse.Reactive.ISubscription;
			if (subscription != null)
			{
				var synchronizedPages = new object[expectedLength];
				for (int i = 0; i < expectedLength && i < _pages.Length; i++)
					synchronizedPages[i] = _pages[i];

				subscription.ReplaceAllExclusive(new SynchronizedPagesArray(synchronizedPages));
			}

			_curPageIndex = Math.Max(-1, expectedLength - 1);
		}

		/**
			Simple IArray wrapper used to truncate the `Pages` array.
		*/
		class SynchronizedPagesArray : IArray
		{
			readonly object[] _pages;

			public SynchronizedPagesArray(object[] pages)
			{
				_pages = pages;
			}

			public int Length { get { return _pages.Length; } }

			public object this[int index]
			{
				get
				{
					if (index < 0 || index >= _pages.Length)
						throw new ArgumentOutOfRangeException("index");
					return _pages[index];
				}
			}
		}

		void CleanupAllTemplateInstances()
		{
			foreach (var context in _viewControllerStack)
				context.Dispose();
			_viewControllerStack.Clear();

			foreach (var context in _modalContexts)
				context.Dispose();
			_modalContexts.Clear();

			if (_dismissingModalContext != null)
			{
				_dismissingModalContext.Dispose();
				_dismissingModalContext = null;
			}
		}

		void NavigateToTemplate(string templateName, bool isPush, bool isPop = false)
		{
			// Always a fresh context: the stack may contain the same template more than once.
			var viewControllerContext = CreateViewControllerContext(templateName, null);
			if (viewControllerContext == null)
				return;

			SetActivePage(viewControllerContext.TemplateInstance);

			UpdateManager.AddDeferredAction(() => CompleteNavigation(viewControllerContext, isPush, isPop));
		}

		/**
			Creates a fresh context (template instance and isolated rendering root) for a template. Never
			reuses one, so the same template can be pushed more than once.
		*/
		ViewControllerContext CreateViewControllerContext(string templateName, object dataContext)
		{
			var tpl = FindTemplate(templateName);
			if (tpl == null)
			{
				Fuse.Diagnostics.UserError("Template '" + templateName + "' not found in NativeNavigationView", this);
				return null;
			}

			var instance = tpl.New() as Visual;
			if (instance == null)
			{
				Fuse.Diagnostics.UserError("Template '" + templateName + "' did not produce a Visual", this);
				return null;
			}

			instance.Name = templateName;
			SetDataContext(instance, dataContext);

			// Set before rooting, so triggers can find the navigation view.
			Fuse.Navigation.Navigation.SetNativeNavigation(instance, this);

			var context = new ViewControllerContext(templateName, instance, this);
			context.PageObject = dataContext;
			return context;
		}

		void CompleteNavigation(ViewControllerContext viewControllerContext, bool isPush, bool isPop)
		{
			SetNavigationState(NavigationState.Transition);
			SetActivePage(viewControllerContext.TemplateInstance);

			// Keep the context list aligned with the native stack before the controller changes, so delegate
			// callbacks always see a consistent stack. Pops are reconciled from the reported native stack.
			if (isPush)
			{
				_viewControllerStack.Add(viewControllerContext);
			}
			else if (!isPop)
			{
				// Initial/root navigation replaces the whole stack.
				foreach (var context in _viewControllerStack)
					context.Dispose();
				_viewControllerStack.Clear();
				_viewControllerStack.Add(viewControllerContext);
			}

			if (_nativeImpl != null)
			{
				var nativeHandle = viewControllerContext.RenderingRoot.GetNativeHandle();
				_nativeImpl.NavigateToView(nativeHandle, viewControllerContext.TemplateName, isPush, isPop);
			}

			// The stack is consistent now, so the page animations can run with the native transition.
			NotifyPageProgressChanged();
		}

		protected override Fuse.Controls.Native.IView CreateNativeView()
		{
			if defined(iOS)
			{
				return Fuse.Controls.iOS.NativeNavigationViewFactory.Create(this);
			}
			else if defined(Android)
			{
				return Fuse.Controls.Android.NativeNavigationViewFactory.Create(this);
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
		internal INativeNavigationView GetNativeImplementation()
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
			// Pages are tracked by position because the same template can appear more than once.
			if (index >= 0 && index < _viewControllerStack.Count)
			{
				return _viewControllerStack[index].TemplateInstance;
			}
			return null;
		}

		public Visual ActivePage
		{
			get { return _activePage; }
		}

		public NavigationPageState GetPageState(Visual page)
		{
			int activeIndex = IndexOfPage(_activePage);
			if (activeIndex < 0)
				activeIndex = _viewControllerStack.Count - 1;

			int pageIndex = IndexOfPage(page);
			if (pageIndex < 0)
			{
				// Not on the stack yet: the incoming page starts in front of the active one, which is what
				// `EnteringAnimation` expects (1 -> 0 as it becomes active).
				return new NavigationPageState { Progress = 1f, PreviousProgress = 1f };
			}

			// Fuse's convention: the active page is 0, pages beneath it are negative, and a page above it
			// (only while a popped page is being removed) counts as behind as well.
			float progress = pageIndex > activeIndex ? -1f : (float)(pageIndex - activeIndex);

			// The same expression against the previous active position is what gives animations direction.
			int previousActiveIndex = _previousActiveIndex >= 0 && _previousActiveIndex < _viewControllerStack.Count
				? _previousActiveIndex
				: activeIndex + 1;
			float previous = (float)(pageIndex - previousActiveIndex);

			return new NavigationPageState { Progress = progress, PreviousProgress = previous };
		}

		int IndexOfPage(Visual page)
		{
			if (page == null)
				return -1;

			for (int i = 0; i < _viewControllerStack.Count; i++)
			{
				if (_viewControllerStack[i].TemplateInstance == page)
					return i;
			}

			return -1;
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
				var previousIndex = IndexOfPage(_activePage);
				if (previousIndex >= 0)
					_previousActiveIndex = previousIndex;

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

			// Page progress is reported by the callers that change the stack, after it is consistent.
			_pageProgress = newActivePage != null ? 0.0 : 1.0;
			}
		}

		/** Reports the page navigation progress to the animation triggers (`EnteringAnimation` etc.). */
		void NotifyPageProgressChanged()
		{
			if (PageProgressChanged != null)
				PageProgressChanged(this, new NavigationArgs(_pageProgress, _pageProgress, NavigationMode.Switch));
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

			if (isInitial)
			{
				// The top page becomes the root (replaces the whole stack).
				NavigateToTemplateWithContext(templateName, pageObj, targetIndex, false, false, true);
			}
			else if (isPush)
			{
				NavigateToTemplateWithContext(templateName, pageObj, targetIndex, true, false, false);
			}
			else if (isPop)
			{
				NavigateToTemplateWithContext(templateName, pageObj, targetIndex, false, true, false);
			}
			else
			{
				// Same top index: the top page's content changed in place (e.g. a replace). This must not
				// be treated as an initial navigation, or the native stack would collapse to the top page.
				if (targetIndex >= 0 && targetIndex < _viewControllerStack.Count)
				{
					var context = _viewControllerStack[targetIndex];
					if (context != null && context.PageObject != pageObj)
					{
						context.PageObject = pageObj;
						SetDataContext(context.TemplateInstance, pageObj);
					}
				}
			}

			_curPageIndex = targetIndex;
		}

		string ExtractTemplatePath(object pageObj)
		{
			var obj = pageObj as IObject;
			if (obj != null)
			{
				if (obj.ContainsKey("$path"))
					return obj["$path"] as string;
				if (obj.ContainsKey("$__fuse_classname"))
					return obj["$__fuse_classname"] as string;
			}

			var dict = pageObj as IDictionary<string, object>;
			if (dict != null)
			{
				if (dict.ContainsKey("$path"))
					return dict["$path"] as string;
				if (dict.ContainsKey("$__fuse_classname"))
					return dict["$__fuse_classname"] as string;
			}

			return null;
		}

		void NavigateToTemplateWithContext(string templateName, object context, int targetIndex, bool isPush, bool isPop, bool isInitial)
		{
			ViewControllerContext viewControllerContext;

			if (isPop)
			{
				// Return to the context already on the stack rather than creating a duplicate.
				if (targetIndex >= 0 && targetIndex < _viewControllerStack.Count &&
					_viewControllerStack[targetIndex].TemplateName == templateName)
				{
					viewControllerContext = _viewControllerStack[targetIndex];
					viewControllerContext.PageObject = context;
					SetDataContext(viewControllerContext.TemplateInstance, context);
				}
				else
				{
					Fuse.Diagnostics.InternalError("Pop target '" + templateName + "' is not on the navigation stack", this);
					return;
				}
			}
			else
			{
				// Push (or initial/replace): always a fresh context.
				viewControllerContext = CreateViewControllerContext(templateName, context);
				if (viewControllerContext == null)
					return;
			}

			SetActivePage(viewControllerContext.TemplateInstance);

			if (isInitial)
			{
				// Initial navigation is not animated.
				CompleteNavigation(viewControllerContext, false, false);
			}
			else
			{
				// Defer, so the rendering context is established before navigating.
				UpdateManager.AddDeferredAction(() => CompleteNavigation(viewControllerContext, isPush, isPop));
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
					// The current page was removed: navigate to the new top page.
					UpdatePagesNavigation();
				}
				else
				{
					// A page below the current one was removed.
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
			UpdatePagesNavigation();
		}

		void Fuse.Reactive.IObserver.OnNewAt(int index, object value)
		{
			UpdatePagesNavigation();
		}

		void Fuse.Reactive.IObserver.OnNewAll(IArray values)
		{
			UpdatePagesNavigation(true);
		}

		void Fuse.Reactive.IObserver.OnClear()
		{
			CleanupAllTemplateInstances();
			SetActivePage(null);
			_curPageIndex = -1;
			FirePageCountChanged();

			var initialTemplate = GetInitialTemplate();
			if (!string.IsNullOrEmpty(initialTemplate))
				NavigateToTemplate(initialTemplate, false);
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

	}
}
