#import <fcntl.h>
#import <sys/types.h>
#import <sys/uio.h>
#import <unistd.h>
#import <AppKit/AppKit.h>
#import "GlyphImageSource.h"

@implementation GlyphImageSource

- (id)initWithObject:(id)theObject
{
    [super initWithObject:theObject];

    _fontNames = [[[NSFontManager sharedFontManager] availableFonts] copy];
    _drawWindow = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 128, 128)
					      styleMask:NSBorderlessWindowMask
						backing:NSBackingStoreBuffered defer:NO];

    return self;
}


- (id)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    _fontNames = [[coder decodeObject] retain];
    _drawWindow = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 128, 128)
					      styleMask:NSBorderlessWindowMask
						backing:NSBackingStoreBuffered defer:NO];
    return self;
}


- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
    [coder encodeObject:_fontNames];
}


- (NSImage *)typeImage;
{
    return [NSImage imageNamed:@"GlyphImageSource"];
}


- (NSString *)descriptor
{
    return @"Random glyphs";
}


- (id)nextImageIdentifier
{
    int			devRandom = open("/dev/random", O_RDONLY, 0);
    unsigned int	bytesRead, randomNumbers[10], fontNum;
    NSFont		*font;
    NSRect		glyphRect;
    
    if (devRandom == -1) return nil;
    
    bytesRead = read(devRandom, randomNumbers, sizeof(int) * 10);
    close(devRandom);

    if (bytesRead < sizeof(unsigned int) * 8) return nil;
    
    fontNum = randomNumbers[0] % [_fontNames count];
    font = [NSFont fontWithName:[_fontNames objectAtIndex:fontNum] size:0.0];
    
    if ([[_drawWindow contentView] lockFocusIfCanDraw])
    {
	glyphRect = [font boundingRectForGlyph:randomNumbers[1] % ([font numberOfGlyphs] - 1) + 1];
	[[_drawWindow contentView] unlockFocus];
	if (glyphRect.size.width == 0 || glyphRect.size.height == 0) return nil;
    }
    else
	return nil;
    
    _imageCount++;
    
    return [NSString stringWithFormat:@"%d %d %d %d %d %d %d %d", fontNum,
					randomNumbers[1] % ([font numberOfGlyphs] - 1) + 1,
					randomNumbers[2] % 256, randomNumbers[3] % 256, randomNumbers[4] % 256,
					randomNumbers[5] % 256, randomNumbers[6] % 256, randomNumbers[7] % 256];
}


- (NSImage *)imageForIdentifier:(id)identifier
{
    NSScanner		*scanner = nil;
    int			fontNum, glyphNum, foreRed, foreGreen, foreBlue, backRed, backGreen, backBlue;
    NSFont		*font = nil;
    NSBezierPath	*glyphPath = [NSBezierPath bezierPath];
    NSRect		glyphRect, destRect = NSZeroRect;
    NSAffineTransform	*transform = [NSAffineTransform transform];
    NSImage		*image = nil;
    NSBitmapImageRep	*imageRep = nil;
    
    if (![identifier isKindOfClass:[NSString class]]) return nil;

    scanner = [NSScanner scannerWithString:identifier];
    [scanner scanInt:&fontNum];		[scanner scanString:@" " intoString:nil];
    [scanner scanInt:&glyphNum];	[scanner scanString:@" " intoString:nil];
    [scanner scanInt:&foreRed];		[scanner scanString:@" " intoString:nil];
    [scanner scanInt:&foreGreen];	[scanner scanString:@" " intoString:nil];
    [scanner scanInt:&foreBlue];	[scanner scanString:@" " intoString:nil];
    [scanner scanInt:&backRed];		[scanner scanString:@" " intoString:nil];
    [scanner scanInt:&backGreen];	[scanner scanString:@" " intoString:nil];
    [scanner scanInt:&backBlue];	[scanner scanString:@" " intoString:nil];
    
    font = [NSFont fontWithName:[_fontNames objectAtIndex:fontNum] size:0.0];
    if (font == nil) return nil;
     
    if ([[_drawWindow contentView] lockFocusIfCanDraw])
    {
	[glyphPath moveToPoint:NSZeroPoint];
	[glyphPath appendBezierPathWithGlyph:glyphNum inFont:font];
	
	glyphRect = [glyphPath bounds];
    
	if (glyphRect.size.width == 0 || glyphRect.size.height == 0)
	{
	    [[_drawWindow contentView] unlockFocus];
	    return nil;
	}
	
	if (glyphRect.size.width > glyphRect.size.height)
	{
	    destRect.size.width = 128;
	    destRect.size.height = 256 / glyphRect.size.width * glyphRect.size.height;
	}
	else
	{
	    destRect.size.width = 128 / glyphRect.size.height * glyphRect.size.width;
	    destRect.size.height = 128;
	}
    
	[transform scaleBy:destRect.size.width / glyphRect.size.width];
	[transform translateXBy:glyphRect.origin.x * -1 yBy:glyphRect.origin.y * -1];
	[glyphPath transformUsingAffineTransform:transform];
    
	image = [[[NSImage alloc] initWithSize:destRect.size] autorelease];
	if (image != nil)
	{
	    // draw the background color
	    [[NSColor colorWithCalibratedRed:backRed/256.0 green:backGreen/256.0 blue:backBlue/256.0
				       alpha:1.0] set];
	    [[NSBezierPath bezierPathWithRect:destRect] fill];
	    
	    // draw the glyph in the foreground color
	    [[NSColor colorWithCalibratedRed:foreRed/256.0 green:foreGreen/256.0 blue:foreBlue/256.0
				       alpha:1.0] set];
	    [glyphPath fill];
	    
	    // grab the image
	    imageRep = [[[NSBitmapImageRep alloc] initWithFocusedViewRect:destRect] autorelease];
    
	    if (imageRep == nil)
		image = nil;
	    else
	    {
		[image addRepresentation:imageRep];
		[image setScalesWhenResized:YES];
	    }
	}
	
	[[_drawWindow contentView] unlockFocus];
	
	return image;
    }

    return nil;
}

@end
