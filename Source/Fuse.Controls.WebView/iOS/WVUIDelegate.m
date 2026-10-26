#import "WVUIDelegate.h"
#import "WVUtils.h"

@interface WVUIDelegate ()
@property (copy) void (^openPanelCompletion)(NSArray<NSURL*>* URLs);
@end

@implementation WVUIDelegate

-(WKWebView*)webView:(WKWebView*)webView
	createWebViewWithConfiguration:(WKWebViewConfiguration*)configuration
	forNavigationAction:(WKNavigationAction*)navigationAction
	windowFeatures:(WKWindowFeatures*)windowFeatures
{
	if (navigationAction.targetFrame != nil)
		return nil;

	if (self.newWindowPolicy == WVNewWindowPolicyBlock)
		return nil;

	if (self.newWindowPolicy == WVNewWindowPolicyOpenExternally)
	{
		[WVUtils openURLExternally:navigationAction.request.URL];
		return nil;
	}

	if (self.newWindowPolicy == WVNewWindowPolicyOpenInWebView)
		[webView loadRequest:navigationAction.request];

	return nil;
}

-(void)webView:(WKWebView*)webView
	runJavaScriptAlertPanelWithMessage:(NSString*)message
	initiatedByFrame:(WKFrameInfo*)frame
	completionHandler:(void (^)(void))completionHandler
{
	dispatch_async(dispatch_get_main_queue(), ^{
		UIViewController* presenter = [WVUtils topViewController];
		if (presenter == nil)
		{
			completionHandler();
			return;
		}

		UIAlertController* alert = [UIAlertController alertControllerWithTitle:nil
			message:message ?: @""
			preferredStyle:UIAlertControllerStyleAlert];

		[alert addAction:[UIAlertAction actionWithTitle:@"OK"
			style:UIAlertActionStyleDefault
			handler:^(UIAlertAction* action) {
				completionHandler();
			}]];

		[presenter presentViewController:alert animated:YES completion:nil];
	});
}

-(void)webView:(WKWebView*)webView
	runJavaScriptConfirmPanelWithMessage:(NSString*)message
	initiatedByFrame:(WKFrameInfo*)frame
	completionHandler:(void (^)(BOOL result))completionHandler
{
	dispatch_async(dispatch_get_main_queue(), ^{
		UIViewController* presenter = [WVUtils topViewController];
		if (presenter == nil)
		{
			completionHandler(NO);
			return;
		}

		UIAlertController* alert = [UIAlertController alertControllerWithTitle:nil
			message:message ?: @""
			preferredStyle:UIAlertControllerStyleAlert];

		[alert addAction:[UIAlertAction actionWithTitle:@"Cancel"
			style:UIAlertActionStyleCancel
			handler:^(UIAlertAction* action) {
				completionHandler(NO);
			}]];

		[alert addAction:[UIAlertAction actionWithTitle:@"OK"
			style:UIAlertActionStyleDefault
			handler:^(UIAlertAction* action) {
				completionHandler(YES);
			}]];

		[presenter presentViewController:alert animated:YES completion:nil];
	});
}

-(void)webView:(WKWebView*)webView
	runJavaScriptTextInputPanelWithPrompt:(NSString*)prompt
	defaultText:(NSString*)defaultText
	initiatedByFrame:(WKFrameInfo*)frame
	completionHandler:(void (^)(NSString* result))completionHandler
{
	dispatch_async(dispatch_get_main_queue(), ^{
		UIViewController* presenter = [WVUtils topViewController];
		if (presenter == nil)
		{
			completionHandler(nil);
			return;
		}

		UIAlertController* alert = [UIAlertController alertControllerWithTitle:nil
			message:prompt ?: @""
			preferredStyle:UIAlertControllerStyleAlert];

		[alert addTextFieldWithConfigurationHandler:^(UITextField* textField) {
			textField.text = defaultText ?: @"";
		}];

		[alert addAction:[UIAlertAction actionWithTitle:@"Cancel"
			style:UIAlertActionStyleCancel
			handler:^(UIAlertAction* action) {
				completionHandler(nil);
			}]];

		__weak UIAlertController* weakAlert = alert;
		[alert addAction:[UIAlertAction actionWithTitle:@"OK"
			style:UIAlertActionStyleDefault
			handler:^(UIAlertAction* action) {
				UIAlertController* strongAlert = weakAlert;
				UITextField* textField = strongAlert.textFields.firstObject;
				completionHandler(textField.text);
			}]];

		[presenter presentViewController:alert animated:YES completion:nil];
	});
}

-(void)webView:(WKWebView*)webView
	runOpenPanelWithParameters:(WKOpenPanelParameters*)parameters
	initiatedByFrame:(WKFrameInfo*)frame
	completionHandler:(void (^)(NSArray<NSURL*>* URLs))completionHandler API_AVAILABLE(ios(14.0))
{
	// Make sure a previous request is completed before starting a new one.
	[self finishOpenPanel:nil];

	self.openPanelCompletion = completionHandler;

	dispatch_async(dispatch_get_main_queue(), ^{
		UIViewController* presenter = [WVUtils topViewController];
		if (presenter == nil)
		{
			[self finishOpenPanel:nil];
			return;
		}

		UIDocumentPickerViewController* picker = [[UIDocumentPickerViewController alloc]
			initWithDocumentTypes:@[@"public.item"]
			inMode:UIDocumentPickerModeImport];
		picker.allowsMultipleSelection = parameters.allowsMultipleSelection;
		picker.delegate = self;

		[presenter presentViewController:picker animated:YES completion:nil];
	});
}

-(void)documentPicker:(UIDocumentPickerViewController*)controller didPickDocumentsAtURLs:(NSArray<NSURL*>*)urls
{
	[self finishOpenPanel:urls];
}

-(void)documentPickerWasCancelled:(UIDocumentPickerViewController*)controller
{
	[self finishOpenPanel:nil];
}

-(void)finishOpenPanel:(NSArray<NSURL*>*)urls
{
	void (^completion)(NSArray<NSURL*>*) = self.openPanelCompletion;
	self.openPanelCompletion = nil;

	if (completion != nil)
		completion(urls);
}

@end
