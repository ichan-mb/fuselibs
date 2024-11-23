#import "AVPlayerContainer.h"

@implementation AVPlayerContainer

    @synthesize avPlayerView;

    - (void)layoutSubviews {
		[super layoutSubviews];
		self.avPlayerView.frame = self.bounds;
	}

@end