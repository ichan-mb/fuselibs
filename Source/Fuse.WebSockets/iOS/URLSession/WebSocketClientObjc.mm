#import "iOS/URLSession/WebSocketClientObjc.h"

// Native WebSockets over URLSessionWebSocketTask (available since iOS 13).
//
// The WebSocket API exists at runtime since iOS 13, but this implementation is
// written to compile against older deployment targets as well: every call into
// the WebSocket API is wrapped in an @available check, and on older runtimes
// connecting produces an "error" + "close" event instead of crashing.
//
// Event contract (same as the previous SocketRocket implementation):
//   "open"  - fired once when the connection handshake completes
//   "close" - fired at most once afterwards, with a reason or nil
//   "error" - fires for transport errors, followed by "close"

@interface WebSocketClientObjc (Private)
- (void)handleOpened;
- (void)handleClosed:(NSString *)reason;
- (void)handleError:(NSError *)error;
@end

@interface WebSocketClientObjcSessionDelegate : NSObject <NSURLSessionWebSocketDelegate>
@property (nonatomic, weak) WebSocketClientObjc *owner;
@end

@implementation WebSocketClientObjcSessionDelegate

- (void)URLSession:(NSURLSession *)session
	webSocketTask:(NSURLSessionWebSocketTask *)webSocketTask
didCloseWithCloseCode:(NSURLSessionWebSocketCloseCode)closeCode
			reason:(NSData *)reason API_AVAILABLE(ios(13.0), macos(10.15)) {
	NSString *reasonString = nil;
	if (reason != nil && [reason length] > 0)
		reasonString = [[NSString alloc] initWithData:reason encoding:NSUTF8StringEncoding];
	[self.owner handleClosed:reasonString];
}

- (void)URLSession:(NSURLSession *)session
	webSocketTask:(NSURLSessionWebSocketTask *)webSocketTask
didOpenWithProtocol:(NSString *)protocol API_AVAILABLE(ios(13.0), macos(10.15)) {
	WebSocketClientObjc *owner = self.owner;
	if (owner != nil)
		[owner handleOpened];
}

// fires for connection failures (before open) and when the task finishes
- (void)URLSession:(NSURLSession *)session
           task:(NSURLSessionTask *)task
didCompleteWithError:(NSError *)error {
	WebSocketClientObjc *owner = self.owner;
	if (owner == nil)
		return;

	if (error != nil &&
		!([error.domain isEqual:NSURLErrorDomain] && error.code == NSURLErrorCancelled))
		[owner handleError:error];
	[owner handleClosed:[error localizedDescription]];
}

@end

@interface WebSocketClientObjc ()

@property (nonatomic, strong) WebSocketClientObjcSessionDelegate *sessionDelegate;
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSURLSessionWebSocketTask *webSocketTask API_AVAILABLE(ios(13.0), macos(10.15));

@property (nonatomic, copy) NSURL *url;
@property (nonatomic, copy) NSArray *protocols;
@property (nonatomic, copy) void (^eventHandler)(NSString *, NSString *);
@property (nonatomic, copy) void (^receivedMessage)(NSString *);
@property (nonatomic, copy) void (^receivedData)(uint8_t *, NSUInteger);

@property (nonatomic, assign) BOOL opened;
@property (nonatomic, assign) BOOL closed;
@property (nonatomic, assign) BOOL errored;

@end

@implementation WebSocketClientObjc

- (instancetype)initWithUrl:(NSString *)url
				  protocols:(NSArray *)protocols
			   eventHandler:(void (^)(NSString *, NSString *))eventHandler
		  onReceivedMessage:(void (^)(NSString *))receivedMessage
			onReceivedData:(void (^)(uint8_t *, NSUInteger))receivedData {
	self = [super init];
	if (self != nil) {
		_url = [NSURL URLWithString:url];
		_protocols = protocols != nil ? [protocols copy] : @[];
		self.eventHandler = eventHandler;
		self.receivedMessage = receivedMessage;
		self.receivedData = receivedData;
	}
	return self;
}

- (void)connect {
	if (_webSocketTask != nil && !_closed)
		return; // already open or connecting

	self.opened = NO;
	self.closed = NO;
	self.errored = NO;

	if (@available(iOS 13.0, macOS 10.15, *)) {
		WebSocketClientObjcSessionDelegate *delegate =
			[[WebSocketClientObjcSessionDelegate alloc] init];
		delegate.owner = self;
		self.sessionDelegate = delegate;

		NSURLSessionConfiguration *configuration =
			[NSURLSessionConfiguration defaultSessionConfiguration];
		self.session = [NSURLSession sessionWithConfiguration:configuration
													delegate:delegate
											   delegateQueue:nil];

		if ([_protocols count] > 0)
			self.webSocketTask = [_session webSocketTaskWithURL:_url protocols:_protocols];
		else
			self.webSocketTask = [_session webSocketTaskWithURL:_url];

		[self.webSocketTask resume];
	} else {
		if (self.eventHandler != nil)
			self.eventHandler(@"error", @"Native WebSockets require iOS 13.0 or later");
		[self handleClosed:nil];
		return;
	}

	[self receiveNext];
}

#pragma mark - Sending

