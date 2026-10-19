#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface FuseToolbarActionHandler : NSObject

@property (nonatomic, copy) void (^onToolbarItemClicked)(int itemIndex);
@property (nonatomic, copy) void (^onMenuItemClicked)(int menuIndex);

- (instancetype)initWithCallbacks:(void (^)(int))toolbarItemClicked
                  menuItemClicked:(void (^)(int))menuItemClicked;
- (void)handleToolbarItemAction:(UIBarButtonItem*)sender;
- (void)handleMenuAction:(int)menuIndex;

@end
