using Uno;
using Uno.Compiler.ExportTargetInterop;
using Fuse.Platform;
using Uno.Platform.iOS;

namespace Fuse.Platform
{
	public enum StatusBarStyle
	{
		Dark,
		Light
	}

	public enum StatusBarAnimation
	{
		// UIStatusBarAnimationNone:
		// UIStatusBarAnimationFade:
		// UIStatusBarAnimationSlide:
		None,
		Fade,
		Slide
	}

	[Require("source.include", "CoreGraphics/CoreGraphics.h")]
	[Require("source.include", "UIKit/UIKit.h")]
	[Require("source.include", "@{Uno.Platform.iOSDisplay:include}")]
	[Require("source.include", "@{Uno.Platform.iOS.Application:include}")]
	[Require("source.include", "Uno-iOS/AppDelegate.h")]
	[Require("source.include", "objc/message.h")]
	[Require("source.include", "NotificationCenterContext.h")]
	static extern(iOS) class SystemUI
	{
		static Rect _bottomFrame;

		static public Rect Frame { get; private set; }

		static public float4 DeviceMargins
		{
			get
			{
				return GetSafeFrame();
			}
		}
		static public float4 SafeMargins
		{
			get
			{
				float4 sf = GetSafeFrame();
				sf.Y = Math.Max(sf.Y, GetStatusBarFrame().Height);
				sf.W = Math.Max(sf.W, _bottomFrame.Height);
				return sf;
			}
		}
		static public float4 StaticMargins
		{
			get
			{
				float4 sm = GetSafeFrame();
				sm.Y = Math.Max(sm.Y, GetStatusBarFrame().Height);
				return sm;
			}
		}

		static public event Action MarginsChanged;
		static public event Action<ScreenOrientation> DeviceOrientationChanged;
		static public event Action<float> TextScaleFactorChanged;

		static float _textScaleFactor = 1.0f;
		static public float TextScaleFactor
		{
			get { return _textScaleFactor; }
			private set
			{
				if (_textScaleFactor != value)
				{
					_textScaleFactor = value;
					if (TextScaleFactorChanged != null)
						TextScaleFactorChanged(value);
				}
			}
		}

		// @property (nonatomic, setter=uSetStatusBarAnimation:) UIStatusBarAnimation uStatusBarAnimation;
		public static StatusBarAnimation uStatusBarAnimation { get; set; }

		static public event EventHandler FrameChanged;
		static private void OnFrameChanged(object s, object a)
		{
			var iDisplay = ((Uno.Platform.iOSDisplay)Uno.Platform.Displays.MainDisplay);
			Frame = iDisplay.Frame;

			var handler = FrameChanged;
			if (handler != null)
				handler(null, EventArgs.Empty);
		}

		//------------------------------------------------------------

		static public void OnCreate()
		{
			((Uno.Platform.iOSDisplay)Uno.Platform.Displays.MainDisplay).FrameChanged += OnFrameChanged;
			Uno.Platform.CoreApp.EnteringForeground += OnEnteringForeground;
			OnFrameChanged(null, null);
			SetupNotificationCenterObservers(_notificationContext);
		}

		static public void OnDestroy()
		{
			RemoveNotificationCenterObservers(_notificationContext);
			Uno.Platform.CoreApp.EnteringForeground -= OnEnteringForeground;
		}

		static void OnEnteringForeground(Uno.Platform.ApplicationState newState)
		{
			ReadConfiguration(_notificationContext);
		}

		[Foreign(Language.ObjC)]
		static void ReadConfiguration(ObjC.Object notificationContext)
		@{
			uNotificationCenterContext* ctx = (uNotificationCenterContext*)notificationContext;
			CGFloat textScaleFactor = [ctx textScaleFactor];
			@{uTextScaleFactorDidChange(float):call(textScaleFactor)};
		@}

		static ObjC.Object _notificationContext = NewNotificationCenterContext();

		[Foreign(Language.ObjC)]
		static ObjC.Object NewNotificationCenterContext()
		@{
			return [[uNotificationCenterContext alloc] init];
		@}

		[Foreign(Language.ObjC)]
		static void SetupNotificationCenterObservers(ObjC.Object notificationContext)
		@{
			uNotificationCenterContext* ctx = (uNotificationCenterContext*)notificationContext;
			NSNotificationCenter* center = [NSNotificationCenter defaultCenter];

			[center
				addObserver:ctx selector:@selector(uKeyboardWillChangeFrame:)
				name:UIKeyboardWillShowNotification object:nil];

			[center
				addObserver:ctx
				selector:@selector(uKeyboardWillChangeFrame:)
				name:UIKeyboardWillHideNotification object:nil];

			[center
				addObserver:ctx
				selector:@selector(onUserSettingsChanged:)
				name:UIContentSizeCategoryDidChangeNotification object:nil];
		@}


		[Foreign(Language.ObjC)]
		static void RemoveNotificationCenterObservers(ObjC.Object notificationContext)
		@{
			uNotificationCenterContext* ctx = (uNotificationCenterContext*)notificationContext;

			[[NSNotificationCenter defaultCenter]
				removeObserver:ctx
				name:UIKeyboardWillShowNotification object:nil];

			[[NSNotificationCenter defaultCenter]
				removeObserver:ctx
				name:UIKeyboardWillHideNotification object:nil];
		@}

		//------------------------------------------------------------
		static bool _isTopFrameVisible = true;
		public static bool IsTopFrameVisible
		{
			get { return _isTopFrameVisible; }
			set
			{
				if (value == _isTopFrameVisible)
					return;

				_isTopFrameVisible = value;

				var endFrame = uCGRect.Zero;
				double animationDuration = 0.5;

				if (!value)
				{
					var screenSize = Pre_iOS8_HandleDeviceOrientation_Size(extern<uCGSize>"[UIScreen mainScreen].bounds.size", null);

					// Assume standard status bar, here.
					// application:willChangeStatusBarFrame: will handle deviations.

					endFrame = extern<uCGRect>(screenSize)"CGRectMake(0., 0., $0.width, 20.)";
					animationDuration = 0.25;
				}

				if (uStatusBarAnimation == extern<int>"(int)UIStatusBarAnimationNone")
					animationDuration = 0;

				_statusBarWillChangeFrame(endFrame, animationDuration);
				// `UIApplication.statusBarHidden` is deprecated. The app delegate is the root view
				// controller and returns this state from `prefersStatusBarHidden` (see
				// AppDelegateStatusBar.mm), so the appearance update below applies it.

				extern(animationDuration)"[UIView animateWithDuration:$0 animations:^{ [(::uAppDelegate*)[UIApplication sharedApplication].delegate setNeedsStatusBarAppearanceUpdate]; }]";
			}
		}

		public static extern uCGSize Pre_iOS8_HandleDeviceOrientation_Size(uCGSize cgsize, ObjC.Object view)
		@{
			if (NSFoundationVersionNumber <= NSFoundationVersionNumber_iOS_7_1
				&& @{Uno.Platform.iOS.Application.IsLandscape():call()}
				&& (!$1 || @{Uno.Platform.iOS.Application.IsRootView(ObjC.Object):call($1)}))
			{
				// Transpose dimensions
				return CGSizeMake($0.height, $0.width);
			}

			return $0;
		@}

		static public int3 OSVersion
		{
			get
			{
				int m,n,r;
				GetOSVersion(out m, out n, out r);
				return int3(m,n,r);
			}
		}

		[Foreign(Language.ObjC)]
		static void GetOSVersion( out int major, out int minor, out int revision )
		@{
			if (NSFoundationVersionNumber < NSFoundationVersionNumber_iOS_8_0)
			{
				//we don't really need specifics before this point
				*major = (int)NSFoundationVersionNumber;
				*minor = ((int)NSFoundationVersionNumber * 10) % 10;
				*revision = 0;
			}
			else
			{
				NSOperatingSystemVersion ver = [[NSProcessInfo processInfo] operatingSystemVersion];
				*major = (int)ver.majorVersion;
				*minor = (int)ver.minorVersion;
				*revision = (int)ver.patchVersion;
			}
		@}

		static public bool IsBottomFrameVisible
		{
			//{TODO} need better metric than this
			get { return (_bottomFrame.Top - _bottomFrame.Bottom) > 0; }
		}

		public static ObjC.Object RootView
		{
			get { return Uno.Platform.iOS.Application.GetRootView(); }
			set { Uno.Platform.iOS.Application.SetRootView(value); }
		}

		static void OnWillResize()
		{
			if (MarginsChanged != null)
				MarginsChanged();
		}

		static Rect GetStatusBarFrame()
		{
			// [UIApplication sharedApplication].statusBarFrame is deprecated and a
			// no-op on iOS 27; on modern devices the status bar height equals the
			// top safe-area inset. The margins derive that from the safe frame.
			return new Uno.Rect(0, 0, 0, GetSafeFrame().Y);
		}

		static float4 GetSafeFrame()
		{
			int major, minor, revision;
			GetOSVersion(out major, out minor, out revision);
			if (major >= 11)
			{
				float l, t, r, b;
				GetSafeArea( out l, out t, out r, out b );
				return float4(l,t,r,b);
			}

			return float4(0);
		}

		//TODO: https://github.com/fuse-open/fuselibs/issues/1015
		//we also need to listen for safeAreInsets changes and call MarginsChanged
		[Foreign(Language.ObjC)]
		static void GetSafeArea(out float l, out float t, out float r, out float b)
		@{
			UIWindow* window = nil;

			if (@available(iOS 13.0, *))
			{
				// `UIApplication.keyWindow` is deprecated; use the window scenes' windows. Prefer the
				// key window of the foreground-active scene, then any connected scene (early launch).
				UIWindow* (^windowOfScene)(UIWindowScene*) = ^UIWindow*(UIWindowScene* windowScene) {
					for (UIWindow* candidate in windowScene.windows)
					{
						if (candidate.isKeyWindow)
							return candidate;
					}
					return windowScene.windows.firstObject;
				};

				for (UIScene* scene in [UIApplication sharedApplication].connectedScenes)
				{
					if (![scene isKindOfClass:[UIWindowScene class]] ||
						scene.activationState != UISceneActivationStateForegroundActive)
						continue;

					window = windowOfScene((UIWindowScene*)scene);
					if (window != nil)
						break;
				}

				if (window == nil)
				{
					for (UIScene* scene in [UIApplication sharedApplication].connectedScenes)
					{
						if (![scene isKindOfClass:[UIWindowScene class]])
							continue;

						window = windowOfScene((UIWindowScene*)scene);
						if (window != nil)
							break;
					}
				}
			}
			#if __IPHONE_OS_VERSION_MIN_REQUIRED < 130000
			else
			{
				#pragma clang diagnostic push
				#pragma clang diagnostic ignored "-Wdeprecated-declarations"
				window = [UIApplication sharedApplication].keyWindow;
				#pragma clang diagnostic pop
			}
			#endif

			if (window == nil) { *l = 0; *t = 0; *r = 0; *b = 0; return; }

			UIView* view = window.rootViewController.view;
			if (view == nil) { *l = 0; *t = 0; *r = 0; *b = 0; return; }

		#if defined(__IPHONE_11_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_11_0
			//Only on iOS11, taken care of in the GetSafeFrame code (we don't use @available in order to support older Xcode version)
			UIEdgeInsets insets = view.safeAreaInsets;
			*l = insets.left;
			*t = insets.top;
			*r = insets.right;
			*b = insets.bottom;
		#else
			*l = *t = *r = *b = 0;
		#endif
		@}

		static void _statusBarWillChangeFrame(Uno.Platform.iOS.uCGRect _endFrame, double animationDuration)
		{
			if (Lifecycle.State == ApplicationState.Uninitialized)
				return;
			OnWillResize();
		}

		static void _statusBarDidChangeFrame(Uno.Platform.iOS.uCGRect _endFrame)
		{
		}

		static void uKeyboardWillChangeFrame (Uno.Platform.iOS.uCGRect frameBegin, Uno.Platform.iOS.uCGRect frameEnd, double animationDuration, int animationCurve, Fuse.Platform.SystemUIResizeReason reason)
		{
			_bottomFrame = Uno.Platform.iOS.Support.CGRectToUnoRect(
				Uno.Platform.iOS.Support.Pre_iOS8_HandleDeviceOrientation_Rect(frameEnd, null),
				1);
			OnWillResize();
		}

		static void uTextScaleFactorDidChange(float _textScaleFactor)
		{
			TextScaleFactor = _textScaleFactor;
		}

		//------------------------------------------------------------

		// @property (nonatomic, readonly) @{Uno.Rect} uStatusBarFrame;
		static Rect uStatusBarFrame()
		{
			uCGRect frame = extern<uCGRect>"[UIApplication sharedApplication].statusBarFrame";
			return Uno.Platform.iOS.Support.CGRectToUnoRect(
				Uno.Platform.iOS.Support.Pre_iOS8_HandleDeviceOrientation_Rect(frame, null),
				1);
		}

		static StatusBarStyle _style = StatusBarStyle.Dark;
		// @property (nonatomic, setter=uSetStatusBarStyle:) UIStatusBarStyle uStatusBarStyle;
		public static StatusBarStyle uStatusBarStyle
		{
			get { return _style; }
			set
			{
				if (value == _style)
					return;

				_style = value;
				if (extern<bool>"[[UIApplication sharedApplication].delegate respondsToSelector:@selector(setNeedsStatusBarAppearanceUpdate)]")
				{
					if (uStatusBarAnimation == extern<int>"(int)UIStatusBarAnimationNone")
						extern "[(::uAppDelegate*)[UIApplication sharedApplication].delegate setNeedsStatusBarAppearanceUpdate]";
					else
						extern "[UIView animateWithDuration:0.33 animations:^{ [(::uAppDelegate*)[UIApplication sharedApplication].delegate setNeedsStatusBarAppearanceUpdate]; }]";
				}
			}
		}

		static public void EnterFullscreen()
		{
			IsTopFrameVisible = false;
		}

		static public int supportedOrientation = GetProjectSettingsOrientation();

		private static int GetProjectSettingsOrientation()
		{
			if (@(project.mobile.orientations:toLower) == "portrait")
				return  extern<int>"UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown";
			if (@(project.mobile.orientations:toLower) == "portraitupsidedown")
				return  extern<int>"UIInterfaceOrientationMaskPortraitUpsideDown";
			if (@(project.mobile.orientations:toLower) == "landscape")
				return  extern<int>"UIInterfaceOrientationMaskLandscapeLeft | UIInterfaceOrientationMaskLandscapeRight";
			if (@(project.mobile.orientations:toLower) == "landscapeleft")
				return  extern<int>"UIInterfaceOrientationMaskLandscapeLeft";
			if (@(project.mobile.orientations:toLower) == "landscaperight")
				return  extern<int>"UIInterfaceOrientationMaskLandscapeRight";
			return  extern<int>"UIInterfaceOrientationMaskAll";
		}

		public static ScreenOrientation DeviceOrientation
		{
			get
			{
				var orientation = GetCurrentScreenOrientation();
				switch (orientation)
				{
					case 0:
						return ScreenOrientation.Portrait;
					case 1:
						return ScreenOrientation.LandscapeLeft;
					case 2:
						return ScreenOrientation.LandscapeRight;
					case 3:
						return ScreenOrientation.PortraitUpsideDown;
					default:
						return ScreenOrientation.Default;
				}
			}
			set
			{
				if (DeviceOrientation != value)
				{
					SetCurrentScreenOrientation(value);
					if (DeviceOrientationChanged != null)
						DeviceOrientationChanged(value);
				}
			}
		}

		[Foreign(Language.ObjC)]
		static int GetCurrentScreenOrientation()
		@{
			UIInterfaceOrientation orientation = UIInterfaceOrientationUnknown;

			#if __IPHONE_OS_VERSION_MIN_REQUIRED >= 130000
			// `UIApplication.windows` is deprecated in iOS 15; the scene owns the windows now.
			UIWindowScene* scene = nil;
			for (UIScene* s in [UIApplication sharedApplication].connectedScenes)
			{
				if (![s isKindOfClass:[UIWindowScene class]])
					continue;

				// Prefer the active scene, but accept any window scene as an early-launch fallback.
				if (scene == nil)
					scene = (UIWindowScene*)s;

				if (s.activationState == UISceneActivationStateForegroundActive)
				{
					scene = (UIWindowScene*)s;
					break;
				}
			}

			if (scene != nil)
				orientation = scene.interfaceOrientation;
			#else
			#pragma clang diagnostic push
			#pragma clang diagnostic ignored "-Wdeprecated-declarations"
			orientation = [[UIApplication sharedApplication] statusBarOrientation];
			#pragma clang diagnostic pop
			#endif

			switch (orientation)
			{
				case UIInterfaceOrientationPortrait:
					return 0;
				case UIInterfaceOrientationLandscapeLeft:
					return 1;
				case UIInterfaceOrientationLandscapeRight:
					return 2;
				case UIInterfaceOrientationPortraitUpsideDown:
					return 3;
				default:
					return 4;
			}
		@}

		[Foreign(Language.ObjC)]
		static void SetCurrentScreenOrientation(int orientation)
		@{
			NSNumber * value;
			switch (orientation)
			{
				case 0:
				{
					@{supportedOrientation:set(UIInterfaceOrientationMaskPortrait)};
					value = [NSNumber numberWithInt:UIInterfaceOrientationPortrait];
					break;
				}
				case 1:
				{
					@{supportedOrientation:set(UIInterfaceOrientationMaskLandscapeLeft)};
					value = [NSNumber numberWithInt:UIInterfaceOrientationLandscapeLeft];
					break;
				}
				case 2:
				{
					@{supportedOrientation:set(UIInterfaceOrientationMaskLandscapeRight)};
					value = [NSNumber numberWithInt:UIInterfaceOrientationLandscapeRight];
					break;
				}
				case 3:
				{
					@{supportedOrientation:set(UIInterfaceOrientationMaskPortraitUpsideDown)};
					value = [NSNumber numberWithInt:UIInterfaceOrientationPortraitUpsideDown];
					break;
				}
				default:
				{
					int orientationMask = GetProjectSettingsOrientation();
					@{supportedOrientation:set(orientationMask)};
					switch (orientationMask)
					{
						case UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown:
							value = [NSNumber numberWithInt:UIInterfaceOrientationPortrait];
							break;
						case UIInterfaceOrientationMaskPortraitUpsideDown:
							value = [NSNumber numberWithInt:UIInterfaceOrientationPortraitUpsideDown];
							break;
						case UIInterfaceOrientationMaskLandscapeLeft | UIInterfaceOrientationMaskLandscapeRight:
							value = [NSNumber numberWithInt:UIInterfaceOrientationLandscapeLeft];
							break;
						case UIInterfaceOrientationMaskLandscapeLeft:
							value = [NSNumber numberWithInt:UIInterfaceOrientationLandscapeLeft];
							break;
						case UIInterfaceOrientationMaskLandscapeRight:
							value = [NSNumber numberWithInt:UIInterfaceOrientationLandscapeRight];
							break;
						default:
							value = [NSNumber numberWithInt:UIInterfaceOrientationPortrait];
					}
				}
			}
			#if defined(__IPHONE_16_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_16_0
			if (@available(iOS 16.0, *)) {
				for (UIScene* scene in UIApplication.sharedApplication.connectedScenes) {
					if (![scene isKindOfClass:[UIWindowScene class]]) {
						continue;
					}
					UIWindowScene* windowScene = (UIWindowScene*)scene;
					UIInterfaceOrientationMask currentInterfaceOrientation = 1 << windowScene.interfaceOrientation;
					if (!(@{supportedOrientation:get()} & currentInterfaceOrientation)) {
						[[[windowScene keyWindow] rootViewController] setNeedsUpdateOfSupportedInterfaceOrientations];
						UIWindowSceneGeometryPreferencesIOS* preference =
						[[UIWindowSceneGeometryPreferencesIOS alloc] initWithInterfaceOrientations:@{supportedOrientation:get()}];
						[windowScene requestGeometryUpdateWithPreferences:preference
										errorHandler:^(NSError* error) {
											NSLog(@"Failed to change device orientation: %@",error);
										}];
					}
				}
			}
			else
			{
				[[UIDevice currentDevice] setValue:value forKey:@"orientation"];
			}
			#else
			[[UIDevice currentDevice] setValue:value forKey:@"orientation"];
			#endif

		@}
	}
}
