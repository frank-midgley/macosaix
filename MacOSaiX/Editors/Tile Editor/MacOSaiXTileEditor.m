//
//  MacOSaiXTileEditor.m
//  MacOSaiX
//
//  Created by Frank Midgley on 12/22/06.
//  Copyright 2006 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXTileEditor.h"

#import "MacOSaiX.h"
#import "MacOSaiXImageCache.h"
#import "MacOSaiXImageMatch.h"
#import "MacOSaiXImageSourceEnumerator.h"
#import "MacOSaiXMosaic.h"
#import "MacOSaiXSourceImage.h"
#import "MacOSaiXWarningController.h"
#import "NSImage+MacOSaiX.h"
#import "PreferencesController.h"
#import "Tiles.h"


@interface MacOSaiXTileContentEditor (PrivateMethods)
- (void)populateGUI;
@end


@implementation MacOSaiXTileContentEditor


- (NSString *)editorNibName
{
	return @"Tile Editor";
}


- (NSString *)title
{
	return NSLocalizedString(@"Tile Content", @"");
}


- (NSSize)minimumViewSize
{
	return NSMakeSize(240.0, 200.0);
}


- (void)awakeFromNib
{
	NSImage		*dontUseImage = [[[NSImage imageNamed:@"Don't Use"] copy] autorelease];
	[dontUseImage setScalesWhenResized:YES];
	[dontUseImage setSize:NSMakeSize(16.0, 16.0)];
	[[dontUseThisImagePopUp itemAtIndex:0] setImage:dontUseImage];
}


- (void)beginEditing
{
	[self populateGUI];
	
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(tileImageDidChange:) 
												 name:MacOSaiXTileContentsDidChangeNotification 
											   object:[[self delegate] mosaic]];
}


- (NSRect)selectionRect
{
	float	minX = MIN(mouseDownPoint.x, mouseDragPoint.x), 
			maxX = MAX(mouseDownPoint.x, mouseDragPoint.x), 
			minY = MIN(mouseDownPoint.y, mouseDragPoint.y), 
			maxY = MAX(mouseDownPoint.y, mouseDragPoint.y);
	
	return NSMakeRect(minX, minY, maxX - minX, maxY - minY);
}


- (NSBezierPath *)outlineOfSelectedTiles
{
	NSBezierPath	*outlineOfSelectedTiles = [NSBezierPath bezierPath];
	NSEnumerator	*selectedTileEnumerator = [[self selectedTiles] objectEnumerator];
	MacOSaiXTile	*selectedTile = nil;
	
	while (selectedTile = [selectedTileEnumerator nextObject])
		[outlineOfSelectedTiles appendBezierPath:[selectedTile outline]];
	
	return outlineOfSelectedTiles;
}


