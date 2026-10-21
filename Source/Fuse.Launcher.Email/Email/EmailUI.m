#import "EmailUI.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import <objc/runtime.h>

static char kFuseEmailComposeDelegateKey;

@interface FuseEmailComposeDelegate : NSObject <MFMailComposeViewControllerDelegate>
@property (nonatomic, copy) FuseEmailComplete onComplete;
@property (nonatomic, copy) FuseEmailError onError;
@end

@implementation FuseEmailComposeDelegate

- (void)mailComposeController:(MFMailComposeViewController*)controller
		  didFinishWithResult:(MFMailComposeResult)result
						error:(NSError*)error
{
	NSString* status = @"cancelled";
	BOOL failed = NO;

	switch (result)
	{
		case MFMailComposeResultSent:
			status = @"sent";
			break;
		case MFMailComposeResultSaved:
			status = @"saved";
			break;
		case MFMailComposeResultCancelled:
			status = @"cancelled";
			break;
		case MFMailComposeResultFailed:
			failed = YES;
			break;
	}

	NSString* message = error != nil && error.localizedDescription.length > 0
		? error.localizedDescription
		: @"The email could not be sent.";

	[controller dismissViewControllerAnimated:YES completion:^{
		if (failed)
		{
			if (self.onError != nil)
				self.onError(message);
		}
		else if (self.onComplete != nil)
		{
			self.onComplete(status);
		}
	}];
}

@end

static UIViewController* FuseEmailTopViewController(void)
{
	UIWindow* window = nil;

	id appDelegate = [UIApplication sharedApplication].delegate;
	UIViewController* delegateVC = [appDelegate isKindOfClass:[UIViewController class]]
		? (UIViewController*)appDelegate
		: nil;

	// Prefer the window that actually hosts the Fuse root view. This avoids
	// picking up a system window whose root view controller is nil or unrelated.
	if (delegateVC != nil)
		window = delegateVC.view.window;

	if (window == nil)
	{
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
	}

	if (window.rootViewController == nil && delegateVC != nil)
		window.rootViewController = delegateVC;

	UIViewController* presenter = window.rootViewController;
	if (presenter == nil)
		presenter = delegateVC;

	while (presenter.presentedViewController != nil)
		presenter = presenter.presentedViewController;

	if ([presenter isKindOfClass:[UIAlertController class]] || presenter.isBeingDismissed)
		presenter = presenter.presentingViewController;

	return presenter;
}

static NSString* FuseEmailMimeType(NSString* fileName)
{
	NSString* extension = fileName.pathExtension.lowercaseString;
	if (extension.length == 0)
		return @"application/octet-stream";

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
	CFStringRef uti = UTTypeCreatePreferredIdentifierForTag(
		kUTTagClassFilenameExtension,
		(__bridge CFStringRef)extension,
		NULL);

	CFStringRef mime = uti != NULL
		? UTTypeCopyPreferredTagWithClass(uti, kUTTagClassMIMEType)
		: NULL;

	NSString* result = mime != NULL ? (__bridge_transfer NSString*)mime : nil;
	if (uti != NULL)
		CFRelease(uti);
#pragma clang diagnostic pop

	return result != nil ? result : @"application/octet-stream";
}

static BOOL FuseEmailAddAttachments(MFMailComposeViewController* composer,
									NSArray* attachmentPaths,
									NSString** error)
{
	for (NSString* path in attachmentPaths)
	{
		NSString* filePath = path;

		if ([path hasPrefix:@"file://"])
		{
			NSURL* parsedPath = [NSURL URLWithString:path];
			filePath = parsedPath.path;
		}

		BOOL isDirectory = NO;
		BOOL exists = filePath != nil && [[NSFileManager defaultManager]
			fileExistsAtPath:filePath
			isDirectory:&isDirectory];

		if (!exists || isDirectory)
		{
			if (error != NULL)
				*error = [NSString stringWithFormat:@"The file does not exist: %@", path];
			return NO;
		}

		NSData* data = [NSData dataWithContentsOfFile:filePath];
		if (data == nil)
		{
			if (error != NULL)
				*error = [NSString stringWithFormat:@"Could not read the file: %@", path];
			return NO;
		}

		[composer addAttachmentData:data
			mimeType:FuseEmailMimeType(filePath)
			fileName:filePath.lastPathComponent];
	}

	return YES;
}

