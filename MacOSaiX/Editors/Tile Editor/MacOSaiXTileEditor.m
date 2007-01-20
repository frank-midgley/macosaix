//
//  MacOSaiXTileEditor.m
//  MacOSaiX
//
//  Created by Frank Midgley on 12/22/06.
//  Copyright 2006 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXTileEditor.h"

#import "MacOSaiXMosaic.h"
#import "Tiles.h"


@implementation MacOSaiXTileEditor


- (id)initWithMosaic:(MosaicView *)inMosaic
{
	if (self = [super initWithMosaicView:inMosaic])
	{
	}
	
	return self;
}


- (NSString *)editorNibName
{
	return @"Tile Editor";
}


- (NSString *)title
{
	return NSLocalizedString(@"Tile Editor", @"");
}


- (void)beginEditing
{
	[[self mosaicView] setTargetImageFraction:0.0];
	
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(tileImageDidChange:) 
												 name:MacOSaiXTileImageDidChangeNotification 
											   object:[[self mosaicView] mosaic]];
}


- (void)embellishMosaicViewInRect:(NSRect)rect
{
	[super embellishMosaicViewInRect:rect];
	
	NSRect				mosaicBounds = [[self mosaicView] imageBounds];
	float				minX = NSMinX(mosaicBounds), 
						minY = NSMinY(mosaicBounds), 
						width = NSWidth(mosaicBounds), 
						height = NSHeight(mosaicBounds);
	NSBezierPath		*unitOutline = [[self selectedTile] unitOutline];
	
		// Draw the tile's outline with a 4pt thick dashed line.
	NSAffineTransform	*transform = [NSAffineTransform transform];
	[transform translateXBy:minX yBy:minY];
	[transform scaleXBy:width yBy:height];
	NSBezierPath		*bezierPath = [transform transformBezierPath:unitOutline];
	[bezierPath setLineWidth:4];
	
	float				dashes[2] = {5.0, 5.0};
	[bezierPath setLineDash:dashes count:2 phase:animationPhase];
	[[NSColor colorWithCalibratedWhite:1.0 alpha:0.5] set];
	[bezierPath stroke];
	
	[bezierPath setLineDash:dashes count:2 phase:(animationPhase + 5) % 10];
	[[NSColor colorWithCalibratedWhite:0.0 alpha:0.5] set];
	[bezierPath stroke];
	
	transform = [NSAffineTransform transform];
	[transform translateXBy:minX + 0.5 yBy:minY - 0.5];
	[transform scaleXBy:width yBy:height];
	[[NSColor colorWithCalibratedWhite:0.0 alpha:0.5] set];	// darken
	[[transform transformBezierPath:unitOutline] stroke];
	
	transform = [NSAffineTransform transform];
	[transform translateXBy:minX - 0.5 yBy:minY + 0.5];
	[transform scaleXBy:width yBy:height];
	[[NSColor colorWithCalibratedWhite:1.0 alpha:0.5] set];	// lighten
	[[transform transformBezierPath:unitOutline] stroke];
}


- (void)handleEventInMosaicView:(NSEvent *)event
{
	[self setSelectedTile:[[self mosaicView] tileAtPoint:[[self mosaicView] convertPoint:[event locationInWindow] fromView:nil]]];
}


- (void)setSelectedTile:(MacOSaiXTile *)tile
{
	NSRect				mosaicBounds = [[self mosaicView] imageBounds];
    NSAffineTransform	*transform = [NSAffineTransform transform];
	[transform translateXBy:NSMinX(mosaicBounds) yBy:NSMinY(mosaicBounds)];
	[transform scaleXBy:NSWidth(mosaicBounds) yBy:NSHeight(mosaicBounds)];
	
    if (selectedTile)
    {
		if ([animateSelectedTileTimer isValid])
			[animateSelectedTileTimer invalidate];
		[animateSelectedTileTimer release];
		
		// Mark the previously highlighted area for re-display.
		NSBezierPath		*bezierPath = [transform transformBezierPath:[selectedTile unitOutline]];
		[[self mosaicView] setNeedsDisplayInRect:NSInsetRect([bezierPath bounds], -2.0, -2.0)];
	}
	
	[selectedTile autorelease];
	selectedTile = [tile retain];
	
    if (selectedTile)
    {
		// Mark the newly highlighted area for re-display.
		NSBezierPath		*bezierPath = [transform transformBezierPath:[selectedTile unitOutline]];
		[[self mosaicView] setNeedsDisplayInRect:NSInsetRect([bezierPath bounds], -2.0, -2.0)];
		
		if (!animateSelectedTileTimer)
		{
			// Create a timer to animate the selected tile ten times per second.
			animateSelectedTileTimer = [[NSTimer scheduledTimerWithTimeInterval:0.1
																		 target:(id)self
																	   selector:@selector(animateSelectedTile:)
																	   userInfo:nil
																		repeats:YES] retain];
		}
	}
	else
	{
	}
}


