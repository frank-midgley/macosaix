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
	NSArray	*originalImagePaths = [[NSUserDefaults standardUserDefaults] arrayForKey:@"Original Image Paths"];
	int		column = 0;
	for (column = 0; column < [originalImageMatrix numberOfColumns]; column++)
	{
		NSButtonCell	*buttonCell = [originalImageMatrix cellAtRow:0 column:column];
		NSString		*imagePath = (column < [originalImagePaths count] ? [originalImagePaths objectAtIndex:column] : nil);
		NSImage			*image = nil;
		
		if ([[NSFileManager defaultManager] fileExistsAtPath:imagePath] &&
			(image = [[NSImage alloc] initWithContentsOfFile:imagePath]))
		{
			[image setScalesWhenResized:YES];
			[image setSize:[originalImageMatrix cellSize]];
			[buttonCell setTitle:imagePath];
			[buttonCell setAlternateImage:image];
			[buttonCell setImagePosition:NSImageOnly];
			
			NSImage	*darkenedImage = [image copy];
			[darkenedImage lockFocus];
				[[NSColor colorWithCalibratedWhite:0.0 alpha:0.5] set];
				[[NSBezierPath bezierPathWithRect:NSMakeRect(0.0, 0.0, [image size].width, [image size].height)] fill];
			[darkenedImage unlockFocus];
			[buttonCell setImage:darkenedImage];
			
			[image release];
			[darkenedImage release];
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


- (void)dealloc
{
	
	
	[super dealloc];
}


@end
