//
//  MacOSaiXImageUsageEditor.m
//  MacOSaiX
//
//  Created by Frank Midgley on 12/22/06.
//  Copyright 2006 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXImageUsageEditor.h"

#import "MacOSaiXMosaic.h"


@implementation MacOSaiXImageUsageEditor


- (id)initWithMosaicView:(MosaicView *)inMosaic
{
	if (self = [super initWithMosaicView:inMosaic])
	{
	}
	
	return self;
}


- (NSString *)editorNibName
{
	return @"Image Usage Editor";
}


- (NSString *)title
{
	return NSLocalizedString(@"Image Usage", @"");
}


- (NSSize)minimumViewSize
{
	return NSMakeSize(230.0, 269.0);
}


- (void)beginEditing
{
	[[self mosaicView] setTargetImageFraction:1.0];
	
	MacOSaiXMosaic	*mosaic = [[self mosaicView] mosaic];
	
	[imageUseCountPopUp selectItemWithTag:[mosaic imageUseCount]];
	[imageReuseSlider setIntValue:[mosaic imageReuseDistance]];
	[imageCropLimitSlider setIntValue:[mosaic imageCropLimit]];
	
	samplePoint = NSMakePoint(0.5, 0.5);
}


- (void)embellishMosaicViewInRect:(NSRect)rect
{
	[super embellishMosaicViewInRect:rect];
	
	[[NSGraphicsContext currentContext] saveGraphicsState];
	
	NSRect				imageBounds = [[self mosaicView] imageBounds];
	[[NSBezierPath bezierPathWithRect:imageBounds] addClip];
	
	float				radius = sqrtf(powf(NSWidth(imageBounds), 2.0) + powf(NSHeight(imageBounds), 2.0)) * [imageReuseSlider floatValue] / 100.0;
	NSPoint				scaledSamplePoint = NSMakePoint(samplePoint.x * NSWidth(imageBounds) + NSMinX(imageBounds), 
														samplePoint.y * NSHeight(imageBounds) + NSMinY(imageBounds));
	NSAffineTransform	*transform = [NSAffineTransform transform];
	[transform translateXBy:scaledSamplePoint.x yBy:scaledSamplePoint.y];
	[transform concat];
	
	[[NSGraphicsContext currentContext] setPatternPhase:scaledSamplePoint];
	
	NSBezierPath		*uniquenessPath = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(-radius, -radius, radius * 2.0, radius * 2.0)];
	[[NSColor colorWithCalibratedWhite:0.0 alpha:0.25] set];
	[uniquenessPath fill];
	[[NSColor colorWithPatternImage:[NSImage imageNamed:@"UniqueX"]] set];
	[uniquenessPath fill];
	[[NSColor darkGrayColor] set];
	[uniquenessPath stroke];
		
	NSBezierPath		*samplePointPath = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(-5.0, -5.0, 10.0, 10.0)];
	[[NSColor whiteColor] set];
	[samplePointPath fill];
	[[NSColor darkGrayColor] set];
	[samplePointPath stroke];
	
	[[NSGraphicsContext currentContext] restoreGraphicsState];
}


- (void)handleEventInMosaicView:(NSEvent *)event
{
	NSRect	imageBounds = [[self mosaicView] imageBounds];
	NSPoint	mouseLocation = [[self mosaicView] convertPoint:[event locationInWindow] fromView:nil], 
			scaledSamplePoint = NSMakePoint(samplePoint.x * NSWidth(imageBounds), 
											samplePoint.y * NSHeight(imageBounds));
	
	if ([event type] == NSLeftMouseDown)
	{
		float	maxDragDistance = sqrtf(powf(NSWidth(imageBounds), 2.0) + 
										powf(NSHeight(imageBounds), 2.0)), 
				currentReuseDistance = [[[self mosaicView] mosaic] imageReuseDistance] / 100.0 * maxDragDistance, 
				clickDistance = sqrtf(powf(mouseLocation.x - NSMinX(imageBounds) - scaledSamplePoint.x, 2.0) + 
									  powf(mouseLocation.y - NSMinY(imageBounds) - scaledSamplePoint.y, 2.0));
		
		if (fabsf(clickDistance) < 5.0 || clickDistance < currentReuseDistance - 5.0)
			moving = YES;
		else if (fabsf(currentReuseDistance - clickDistance) < 5.0)
			resizing = YES;
	}
	else if ([event type] == NSLeftMouseDragged)
	{
		if (moving)
		{
			samplePoint = NSMakePoint((mouseLocation.x - NSMinX(imageBounds)) / NSWidth(imageBounds), 
									  (mouseLocation.y - NSMinY(imageBounds)) / NSHeight(imageBounds));
			
			if (samplePoint.x < 0.0)
				samplePoint.x = 0.0;
			if (samplePoint.x > 1.0)
				samplePoint.x = 1.0;
			if (samplePoint.y < 0.0)
				samplePoint.y = 0.0;
			if (samplePoint.y > 1.0)
				samplePoint.y = 1.0;
			
			[[self mosaicView] setNeedsDisplay:YES];
		}
		else if (resizing)
		{
			float	dragDistance = sqrtf(powf(mouseLocation.x - NSMinX(imageBounds) - scaledSamplePoint.x, 2.0) + 
										 powf(mouseLocation.y - NSMinY(imageBounds) - scaledSamplePoint.y, 2.0)), 
					maxDragDistance = sqrtf(powf(NSWidth(imageBounds), 2.0) + 
											powf(NSHeight(imageBounds), 2.0));
			
			if (dragDistance >= maxDragDistance)
				[imageReuseSlider setFloatValue:100.0];
			else
				[imageReuseSlider setFloatValue:dragDistance / maxDragDistance * 100.0];
			
			[self setImageReuseDistance:self];
		}
	}
	else if ([event type] == NSLeftMouseUp)
	{
		moving = NO;
		resizing = NO;
	}
}


- (IBAction)setImageUseCount:(id)sender
{
	[[[self mosaicView] mosaic] setImageUseCount:[[imageUseCountPopUp selectedItem] tag]];
	
	[[self mosaicView] setNeedsDisplay:YES];
}


- (IBAction)setImageReuseDistance:(id)sender
{
	[[[self mosaicView] mosaic] setImageReuseDistance:[imageReuseSlider intValue]];
	
	[[self mosaicView] setNeedsDisplay:YES];
}


- (IBAction)setImageCropLimit:(id)sender
{
}


- (void)endEditing
{
}


//- (void)dealloc
//{
//	[super dealloc];
//}


@end