- (MacOSaiXTile *)selectedTile
{
	return selectedTile;
}


- (void)animateSelectedTile:(NSTimer *)timer
{
    animationPhase = ++animationPhase % 10;
	
	NSRect				mosaicBounds = [[self mosaicView] imageBounds];
    NSAffineTransform	*transform = [NSAffineTransform transform];
	[transform translateXBy:NSMinX(mosaicBounds) yBy:NSMinY(mosaicBounds)];
	[transform scaleXBy:NSWidth(mosaicBounds) yBy:NSHeight(mosaicBounds)];
    NSBezierPath		*bezierPath = [transform transformBezierPath:[[self selectedTile] unitOutline]];
	
    [[self mosaicView] setNeedsDisplayInRect:NSInsetRect([bezierPath bounds], -2.0, -2.0)];
}


- (void)tileImageDidChange:(NSNotification *)notification
{
	// TODO: update the "choose image" sheet if it's displaying the changed tile
}


#pragma mark -
#pragma mark Hand picked images


- (IBAction)chooseImageForSelectedTile:(id)sender
{
	//	MacOSaiXTileEditor	*tileEditor = [[MacOSaiXTileEditor alloc] init];
	//	
	//	[tileEditor chooseImageForTile:[mosaicView highlightedTile] 
	//					modalForWindow:[self window] 
	//					 modalDelegate:self 
	//					didEndSelector:@selector(chooseImageForSelectedTileDidEnd)];
}


- (void)chooseImageForSelectedTilePanelDidEnd
{
}


- (IBAction)removeChosenImageForSelectedTile:(id)sender
{
	[[[self mosaicView] mosaic] removeHandPickedImageForTile:[self selectedTile]];
}


#pragma mark -


- (void)centerViewOnSelectedTile:(id)sender
{
    NSPoint			contentOrigin = NSMakePoint(NSMidX([[[self selectedTile] unitOutline] bounds]),
												NSMidY([[[self selectedTile] unitOutline] bounds]));
    NSScrollView	*mosaicScrollView = [mosaicView enclosingScrollView];
	
    contentOrigin.x *= [mosaicView frame].size.width;
    contentOrigin.x -= [[mosaicScrollView contentView] bounds].size.width / 2;
    if (contentOrigin.x < 0) contentOrigin.x = 0;
    if (contentOrigin.x + [[mosaicScrollView contentView] bounds].size.width >
		[mosaicView frame].size.width)
		contentOrigin.x = [mosaicView frame].size.width - 
			[[mosaicScrollView contentView] bounds].size.width;
	
    contentOrigin.y *= [mosaicView frame].size.height;
    contentOrigin.y -= [[mosaicScrollView contentView] bounds].size.height / 2;
    if (contentOrigin.y < 0) contentOrigin.y = 0;
    if (contentOrigin.y + [[mosaicScrollView contentView] bounds].size.height >
		[mosaicView frame].size.height)
		contentOrigin.y = [mosaicView frame].size.height - 
			[[mosaicScrollView contentView] bounds].size.height;
	
    [[mosaicScrollView contentView] scrollToPoint:contentOrigin];
    [mosaicScrollView reflectScrolledClipView:[mosaicScrollView contentView]];
}


- (void)endEditing
{
	// TBD: close NSOpenPanel?
	
	[[NSNotificationCenter defaultCenter] removeObserver:self 
													name:MacOSaiXTileImageDidChangeNotification 
												  object:[[self mosaicView] mosaic]];
	
	[self setSelectedTile:nil];
}


//- (void)dealloc
//{
//	[super dealloc];
//}


@end
