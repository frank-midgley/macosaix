//
//  MacOSaiXTileEditor.m
//  MacOSaiX
//
//  Created by Frank Midgley on Jun 10, 2006
//  Copyright 2006 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXTileEditor.h"

#import "MacOSaiXImageCache.h"
#import "MacOSaiXImageMatcher.h"
#import "MacOSaiXMosaic.h"
#import "Tiles.h"
#import "NSString+MacOSaiX.h"


@implementation MacOSaiXTileEditor


- (NSImage *)highlightTileOutlineInImage:(NSImage *)image croppedPercentage:(float *)croppedPercentage
{
		// Scale the image to at most 128 pixels.
    NSImage				*highlightedImage = [[[NSImage alloc] initWithSize:[image size]] autorelease];
	
		// Figure out how to scale and translate the tile to fit within the image.
    NSSize				tileSize = [[tile outline] bounds].size,
						originalSize = [[[tile mosaic] originalImage] size], 
						denormalizedTileSize = NSMakeSize(tileSize.width * originalSize.width, 
														  tileSize.height * originalSize.height);
    float				xScale, yScale;
    NSPoint				origin;
    if (([image size].width / denormalizedTileSize.width) < ([image size].height / denormalizedTileSize.height))
    {
			// Width is the limiting dimension.
		float	scaledHeight = [image size].width * denormalizedTileSize.height / denormalizedTileSize.width, 
				heightDiff = [image size].height - scaledHeight;
		xScale = [image size].width / tileSize.width;
		yScale = scaledHeight / tileSize.height;
		origin = NSMakePoint(0.0, heightDiff / 2.0);
		if (croppedPercentage)
			*croppedPercentage = ([image size].width * heightDiff) / 
								 ([image size].width * [image size].height) * 100.0;
    }
    else
    {
			// Height is the limiting dimension.
		float	scaledWidth = [image size].height * denormalizedTileSize.width / denormalizedTileSize.height, 
				widthDiff = [image size].width - scaledWidth;
		xScale = scaledWidth / tileSize.width;
		yScale = [image size].height / tileSize.height;
		origin = NSMakePoint(widthDiff / 2.0, 0.0);
		if (croppedPercentage)
			*croppedPercentage = (widthDiff * [image size].height) / 
								 ([image size].width * [image size].height) * 100.0;
    }
	
		// Create a transform to scale and translate the tile outline.
    NSAffineTransform	*transform = [NSAffineTransform transform];
    [transform translateXBy:origin.x yBy:origin.y];
    [transform scaleXBy:xScale yBy:yScale];
    [transform translateXBy:-[[tile outline] bounds].origin.x yBy:-[[tile outline] bounds].origin.y];
	NSBezierPath		*transformedTileOutline = [transform transformBezierPath:[tile outline]];
    
	NS_DURING
		[highlightedImage lockFocus];
				// Start with the original image.
			[image compositeToPoint:NSZeroPoint operation:NSCompositeCopy];
			
				// Lighten the area outside of the tile.
			NSBezierPath	*lightenOutline = [NSBezierPath bezierPath];
			[lightenOutline moveToPoint:NSMakePoint(0, 0)];
			[lightenOutline lineToPoint:NSMakePoint(0, [highlightedImage size].height)];
			[lightenOutline lineToPoint:NSMakePoint([highlightedImage size].width, [highlightedImage size].height)];
			[lightenOutline lineToPoint:NSMakePoint([highlightedImage size].width, 0)];
			[lightenOutline closePath];
			[lightenOutline appendBezierPath:transformedTileOutline];
			[[NSColor colorWithCalibratedWhite:1.0 alpha:0.5] set];
			[lightenOutline fill];
			
				// Darken the outline of the tile.
			[[NSColor colorWithCalibratedWhite:0.0 alpha:0.5] set];
			[transformedTileOutline stroke];
		[highlightedImage unlockFocus];
	NS_HANDLER
		NSLog(@"Could not lock focus on editor image");
	NS_ENDHANDLER
	
    return highlightedImage;
}


