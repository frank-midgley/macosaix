#import "ImageSource.h"


@implementation ImageSource

- (id)init
{
    self = [super init];
	if (self)
	{
		_imageCount = 0;
		_pauseLock = [[[NSLock alloc] init] retain];
	}
    return self;
}


- (BOOL)hasMoreImages {return NO;}

- (void)pause
{
	[_pauseLock lock];
}

- (void)resume
{
	[_pauseLock unlock];
}

- (void)waitWhilePaused
{
	[_pauseLock lock];
	[_pauseLock unlock];
}

- (BOOL)canRefetchImages
{
	return YES;
}


- (NSImage *)image {return nil;}
- (NSString *)descriptor {return nil;}

- (id)nextImageIdentifier {return nil;}

- (int)imageCount {return _imageCount;}

- (NSImage *)imageForIdentifier:(id)identifier
{
    NSData		*imageData = nil;
    NSImage		*image = nil;
    
    // the default method only accepts URL's
    if (![identifier isKindOfClass:[NSURL class]]) return nil;
    
    NS_DURING
		if ([identifier isFileURL])
			imageData = [NSData dataWithContentsOfFile:[identifier path]];
		else
			imageData = [identifier resourceDataUsingCache:NO];
    NS_HANDLER
		if (imageData != nil) imageData = nil;
    NS_ENDHANDLER
    if (imageData != nil)
    {
		NS_DURING
			image = [[NSImage alloc] initWithData:imageData];
		NS_HANDLER
			if (image != nil) image = nil;
		NS_ENDHANDLER
		if (image != nil)
		{
			if ([image isValid] && [image size].width > 0 && [image size].height > 0)
			{
				[image autorelease];
				[image setCachedSeparately:NO];
				[image setScalesWhenResized:YES];
				[image setDataRetained:NO];	// saves much memory if image size is reduced
			}
			else
			{
				[image release];
				image = nil;
			}
		}
    }
    
    return image;
}

@end
