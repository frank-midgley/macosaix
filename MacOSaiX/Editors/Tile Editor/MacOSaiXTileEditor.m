//
//  MacOSaiXTileEditor.m
//  MacOSaiX
//
//  Created by Frank Midgley on 12/22/06.
//  Copyright 2006 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXTileEditor.h"

#import "MacOSaiXImageCache.h"
#import "MacOSaiXMosaic.h"
#import "NSImage+MacOSaiX.h"
#import "Tiles.h"


@implementation MacOSaiXTileContentEditor


- (id)initWithMosaicView:(MosaicView *)inMosaic
{
	if (self = [super initWithMosaicView:inMosaic])
	{
		CFURLRef	browserURL = nil;
		OSStatus	status = LSGetApplicationForURL((CFURLRef)[NSURL URLWithString:@"http://www.apple.com/"], 
													kLSRolesViewer,
													NULL,
													&browserURL);
		if (status == noErr)
		{
			browserIcon = [[[NSWorkspace sharedWorkspace] iconForFile:[(NSURL *)browserURL path]] retain];
			[browserIcon setSize:NSMakeSize(16.0, 16.0)];
		}
	}
	
	return self;
}


- (NSString *)editorNibName
{
	return @"Tile Editor";
}


- (NSString *)title
{
	return NSLocalizedString(@"Tile Content", @"");
}


- (void)beginEditing
{
	[[self mosaicView] setTargetImageFraction:0.0];
	
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(tileImageDidChange:) 
												 name:MacOSaiXTileContentsDidChangeNotification 
											   object:[[self mosaicView] mosaic]];
}


- (void)embellishMosaicViewInRect:(NSRect)rect
{
	[super embellishMosaicViewInRect:rect];
	
	if ([self selectedTile])
	{
		NSRect				mosaicBounds = [[self mosaicView] imageBounds];
		NSSize				targetImageSize = [[[[self mosaicView] mosaic] targetImage] size];
		float				minX = NSMinX(mosaicBounds), 
							minY = NSMinY(mosaicBounds), 
							width = NSWidth(mosaicBounds), 
							height = NSHeight(mosaicBounds);
		NSBezierPath		*outline = [[self selectedTile] outline];
		
			// Draw the tile's outline with a 4pt thick dashed line.
		NSAffineTransform	*transform = [NSAffineTransform transform];
		[transform translateXBy:minX yBy:minY];
		[transform scaleXBy:width / targetImageSize.width 
						yBy:height / targetImageSize.height];
		NSBezierPath		*tileOutline = [transform transformBezierPath:outline];
		[tileOutline setLineWidth:4];
		[[NSColor colorWithCalibratedWhite:0.0 alpha:0.5] set];
		[tileOutline stroke];
		
			// Dim the rest of the mosaic view
		NSBezierPath		*dimPath = [NSBezierPath bezierPathWithRect:mosaicBounds];
		[dimPath appendBezierPath:[tileOutline bezierPathByReversingPath]];
		[[NSColor colorWithCalibratedWhite:1.0 alpha:0.75] set];
		[dimPath fill];
		
		switch ([selectedTile fillStyle])
		{
			case fillWithUniqueMatch:
			{
				MacOSaiXImageMatch	*bestMatch = [[self selectedTile] uniqueImageMatch];
				float				curY = NSMinY([tileOutline bounds]) - 18.0;
				
				if (bestMatch)
				{
						// Display the description of the image being displayed.
					NSString	*matchName = [[bestMatch imageSource] descriptionForIdentifier:[bestMatch imageIdentifier]];
					if (!matchName)
						matchName = NSLocalizedString(@"No description available", @"");
					NSDictionary	*attributes = [NSDictionary dictionaryWithObject:[NSFont boldSystemFontOfSize:0.0] 
																			  forKey:NSFontAttributeName];
					NSSize		stringSize = [matchName sizeWithAttributes:attributes];
					[matchName drawAtPoint:NSMakePoint(NSMidX([tileOutline bounds]) - stringSize.width / 2.0, curY) withAttributes:attributes];
					curY -= 18.0;
					
						// Display the source of the image being displayed.
					NSString	*sourceLabel = NSLocalizedString(@"Source: ", @"");
					stringSize = [sourceLabel sizeWithAttributes:nil];
					float		sourceWidth = stringSize.width + 2.0;
					NSImage		*sourceImage = [[[[bestMatch imageSource] image] copy] autorelease];
					[sourceImage setScalesWhenResized:YES];
					[sourceImage setSize:NSMakeSize([sourceImage size].width / [sourceImage size].height * 16.0, 16.0)];
					sourceWidth += [sourceImage size].width + 4.0;
					id			sourceDescription = [[bestMatch imageSource] briefDescription];
					if ([sourceDescription isKindOfClass:[NSString class]])
						sourceWidth += [(NSString *)sourceDescription sizeWithAttributes:nil].width;
					else
						sourceWidth += [(NSAttributedString *)sourceDescription size].width;
					float		leftEdge = NSMidX([tileOutline bounds]) - sourceWidth / 2.0;
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
							tileArea = NSWidth([tileOutline bounds]) * NSHeight([tileOutline bounds]);
					[[NSString stringWithFormat:NSLocalizedString(@"Cropping: %.0f%%", @""), (imageArea - tileArea) / imageArea * 100.0] drawAtPoint:NSMakePoint(leftEdge, curY) withAttributes:nil];
				}
				else
				{
					NSString	*noMatchString = NSLocalizedString(@"No match available", @"");
					NSSize		stringSize = [noMatchString sizeWithAttributes:nil];
					[noMatchString drawAtPoint:NSMakePoint(NSMidX([tileOutline bounds]) - stringSize.width / 2.0, curY) withAttributes:nil];
				}
				
				break;
			}
			case fillWithHandPicked:
			{
				MacOSaiXImageMatch	*handPickedMatch = [[self selectedTile] userChosenImageMatch];
				
				if (handPickedMatch)
				{
				}
				
				break;
			}
			case fillWithTargetImage:
			{
				// TODO: create the image that shows the portion of the target image
				
				break;
			}
			case fillWithSolidColor:
			{
				NSColor	*tileColor = [selectedTile fillColor];
				
				if (!tileColor)
					tileColor = [NSColor blackColor];
				
				break;
			}
		}
	}
}


