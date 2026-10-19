using Uno;
using Uno.Collections;
using Uno.Compiler.ExportTargetInterop;

using Fuse.Controls.Native;

namespace Fuse.Controls.iOS
{
	[ForeignInclude(Language.ObjC, "iOS/TabBarDelegate.h")]
	[ForeignInclude(Language.ObjC, "iOS/TabBarController.h")]
	extern(iOS) internal class NativeTabNavigationViewImpl : Fuse.Controls.Native.iOS.LeafView, INativeTabNavigationView
	{
		ObjC.Object _tabController;
		ObjC.Object _delegate;
		Action<int> _selectedCallback;
		Action<float4> _contentInsetsCallback;
		TabBarLabelVisibility _showLabels = TabBarLabelVisibility.Always;
		float4 _tintColor = float4(0.42f, 0.45f, 0.5f, 1);
		float4 _selectedTintColor = float4(0.0f, 0.48f, 1.0f, 1);
		readonly List<TabProps> _tabProps = new List<TabProps>();

		public NativeTabNavigationViewImpl() : base(CreateContainer())
		{
			_tabController = CreateTabController();
			_delegate = FuseTabBarDelegate.Create(OnTabSelected);
			SetDelegate(_tabController, _delegate);
			AddTabControllerToContainer(Handle, GetTabControllerView(_tabController));
			EnsureInViewControllerHierarchy(_tabController);

			SetOnLayout(_tabController, () => ReportContentInsets());
			ReportContentInsets();
		}

		public void SetSelectedCallback(Action<int> callback)
		{
			_selectedCallback = callback;
		}

		public void SetContentInsetsCallback(Action<float4> callback)
		{
			_contentInsetsCallback = callback;
		}

		public override void Dispose()
		{
			if (_delegate != null)
			{
				FuseTabBarDelegate.Destroy(_delegate);
				_delegate = null;
			}

			_tabController = null;
			_selectedCallback = null;
			_contentInsetsCallback = null;
			base.Dispose();
		}

		public void AddTab(object nativeHandle, string templateName, TabProps props)
		{
			if (_tabController == null)
				return;

			// A lazy tab is added without its page; SetTabContent attaches it on first show.
			var view = nativeHandle as ObjC.Object;
			var viewController = CreateViewController(templateName);
			if (view != null)
				AttachContentView(viewController, view);

			AppendViewController(_tabController, viewController, templateName, (int)props.Placement);
			_tabProps.Add(props);
			ApplyTabProps(_tabProps.Count - 1);
			ApplyTabTitles();
			EnsureInViewControllerHierarchy(_tabController);
		}

		public void SetTabProps(int index, TabProps props)
		{
			if (_tabController == null)
				return;

			if (index < 0 || index >= _tabProps.Count)
				return;

			_tabProps[index] = props;
			ApplyTabProps(index);
		}

		public void SetTabContent(int index, object nativeHandle)
		{
			var view = nativeHandle as ObjC.Object;
			if (view == null || _tabController == null)
				return;

			var viewController = GetViewControllerAt(_tabController, index);
			if (viewController != null)
				AttachContentView(viewController, view);
		}

		public void RemoveTab(int index)
		{
			if (_tabController == null)
				return;

			RemoveViewController(_tabController, index);
			if (index >= 0 && index < _tabProps.Count)
				_tabProps.RemoveAt(index);
			ApplyTabTitles();
		}

		public void SelectTab(int index)
		{
			if (_tabController == null)
				return;

			SetSelectedIndex(_tabController, index);
			ApplyTabTitles();
		}

		public void ConfigureTabBar(TabBarProps props)
		{
			if (_tabController == null)
				return;

			_tintColor = props.TintColor;
			_selectedTintColor = props.SelectedTintColor;

			SetTabBarAppearance(_tabController,
				(int)Uno.Color.ToArgb(props.BackgroundColor),
				(int)Uno.Color.ToArgb(props.TintColor),
				(int)Uno.Color.ToArgb(props.SelectedTintColor),
				props.Translucent);

			for (int i = 0; i < _tabProps.Count; i++)
				ApplyTabProps(i);

			SetBarHidden(_tabController, props.Hidden);

			_showLabels = props.ShowLabels;
			ApplyTabTitles();
		}

		/** Applies a stored tab's item, with the current bar colours as its fallbacks. */
		void ApplyTabProps(int index)
		{
			if (index < 0 || index >= _tabProps.Count)
				return;

			var viewController = GetViewControllerAt(_tabController, index);
			if (viewController == null)
				return;

			var props = _tabProps[index];

			// Placement first: switching between a search tab and a normal tab replaces the platform
			// tab object, and SetTabBarItem then mirrors the props onto the new one.
			SetTabPlacement(_tabController, index, (int)props.Placement);
			SetTabBarItem(viewController, props.Title ?? "", props.Symbols, props.AccessibilityLabel,
				props.Badge, (int)Uno.Color.ToArgb(props.BadgeColor),
				(int)Uno.Color.ToArgb(props.BadgeTextColor), props.Enabled,
				props.HasColor, (int)Uno.Color.ToArgb(props.Color),
				props.HasSelectedColor, (int)Uno.Color.ToArgb(props.SelectedColor),
				(int)Uno.Color.ToArgb(_tintColor), (int)Uno.Color.ToArgb(_selectedTintColor));
		}

		void ApplyTabTitles()
		{
			if (_tabController != null)
				SetBarTitles(_tabController, (int)_showLabels);
		}

		/** Called on layout: reports the status-bar / safe-area insets, in points. */
		void NotifyContentInsets(float left, float top, float right, float bottom)
		{
			if (_contentInsetsCallback != null)
				_contentInsetsCallback(float4(left, top, right, bottom));
		}

		void ReportContentInsets()
		{
			if (_tabController != null)
				ReportContentInsetsImpl(_tabController);
		}

		void OnTabSelected(int index)
		{
			if (_selectedCallback != null)
				_selectedCallback(index);
		}

		// -------- Native helpers --------

		[Foreign(Language.ObjC)]
		static ObjC.Object CreateContainer()
		@{
			UIView* containerView = [[UIView alloc] init];
			containerView.backgroundColor = [UIColor whiteColor];
			containerView.frame = [[UIScreen mainScreen] bounds];
			return containerView;
		@}

		/**
			Reports the safe-area insets; the bottom is omitted because the tab bar owns that area.
		*/
		[Foreign(Language.ObjC)]
		void ReportContentInsetsImpl(ObjC.Object controller)
		@{
			UIViewController* c = (UIViewController*)controller;
			if (c == nil || c.view.window == nil)
				return;

			UIEdgeInsets insets = c.view.safeAreaInsets;
			@{global::Fuse.Controls.iOS.NativeTabNavigationViewImpl:of(_this).NotifyContentInsets(float,float,float,float):call(insets.left, insets.top, insets.right, 0.0f)};
		@}

		[Foreign(Language.ObjC)]
		static void SetOnLayout(ObjC.Object controller, Action onLayout)
		@{
			((FuseNativeTabBarController*)controller).onLayout = onLayout;
		@}

		[Foreign(Language.ObjC)]
		static ObjC.Object CreateTabController()
		@{
			FuseNativeTabBarController* controller = [[FuseNativeTabBarController alloc] init];
			controller.tabBar.translucent = NO;
			return controller;
		@}

		[Foreign(Language.ObjC)]
		static ObjC.Object GetTabControllerView(ObjC.Object controller)
		@{
			return ((UITabBarController*)controller).view;
		@}

		[Foreign(Language.ObjC)]
		static void AddTabControllerToContainer(ObjC.Object container, ObjC.Object controllerView)
		@{
			UIView* containerView = (UIView*)container;
			UIView* view = (UIView*)controllerView;

			[containerView addSubview:view];

			// Pin to the host with Auto Layout so the tab bar is laid out correctly; the host's initial
			// frame keeps it satisfiable before Fuse measures it.
			view.translatesAutoresizingMaskIntoConstraints = NO;
			[NSLayoutConstraint activateConstraints:@[
				[view.topAnchor constraintEqualToAnchor:containerView.topAnchor],
				[view.leadingAnchor constraintEqualToAnchor:containerView.leadingAnchor],
				[view.trailingAnchor constraintEqualToAnchor:containerView.trailingAnchor],
				[view.bottomAnchor constraintEqualToAnchor:containerView.bottomAnchor]
			]];
		@}

		[Foreign(Language.ObjC)]
		static void SetDelegate(ObjC.Object controller, ObjC.Object tabBarDelegate)
		@{
			((UITabBarController*)controller).delegate = (FuseNativeTabBarDelegate*)tabBarDelegate;
		@}

		[Foreign(Language.ObjC)]
		static ObjC.Object CreateViewController(string templateName)
		@{
			UIViewController* viewController = [[UIViewController alloc] init];
			viewController.title = templateName;
			viewController.extendedLayoutIncludesOpaqueBars = YES;

			UIView* containerView = [[UIView alloc] init];
			containerView.backgroundColor = [UIColor whiteColor];
			containerView.accessibilityIdentifier = templateName;
			viewController.view = containerView;
			return viewController;
		@}

		[Foreign(Language.ObjC)]
		static void AttachContentView(ObjC.Object viewController, ObjC.Object nativeView)
		@{
			UIView* fuseView = (UIView*)nativeView;
			UIView* containerView = ((UIViewController*)viewController).view;
			if (fuseView == nil || containerView == nil)
				return;

			// Use frame/autoresizing, not Auto Layout: Fuse anchors native views top-left and manages
			// frames directly, so AL would offset by half the size.
			[containerView addSubview:fuseView];
			fuseView.frame = containerView.bounds;
			fuseView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		@}

		[Foreign(Language.ObjC)]
		static void AppendViewController(ObjC.Object controller, ObjC.Object viewController,
			string templateName, int placement)
		@{
			UITabBarController* tabController = (UITabBarController*)controller;
			UIViewController* vc = (UIViewController*)viewController;
			if (tabController == nil || vc == nil)
				return;

			if (@available(iOS 18.0, *))
			{
				// Once `tabs` is set UIKit ignores `viewControllers`, so every mutation goes through
				// this array. A tab wraps the view controller we already created, keeping it stable.
				UITab* tab = nil;
				if (placement == 7) // Fuse.Controls.TabPlacement.Search
				{
					// A search tab: iOS 26+ renders it as the separate trailing search button.
					UISearchTab* searchTab = [[UISearchTab alloc] initWithViewControllerProvider:^UIViewController*(__kindof UITab* t) {
						return vc;
					}];
					searchTab.title = vc.title;
					searchTab.image = vc.tabBarItem.image;
					if (@available(iOS 26.0, *))
						searchTab.automaticallyActivatesSearch = YES;
					tab = searchTab;
				}

				if (tab == nil)
				{
					NSString* identifier = templateName != nil && templateName.length > 0
						? templateName
						: [NSString stringWithFormat:@"fuse.tab.%lu",
							(unsigned long)tabController.tabs.count];

					tab = [[UITab alloc] initWithTitle:vc.title
												 image:vc.tabBarItem.image
										  identifier:identifier
							  viewControllerProvider:^UIViewController*(__kindof UITab* t) {
								  return vc;
							  }];
					// `Search` has no UIKit placement; the fallback tab is a normal one.
					if (placement >= 0 && placement <= 6)
						tab.preferredPlacement = (UITabPlacement)placement;
				}

				NSMutableArray<UITab*>* tabs = tabController.tabs != nil
					? [tabController.tabs mutableCopy]
					: [NSMutableArray array];
				[tabs addObject:tab];
				tabController.tabs = tabs;
				return;
			}

			NSMutableArray* controllers = tabController.viewControllers != nil
				? [tabController.viewControllers mutableCopy]
				: [NSMutableArray array];
			[controllers addObject:vc];
			tabController.viewControllers = controllers;
		@}

		/** Sets the tab's preferred placement (iOS 18+); ignored on older systems. */
		[Foreign(Language.ObjC)]
		static void SetTabPlacement(ObjC.Object controller, int index, int placement)
		@{
			if (@available(iOS 18.0, *))
			{
				UITabBarController* tabController = (UITabBarController*)controller;
				NSArray<UITab*>* tabs = tabController != nil ? tabController.tabs : nil;
				if (tabs == nil || index < 0 || index >= (int)tabs.count)
					return;

				UITab* current = tabs[index];
				BOOL isSearch = [current isKindOfClass:[UISearchTab class]];
				BOOL wantSearch = placement == 7; // Fuse.Controls.TabPlacement.Search
				if (isSearch == wantSearch)
				{
					if (!wantSearch)
						current.preferredPlacement = (UITabPlacement)placement;
					return;
				}

				// Switching between a search tab and a normal tab requires a new tab object.
				UIViewController* vc = current.viewController;
				if (vc == nil)
					return;

				UITab* replacement = nil;
				if (wantSearch)
				{
					UISearchTab* searchTab = [[UISearchTab alloc] initWithViewControllerProvider:^UIViewController*(__kindof UITab* t) {
						return vc;
					}];
					searchTab.title = vc.title;
					searchTab.image = vc.tabBarItem.image;
					if (@available(iOS 26.0, *))
						searchTab.automaticallyActivatesSearch = YES;
					replacement = searchTab;
				}
				else
				{
					replacement = [[UITab alloc] initWithTitle:vc.title
													 image:vc.tabBarItem.image
											  identifier:[NSString stringWithFormat:@"fuse.tab.%lu", (unsigned long)index]
									  viewControllerProvider:^UIViewController*(__kindof UITab* t) {
										  return vc;
									  }];
					replacement.preferredPlacement = (UITabPlacement)placement;
				}

				replacement.badgeValue = current.badgeValue;

				NSMutableArray<UITab*>* updated = [tabs mutableCopy];
				updated[index] = replacement;
				tabController.tabs = updated;
			}
		@}

		[Foreign(Language.ObjC)]
		static void RemoveViewController(ObjC.Object controller, int index)
		@{
			UITabBarController* tabController = (UITabBarController*)controller;
			if (tabController == nil)
				return;

			if (@available(iOS 18.0, *))
			{
				NSArray<UITab*>* tabs = tabController.tabs;
				if (tabs != nil && index >= 0 && index < (int)tabs.count)
				{
					NSMutableArray<UITab*>* updated = [tabs mutableCopy];
					[updated removeObjectAtIndex:index];
					tabController.tabs = updated;
					return;
				}
			}

			if (index < 0 || index >= (int)tabController.viewControllers.count)
				return;

			NSMutableArray* controllers = [tabController.viewControllers mutableCopy];
			[controllers removeObjectAtIndex:index];
			tabController.viewControllers = controllers;
		@}

		[Foreign(Language.ObjC)]
		static ObjC.Object GetViewControllerAt(ObjC.Object controller, int index)
		@{
			UITabBarController* tabController = (UITabBarController*)controller;
			if (tabController == nil)
				return nil;

			if (@available(iOS 18.0, *))
			{
				NSArray<UITab*>* tabs = tabController.tabs;
				if (tabs != nil)
				{
					if (index < 0 || index >= (int)tabs.count)
						return nil;
					return tabs[index].viewController;
				}
			}

			if (index < 0 || index >= (int)tabController.viewControllers.count)
				return nil;
			return tabController.viewControllers[index];
		@}

		[Foreign(Language.ObjC)]
		static void SetTabBarItem(ObjC.Object viewController, string title, string symbol, string accessibilityLabel,
			string badge, int badgeColorArgb, int badgeTextColorArgb, bool enabled,
			bool hasColor, int colorArgb, bool hasSelectedColor, int selectedColorArgb,
			int tintArgb, int selectedTintArgb)
		@{
			UIViewController* vc = (UIViewController*)viewController;
			if (vc == nil)
				return;

			// The visible title is applied by SetBarTitles (see ShowLabels); the accessibility name is
			// kept separately so an icon-only tab still has one.
			vc.title = title != nil && title.length > 0 ? title : nil;
			NSString* label = accessibilityLabel != nil && accessibilityLabel.length > 0
				? accessibilityLabel : title;
			vc.tabBarItem.accessibilityLabel = label != nil && label.length > 0 ? label : nil;

			UIImage* image = nil;
			if (symbol != nil && symbol.length > 0)
			{
				if (@available(iOS 13.0, *))
					image = [UIImage systemImageNamed:symbol];
			}
			if (image != nil)
				image = [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];

			UIColor* (^colorOf)(int) = ^UIColor*(int argb) {
				return [UIColor colorWithRed:((argb >> 16) & 0xFF) / 255.0
					green:((argb >> 8) & 0xFF) / 255.0
					 blue:(argb & 0xFF) / 255.0
					alpha:((argb >> 24) & 0xFF) / 255.0];
			};

			// Per-item title colours, falling back to the bar's tints. These are honoured by the legacy
			// `viewControllers` bar; the iOS 18+ `UITab` API ignores per-item title colours, so there the
			// title follows the bar appearance.
			UIColor* normalColor = hasColor ? colorOf(colorArgb) : colorOf(tintArgb);
			UIColor* selectedColor = hasSelectedColor ? colorOf(selectedColorArgb) : colorOf(selectedTintArgb);
			[vc.tabBarItem setTitleTextAttributes:@{ NSForegroundColorAttributeName: normalColor }
				forState:UIControlStateNormal];
			[vc.tabBarItem setTitleTextAttributes:@{ NSForegroundColorAttributeName: selectedColor }
				forState:UIControlStateSelected];

			// A tab with its own icon colours gets pre-tinted images; the rest stay template images and the
			// appearance tints them with the bar's colours.
			vc.tabBarItem.image = image;
			vc.tabBarItem.selectedImage = nil;

			if (image != nil && (hasColor || hasSelectedColor))
			{
				if (@available(iOS 13.0, *))
				{
					vc.tabBarItem.image = [image imageWithTintColor:normalColor
						renderingMode:UIImageRenderingModeAlwaysOriginal];
					vc.tabBarItem.selectedImage = [image imageWithTintColor:selectedColor
						renderingMode:UIImageRenderingModeAlwaysOriginal];
				}
			}

			vc.tabBarItem.enabled = enabled;

			// Null hides the badge; an empty string is a dot (UIKit has no dot badge, so a space gives the
			// smallest one it draws).
			if (badge == nil)
				vc.tabBarItem.badgeValue = nil;
			else
				vc.tabBarItem.badgeValue = badge.length == 0 ? @" " : badge;

			if (@available(iOS 10.0, *))
			{
				vc.tabBarItem.badgeColor = [UIColor colorWithRed:((badgeColorArgb >> 16) & 0xFF) / 255.0
					green:((badgeColorArgb >> 8) & 0xFF) / 255.0
					 blue:(badgeColorArgb & 0xFF) / 255.0
					alpha:((badgeColorArgb >> 24) & 0xFF) / 255.0];

				UIColor* badgeText = [UIColor colorWithRed:((badgeTextColorArgb >> 16) & 0xFF) / 255.0
					green:((badgeTextColorArgb >> 8) & 0xFF) / 255.0
					 blue:(badgeTextColorArgb & 0xFF) / 255.0
					alpha:((badgeTextColorArgb >> 24) & 0xFF) / 255.0];
				[vc.tabBarItem setBadgeTextAttributes:@{ NSForegroundColorAttributeName: badgeText }
					forState:UIControlStateNormal];
			}

			// iOS 18+ renders from the tab (`UITab`), not the tab bar item, so mirror the title,
			// image and badge there as well.
			if (@available(iOS 18.0, *))
			{
				UITab* tab = vc.tab;
				if (tab != nil)
				{
					tab.title = vc.title;
					tab.image = vc.tabBarItem.image;
					tab.badgeValue = vc.tabBarItem.badgeValue;
					if (@available(iOS 18.4, *))
						tab.enabled = enabled;
				}
			}
		@}

		[Foreign(Language.ObjC)]
		static void SetBarHidden(ObjC.Object controller, bool hidden)
		@{
			((UITabBarController*)controller).tabBar.hidden = hidden;
		@}

		[Foreign(Language.ObjC)]
		static void SetBarTitles(ObjC.Object controller, int mode)
		@{
			UITabBarController* tabController = (UITabBarController*)controller;
			if (tabController == nil)
				return;

			if (@available(iOS 18.0, *))
			{
				NSArray<UITab*>* tabs = tabController.tabs;
				if (tabs != nil)
				{
					for (NSUInteger i = 0; i < tabs.count; i++)
					{
						UIViewController* vc = tabs[i].viewController;
						BOOL show = mode == 0 || (mode == 1 && i == (NSUInteger)tabController.selectedIndex);
						NSString* title = show ? vc.title : nil;
						tabs[i].title = title;
						vc.tabBarItem.title = title;
					}
					return;
				}
			}

			NSArray<UIViewController*>* controllers = tabController.viewControllers;
			for (NSUInteger i = 0; i < controllers.count; i++)
			{
				UIViewController* vc = controllers[i];
				BOOL show = mode == 0 || (mode == 1 && i == tabController.selectedIndex);
				vc.tabBarItem.title = show ? vc.title : nil;
			}
		@}

		[Foreign(Language.ObjC)]
		static void SetSelectedIndex(ObjC.Object controller, int index)
		@{
			UITabBarController* tabController = (UITabBarController*)controller;
			if (tabController == nil)
				return;

			if (@available(iOS 18.0, *))
			{
				NSArray<UITab*>* tabs = tabController.tabs;
				if (tabs != nil)
				{
					if (index >= 0 && index < (int)tabs.count)
						tabController.selectedTab = tabs[index];
					return;
				}
			}

			if (index >= 0 && index < (int)tabController.viewControllers.count)
				tabController.selectedIndex = index;
		@}

		[Foreign(Language.ObjC)]
		static void SetTabBarAppearance(ObjC.Object controller, int backgroundArgb, int tintArgb,
			int selectedTintArgb, bool translucent)
		@{
			UITabBar* bar = ((UITabBarController*)controller).tabBar;

			UIColor* (^colorOf)(int) = ^UIColor*(int argb) {
				return [UIColor colorWithRed:((argb >> 16) & 0xFF) / 255.0
					green:((argb >> 8) & 0xFF) / 255.0
					 blue:(argb & 0xFF) / 255.0
					alpha:((argb >> 24) & 0xFF) / 255.0];
			};

			UIColor* background = colorOf(backgroundArgb);
			UIColor* normal = colorOf(tintArgb);
			UIColor* selected = colorOf(selectedTintArgb);

			if (@available(iOS 13.0, *))
			{
				UITabBarAppearance* appearance = [[UITabBarAppearance alloc] init];
				if (translucent)
					[appearance configureWithDefaultBackground];
				else
					[appearance configureWithOpaqueBackground];
				appearance.backgroundColor = background;

				void (^applyItems)(UITabBarItemAppearance*) = ^(UITabBarItemAppearance* items) {
					items.normal.iconColor = normal;
					items.selected.iconColor = selected;
				};
				applyItems(appearance.stackedLayoutAppearance);
				applyItems(appearance.inlineLayoutAppearance);
				applyItems(appearance.compactInlineLayoutAppearance);

				bar.standardAppearance = appearance;

				// iOS 15 uses the scroll-edge appearance while content is at its edge; without it the bar
				// would be transparent there, hiding the configured background.
				if (@available(iOS 15.0, *))
					bar.scrollEdgeAppearance = appearance;
			}
			else
			{
				bar.barTintColor = background;
				bar.tintColor = selected;
				bar.unselectedItemTintColor = normal;
				bar.translucent = translucent;
			}
		@}

		/**
			Makes the tab controller a child of the nearest ancestor controller. A detached controller
			cannot present or size its bar properly.
		*/
		[Foreign(Language.ObjC)]
		static void EnsureInViewControllerHierarchy(ObjC.Object controller)
		@{
			UITabBarController* tabController = (UITabBarController*)controller;
			if (tabController == nil || tabController.parentViewController != nil)
				return;

			UIResponder* responder = tabController.view.superview;
			while (responder != nil && ![responder isKindOfClass:[UIViewController class]])
				responder = responder.nextResponder;
			UIViewController* parent = (UIViewController*)responder;
			if (parent == nil)
				parent = tabController.view.window.rootViewController;

			if (parent != nil && parent != tabController)
			{
				[parent addChildViewController:tabController];
				[tabController didMoveToParentViewController:parent];
				return;
			}

			// Not in the hierarchy yet (first rooting pass): retry once the view is in the window.
			dispatch_async(dispatch_get_main_queue(), ^{
				UITabBarController* retry = (UITabBarController*)controller;
				if (retry == nil || retry.parentViewController != nil)
					return;

				UIResponder* r = retry.view.superview;
				while (r != nil && ![r isKindOfClass:[UIViewController class]])
					r = r.nextResponder;
				UIViewController* p = (UIViewController*)r;
				if (p == nil)
					p = retry.view.window.rootViewController;
				if (p != nil && p != retry)
				{
					[p addChildViewController:retry];
					[retry didMoveToParentViewController:p];
				}
			});
		@}
	}

	extern(iOS) internal static class FuseTabBarDelegate
	{
		[Foreign(Language.ObjC)]
		internal static ObjC.Object Create(Action<int> onSelected)
		@{
			return [[FuseNativeTabBarDelegate alloc] initWithCallback:onSelected];
		@}

		[Foreign(Language.ObjC)]
		internal static void Destroy(ObjC.Object handle)
		@{
			((FuseNativeTabBarDelegate*)handle).onSelected = nil;
		@}
	}

	extern(iOS) internal static class NativeTabNavigationViewFactory
	{
		internal static Fuse.Controls.Native.IView Create()
		{
			return new NativeTabNavigationViewImpl();
		}
	}
}
