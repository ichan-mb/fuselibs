#import "FOMotionManager.h"


@interface FOMotionManagerListener : NSObject

@property (nonatomic, assign) NSInteger token;
@property (nonatomic, copy) void (^onDataChanged)(CMDeviceMotion* deviceMotionData);
@property (nonatomic, copy) void (^onError)(NSError* error);

@end


@implementation FOMotionManagerListener
@end


@interface FOMotionManager ()
+ (void)dispatchDeviceMotion:(CMDeviceMotion *)deviceMotionData error:(NSError *)error;
@end


static NSMutableArray *deviceMotionListeners;
static NSOperationQueue *deviceMotionQueue;
static NSInteger nextDeviceMotionToken = 1;


@implementation FOMotionManager

+ (CMMotionManager *)sharedMotionManager
{
    static CMMotionManager *sharedMotionManager;
    @synchronized(self)
    {
        if (!sharedMotionManager)
        {
            sharedMotionManager = [[CMMotionManager alloc] init];
        }

        return sharedMotionManager;
    }
    return sharedMotionManager;
}

+ (NSInteger)addDeviceMotionListener:(void (^)(CMDeviceMotion* deviceMotionData))onDataChanged
                               error:(void (^)(NSError* err))onError
{
    CMMotionManager *manager = [self sharedMotionManager];

    @synchronized (self)
    {
        if (!deviceMotionListeners)
            deviceMotionListeners = [NSMutableArray array];

        FOMotionManagerListener *listener = [[FOMotionManagerListener alloc] init];
        listener.token = nextDeviceMotionToken++;
        listener.onDataChanged = onDataChanged;
        listener.onError = onError;
        [deviceMotionListeners addObject:listener];

        if (deviceMotionListeners.count == 1)
        {
            if (!deviceMotionQueue)
                deviceMotionQueue = [[NSOperationQueue alloc] init];

            // The update interval is configured by FOSensorConfig before the sensor starts.
            [manager startDeviceMotionUpdatesToQueue:deviceMotionQueue
                                         withHandler:^(CMDeviceMotion *deviceMotionData, NSError *error) {
                [FOMotionManager dispatchDeviceMotion:deviceMotionData error:error];
            }];
        }

        return listener.token;
    }
}

+ (void)removeDeviceMotionListener:(NSInteger)token
{
    if (token == 0)
        return;

    @synchronized (self)
    {
        if (!deviceMotionListeners)
            return;

        for (NSInteger i = deviceMotionListeners.count - 1; i >= 0; --i)
        {
            FOMotionManagerListener *listener = deviceMotionListeners[i];
            if (listener.token == token)
                [deviceMotionListeners removeObjectAtIndex:i];
        }

        // The shared manager only supports one handler, so it must stay running while
        // any provider is still interested in device motion.
        if (deviceMotionListeners.count == 0)
            [[self sharedMotionManager] stopDeviceMotionUpdates];
    }
}

+ (void)dispatchDeviceMotion:(CMDeviceMotion *)deviceMotionData error:(NSError *)error
{
    NSArray *listeners;
    @synchronized (self)
    {
        listeners = [deviceMotionListeners copy];
    }

    for (FOMotionManagerListener *listener in listeners)
    {
        if (error != nil)
        {
            if (listener.onError)
                listener.onError(error);
        }
        else if (deviceMotionData != nil)
        {
            if (listener.onDataChanged)
                listener.onDataChanged(deviceMotionData);
        }
    }
}

@end