- (void)handleEventInMosaicView:(NSEvent *)event
{
	[self setSelectedTile:[[self mosaicView] tileAtPoint:[[self mosaicView] convertPoint:[event locationInWindow] fromView:nil]]];
}


- (void)populateGUI
{
	MacOSaiXTileFillStyle	fillStyle = [selectedTile fillStyle];
	
	[fillStylePopUp selectItemWithTag:fillStyle];
	
	[fillStyleTabView selectTabViewItemWithIdentifier:[NSString stringWithFormat:@"%d", fillStyle]];
	
	switch (fillStyle)
	{
		case fillWithUniqueMatch:
		{
			MacOSaiXImageMatch	*bestMatch = [[self selectedTile] uniqueImageMatch];
			
			if (bestMatch)
			{
				NSImageRep			*bestMatchRep = [[MacOSaiXImageCache sharedImageCache] imageRepAtSize:NSZeroSize 
																							forIdentifier:[bestMatch imageIdentifier] 
																							   fromSource:[bestMatch imageSource]];
				NSImage				*bestMatchImage = [[[NSImage alloc] initWithSize:[bestMatchRep size]] autorelease];
				[bestMatchImage addRepresentation:bestMatchRep];
				
				[bestMatchImageView setImage:bestMatchImage];
			}
			else
				[bestMatchImageView setImage:nil];
			
			if ([[bestMatch imageSource] contextURLForIdentifier:[bestMatch imageIdentifier]])
			{
				if (!openBestMatchInBrowserButton)
				{
					openBestMatchInBrowserButton = [[[NSButton alloc] initWithFrame:NSMakeRect(NSMaxX([bestMatchImageView frame]) - 28.0, 5.0, 16.0, 16.0)] autorelease];
					[openBestMatchInBrowserButton setBordered:NO];
					[openBestMatchInBrowserButton setTitle:nil];
					[openBestMatchInBrowserButton setImage:browserIcon];
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
			
			break;
		}
		case fillWithHandPicked:
		{
			MacOSaiXImageMatch	*handPickedMatch = [[self selectedTile] userChosenImageMatch];
			
			if (handPickedMatch)
			{
				NSImageRep			*handPickedRep = [[MacOSaiXImageCache sharedImageCache] imageRepAtSize:NSZeroSize 
																							 forIdentifier:[handPickedMatch imageIdentifier] 
																								fromSource:[handPickedMatch imageSource]];
				NSImage				*handPickedImage = [[[NSImage alloc] initWithSize:[handPickedRep size]] autorelease];
				[handPickedImage addRepresentation:handPickedRep];
				
				[handPickedImageView setImage:handPickedImage];
			}
			
			break;
		}
		case fillWithTargetImage:
		{
			// TODO: create the image that shows the portion of the target image
			
			break;
		}
		case fillWithSolidColor:
		{
			NSColor	*tileColor = [selectedTile fillColor];
			
			if (!tileColor)
				tileColor = [NSColor blackColor];
			
			if ([tileColor isEqualTo:[NSColor blackColor]])
				[solidColorMatrix selectCellAtRow:0 column:0];
			else if ([tileColor isEqualTo:[NSColor clearColor]])
				[solidColorMatrix selectCellAtRow:1 column:0];
			else
				[solidColorMatrix selectCellAtRow:2 column:0];
			
			[solidColorWell setColor:tileColor];
			
			break;
		}
	}
}


- (void)setSelectedTile:(MacOSaiXTile *)tile
{
	if (tile != selectedTile)
	{
		[selectedTile autorelease];
		selectedTile = [tile retain];
		
//		NSRect				mosaicBounds = [[self mosaicView] imageBounds];
//		NSSize				targetImageSize = [[[[self mosaicView] mosaic] targetImage] size];
//		NSAffineTransform	*transform = [NSAffineTransform transform];
//		[transform translateXBy:NSMinX(mosaicBounds) yBy:NSMinY(mosaicBounds)];
//		[transform scaleXBy:NSWidth(mosaicBounds) / targetImageSize.width 
//						yBy:NSHeight(mosaicBounds) / targetImageSize.height];
		
		if (NO)
		{
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
		}
		
		[[self mosaicView] setNeedsDisplay:YES];
		
		[self populateGUI];
	}
}


- (MacOSaiXTile *)selectedTile
{
	return selectedTile;
}


- (IBAction)setFillStyle:(id)sender
{
	[selectedTile setFillStyle:[[fillStylePopUp selectedItem] tag]];
	
	[self populateGUI];
}


- (IBAction)dontUseThisImage:(id)sender
{
	
}


- (IBAction)chooseImageForTile:(id)sender
{
	
}


- (IBAction)setSolidColor:(id)sender
{
	if (sender == solidColorMatrix)
	{
		if ([solidColorMatrix selectedRow] == 0)
		{
			[selectedTile setFillColor:[NSColor blackColor]];
			[solidColorWell setColor:[NSColor blackColor]];
		}
		else if ([solidColorMatrix selectedRow] == 1)
		{
			[selectedTile setFillColor:[NSColor clearColor]];
			[solidColorWell setColor:[NSColor clearColor]];
		}
	}
	else if (sender == solidColorWell)
	{
		[selectedTile setFillColor:[solidColorWell color]];
	}
}


- (IBAction)openWebPageForCurrentImage:(id)sender
{
	MacOSaiXImageMatch	*imageMatch = nil;
	
	if ([selectedTile fillStyle] == fillWithUniqueMatch)
		imageMatch = [selectedTile uniqueImageMatch];
	else if ([selectedTile fillStyle] == fillWithHandPicked)
		imageMatch = [selectedTile userChosenImageMatch];

	if (imageMatch)
		[[NSWorkspace sharedWorkspace] openURL:[[imageMatch imageSource] contextURLForIdentifier:[imageMatch imageIdentifier]]];
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
    NSPoint			contentOrigin = NSMakePoint(NSMidX([[[self selectedTile] outline] bounds]),
												NSMidY([[[self selectedTile] outline] bounds]));
    NSScrollView	*mosaicScrollView = [mosaicView enclosingScrollView];
	NSSize			targetImageSize = [[[[self mosaicView] mosaic] targetImage] size];
	
    contentOrigin.x *= [mosaicView frame].size.width / targetImageSize.width;
    contentOrigin.x -= [[mosaicScrollView contentView] bounds].size.width / 2;
    if (contentOrigin.x < 0) contentOrigin.x = 0;
    if (contentOrigin.x + [[mosaicScrollView contentView] bounds].size.width >
		[mosaicView frame].size.width)
		contentOrigin.x = [mosaicView frame].size.width - 
			[[mosaicScrollView contentView] bounds].size.width;
	
    contentOrigin.y *= [mosaicView frame].size.height / targetImageSize.height;
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
													name:MacOSaiXTileContentsDidChangeNotification 
												  object:[[self mosaicView] mosaic]];
	
	[self setSelectedTile:nil];
}


//- (void)dealloc
//{
//	[super dealloc];
//}


@end