- (void)embellishMosaicView:(MosaicView *)mosaicView inRect:(NSRect)rect;
{
	[super embellishMosaicView:mosaicView inRect:rect];
	
	NSRect				mosaicBounds = [mosaicView imageBounds];
	NSSize				targetImageSize = [[[[self delegate] mosaic] targetImage] size];
	float				minX = NSMinX(mosaicBounds), 
						minY = NSMinY(mosaicBounds), 
						width = NSWidth(mosaicBounds), 
						height = NSHeight(mosaicBounds);
	NSAffineTransform	*transform = [NSAffineTransform transform];
	[transform translateXBy:minX yBy:minY];
	[transform scaleXBy:width / targetImageSize.width 
					yBy:height / targetImageSize.height];
	
	if (!NSEqualPoints(mouseDragPoint, NSZeroPoint))
	{
		// The user is doing a drag selection.  Highlight the dragged rectangle as well as the tiles that will be selected.
		
		NSBezierPath		*selectionPath = [NSBezierPath bezierPathWithRect:[self selectionRect]];
		BOOL				commandKeyDown = (([[NSApp currentEvent] modifierFlags] & NSCommandKeyMask) != 0);
		
			// Create a path containing all selected tile's outlines.
		NSBezierPath	*selectedTilesOutline = (commandKeyDown ? [self outlineOfSelectedTiles] : [NSBezierPath bezierPath]);
		[selectedTilesOutline transformUsingAffineTransform:transform];
		
			// Lighten the rest of the mosaic view
		NSBezierPath		*nonSelectedPath = [NSBezierPath bezierPathWithRect:mosaicBounds];
		[nonSelectedPath appendBezierPath:[selectionPath bezierPathByReversingPath]];
		[nonSelectedPath appendBezierPath:[selectedTilesOutline bezierPathByReversingPath]];
		[[NSColor colorWithCalibratedWhite:1.0 alpha:0.5] set];
		[nonSelectedPath fill];
		
			// Darken the selected tiles' outline
		[selectedTilesOutline setLineWidth:2.0];
		[[NSColor colorWithCalibratedWhite:0.0 alpha:0.5] set];
		[selectedTilesOutline stroke];
		
			// Darken the tiles to be selected.
		NSBezierPath	*tilesToBeSelectedOutline = [NSBezierPath bezierPath];
		NSEnumerator	*tilesToBeSelectedEnumerator = [[mosaicView tilesInRect:[self selectionRect]] objectEnumerator];
		MacOSaiXTile	*tileToBeSelected = nil;
		while (tileToBeSelected = [tilesToBeSelectedEnumerator nextObject])
			[tilesToBeSelectedOutline appendBezierPath:[tileToBeSelected outline]];
		[tilesToBeSelectedOutline transformUsingAffineTransform:transform];
		[[NSColor colorWithCalibratedWhite:0.0 alpha:0.25] set];
		[tilesToBeSelectedOutline stroke];
		
			// Darken the selection rect.
		[selectionPath setLineWidth:2];
		[[NSColor colorWithCalibratedWhite:0.0 alpha:0.5] set];
		[selectionPath stroke];
	}
	else if ([[self selectedTiles] count] > 0)
	{
			// Create a path containing all selected tile's outlines.
		NSBezierPath	*selectedTilesOutline = [self outlineOfSelectedTiles];
		[selectedTilesOutline transformUsingAffineTransform:transform];
		
			// Lighten the rest of the mosaic view
		NSBezierPath		*dimPath = [NSBezierPath bezierPathWithRect:mosaicBounds];
		[dimPath appendBezierPath:[selectedTilesOutline bezierPathByReversingPath]];
		[[NSColor colorWithCalibratedWhite:1.0 alpha:0.5] set];
		[dimPath fill];
		
			// Darken the selected tiles' outline
		[selectedTilesOutline setLineWidth:2.0];
		[[NSColor colorWithCalibratedWhite:0.0 alpha:0.5] set];
		[selectedTilesOutline stroke];
		
			// Add details if only one tile is selected.
		if ([[self selectedTiles] count] == 1)
		{
			MacOSaiXTile		*selectedTile = [[self selectedTiles] lastObject];
			
			switch ([selectedTile fillStyle])
			{
				case fillWithUniqueMatch:
				{
					MacOSaiXImageMatch	*bestMatch = [selectedTile uniqueImageMatch];
					float				curY = NSMinY([selectedTilesOutline bounds]) - 18.0;
					
					if (bestMatch)
					{
						MacOSaiXSourceImage	*bestSourceImage = [bestMatch sourceImage];
						
							// Display the description of the image being displayed.
						NSString		*matchName = [[[bestSourceImage enumerator] workingImageSource] descriptionForIdentifier:[bestSourceImage imageIdentifier]];
						if (!matchName)
							matchName = NSLocalizedString(@"No description available", @"");
						NSDictionary	*attributes = [NSDictionary dictionaryWithObject:[NSFont boldSystemFontOfSize:0.0] 
																				  forKey:NSFontAttributeName];
						NSSize		stringSize = [matchName sizeWithAttributes:attributes];
						[matchName drawAtPoint:NSMakePoint(NSMidX([selectedTilesOutline bounds]) - stringSize.width / 2.0, curY) withAttributes:attributes];
						curY -= 18.0;
						
							// Display the source of the image being displayed.
						NSString	*sourceLabel = NSLocalizedString(@"Source: ", @"");
						stringSize = [sourceLabel sizeWithAttributes:nil];
						float		sourceWidth = stringSize.width + 2.0;
						NSImage		*sourceImage = [[[[[bestSourceImage enumerator] workingImageSource] image] copy] autorelease];
						[sourceImage setScalesWhenResized:YES];
						[sourceImage setSize:NSMakeSize([sourceImage size].width / [sourceImage size].height * 16.0, 16.0)];
						sourceWidth += [sourceImage size].width + 4.0;
						id			sourceDescription = [[[bestSourceImage enumerator] workingImageSource] briefDescription];
						if ([sourceDescription isKindOfClass:[NSString class]])
							sourceWidth += [(NSString *)sourceDescription sizeWithAttributes:nil].width;
						else
							sourceWidth += [(NSAttributedString *)sourceDescription size].width;
						float		leftEdge = NSMidX([selectedTilesOutline bounds]) - sourceWidth / 2.0;
						[sourceLabel drawAtPoint:NSMakePoint(leftEdge, curY) withAttributes:nil];
						[sourceImage drawAtPoint:NSMakePoint(leftEdge + stringSize.width + 2.0, curY - 0.0) 
										fromRect:NSZeroRect 
									   operation:NSCompositeSourceOver 
										fraction:1.0];
						if ([sourceDescription isKindOfClass:[NSString class]])
							[(NSString *)sourceDescription drawAtPoint:NSMakePoint(leftEdge + stringSize.width + 2.0 + [sourceImage size].width + 4.0, curY) 
														withAttributes:nil];
						else
							[(NSAttributedString *)sourceDescription drawAtPoint:NSMakePoint(leftEdge + stringSize.width + 4.0 + [sourceImage size].width + 4.0, curY)];
						curY -= 14.0;
						
							// Display the match value of the image being displayed.
						[[NSString stringWithFormat:NSLocalizedString(@"Match: %.0f%%", @""), [bestMatch matchValue]] drawAtPoint:NSMakePoint(leftEdge, curY) 
																												   withAttributes:nil];
						curY -= 14.0;
						
							// Display the crop amount of the image being displayed.
						float	imageArea = NSWidth(mosaicBounds) * NSHeight(mosaicBounds), 
								tileArea = NSWidth([selectedTilesOutline bounds]) * NSHeight([selectedTilesOutline bounds]);
						[[NSString stringWithFormat:NSLocalizedString(@"Cropping: %.0f%%", @""), (imageArea - tileArea) / imageArea * 100.0] drawAtPoint:NSMakePoint(leftEdge, curY) withAttributes:nil];
					}
					else
					{
						NSString	*noMatchString = NSLocalizedString(@"No match available", @"");
						NSSize		stringSize = [noMatchString sizeWithAttributes:nil];
						[noMatchString drawAtPoint:NSMakePoint(NSMidX([selectedTilesOutline bounds]) - stringSize.width / 2.0, curY) withAttributes:nil];
					}
					
					break;
				}
				case fillWithHandPicked:
				{
					MacOSaiXImageMatch	*handPickedMatch = [selectedTile userChosenImageMatch];
					
					if (handPickedMatch)
					{
						// TODO
					}
					
					break;
				}
				case fillWithTargetImage:
				{
					// TODO: create the image that shows the portion of the target image
					
					break;
				}
				case fillWithColor:
				case fillWithAverageTargetColor:
				{
					NSColor	*tileColor = [selectedTile fillColor];
					
					if (!tileColor)
						tileColor = [NSColor blackColor];
					
					// TODO?
					
					break;
				}
			}
		}
	}
}


