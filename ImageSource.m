#import "ImageSource.h"


@implementation ImageSource

- (id)initWithObject:(id)theObject
{
    [super init];
    _imageCount = 0;
    return self;
}


- (id)initWithCoder:(NSCoder *)coder
{
    _imageCount = [[coder decodeObject] intValue];
    return self;
}


- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:[NSNumber numberWithInt:_imageCount]];
}


- (NSImage *)typeImage {return nil;}
- (NSString *)descriptor {return nil;}

- (id)nextImageIdentifier {return nil;}

- (int)imageCount {return _imageCount;}

- (NSImage *)imageForIdentifier:(id)identifier
{
    NSData		*imageData;
    NSImage		*image = nil;
    
    // the default method only accepts URL's
    if (![identifier isKindOfClass:[NSURL class]]) return nil;
    
    NS_DURING
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