BOOL FuseEmailIsAvailable(void)
{
	__block BOOL available = NO;

	void (^check)(void) = ^{
		NSURL* url = [NSURL URLWithString:@"mailto:"];
		#pragma clang diagnostic push
		#pragma clang diagnostic ignored "-Wdeprecated-declarations"
		available = [MFMailComposeViewController canSendMail] ||
			(url != nil && [[UIApplication sharedApplication] canOpenURL:url]);
		#pragma clang diagnostic pop
	};

	if ([NSThread isMainThread])
		check();
	else
		dispatch_sync(dispatch_get_main_queue(), check);

	return available;
}

void FuseEmailLaunch(NSString* mailtoUri,
					 NSArray* to,
					 NSArray* cc,
					 NSArray* bcc,
					 NSString* subject,
					 NSString* body,
					 NSString* htmlBody,
					 NSArray* attachmentPaths,
					 BOOL useInApp,
					 FuseEmailComplete onComplete,
					 FuseEmailError onError)
{
	BOOL canSendMail = [MFMailComposeViewController canSendMail];

	if (useInApp && canSendMail)
	{
		MFMailComposeViewController* composer = [[MFMailComposeViewController alloc] init];
		if (composer == nil)
		{
			onError(@"Could not create the email composer.");
			return;
		}

		if (to.count > 0)
			[composer setToRecipients:to];
		if (cc.count > 0)
			[composer setCcRecipients:cc];
		if (bcc.count > 0)
			[composer setBccRecipients:bcc];
		if (subject.length > 0)
			[composer setSubject:subject];

		if (htmlBody.length > 0)
			[composer setMessageBody:htmlBody isHTML:YES];
		else if (body.length > 0)
			[composer setMessageBody:body isHTML:NO];

		NSString* attachmentError = nil;
		if (!FuseEmailAddAttachments(composer, attachmentPaths, &attachmentError))
		{
			onError(attachmentError != nil
			? attachmentError
			: @"Could not attach the file.");
			return;
		}

		FuseEmailComposeDelegate* delegate = [[FuseEmailComposeDelegate alloc] init];
		delegate.onComplete = onComplete;
		delegate.onError = onError;
		composer.mailComposeDelegate = delegate;
		objc_setAssociatedObject(composer, &kFuseEmailComposeDelegateKey, delegate,
			OBJC_ASSOCIATION_RETAIN_NONATOMIC);

		UIViewController* presenter = FuseEmailTopViewController();
		if (presenter == nil || presenter.view.window == nil)
		{
			onError(@"No view controller available to present the email composer.");
			return;
		}

		[presenter presentViewController:composer animated:YES completion:nil];
		return;
	}

	if (attachmentPaths.count > 0)
	{
		onError(@"Attachments require a configured Mail account.");
		return;
	}

	if (htmlBody.length > 0 && (body == nil || body.length == 0))
	{
		onError(@"HTML email requires a configured Mail account or a plain text body.");
		return;
	}

	NSURL* url = [NSURL URLWithString:mailtoUri];
	if (url == nil)
	{
		onError(@"Could not create the email link.");
		return;
	}

	if (@available(iOS 10.0, *))
	{
		[[UIApplication sharedApplication] openURL:url options:[NSDictionary dictionary] completionHandler:^(BOOL success) {
			if (success)
				onComplete(@"opened");
			else
				onError(@"No app is available to open the email link.");
		}];
	}
	else
	{
		#pragma clang diagnostic push
		#pragma clang diagnostic ignored "-Wdeprecated-declarations"
		BOOL success = [[UIApplication sharedApplication] openURL:url];
		#pragma clang diagnostic pop

		if (success)
			onComplete(@"opened");
		else
			onError(@"No app is available to open the email link.");
	}
}
