#import "SwiftUIHostingContainer.h"

@implementation SwiftUIHostingContainer

    @synthesize swiftUIView;

    - (void)layoutSubviews {
		[super layoutSubviews];
		self.swiftUIView.frame = self.bounds;
	}

@end