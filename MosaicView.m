#import "MosaicView.h"

@implementation MosaicView

- (id)initWithFrame:(NSRect)frame
{
    if (self = [super initWithFrame:frame])
    {
	[self setBoundsSize:frame.size];
	_image = nil;
    }
    return self;
}

- (void)setImage:(NSImage*)image
{
    NSImage	*oldImage;
    
    if (image != _image)
    {
	oldImage = _image;
	_image = [image retain];
	[oldImage release];
	oldImage = nil;
	[_image setScalesWhenResized:YES];
	[self setBoundsOrigin:NSMakePoint(0, 0)];
	[self setBoundsSize:[_image size]];
    }
}

- (void)drawRect:(NSRect)rect
{
    [self lockFocus];
//    [self setBoundsSize:[_image size]];
    [_image compositeToPoint:NSMakePoint(0, 0) operation:NSCompositeCopy];
    [self unlockFocus];
}

@end
