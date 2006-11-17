//
//  MacOSaiXAboutBoxController.m
//  MacOSaiX
//
//  Created by Frank Midgley on 11/16/06.
//  Copyright 2006 Frank M. Midgley.  All rights reserved.
//

#import "MacOSaiXAboutBoxController.h"

#import "MosaicView.h"
#import "MacOSaiXMosaic.h"

#import <AddressBook/AddressBook.h>


@interface NSObject (AboutBoxHack)
- (void)setTilesAcross:(int)tilesDown;
- (void)setTilesDown:(int)tilesAcross;
@end


@implementation MacOSaiXAboutBoxController

- (NSString *)windowNibName
{
	return @"About Box";
}


- (void)windowDidLoad
{
	[mosaicView setBackgroundMode:clearMode];
	[mosaicView setFade:1.0];
	
	MacOSaiXMosaic			*mosaic = [[[MacOSaiXMosaic alloc] init] autorelease];
	[mosaic setImageUseCount:1];
	[mosaic setImageCropLimit:1.0];
	[mosaicView setMosaic:mosaic];
	
	id<MacOSaiXTileShapes>	tileShapes = [[NSClassFromString(@"MacOSaiXRectangularTileShapes") alloc] init];
	[(id)tileShapes setTilesAcross:20];
	[(id)tileShapes setTilesDown:20];
	[mosaic setTileShapes:tileShapes creatingTiles:YES];
	[tileShapes release];
	
	id<MacOSaiXImageSource>	imageSource = [[NSClassFromString(@"MacOSaiXGlyphImageSource") alloc] init];
	[imageSource performSelector:@selector(addFontWithName:) 
					  withObject:[[NSFont systemFontOfSize:0.0] fontName]];
	[mosaic addImageSource:imageSource];
	[imageSource release];
	
	ABPerson				*myRecord = [[ABAddressBook sharedAddressBook] me];
	NSImage					*myImage = [[[NSImage alloc] initWithData:[myRecord imageData]] autorelease];
	if (myImage)
	{
		[mosaic setOriginalImage:myImage];
		[mosaic resume];
	}
	else
	{
		[myRecord beginLoadingImageDataForClient:self];
	}
}


- (void)consumeImageData:(NSData *)imageData forTag:(int)imageTag
{
	if (imageData)
	{
		NSImage	*myImage = [[[NSImage alloc] initWithData:imageData] autorelease];
		[[mosaicView mosaic] setOriginalImage:myImage];
	}
	else
		[[mosaicView mosaic] setOriginalImage:[NSImage imageNamed:@"Application Icon"]];
	
	[[mosaicView mosaic] resume];
}


- (void)windowWillClose:(NSNotification *)notification
{
	[self autorelease];
}


- (void)dealloc
{
	[super dealloc];
}


@end
