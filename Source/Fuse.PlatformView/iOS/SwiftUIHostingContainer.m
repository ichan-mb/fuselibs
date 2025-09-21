#import "SwiftUIHostingContainer.h"

/**
	Implementation of SwiftUIHostingContainer that handles layout of SwiftUI content.

	This implementation ensures that the hosted SwiftUI view always fills the
	entire bounds of the container, providing seamless integration with Fuse's
	layout system. The container automatically updates the SwiftUI view's frame
	whenever the container's layout changes.
*/
@implementation SwiftUIHostingContainer

    @synthesize swiftUIView;

    /**
    	Overrides layoutSubviews to ensure the hosted SwiftUI view matches the container's bounds.
    	This method is called automatically by the iOS layout system whenever the container's
    	size or position changes, ensuring the SwiftUI content is always properly sized.

    	The implementation:
    	1. Calls super to handle standard UIView layout behavior
    	2. Sets the SwiftUI view's frame to match the container's bounds exactly

    	This ensures that SwiftUI content appears seamlessly integrated within the Fuse
    	application's layout, responding to size changes and animations properly.
    */
    - (void)layoutSubviews {
		[super layoutSubviews];
		self.swiftUIView.frame = self.bounds;
	}

@end
