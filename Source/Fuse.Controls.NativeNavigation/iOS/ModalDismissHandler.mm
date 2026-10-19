#import "iOS/ModalDismissHandler.h"

@implementation FuseModalDismissHandler

- (instancetype)initWithCallback:(void (^)(void))dismissed
{
    self = [super init];
    if (self) {
        _onDismissed = dismissed;
    }
    return self;
}

#pragma mark - UIAdaptivePresentationControllerDelegate

- (void)presentationControllerDidDismiss:(UIPresentationController *)presentationController
{
    if (self.onDismissed) {
        self.onDismissed();
    }
}

@end