- (void)handleEvent:(NSEvent *)event inMosaicView:(MosaicView *)mosaicView;
{
	NSPoint	mousePoint = [mosaicView convertPoint:[event locationInWindow] fromView:nil];
	BOOL	commandKeyDown = (([event modifierFlags] & NSCommandKeyMask) != 0);
	
	if ([event type] == NSLeftMouseDown)
	{
		mouseDownPoint = mousePoint;
		mouseDragPoint = NSZeroPoint;
	}
	else if ([event type] == NSLeftMouseDragged)
	{
		mouseDragPoint = mousePoint;
		
		[[self delegate] embellishmentNeedsDisplay];
	}
	else if ([event type] == NSLeftMouseUp)
	{
		if (NSEqualPoints(mouseDragPoint, NSZeroPoint))
		{
			MacOSaiXTile	*selectedTile = [mosaicView tileAtPoint:mousePoint];
			
			mouseDownPoint = mouseDragPoint = NSZeroPoint;
			
			if (!selectedTile && !commandKeyDown)
				[self setSelectedTiles:nil];
			else if (selectedTile)
			{
				if (!commandKeyDown)
					[self setSelectedTiles:[NSArray arrayWithObject:selectedTile]];
				else
				{
					NSMutableArray	*tiles = [[[self selectedTiles] mutableCopy] autorelease];
					if (!tiles)
						tiles = [NSMutableArray array];
					
					unsigned		tileIndex = [tiles indexOfObjectIdenticalTo:selectedTile];
					if (tileIndex == NSNotFound)
						[tiles addObject:selectedTile];
					else
						[tiles removeObjectAtIndex:tileIndex];
					
					[self setSelectedTiles:tiles];
				}
			}
		}
		else
		{
			mouseDragPoint = mousePoint;
			
			NSRect	selectionRect = [self selectionRect];

			mouseDownPoint = mouseDragPoint = NSZeroPoint;

			if (commandKeyDown)
			{
				NSMutableSet	*tiles = ([self selectedTiles] ? [NSMutableSet setWithArray:[self selectedTiles]] : [NSMutableSet set]);
				NSSet			*newTiles = [NSSet setWithArray:[mosaicView tilesInRect:selectionRect]];
				
//				if ([[tiles intersectSet:newTiles] count] == [newTiles count])
//					[self setSelectedTiles:[[tiles minusSet:newTiles] allObjects]];
//				else
				[tiles unionSet:newTiles];
				[self setSelectedTiles:[tiles allObjects]];
			}
			else
				[self setSelectedTiles:[mosaicView tilesInRect:selectionRect]];
		}
	}
}


- (NSImage *)browserIcon
{
	static NSImage	*browserIcon = nil;
	
	if (!browserIcon)
	{
		CFURLRef	browserURL = nil;
		OSStatus	status = LSGetApplicationForURL((CFURLRef)[NSURL URLWithString:@"http://www.apple.com/"], 
													kLSRolesViewer,
													NULL,
													&browserURL);
		if (status == noErr)
			browserIcon = [[[NSWorkspace sharedWorkspace] iconForFile:[(NSURL *)browserURL path]] retain];
		else
		{
			NSString	*safariPath = [[NSWorkspace sharedWorkspace] fullPathForApplication:@"Safari"];
			
			if (safariPath)
				browserIcon = [[[NSWorkspace sharedWorkspace] iconForFile:safariPath] retain];
			// TBD: else ???
		}
		
		[browserIcon setSize:NSMakeSize(16.0, 16.0)];
	}
	
	return browserIcon;
}


