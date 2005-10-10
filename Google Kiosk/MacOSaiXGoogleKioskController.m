//
//  MacOSaiXGoogleKioskController.m
//  MacOSaiX
//
//  Created by Frank Midgley on 9/26/05.
//  Copyright 2005 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXGoogleKioskController.h"

#import "GoogleImageSource.h"


@implementation MacOSaiXGoogleKioskController


- (NSString *)windowNibName
{
	return @"Google Kiosk";
}


- (void)awakeFromNib
{
		// Populate the original image buttons
	originalImages = [[NSMutableArray arrayWithObjects:[NSNull null], [NSNull null], [NSNull null], [NSNull null], [NSNull null], [NSNull null], nil] retain];
	NSArray			*originalImagePaths = [[NSUserDefaults standardUserDefaults] arrayForKey:@"Original Image Paths"];
	int				column = 0;
	for (column = 0; column < [originalImageMatrix numberOfColumns]; column++)
	{
		NSButtonCell	*buttonCell = [originalImageMatrix cellAtRow:0 column:column];
		NSString		*imagePath = (column < [originalImagePaths count] ? [originalImagePaths objectAtIndex:column] : nil);
		NSImage			*image = nil;
		
		if ([[NSFileManager defaultManager] fileExistsAtPath:imagePath] &&
			(image = [[NSImage alloc] initWithContentsOfFile:imagePath]))
		{
			[originalImages replaceObjectAtIndex:column withObject:image];
			[buttonCell setTitle:imagePath];
			[buttonCell setImagePosition:NSImageOnly];
			[image release];
		}
		else
		{
			[buttonCell setTitle:@"No Image Available"];
			[buttonCell setImage:nil];
			[buttonCell setImagePosition:NSNoImage];
		}
	}
	
	mosaic = [[MacOSaiXMosaic alloc] init];
	[mosaicView setMosaic:mosaic];
	[mosaic setOriginalImagePath:[originalImagePaths objectAtIndex:0]];
}


- (IBAction)setOriginalImage:(id)sender
{
	NSButtonCell	*buttonCell = [originalImageMatrix selectedCell];
	
	[mosaic setOriginalImagePath:[buttonCell title]];
}


- (IBAction)addKeyword:(id)sender
{
	GoogleImageSource	*newSource = [[GoogleImageSource alloc] init];
	
	[newSource setAdultContentFiltering:strictFiltering];
	[newSource setRequiredTerms:[keywordTextField stringValue]];
	
	[mosaic addImageSource:newSource];
	
	[newSource release];
}


- (IBAction)removeKeyword:(id)sender
{
	
}


#pragma mark


- (void)windowDidResize:(NSNotification *)notification
{
	NSWindow	*window = [notification object];
	float		matrixWidth = 24.0 * [window frame].size.height / 21.0, 
				matrixHeight = matrixWidth / 6.0 / 4.0 * 3.0, 
				settingsWidth = [window frame].size.width - matrixWidth, 
				mosaicHeight = [window frame].size.height - matrixHeight;
	
	[originalImageMatrix setCellSize:NSMakeSize(matrixWidth / 6.0, matrixHeight)];
	[originalImageMatrix setFrame:NSMakeRect(0.0, mosaicHeight, matrixWidth, matrixHeight)];
	[customImageView setFrame:NSMakeRect(matrixWidth, mosaicHeight, settingsWidth, matrixHeight)];
	[mosaicView setFrame:NSMakeRect(0.0, 0.0, matrixWidth, mosaicHeight)];
	[googleBox setFrame:NSMakeRect(matrixWidth, 0.0, settingsWidth, mosaicHeight)];
	
		// Populate the original image buttons now that we know what size they are.
	int		column = 0;
	for (column = 0; column < [originalImageMatrix numberOfColumns]; column++)
	{
		NSButtonCell	*buttonCell = [originalImageMatrix cellAtRow:0 column:column];
		
		if ([buttonCell imagePosition] == NSImageOnly)
		{
			NSImage	*image = [[originalImages objectAtIndex:column] copy];
			
			[image setScalesWhenResized:YES];
			[image setSize:[originalImageMatrix cellSize]];
			[buttonCell setAlternateImage:image];
			
			NSImage	*darkenedImage = [image copy];
			[darkenedImage lockFocus];
				[[NSColor colorWithCalibratedWhite:0.0 alpha:0.5] set];
				[[NSBezierPath bezierPathWithRect:NSMakeRect(0.0, 0.0, [image size].width, [image size].height)] fill];
			[darkenedImage unlockFocus];
			[buttonCell setImage:darkenedImage];
			
			[image release];
			[darkenedImage release];
		}
	}
}


#pragma mark


- (void)dealloc
{
	[originalImages release];
	
	[super dealloc];
}


@end