- (void)chooseImageForTile:(MacOSaiXTile *)inTile 
			modalForWindow:(NSWindow *)window 
			 modalDelegate:(id)inDelegate
			didEndSelector:(SEL)inDidEndSelector
{
	tile = inTile;
	delegate = inDelegate;
	didEndSelector = inDidEndSelector;
	
	if (!accessoryView)
		[NSBundle loadNibNamed:@"Tile Editor" owner:self];
	
		// Create the image for the "Original Image" view of the accessory view.
	NSRect		originalImageViewFrame = NSMakeRect(0.0, 0.0, [originalImageView frame].size.width, 
													[originalImageView frame].size.height);
	NSImage		*originalImageForTile = [[[NSImage alloc] initWithSize:originalImageViewFrame.size] autorelease];
	NS_DURING
		[originalImageForTile lockFocus];
		
				// Start with a black background.
			[[NSColor blackColor] set];
			NSRectFill(originalImageViewFrame);
			
				// Determine the bounds of the tile in the original image and in the scratch window.
			NSBezierPath	*tileOutline = [tile outline];
			NSImage			*originalImage = [[tile mosaic] originalImage];
			NSRect			origRect = NSMakeRect([tileOutline bounds].origin.x * [originalImage size].width,
												  [tileOutline bounds].origin.y * [originalImage size].height,
												  [tileOutline bounds].size.width * [originalImage size].width,
												  [tileOutline bounds].size.height * [originalImage size].height);
			
				// Expand the rectangle so that it's square.
			if (origRect.size.width > origRect.size.height)
				origRect = NSInsetRect(origRect, 0.0, (origRect.size.height - origRect.size.width) / 2.0);
			else
				origRect = NSInsetRect(origRect, (origRect.size.width - origRect.size.height) / 2.0, 0.0);
			
				// Copy out the portion of the original image contained by the tile's outline.
			[originalImage drawInRect:originalImageViewFrame fromRect:origRect operation:NSCompositeCopy fraction:1.0];
		[originalImageForTile unlockFocus];
	NS_HANDLER
		NSLog(@"Exception raised while extracting tile images: %@", [localException name]);
	NS_ENDHANDLER
	[originalImageView setImage:[self highlightTileOutlineInImage:originalImageForTile croppedPercentage:nil]];
	
		// Set up the current image box
	MacOSaiXImageMatch	*currentMatch = [tile displayedImageMatch];
	if (currentMatch)
	{
		id<MacOSaiXImageSource>	currentSource = [currentMatch imageSource];
		NSString				*currentIdentifier = [currentMatch imageIdentifier];
		NSSize					currentSize = [[MacOSaiXImageCache sharedImageCache] nativeSizeOfImageWithIdentifier:currentIdentifier 
																										  fromSource:currentSource];
		
		if (NSEqualSizes(currentSize, NSZeroSize))
		{
				// The image is not in the cache so request a random sized rep to get it loaded.
			[[MacOSaiXImageCache sharedImageCache] imageRepAtSize:NSMakeSize(1.0, 1.0) 
													forIdentifier:currentIdentifier 
													   fromSource:currentSource];
			currentSize = [[MacOSaiXImageCache sharedImageCache] nativeSizeOfImageWithIdentifier:currentIdentifier 
																					  fromSource:currentSource];
		}
		
		NSBitmapImageRep	*currentRep = [[MacOSaiXImageCache sharedImageCache] imageRepAtSize:currentSize 
																				  forIdentifier:currentIdentifier 
																					 fromSource:currentSource];
		NSImage				*currentImage = [[[NSImage alloc] initWithSize:currentSize] autorelease];
		[currentImage addRepresentation:currentRep];
		float				croppedPercentage = 0.0;
		[currentImageView setImage:[self highlightTileOutlineInImage:currentImage croppedPercentage:&croppedPercentage]];
		//		float				worstCaseMatch = sqrtf([selectedTile worstCaseMatchValue]), 
		//							matchPercentage = (worstCaseMatch - sqrtf([currentMatch matchValue])) / worstCaseMatch * 100.0;
		[currentMatchQualityTextField setStringValue:[NSString stringWithFormat:@"%.0f%%", 100.0 - [currentMatch matchValue] * 100.0]];
		[currentPercentCroppedTextField setStringValue:[NSString stringWithFormat:@"%.0f%%", croppedPercentage]];
		[currentImageSourceImageView setImage:[currentSource image]];
		[currentImageSourceNameField setObjectValue:[currentSource descriptor]];
		[currentImageDescriptionField setStringValue:[currentSource descriptionForIdentifier:currentIdentifier]];
	}
	else
	{
		[currentImageView setImage:nil];
		[currentMatchQualityTextField setStringValue:@"--"];
		[currentPercentCroppedTextField setStringValue:@"--"];
	}
	
	// Set up the chosen image box.
	[chosenImageBox setTitle:@"No Image File Selected"];
	[chosenImageView setImage:nil];
	[chosenMatchQualityTextField setStringValue:@"--"];
	[chosenPercentCroppedTextField setStringValue:@"--"];
	
	// Prompt the user to choose the image from which to make a mosaic.
	NSOpenPanel	*openPanel = [NSOpenPanel openPanel];
	[openPanel setCanChooseFiles:YES];
	[openPanel setCanChooseDirectories:NO];
	if ([openPanel respondsToSelector:@selector(setMessage:)])
		[openPanel setMessage:@"Choose an image to be displayed in this tile:"];
	[openPanel setPrompt:@"Choose"];
	[openPanel setDelegate:self];
	
	[openPanel setAccessoryView:accessoryView];
	NSSize	superSize = [[accessoryView superview] frame].size;
	[accessoryView setFrame:NSMakeRect(5.0, 5.0, superSize.width - 10.0, superSize.height - 10.0)];
	[accessoryView setAutoresizingMask:NSViewWidthSizable];
	
	[openPanel beginSheetForDirectory:nil
								 file:nil
								types:[NSImage imageFileTypes]
					   modalForWindow:window
						modalDelegate:self
					   didEndSelector:@selector(chooseImagePanelDidEnd:returnCode:contextInfo:)
						  contextInfo:nil];
}


