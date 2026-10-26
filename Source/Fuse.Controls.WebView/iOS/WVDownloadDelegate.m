#import "WVDownloadDelegate.h"

@interface WVDownloadDelegate ()
@property(strong) NSMapTable* destinations;
@end

@implementation WVDownloadDelegate

-(instancetype)init
{
	self = [super init];
	if (self)
		self.destinations = [NSMapTable weakToStrongObjectsMapTable];
	return self;
}

-(NSString*)uniquePathInDirectory:(NSString*)directory filename:(NSString*)filename
{
	NSFileManager* fileManager = [NSFileManager defaultManager];
	NSString* path = [directory stringByAppendingPathComponent:filename];
	if (![fileManager fileExistsAtPath:path])
		return path;

	NSString* base = [filename stringByDeletingPathExtension];
	NSString* extension = [filename pathExtension];

	int i = 1;
	while (YES)
	{
		NSString* candidate = extension.length > 0
			? [NSString stringWithFormat:@"%@ (%d).%@", base, i, extension]
			: [NSString stringWithFormat:@"%@ (%d)", base, i];

		path = [directory stringByAppendingPathComponent:candidate];
		if (![fileManager fileExistsAtPath:path])
			return path;

		i++;
	}

	return path;
}

-(void)download:(WKDownload*)download
	decideDestinationUsingResponse:(NSURLResponse*)response
	suggestedFilename:(NSString*)suggestedFilename
	completionHandler:(void (^)(NSURL* destination))completionHandler
{
	NSString* filename = suggestedFilename.length > 0 ? suggestedFilename : @"download";

	NSFileManager* fileManager = [NSFileManager defaultManager];
	NSArray* paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	NSString* documents = paths.firstObject;
	NSString* downloads = [documents stringByAppendingPathComponent:@"Downloads"];
	[fileManager createDirectoryAtPath:downloads withIntermediateDirectories:YES attributes:nil error:nil];

	NSURL* downloadsUrl = [NSURL fileURLWithPath:downloads isDirectory:YES];
	[downloadsUrl setResourceValue:@(YES) forKey:NSURLIsExcludedFromBackupKey error:nil];

	NSString* path = [self uniquePathInDirectory:downloads filename:filename];
	[self.destinations setObject:path forKey:download];

	completionHandler([NSURL fileURLWithPath:path]);
}

-(void)download:(WKDownload*)download didFinishDownloadingToURL:(NSURL*)location
{
	NSString* path = [self.destinations objectForKey:download];
	[self.destinations removeObjectForKey:download];

	if (path != nil && ![path isEqualToString:location.path])
	{
		NSFileManager* fileManager = [NSFileManager defaultManager];
		[fileManager removeItemAtPath:path error:nil];
		if (![fileManager moveItemAtPath:location.path toPath:path error:nil])
			path = location.path;
	}
	else if (path == nil)
	{
		path = location.path;
	}

	NSString* url = download.originalRequest.URL.absoluteString;
	if (url == nil)
		url = @"";

	if (self.onFinished != nil)
		self.onFinished(url, path != nil ? path : @"");
}

-(void)download:(WKDownload*)download didFailWithError:(NSError*)error
{
	[self.destinations removeObjectForKey:download];
}

@end
