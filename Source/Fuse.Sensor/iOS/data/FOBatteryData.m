#import "FOBatteryData.h"

@implementation FOBatteryData

@synthesize _level;
@synthesize _state;

- (instancetype)initWithLevel:(CGFloat)level state:(UIDeviceBatteryState)state
{
    if (self = [super init])
    {
        _level = level;
        _state = state;
    }
    return self;
}

- (NSString *)stateString
{
    // These values are part of the public API, so they must match the Android implementation.
    switch (_state) {
        case UIDeviceBatteryStateCharging:
            return @"charging";

        case UIDeviceBatteryStateFull:
            return @"full";

        case UIDeviceBatteryStateUnplugged:
            return @"unplugged";

        case UIDeviceBatteryStateUnknown:
            return @"unknown";

        default:
            NSLog(@"Warning: Unknown state: %d", (int)_state);
            return @"unknown";
    }
}

@end