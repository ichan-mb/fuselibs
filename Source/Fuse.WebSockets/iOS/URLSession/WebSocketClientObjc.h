#import <Foundation/Foundation.h>

@interface WebSocketClientObjc : NSObject

- (instancetype)initWithUrl:(NSString *)url
				  protocols:(NSArray *)protocols
			   eventHandler:(void (^)(NSString *, NSString *))eventHandler
		  onReceivedMessage:(void (^)(NSString *))receivedMessage
			onReceivedData:(void (^)(uint8_t *, NSUInteger))receivedData;

- (void)connect;
- (void)disconnect;
- (void)sendString:(NSString *)data;
- (void)sendData:(const uint8_t *)data length:(NSUInteger)length;
- (void)setHeaderKey:(NSString *)key withValue:(NSString *)value;
- (void)dispose;

@end