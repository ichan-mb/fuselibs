#import <UIKit/UIKit.h>

/**
        SwiftUIHostingContainer is a UIView subclass that serves as a native
        container for hosting SwiftUI views within Fuse applications on iOS.

        This container acts as a bridge between Fuse's native view system and
        SwiftUI's hosting mechanism. It holds a reference to the SwiftUI view
        (wrapped in a UIHostingController's view) and ensures proper layout and
        rendering.

        Key responsibilities:
        - Hosting SwiftUI views within Fuse's native view hierarchy
        - Managing layout of the hosted SwiftUI content
        - Providing proper touch handling and clipping behavior
        - Maintaining the connection between Fuse and SwiftUI view lifecycles
*/
@interface SwiftUIHostingContainer : UIView

/** The SwiftUI view (from UIHostingController.view) that this container hosts
 */
@property(nonatomic, strong) UIView *swiftUIView;

@end
