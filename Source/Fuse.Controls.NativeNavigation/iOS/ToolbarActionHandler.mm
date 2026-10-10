#import "iOS/ToolbarActionHandler.h"

@implementation FuseToolbarActionHandler

- (instancetype)initWithCallback:(void (^)(int))callback
{
    self = [super init];
    if (self) {
        _onToolbarItemClicked = callback;
    }
    return self;
}

- (void)handleToolbarItemAction:(UIBarButtonItem*)sender
{
    if (self.onToolbarItemClicked) {
        int itemIndex = (int)sender.tag;
        self.onToolbarItemClicked(itemIndex);
    }
}

@end