- (NSImage *)selectedPortionOfTargetImage
{
	NSBezierPath		*outlineOfSelectedTiles = [self outlineOfSelectedTiles];
	NSRect				outlineBounds = [outlineOfSelectedTiles bounds], 
						portionImageBounds = NSInsetRect(outlineBounds, -NSWidth(outlineBounds) * 0.05, -NSHeight(outlineBounds) * 0.05);
	NSImage				*portionImage = [[NSImage alloc] initWithSize:portionImageBounds.size], 
						*targetImage = [[[self delegate] mosaic] targetImage];
	NSRect				targetImageBounds = NSMakeRect(0.0, 0.0, [targetImage size].width, [targetImage size].height);
	NSAffineTransform	*transform = [NSAffineTransform transform];
	[transform translateXBy:NSWidth(outlineBounds) * 0.05 - NSMinX(outlineBounds) 
						yBy:NSHeight(outlineBounds) * 0.05 - NSMinY(outlineBounds)];
	
	[portionImage lockFocus];
		
		[transform set];
		
		[[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
		
			// Start with a lightened copy of the target image.
		[targetImage compositeToPoint:NSMakePoint(0.0, 0.0) fromRect:targetImageBounds operation:NSCompositeCopy fraction:0.25];
		
			// Now fill the selected tiles with the normal image.
		[[NSGraphicsContext currentContext] saveGraphicsState];
			[outlineOfSelectedTiles addClip];
			[targetImage compositeToPoint:NSMakePoint(0.0, 0.0) fromRect:targetImageBounds operation:NSCompositeCopy fraction:1.0];
		[[NSGraphicsContext currentContext] restoreGraphicsState];
		
			// Finish by darkening the outline of the selected tiles.
		[[NSColor colorWithCalibratedWhite:0.0 alpha:0.75] set];
		[outlineOfSelectedTiles setLineWidth:2.0];
		[outlineOfSelectedTiles stroke];
		
	[portionImage unlockFocus];
	
	return [portionImage autorelease];
}


- (void)populateGUI
{
	int	tileCount = [[self selectedTiles] count];
	
	if (tileCount == 0)
	{
		[fillStylePopUp setEnabled:NO];
		[fillStylePopUp selectItemWithTag:fillWithUniqueMatch];
		[fillStyleTabView selectTabViewItemWithIdentifier:@"No Tile Selected"];
	}
	else
	{
		[fillStylePopUp setEnabled:YES];
		
			// Determine which fill styles are in use by the selected tiles.
		BOOL					fillSelectionWithUniqueMatch = NO, 
								fillSelectionWithHandPicked = NO, 
								fillSelectionWithTargetImage = NO, 
								fillSelectionWithColor = NO, 
								multipleFillStyles = NO, 
								multipleUniqueMatches = NO, 
								fillSelectionWithAverageTargetColor = NO, 
								fillSelectionWithBlackColor = NO, 
								fillSelectionWithClearColor = NO, 
								fillSelectionWithCustomColor = NO, 
								multipleFillColors = NO;
		MacOSaiXImageMatch		*uniqueMatch = nil;
		NSColor					*fillColor = nil;
		NSEnumerator			*selectedTileEnumerator = [[self selectedTiles] objectEnumerator];
		MacOSaiXTile			*selectedTile = nil;
		while (selectedTile = [selectedTileEnumerator nextObject])
		{
			switch ([selectedTile fillStyle])
			{
				case fillWithUniqueMatch:
					fillSelectionWithUniqueMatch = YES;
					if (fillSelectionWithHandPicked || fillSelectionWithTargetImage || fillSelectionWithColor)
						multipleFillStyles = YES;
					if (!uniqueMatch)
						uniqueMatch = [selectedTile uniqueImageMatch];
					else if (!multipleUniqueMatches && ![[uniqueMatch sourceImage] isEqualTo:[[selectedTile uniqueImageMatch] sourceImage]])
						multipleUniqueMatches = YES;
					break;
				case fillWithHandPicked:
					fillSelectionWithHandPicked = YES;
					if (fillSelectionWithUniqueMatch || fillSelectionWithTargetImage || fillSelectionWithColor)
						multipleFillStyles = YES;
					break;
				case fillWithTargetImage:
					fillSelectionWithTargetImage = YES;
					if (fillSelectionWithUniqueMatch || fillSelectionWithHandPicked || fillSelectionWithColor)
						multipleFillStyles = YES;
					break;
				case fillWithColor:
				case fillWithAverageTargetColor:
					fillSelectionWithColor = YES;
					if (fillSelectionWithUniqueMatch || fillSelectionWithHandPicked || fillSelectionWithTargetImage)
						multipleFillStyles = YES;
					else
					{
						if ([selectedTile fillStyle] == fillWithAverageTargetColor)
						{
							fillSelectionWithAverageTargetColor = YES;
							if (fillSelectionWithBlackColor || fillSelectionWithClearColor || fillSelectionWithCustomColor)
								multipleFillColors = YES;
						}
						else if ([[selectedTile fillColor] isEqualTo:[NSColor blackColor]])
						{
							fillSelectionWithBlackColor = YES;
							if (fillSelectionWithAverageTargetColor || fillSelectionWithClearColor || fillSelectionWithCustomColor)
								multipleFillColors = YES;
						}
						else if ([[selectedTile fillColor] isEqualTo:[NSColor clearColor]])
						{
							fillSelectionWithClearColor = YES;
							if (fillSelectionWithAverageTargetColor || fillSelectionWithBlackColor || fillSelectionWithCustomColor)
								multipleFillColors = YES;
						}
						else
						{
							fillSelectionWithCustomColor = YES;
							if (fillSelectionWithAverageTargetColor || fillSelectionWithBlackColor || fillSelectionWithClearColor || 
								(fillColor && ![[selectedTile fillColor] isEqualTo:fillColor]))
								multipleFillColors = YES;
						}
					}
					
					if (!multipleFillColors)
						fillColor = [selectedTile fillColor];
					
					break;
			}
		}
		
		if (multipleFillStyles)
		{
			// If multiple styles are in use then no editing can be done except to switch all selected tiles to the same fill style.  The pop-up will show which styles are in use.
			
			if (fillSelectionWithUniqueMatch)
				[fillStylePopUp selectItemWithTag:fillWithUniqueMatch];
			else if (fillSelectionWithHandPicked)
				[fillStylePopUp selectItemWithTag:fillWithHandPicked];
			else if (fillSelectionWithTargetImage)
				[fillStylePopUp selectItemWithTag:fillWithTargetImage];
			else if (fillSelectionWithColor)
				[fillStylePopUp selectItemWithTag:fillWithColor];
			
			if (fillSelectionWithUniqueMatch)
				[[[fillStylePopUp menu] itemWithTag:fillWithUniqueMatch] setState:NSMixedState];
			if (fillSelectionWithHandPicked)
				[[[fillStylePopUp menu] itemWithTag:fillWithHandPicked] setState:NSMixedState];
			if (fillSelectionWithTargetImage)
				[[[fillStylePopUp menu] itemWithTag:fillWithTargetImage] setState:NSMixedState];
			if (fillSelectionWithColor)
				[[[fillStylePopUp menu] itemWithTag:fillWithColor] setState:NSMixedState];
			
			[fillStyleTabView selectTabViewItemWithIdentifier:@"Multiple Styles Selected"];
		}
		else
		{
			// Only one fill style is in use by the selected tiles but the tiles may have different settings for the style, e.g. different fill colors.
			
			MacOSaiXTile			*selectedTile = [[self selectedTiles] lastObject];
			
			switch ([selectedTile fillStyle])
			{
				case fillWithUniqueMatch:
				{
					[fillStylePopUp selectItemWithTag:fillWithUniqueMatch];
					
					if (multipleUniqueMatches)
						[fillStyleTabView selectTabViewItemWithIdentifier:@"Multiple Tiles Selected"];
					else
					{
						[fillStyleTabView selectTabViewItemWithIdentifier:[NSString stringWithFormat:@"%d", fillWithUniqueMatch]];
						
						if (uniqueMatch)
						{
							NSImageRep	*uniqueMatchRep = [[uniqueMatch sourceImage] imageRepAtSize:NSZeroSize];
							NSImage		*uniqueMatchImage = [[[NSImage alloc] initWithSize:[uniqueMatchRep size]] autorelease];
							[uniqueMatchImage addRepresentation:uniqueMatchRep];
							
							[bestMatchImageView setImage:uniqueMatchImage];
						}
						else
							[bestMatchImageView setImage:nil];
						
						if ([[uniqueMatch sourceImage] contextURL])
						{
							if (!openBestMatchInBrowserButton)
							{
								openBestMatchInBrowserButton = [[[NSButton alloc] initWithFrame:NSMakeRect(NSMaxX([bestMatchImageView frame]) - 28.0, 5.0, 16.0, 16.0)] autorelease];
								[openBestMatchInBrowserButton setBordered:NO];
								[openBestMatchInBrowserButton setTitle:nil];
								[openBestMatchInBrowserButton setImage:[self browserIcon]];
								[openBestMatchInBrowserButton setImagePosition:NSImageOnly];
								[openBestMatchInBrowserButton setAutoresizingMask:(NSViewMinXMargin | NSViewMaxYMargin)];
								[openBestMatchInBrowserButton setTarget:self];
								[openBestMatchInBrowserButton setAction:@selector(openWebPageForCurrentImage:)];
								[bestMatchImageView addSubview:openBestMatchInBrowserButton];
							}
						}
						else if (openBestMatchInBrowserButton)
						{
							[openBestMatchInBrowserButton removeFromSuperview];
							openBestMatchInBrowserButton = nil;
						}
					}
					
					break;
				}
				case fillWithHandPicked:
				{
					[fillStylePopUp selectItemWithTag:fillWithHandPicked];
					[fillStyleTabView selectTabViewItemWithIdentifier:[NSString stringWithFormat:@"%d", fillWithHandPicked]];
					MacOSaiXImageMatch	*handPickedMatch = [selectedTile userChosenImageMatch];
					
					if (handPickedMatch)
					{
						NSImageRep			*handPickedRep = [[handPickedMatch sourceImage] imageRepAtSize:NSZeroSize];
						NSImage				*handPickedImage = [[[NSImage alloc] initWithSize:[handPickedRep size]] autorelease];
						[handPickedImage addRepresentation:handPickedRep];
						
						[handPickedImageView setImage:handPickedImage];
					}
					else
						[handPickedImageView setImage:nil];
					
					break;
				}
				case fillWithTargetImage:
				{
					[fillStylePopUp selectItemWithTag:fillWithTargetImage];
					[fillStyleTabView selectTabViewItemWithIdentifier:[NSString stringWithFormat:@"%d", fillWithTargetImage]];
					
					// TODO: create the image that shows the portion(s) of the target image
					[portionOfTargetImageView setImage:[self selectedPortionOfTargetImage]];
					
					break;
				}
				case fillWithColor:
				case fillWithAverageTargetColor:
				{
					[fillStylePopUp selectItemWithTag:fillWithColor];
					[fillStyleTabView selectTabViewItemWithIdentifier:[NSString stringWithFormat:@"%d", fillWithColor]];
					
					if (multipleFillColors)
					{
						[[solidColorMatrix cellAtRow:0 column:0] setState:(fillSelectionWithAverageTargetColor ? NSMixedState : NSOffState)];
						[[solidColorMatrix cellAtRow:1 column:0] setState:(fillSelectionWithBlackColor ? NSMixedState : NSOffState)];
						[[solidColorMatrix cellAtRow:2 column:0] setState:(fillSelectionWithClearColor ? NSMixedState : NSOffState)];
						[[solidColorMatrix cellAtRow:3 column:0] setState:(fillSelectionWithCustomColor ? NSMixedState : NSOffState)];
					}
					else
					{
						if ([selectedTile fillStyle] == fillWithAverageTargetColor)
							[solidColorMatrix selectCellAtRow:0 column:0];
						else if ([fillColor isEqualTo:[NSColor blackColor]])
							[solidColorMatrix selectCellAtRow:1 column:0];
						else if ([fillColor isEqualTo:[NSColor clearColor]])
							[solidColorMatrix selectCellAtRow:2 column:0];
						else
							[solidColorMatrix selectCellAtRow:3 column:0];
					}
					
					[solidColorWell setColor:fillColor];
					
					break;
				}
			}
		}
	}
}


- (void)setSelectedTiles:(NSArray *)tiles
{
	if (![tiles isEqualToArray:selectedTiles])
	{
		[selectedTiles autorelease];
		selectedTiles = [tiles retain];
		
// TODO: zoom the mosaic to center on the selection
//		NSRect				mosaicBounds = [[self mosaicView] imageBounds];
//		NSSize				targetImageSize = [[[[self delegate] mosaic] targetImage] size];
//		NSAffineTransform	*transform = [NSAffineTransform transform];
//		[transform translateXBy:NSMinX(mosaicBounds) yBy:NSMinY(mosaicBounds)];
//		[transform scaleXBy:NSWidth(mosaicBounds) / targetImageSize.width 
//						yBy:NSHeight(mosaicBounds) / targetImageSize.height];
//
//		if (NO)
//		{
//			// Calculate the currently centered point of the mosaic image independent of the zoom factor.
//			NSRect	frame = [[[[self mosaicView] enclosingScrollView] contentView] frame],
//					visibleRect = [mosaicView visibleRect];
//			
//			// TODO: Sync the slider with the current zoom setting.
//			
//			// Update the frame and bounds of the mosaic view.
//			frame.size.width *= zoom;
//			frame.size.height *= zoom;
//			[mosaicView setFrame:frame];
//			[mosaicView setBounds:frame];
//			
//			// Reset the scroll position so that the previous center point is as close to the center as possible.
//			[[[self mosaicView] enclosingScrollView] scrollRectToVisible:];
//			
//			[mosaicView setInLiveRedraw:[NSNumber numberWithBool:YES]];
//			[mosaicView performSelector:@selector(setInLiveRedraw:) withObject:[NSNumber numberWithBool:NO] afterDelay:0.0];
//		}
		
		[self populateGUI];
		
		[[self delegate] embellishmentNeedsDisplay];
	}
}


- (NSArray *)selectedTiles
{
	return selectedTiles;
}


- (IBAction)setFillStyle:(id)sender
{
	NSEnumerator	*selectedTileEnumerator = [[self selectedTiles] objectEnumerator];
	MacOSaiXTile	*selectedTile = nil;
	while (selectedTile = [selectedTileEnumerator nextObject])
		[selectedTile setFillStyle:[[fillStylePopUp selectedItem] tag]];
	
	[self populateGUI];
}


#pragma mark -
#pragma mark Best match from sources


- (IBAction)dontUseImageInSelectedTile:(id)sender
{
	if ([[self selectedTiles] count] != 1)
		NSBeep();
	else if (![MacOSaiXWarningController warningIsEnabled:@"Disallowing Image"] || 
			 [MacOSaiXWarningController runAlertForWarning:@"Disallowing Image" 
													 title:NSLocalizedString(@"Are you sure you don't want to use the image in the selected tile?", @"") 
												   message:NSLocalizedString(@"All of the image sources must be searched again to find a new image for the tile.", @"") 
											  buttonTitles:[NSArray arrayWithObjects:NSLocalizedString(@"Don't Use", @""), NSLocalizedString(@"Cancel", @""), nil]] == 0)
	{
		MacOSaiXTile	*selectedTile = [[self selectedTiles] objectAtIndex:0];
		
		[selectedTile disallowImage:[[selectedTile uniqueImageMatch] sourceImage]];
	}
}


- (IBAction)dontUseSelectedImageInThisMosaic:(id)sender
{
	if ([[self selectedTiles] count] != 1)
		NSBeep();
	else if (![MacOSaiXWarningController warningIsEnabled:@"Disallowing Image"] || 
			 [MacOSaiXWarningController runAlertForWarning:@"Disallowing Image" 
													 title:NSLocalizedString(@"Are you sure you don't want to use the image in the selected tile?", @"") 
												   message:NSLocalizedString(@"All of the image sources must be searched again to find a new image for the tile.", @"") 
											  buttonTitles:[NSArray arrayWithObjects:NSLocalizedString(@"Don't Use", @""), NSLocalizedString(@"Cancel", @""), nil]] == 0)
	{
		MacOSaiXTile	*selectedTile = [[self selectedTiles] objectAtIndex:0];
		
		[[[self delegate] mosaic] disallowImage:[[selectedTile uniqueImageMatch] sourceImage]];
	}
}


- (IBAction)dontUseSelectedImageInAnyMosaic:(id)sender
{
	if ([[self selectedTiles] count] != 1)
		NSBeep();
	else if (![MacOSaiXWarningController warningIsEnabled:@"Disallowing Image"] || 
			 [MacOSaiXWarningController runAlertForWarning:@"Disallowing Image" 
													 title:NSLocalizedString(@"Are you sure you don't want to use the image in the selected tile?", @"") 
												   message:NSLocalizedString(@"All of the image sources must be searched again to find a new image for the tile.", @"") 
											  buttonTitles:[NSArray arrayWithObjects:NSLocalizedString(@"Don't Use", @""), NSLocalizedString(@"Cancel", @""), nil]] == 0)
	{
		MacOSaiXTile	*selectedTile = [[self selectedTiles] objectAtIndex:0];
		
		[(MacOSaiX *)[NSApp delegate] disallowImage:[[selectedTile uniqueImageMatch] sourceImage]];
	}
}


- (IBAction)restoreImages:(id)sender
{
	[[MacOSaiXPreferencesController sharedController] showDisallowedImages:self];
}


#pragma mark -
#pragma mark Hand picked images


- (IBAction)chooseImageForTile:(id)sender
{
	NSOpenPanel	*openPanel = [NSOpenPanel openPanel];
	[openPanel setCanChooseFiles:YES];
	[openPanel setCanChooseDirectories:NO];
	if ([openPanel respondsToSelector:@selector(setMessage:)])
		[openPanel setMessage:NSLocalizedString(@"Choose an image to be displayed in this tile:", @"")];
	[openPanel setPrompt:NSLocalizedString(@"Choose", @"")];
	[openPanel setDelegate:self];
	
// TODO:
//	[openPanel setAccessoryView:accessoryView];
//	NSSize	superSize = [[accessoryView superview] frame].size;
//	[accessoryView setFrame:NSMakeRect(5.0, 5.0, superSize.width - 10.0, superSize.height - 10.0)];
//	[accessoryView setAutoresizingMask:NSViewWidthSizable];
	
	[openPanel beginSheetForDirectory:nil
								 file:nil
								types:[NSImage imageFileTypes]
					   modalForWindow:[(NSView *)[self delegate] window]	// TBD: add -window to delegate protocol?
						modalDelegate:self
					   didEndSelector:@selector(chooseImagePanelDidEnd:returnCode:contextInfo:)
						  contextInfo:nil];
}


// TODO: show how the chosen image will be cropped and its match value
//- (void)panelSelectionDidChange:(id)sender
//{
//	if ([[sender URLs] count] == 0)
//	{
//		[chosenImageBox setTitle:[NSString stringWithFormat:newImageTitleFormat, NSLocalizedString(@"No File Selected", @"")]];
//		[chosenImageView setImage:nil];
//		[chosenMatchQualityTextField setStringValue:@"--"];
//		[chosenPercentCroppedTextField setStringValue:@"--"];
//	}
//	else
//	{
//		// This shouldn't be necessary but updating the views right away often crashes because of some interaction with the AppKit thread that is creating a preview of the selected image.
//		[self performSelector:@selector(updateUserChosenViewsForImageAtPath:) withObject:[[sender filenames] objectAtIndex:0] afterDelay:0.0];
//	}
//}
//
//
//
//- (void)updateUserChosenViewsForImageAtPath:(NSString *)imagePath
//{
//	NSString			*chosenImageIdentifier = imagePath, 
//	*chosenImageName = [[NSFileManager defaultManager] displayNameAtPath:chosenImageIdentifier];
//	
//	[chosenImageBox setTitle:[NSString stringWithFormat:newImageTitleFormat, chosenImageName]];
//	
//	NSImage				*chosenImage = [[[NSImage alloc] initWithContentsOfFile:chosenImageIdentifier] autorelease];
//	[chosenImage setCachedSeparately:YES];
//	[chosenImage setCacheMode:NSImageCacheNever];
//	
//	if (chosenImage)
//	{
//		NSImageRep			*originalRep = [[chosenImage representations] objectAtIndex:0];
//		NSSize				imageSize = NSMakeSize([originalRep pixelsWide], [originalRep pixelsHigh]);
//		[originalRep setSize:imageSize];
//		[chosenImage setSize:imageSize];
//		
//		float				croppedPercentage = 0.0;
//		[chosenImageView setImage:[self highlightTileOutlineInImage:chosenImage croppedPercentage:&croppedPercentage]];
//		
//		[chosenPercentCroppedTextField setStringValue:[NSString stringWithFormat:@"%.0f%%", croppedPercentage]];
//		
//		// Calculate how well the chosen image matches the selected tile.
//		[[MacOSaiXImageCache sharedImageCache] cacheImage:chosenImage withIdentifier:chosenImageIdentifier fromSource:nil];
//		NSBitmapImageRep	*chosenImageRep = [[MacOSaiXImageCache sharedImageCache] imageRepAtSize:[[tile bitmapRep] size] 
//																					  forIdentifier:chosenImageIdentifier 
//																						 fromSource:nil];
//		chosenMatchValue = [[MacOSaiXImageMatcher sharedMatcher] compareImageRep:[tile bitmapRep]  
//																		withMask:[tile maskRep] 
//																	  toImageRep:chosenImageRep
//																	previousBest:1.0];
//		[chosenMatchQualityTextField setStringValue:[NSString stringWithFormat:@"%.0f%%", 100.0 - chosenMatchValue * 100.0]];
//	}
//}


- (void)chooseImagePanelDidEnd:(NSOpenPanel *)openPanel returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	[openPanel orderOut:self];
	
	if ([openPanel respondsToSelector:@selector(setMessage:)])
		[openPanel setMessage:@""];
	
	if (returnCode == NSOKButton)
	{
		MacOSaiXImageSourceEnumerator	*handPickedEnumerator = [[[self delegate] mosaic] handPickedImageSourceEnumerator];
		NSEnumerator	*selectedTileEnumerator = [[self selectedTiles] objectEnumerator];
		MacOSaiXTile	*selectedTile = nil;
		while (selectedTile = [selectedTileEnumerator nextObject])
		{
			MacOSaiXSourceImage	*sourceImage = [[MacOSaiXSourceImage alloc] initWithIdentifier:[[openPanel filenames] objectAtIndex:0] fromEnumerator:handPickedEnumerator];
			MacOSaiXImageMatch	*match = [MacOSaiXImageMatch imageMatchWithValue:0.0 forSourceImage:sourceImage forTile:selectedTile];
			[selectedTile setUserChosenImageMatch:match];
		}
		
		[self populateGUI];
	}
}


- (IBAction)removeChosenImageForSelectedTiles:(id)sender
{
	NSEnumerator	*selectedTileEnumerator = [[self selectedTiles] objectEnumerator];
	MacOSaiXTile	*selectedTile = nil;
	while (selectedTile = [selectedTileEnumerator nextObject])
		[selectedTile setUserChosenImageMatch:nil];
}


#pragma mark -
#pragma mark Solid color


- (IBAction)setSolidColor:(id)sender
{
	MacOSaiXTileFillStyle	fillStyle = fillWithColor;
	NSColor					*fillColor = nil;
	
	if (sender == solidColorMatrix)
	{
		if ([solidColorMatrix selectedRow] == 0)
			fillStyle = fillWithAverageTargetColor;
		else if ([solidColorMatrix selectedRow] == 1)
			fillColor = [NSColor blackColor];
		else if ([solidColorMatrix selectedRow] == 2)
			fillColor = [NSColor clearColor];
		
		if (fillColor)
			[solidColorWell setColor:fillColor];
	}
	else if (sender == solidColorWell)
		fillColor = [solidColorWell color];
	
	NSEnumerator	*selectedTileEnumerator = [[self selectedTiles] objectEnumerator];
	MacOSaiXTile	*selectedTile = nil;
	while (selectedTile = [selectedTileEnumerator nextObject])
	{
		[selectedTile setFillStyle:fillStyle];
		
		if (fillStyle == fillWithColor)
			[selectedTile setFillColor:fillColor];
	}
}


#pragma mark -


- (IBAction)openWebPageForCurrentImage:(id)sender
{
	MacOSaiXTile		*selectedTile = [[self selectedTiles] lastObject];
	MacOSaiXImageMatch	*imageMatch = nil;
	
	if ([selectedTile fillStyle] == fillWithUniqueMatch)
		imageMatch = [selectedTile uniqueImageMatch];
	else if ([selectedTile fillStyle] == fillWithHandPicked)
		imageMatch = [selectedTile userChosenImageMatch];

	if (imageMatch)
		[[NSWorkspace sharedWorkspace] openURL:[[imageMatch sourceImage] contextURL]];
}


- (void)tileImageDidChange:(NSNotification *)notification
{
	// TODO: update the "choose image" sheet if it's displaying the changed tile
}


#pragma mark -


- (void)centerViewOnSelectedTile:(id)sender
{
// TODO: where should this live?
//    NSPoint			contentOrigin = NSMakePoint(NSMidX([[[self selectedTile] outline] bounds]),
//												NSMidY([[[self selectedTile] outline] bounds]));
//    NSScrollView	*mosaicScrollView = [mosaicView enclosingScrollView];
//	NSSize			targetImageSize = [[[[self delegate] mosaic] targetImage] size];
//	
//    contentOrigin.x *= [mosaicView frame].size.width / targetImageSize.width;
//    contentOrigin.x -= [[mosaicScrollView contentView] bounds].size.width / 2;
//    if (contentOrigin.x < 0) contentOrigin.x = 0;
//    if (contentOrigin.x + [[mosaicScrollView contentView] bounds].size.width >
//		[mosaicView frame].size.width)
//		contentOrigin.x = [mosaicView frame].size.width - 
//			[[mosaicScrollView contentView] bounds].size.width;
//	
//    contentOrigin.y *= [mosaicView frame].size.height / targetImageSize.height;
//    contentOrigin.y -= [[mosaicScrollView contentView] bounds].size.height / 2;
//    if (contentOrigin.y < 0) contentOrigin.y = 0;
//    if (contentOrigin.y + [[mosaicScrollView contentView] bounds].size.height >
//		[mosaicView frame].size.height)
//		contentOrigin.y = [mosaicView frame].size.height - 
//			[[mosaicScrollView contentView] bounds].size.height;
//	
//    [[mosaicScrollView contentView] scrollToPoint:contentOrigin];
//    [mosaicScrollView reflectScrolledClipView:[mosaicScrollView contentView]];
}


- (void)endEditing
{
	// TBD: close NSOpenPanel?
	
	[[NSNotificationCenter defaultCenter] removeObserver:self 
													name:MacOSaiXTileContentsDidChangeNotification 
												  object:[[self delegate] mosaic]];
	
	[self setSelectedTiles:nil];
	
	[super endEditing];
}


@end
