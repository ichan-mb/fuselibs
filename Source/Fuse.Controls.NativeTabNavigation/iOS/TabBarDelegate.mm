#import "iOS/TabBarDelegate.h"

@implementation FuseNativeTabBarDelegate

- (instancetype)initWithCallback:(void (^)(int))selected
{
    self = [super init];
    if (self) {
        _onSelected = selected;
    }
    return self;
}

/** The index of `viewController`, or NSNotFound. */
- (NSUInteger)indexOfViewController:(UIViewController *)viewController
                     inTabController:(UITabBarController *)tabBarController
{
    if (viewController == nil)
        return NSNotFound;

    // With the iOS 18 `tabs` API, `viewControllers` and the new tab objects are separate views of
    // the same set; match against both, then fall back to the controller's current selection.
    if (@available(iOS 18.0, *)) {
        NSArray<UITab *> *tabs = tabBarController.tabs;
        for (NSUInteger i = 0; i < tabs.count; i++) {
            if (tabs[i].viewController == viewController)
                return i;
        }
    }

    NSUInteger index = [tabBarController.viewControllers indexOfObject:viewController];
    if (index != NSNotFound)
        return index;

    NSInteger selected = tabBarController.selectedIndex;
    return selected >= 0 ? (NSUInteger)selected : NSNotFound;
}

- (void)notifySelection:(UIViewController *)viewController
       inTabController:(UITabBarController *)tabBarController
{
    NSUInteger index = [self indexOfViewController:viewController inTabController:tabBarController];
    if (index != NSNotFound && self.onSelected)
        self.onSelected((int)index);
}

- (void)tabBarController:(UITabBarController *)tabBarController
didSelectViewController:(UIViewController *)viewController
{
    [self notifySelection:viewController inTabController:tabBarController];
}

- (void)tabBarController:(UITabBarController *)tabBarController
           didSelectTab:(UITab *)selectedTab
            previousTab:(UITab *)previousTab API_AVAILABLE(ios(18.0))
{
    (void)previousTab;
    [self notifySelection:selectedTab.viewController inTabController:tabBarController];
}

@end
