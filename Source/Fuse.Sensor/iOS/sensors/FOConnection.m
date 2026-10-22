#import "FOConnection.h"

@interface FOConnection ()

@property (nonatomic, strong) FOReachability* reach;

// -1 = nothing reported yet, 0 = disconnected, 1 = connected
@property (nonatomic, assign) int lastReportedState;

- (void)postState:(bool)connected;

@end

@implementation FOConnection

@synthesize _onDataChanged;
@synthesize _onError;

- (instancetype)initWithBlock:(void (^)(FOConnectionStateData * status))onDataChanged error:(void (^)(NSError* err))onError
{
    if (self = [super init])
    {
        self._onDataChanged = onDataChanged;
        self._onError = onError;
        self.lastReportedState = -1;

        // A zero-address reachability check does not perform a DNS lookup, so it does not report
        // "disconnected" merely because a specific host is unreachable (captive portals, firewalls, ...).
        self.reach = [FOReachability reachabilityForInternetConnection];

        __weak FOConnection *weakSelf = self;
        self.reach.reachableBlock = ^(FOReachability*reach)
        {
            [weakSelf postState:YES];
        };

        self.reach.unreachableBlock = ^(FOReachability*reach)
        {
            [weakSelf postState:NO];
        };
    }
    return self;
}

#pragma mark Sensing

- (BOOL)startSensing
{
    if (_sensing)
        return YES;

    if (![self.reach startNotifier])
        return NO;

    _sensing = YES;

    // Report the current state immediately, so the app does not have to wait for a change.
    [self postState:[self.reach isReachable]];

    return YES;
}

- (BOOL)stopSensing
{
    if (!_sensing)
        return YES;

    [self.reach stopNotifier];
    _sensing = NO;
    self.lastReportedState = -1;
    return YES;
}

- (void)postState:(bool)connected
{
    if (!_sensing || !self._onDataChanged)
        return;

    // Switching between WiFi and cellular reports "reachable" again, so only emit on change.
    int state = connected ? 1 : 0;
    if (self.lastReportedState == state)
        return;

    self.lastReportedState = state;
    self._onDataChanged([[FOConnectionStateData alloc] initWithState:connected]);
}

@end
