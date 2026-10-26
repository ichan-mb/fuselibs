#import "WVUtils.h"

@implementation WVUtils

+ (BOOL)openURLExternally:(NSURL*)url
{
	if (url == nil)
		return NO;

	UIApplication* app = [UIApplication sharedApplication];
	if (![app canOpenURL:url])
		return NO;

	if (@available(iOS 10.0, *))
		[app openURL:url options:[NSDictionary dictionary] completionHandler:nil];
	else
		[app openURL:url];

	return YES;
}

+ (UIViewController*)topViewController
{
	UIWindow* window = nil;
	for (UIWindow* candidate in [UIApplication sharedApplication].windows)
	{
		if (candidate.isKeyWindow)
		{
			window = candidate;
			break;
		}
	}

	if (window == nil)
		window = [UIApplication sharedApplication].windows.firstObject;

	if (window == nil)
		window = [UIApplication sharedApplication].delegate.window;

	UIViewController* controller = window.rootViewController;
	while (controller.presentedViewController != nil)
		controller = controller.presentedViewController;

	return controller;
}

@end
