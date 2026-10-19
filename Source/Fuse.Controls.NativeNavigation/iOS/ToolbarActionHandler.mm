#import "iOS/ToolbarActionHandler.h"

@implementation FuseToolbarActionHandler

- (instancetype)initWithCallbacks:(void (^)(int))toolbarItemClicked
                  menuItemClicked:(void (^)(int))menuItemClicked
{
    self = [super init];
    if (self) {
        _onToolbarItemClicked = toolbarItemClicked;
        _onMenuItemClicked = menuItemClicked;
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

- (void)handleMenuAction:(int)menuIndex
{
    if (self.onMenuItemClicked) {
        self.onMenuItemClicked(menuIndex);
    }
}

@end
