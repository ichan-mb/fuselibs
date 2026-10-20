#import "AlertsUI.h"

static FuseAlertsPopoverDelegate* _fuseAlertsPopoverDelegate = nil;
static FuseAlertsTextChangeHandler* _fuseAlertsTextChangeHandler = nil;
static UIAlertController* _fuseAlertsCurrentController = nil;
static void (^_fuseAlertsCurrentDismissHandler)(void) = nil;

@implementation FuseAlertsPopoverDelegate

- (void)popoverPresentationControllerDidDismissPopover:(UIPopoverPresentationController *)popoverPresentationController
{
	if (self.onDismiss)
		self.onDismiss();
}

@end

@implementation FuseAlertsTextChangeHandler

- (void)textChanged:(UITextField*)textField
{
	if (self.onChange)
		self.onChange(textField.text);
}

@end

FuseAlertsPopoverDelegate* FuseAlertsCreatePopoverDelegate(void (^onDismiss)(void))
{
	_fuseAlertsPopoverDelegate = [[FuseAlertsPopoverDelegate alloc] init];
	_fuseAlertsPopoverDelegate.onDismiss = onDismiss;
	return _fuseAlertsPopoverDelegate;
}

FuseAlertsTextChangeHandler* FuseAlertsCreateTextChangeHandler(void (^onChange)(NSString*))
{
	_fuseAlertsTextChangeHandler = [[FuseAlertsTextChangeHandler alloc] init];
	_fuseAlertsTextChangeHandler.onChange = onChange;
	return _fuseAlertsTextChangeHandler;
}

void FuseAlertsSetCurrentController(UIAlertController* controller, void (^onDismiss)(void))
{
	_fuseAlertsCurrentController = controller;
	_fuseAlertsCurrentDismissHandler = onDismiss;
}

void FuseAlertsDismissCurrentController(void)
{
	UIAlertController* controller = _fuseAlertsCurrentController;
	void (^handler)(void) = _fuseAlertsCurrentDismissHandler;

	_fuseAlertsCurrentController = nil;
	_fuseAlertsCurrentDismissHandler = nil;

	if (controller != nil)
		[controller dismissViewControllerAnimated:YES completion:nil];

	if (handler != nil)
		handler();
}
