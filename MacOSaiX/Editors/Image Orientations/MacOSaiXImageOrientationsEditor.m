//
//  MacOSaiXImageOrientationsEditor.m
//  MacOSaiX
//
//  Created by Frank Midgley on 12/22/06.
//  Copyright 2006 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXImageOrientationsEditor.h"

#import "MacOSaiX.h"
#import "MacOSaiXMosaic.h"
#import "MacOSaiXImageOrientations.h"


@implementation MacOSaiXImageOrientationsEditor


- (id)initWithDelegate:(id<MacOSaiXMosaicEditorDelegate>)delegate
{
	if (self = [super initWithDelegate:delegate])
	{
	}
	
	return self;
}


- (NSString *)editorNibName
{
	return @"Image Orientations Editor";
}


- (NSString *)title
{
	return NSLocalizedString(@"Image Orientations", @"");
}


- (NSArray *)plugInClasses
{
	return [(MacOSaiX *)[NSApp delegate] imageOrientationsPlugIns];
}


- (NSString *)plugInTitleFormat
{
	return NSLocalizedString(@"%@", @"");
}


- (void)setMosaicDataSource:(id<MacOSaiXDataSource>)dataSource
{
	[[[self delegate] mosaic] setImageOrientations:(id<MacOSaiXImageOrientations>)dataSource];
	
	[[self delegate] embellishmentNeedsDisplay];
}


- (id<MacOSaiXDataSource>)mosaicDataSource
{
	return [[[self delegate] mosaic] imageOrientations];
}


- (void)embellishMosaicView:(MosaicView *)mosaicView inRect:(NSRect)rect;
{
	[super embellishMosaicView:mosaicView inRect:rect];

	static	NSBezierPath	*vectorPath = nil;
	if (!vectorPath)
	{
		vectorPath = [[NSBezierPath bezierPath] retain];
		
			// Start with the head.
		//NSMakeRect(-4.0, -5.0, 8.0, 12.0)
		[vectorPath moveToPoint:NSMakePoint(0.0, -4.0)];
		[vectorPath curveToPoint:NSMakePoint(0.0, 7.0) controlPoint1:NSMakePoint(-5.0, -4.0) controlPoint2:NSMakePoint(-5.0, 7.0)];
		[vectorPath curveToPoint:NSMakePoint(0.0, -4.0) controlPoint1:NSMakePoint(5.0, 7.0) controlPoint2:NSMakePoint(5.0, -4.0)];
		
			// Then the shoulders.
		[vectorPath moveToPoint:NSMakePoint(-8.0, -7.0)];
		[vectorPath curveToPoint:NSMakePoint(8.0, -7.0) controlPoint1:NSMakePoint(-8.0, -2.0) controlPoint2:NSMakePoint(8.0, -2.0)];
		[vectorPath lineToPoint:NSMakePoint(-8.0, -7.0)];
		
			// Finish with the box outline.
		[vectorPath moveToPoint:NSMakePoint(-12.0, -8.0)];
		[vectorPath lineToPoint:NSMakePoint(12.0, -8.0)];
		[vectorPath lineToPoint:NSMakePoint(12.0, 8.0)];
		[vectorPath lineToPoint:NSMakePoint(-12.0, 8.0)];
		[vectorPath lineToPoint:NSMakePoint(-12.0, -8.0)];
	}
	
		// Get the bounds of the mosaic within the mosaic view.
	NSRect							imageBounds = [mosaicView imageBounds];
	
		// Start by lightening the whole mosaic.
	[[NSColor colorWithCalibratedWhite:1.0 alpha:0.2] set];
	NSRectFillUsingOperation(NSIntersectionRect(rect, imageBounds), NSCompositeSourceOver);
			   
		// Draw a darkened vector field over the mosaic.
	[[NSColor colorWithCalibratedWhite:0.0 alpha:0.6] set];
	id<MacOSaiXImageOrientations>	imageOrientations = [[[self delegate] mosaic] imageOrientations];
	int								xCount = NSWidth(imageBounds) / 30, 
									yCount = NSHeight(imageBounds) / 30;
	float							xSize = NSWidth(imageBounds) / xCount, 
									ySize = NSHeight(imageBounds) / yCount;
	float							x, y;
	for (y = ySize / 2.0; y < NSHeight(imageBounds); y += ySize)
		for (x = xSize / 2.0; x < NSWidth(imageBounds); x += xSize)
		{
			float	angle = [imageOrientations imageOrientationAtPoint:NSMakePoint(x, y) inRectOfSize:imageBounds.size];
			
			NSAffineTransform	*transform = [NSAffineTransform transform];
			[transform translateXBy:x + NSMinX(imageBounds) yBy:y + NSMinY(imageBounds)];
			[transform rotateByDegrees:-angle];
			[[transform transformBezierPath:vectorPath] fill];
		}
			
	
	// TBD: What API would be required for the radial plug-in to draw its focus point?
}


- (void)handleEvent:(NSEvent *)event inMosaicView:(MosaicView *)mosaicView;
{
		// Convert the event location to the target image's space.
	NSRect	mosaicBounds = [mosaicView imageBounds];
	NSPoint	targetLocation = [mosaicView convertPoint:[event locationInWindow] fromView:nil];
	targetLocation.x -= NSMinX(mosaicBounds);
	targetLocation.y -= NSMinY(mosaicBounds);
	targetLocation.x *= [[self targetImage] size].width / NSWidth(mosaicBounds);
	targetLocation.y *= [[self targetImage] size].height / NSHeight(mosaicBounds);
	
	NSEvent	*newEvent = [NSEvent mouseEventWithType:[event type] 
										   location:targetLocation 
									  modifierFlags:[event modifierFlags] 
										  timestamp:[event timestamp] 
									   windowNumber:[event windowNumber] 
											context:[event context] 
										eventNumber:[event eventNumber] 
										 clickCount:[event clickCount] 
										   pressure:[event pressure]];
	
	BOOL	plugInHandledEvent = NO;
	
		// Pass along mouse events to the plug in's editor.
	switch ([event type])
	{
		case NSLeftMouseDown:
		case NSRightMouseDown:
		case NSOtherMouseDown:
			plugInHandledEvent = [plugInEditor mouseDownInMosaic:newEvent];
			break;
		case NSLeftMouseDragged:
		case NSRightMouseDragged:
		case NSOtherMouseDragged:
			plugInHandledEvent = [plugInEditor mouseDraggedInMosaic:newEvent];
			break;
		case NSLeftMouseUp:
		case NSRightMouseUp:
		case NSOtherMouseUp:
			plugInHandledEvent = [plugInEditor mouseUpInMosaic:newEvent];
			break;
		default:
			break;
	}
	
	if (!plugInHandledEvent)
		[super handleEvent:event inMosaicView:mosaicView];
}


- (void)dataSource:(id<MacOSaiXDataSource>)dataSource settingsDidChange:(NSString *)changeDescription
{
	[[self delegate] embellishmentNeedsDisplay];
}


@end
