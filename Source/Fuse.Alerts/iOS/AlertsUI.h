#pragma once
#ifdef __OBJC__
#include <UIKit/UIKit.h>

/*
	Keeps the popover delegate alive while an action sheet is presented.
	The UIPopoverPresentationController delegate is weak, and dismissing the
	popover by tapping outside does not invoke the cancel action on iPad.
*/
@interface FuseAlertsPopoverDelegate : NSObject <UIPopoverPresentationControllerDelegate>
@property (nonatomic, copy) void (^onDismiss)(void);
@end

@interface FuseAlertsTextChangeHandler : NSObject
@property (nonatomic, copy) void (^onChange)(NSString* text);
- (void)textChanged:(UITextField*)textField;
@end

#ifdef __cplusplus
extern "C" {
#endif
FuseAlertsPopoverDelegate* FuseAlertsCreatePopoverDelegate(void (^onDismiss)(void));
FuseAlertsTextChangeHandler* FuseAlertsCreateTextChangeHandler(void (^onChange)(NSString*));
void FuseAlertsSetCurrentController(UIAlertController* controller, void (^onDismiss)(void));
void FuseAlertsDismissCurrentController(void);
#ifdef __cplusplus
}
#endif

/*
	Returns the view controller that should present an alert or action sheet.

	`UIApplication.keyWindow` is deprecated since iOS 13, so prefer the key
	window of the foreground-active window scene, then any connected scene
	(early launch). The pre-iOS 13 fallback is compiled only when the project
	deployment target requires it.
*/
static inline UIViewController* FuseAlertsTopViewController(void)
{
	UIWindow* window = nil;

	if (@available(iOS 13.0, *))
	{
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

	UIViewController* presenter = window.rootViewController;
	if (!presenter)
		presenter = (UIViewController*)[[UIApplication sharedApplication] delegate];

	while (presenter.presentedViewController)
		presenter = presenter.presentedViewController;

	if ([presenter isKindOfClass:[UIAlertController class]] || presenter.isBeingDismissed)
		presenter = presenter.presentingViewController;

	return presenter;
}

#endif