- (void)sendString:(NSString *)data {
	if (@available(iOS 13.0, macOS 10.15, *)) {
		if (_webSocketTask == nil)
			return;
		NSURLSessionWebSocketMessage *message =
			[[NSURLSessionWebSocketMessage alloc] initWithString:data];
		[self sendMessage:message];
	}
}

- (void)sendData:(const uint8_t *)data length:(NSUInteger)length {
	if (@available(iOS 13.0, macOS 10.15, *)) {
		if (_webSocketTask == nil)
			return;
		NSURLSessionWebSocketMessage *message =
			[[NSURLSessionWebSocketMessage alloc] initWithData:
				[NSData dataWithBytes:data
							   length:sizeof(unsigned char) * length]];
		[self sendMessage:message];
	}
}

- (void)sendMessage:(NSURLSessionWebSocketMessage *)message API_AVAILABLE(ios(13.0), macos(10.15)) {
	if (_webSocketTask == nil)
		return;

	__weak WebSocketClientObjc *weakSelf = self;
	[_webSocketTask sendMessage:message completionHandler:^(NSError *sendError) {
		__strong WebSocketClientObjc *strongSelf = weakSelf;
		if (strongSelf == nil)
			return;
		if (sendError != nil)
			[strongSelf handleError:sendError];
	}];
}

#pragma mark - Closing

- (void)disconnect {
	if (_webSocketTask == nil || _closed)
		return;

	if (@available(iOS 13.0, macOS 10.15, *)) {
		// Begin the WebSocket close handshake (code 1000, like SocketRocket did);
		// the "close" event is delivered by didCloseWithCloseCode:reason:.
		[_webSocketTask cancelWithCloseCode:NSURLSessionWebSocketCloseCodeNormalClosure
									 reason:nil];
	} else {
		[_webSocketTask cancel];
	}
}

- (void)setHeaderKey:(NSString *)key withValue:(NSString *)value {
	// URLSessionWebSocketTask cannot send custom handshake headers before iOS 17
	// (webSocketTaskWithRequest:headers:). Same TODO as the SocketRocket glue had.
}

- (void)dispose {
	// Silent teardown (Uno-side GC path): suppress events, tear everything down.
	self.closed = YES;
	[_webSocketTask cancel];
	if (_session != nil)
		[_session invalidateAndCancel];
	self.webSocketTask = nil;
	self.session = nil;
	self.sessionDelegate = nil;
}

- (void)dealloc {
	// NSURLSession retains its delegate until it is invalidated. If this wrapper
	// is dropped from the Uno side without a prior disconnect, break it here.
	[_session invalidateAndCancel];
}

#pragma mark - Event delivery

- (void)handleOpened {
	if (_opened)
		return;
	self.opened = YES;
	if (self.eventHandler != nil)
		self.eventHandler(@"open", nil);
}

- (void)handleClosed:(NSString *)reason {
	if (_closed)
		return;
	self.closed = YES;
	if (self.eventHandler != nil)
		self.eventHandler(@"close", reason);
	[self invalidateSession];
}

- (void)handleError:(NSError *)error {
	if (_errored || _closed)
		return; // errors after close are teardown noise; the same transport failure reaches us via several task callbacks
	self.errored = YES;
	NSString *message = [error localizedDescription];
	if (self.eventHandler != nil)
		self.eventHandler(@"error", message != nil ? message : @"WebSocket error");
}

- (void)invalidateSession {
	if (_session != nil)
		[_session invalidateAndCancel];
	self.webSocketTask = nil;
	self.session = nil;
}

#pragma mark - Receiving

- (void)receiveNext API_AVAILABLE(ios(13.0), macos(10.15)) {
	if (_closed || _webSocketTask == nil)
		return;

	__weak WebSocketClientObjc *weakSelf = self;
	[_webSocketTask receiveMessageWithCompletionHandler:
		^(NSURLSessionWebSocketMessage *message, NSError *error) {
			if (@available(iOS 13.0, macOS 10.15, *)) {
				__strong WebSocketClientObjc *strongSelf = weakSelf;
				if (strongSelf == nil)
					return;

				if (error != nil) {
					NSString *domain = [error domain];
					if ([domain isEqual:NSURLErrorDomain] &&
						[error code] == NSURLErrorCancelled) {
						// The task closed; normally the "close" event already
						// arrived via didCloseWithCloseCode:reason:, and this is
						// the fallback if it never fires (handleClosed is
						// idempotent).
						[strongSelf handleClosed:nil];
					} else {
						[strongSelf handleError:error];
						[strongSelf handleClosed:[error localizedDescription]];
					}
					return;
				}

				NSString *text = nil;
				NSData *data = nil;
				switch ([message type]) {
					case NSURLSessionWebSocketMessageTypeString:
						text = [message string];
						if (text != nil && strongSelf.receivedMessage != nil)
							strongSelf.receivedMessage(text);
						break;
					case NSURLSessionWebSocketMessageTypeData:
						data = [message data];
						if (data != nil && strongSelf.receivedData != nil)
							strongSelf.receivedData((uint8_t *)[data bytes], [data length]);
						break;
					default:
						break;
				}
				[strongSelf receiveNext];
			}
		}];
}

@end