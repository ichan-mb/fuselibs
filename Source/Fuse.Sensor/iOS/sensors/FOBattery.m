#import "FOBattery.h"

@interface FOBattery ()

@property (nonatomic, assign) BOOL wasMonitoringEnabled;

- (void)postBatteryData;

@end

@implementation FOBattery

@synthesize _onDataChanged;
@synthesize _onError;

- (instancetype)initWithBlock:(void (^)(FOBatteryData* batteryData))onDataChanged error:(void (^)(NSError* err))onError
{
    if (self = [super init])
    {
        self._onDataChanged = onDataChanged;
        self._onError = onError;
        self.wasMonitoringEnabled = NO;
    }
    return self;
}

- (void)dealloc
{
    // Never leave observers behind, even if the provider was never stopped.
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark Sensing

- (BOOL)startSensing
{
    if (_sensing)
        return YES;

    self.wasMonitoringEnabled = [UIDevice currentDevice].batteryMonitoringEnabled;

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(batteryChanged:)
                                                 name:UIDeviceBatteryLevelDidChangeNotification object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(batteryChanged:)
                                                 name:UIDeviceBatteryStateDidChangeNotification object:nil];

    [UIDevice currentDevice].batteryMonitoringEnabled = YES;
    _sensing = YES;

    // Android delivers the current state immediately through a sticky broadcast, so do the
    // same here instead of making the app wait for the first change.
    [self postBatteryData];

    return YES;
}

- (BOOL)stopSensing
{
    if (!_sensing)
        return YES;

    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIDeviceBatteryLevelDidChangeNotification
                                                  object:nil];

    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIDeviceBatteryStateDidChangeNotification
                                                  object:nil];

    // Restore whatever the app had configured before we started monitoring.
    [UIDevice currentDevice].batteryMonitoringEnabled = self.wasMonitoringEnabled;
    _sensing = NO;
    return YES;
}

- (void)batteryChanged:(NSNotification *)notification
{
    [self postBatteryData];
}

- (void)postBatteryData
{
    if (!_sensing || !self._onDataChanged)
        return;

    FOBatteryData *data = [[FOBatteryData alloc] initWithLevel:[UIDevice currentDevice].batteryLevel
                                                         state:[UIDevice currentDevice].batteryState];

    self._onDataChanged(data);
}

@end
