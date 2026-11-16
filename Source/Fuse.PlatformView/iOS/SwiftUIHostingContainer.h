#import <UIKit/UIKit.h>

/**
        SwiftUIHostingContainer is a UIView subclass that serves as a native
        container for hosting SwiftUI views within Fuse applications on iOS.

        This container acts as a bridge between Fuse's native view system and
        SwiftUI's hosting mechanism. It holds the UIHostingController that owns
        the SwiftUI view, establishes proper view controller containment, and
        ensures correct layout and rendering.

        Key responsibilities:
        - Hosting SwiftUI views within Fuse's native view hierarchy
        - Establishing parent/child relationship with the hosting controller
        - Managing layout of the hosted SwiftUI content
        - Providing proper touch handling and clipping behavior
        - Maintaining the connection between Fuse and SwiftUI view lifecycles
*/
@interface SwiftUIHostingContainer : UIView

/** The SwiftUI view (from UIHostingController.view) that this container hosts
 */
@property(nonatomic, strong) UIView *swiftUIView;

/** The hosting controller that owns the SwiftUI view.

    The container establishes proper view controller containment for this
    controller so SwiftUI view lifecycle callbacks (onAppear/onDisappear),
    sheets, keyboard handling and focus behave correctly.
 */
@property(nonatomic, strong) UIViewController *hostingController;

@end