- (void)panelSelectionDidChange:(id)sender
{
	if ([[sender URLs] count] == 0)
	{
		[chosenImageBox setTitle:@"No Image File Selected"];
		[chosenImageView setImage:nil];
		[chosenMatchQualityTextField setStringValue:@"--"];
		[chosenPercentCroppedTextField setStringValue:@"--"];
	}
	else
	{
			// This shouldn't be necessary but updating the views right away often crashes 
			// because of some interaction with the AppKit thread that is creating a preview 
			// of the selected image.
		[self performSelector:@selector(updateUserChosenViewsForImageAtPath:) withObject:[[sender filenames] objectAtIndex:0] afterDelay:0.0];
	}
}


- (void)updateUserChosenViewsForImageAtPath:(NSString *)imagePath
{
	NSString			*chosenImageIdentifier = imagePath;
	[chosenImageBox setTitle:[[NSFileManager defaultManager] displayNameAtPath:chosenImageIdentifier]];
	
	NSImage				*chosenImage = [[[NSImage alloc] initWithContentsOfFile:chosenImageIdentifier] autorelease];
	[chosenImage setCachedSeparately:YES];
	[chosenImage setCacheMode:NSImageCacheNever];
	
	if (chosenImage)
	{
		NSImageRep			*originalRep = [[chosenImage representations] objectAtIndex:0];
		NSSize				imageSize = NSMakeSize([originalRep pixelsWide], [originalRep pixelsHigh]);
		[originalRep setSize:imageSize];
		[chosenImage setSize:imageSize];
		
		float				croppedPercentage = 0.0;
		[chosenImageView setImage:[self highlightTileOutlineInImage:chosenImage croppedPercentage:&croppedPercentage]];
		
		[chosenPercentCroppedTextField setStringValue:[NSString stringWithFormat:@"%.0f%%", croppedPercentage]];
		
			// Calculate how well the chosen image matches the selected tile.
		[[MacOSaiXImageCache sharedImageCache] cacheImage:chosenImage withIdentifier:chosenImageIdentifier fromSource:nil];
		NSBitmapImageRep	*chosenImageRep = [[MacOSaiXImageCache sharedImageCache] imageRepAtSize:[[tile bitmapRep] size] 
																					  forIdentifier:chosenImageIdentifier 
																						 fromSource:nil];
		chosenMatchValue = [[MacOSaiXImageMatcher sharedMatcher] compareImageRep:[tile bitmapRep]  
																		withMask:[tile maskRep] 
																	  toImageRep:chosenImageRep
																	previousBest:1.0];
		[chosenMatchQualityTextField setStringValue:[NSString stringWithFormat:@"%.0f%%", 100.0 - chosenMatchValue * 100.0]];
	}
}


- (void)chooseImagePanelDidEnd:(NSOpenPanel *)openPanel returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	[openPanel orderOut:self];
	
	if ([openPanel respondsToSelector:@selector(setMessage:)])
		[openPanel setMessage:@""];
	
	if (returnCode == NSOKButton)
	{
		[[tile mosaic] setHandPickedImageAtPath:[[openPanel filenames] objectAtIndex:0]
								 withMatchValue:chosenMatchValue
										forTile:tile];
	}
	
	if ([delegate respondsToSelector:@selector(didEndSelector)])
		[delegate performSelector:didEndSelector];
	
	tile = nil;
	delegate = nil;
	didEndSelector = nil;
}


- (void)dealloc
{
	[accessoryView release];
	
	[super dealloc];
}


@end
