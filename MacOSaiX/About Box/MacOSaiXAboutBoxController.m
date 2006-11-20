//
//  MacOSaiXAboutBoxController.m
//  MacOSaiX
//
//  Created by Frank Midgley on 11/16/06.
//  Copyright 2006 Frank M. Midgley.  All rights reserved.
//

#import "MacOSaiXAboutBoxController.h"

#import "MacOSaiXImageCache.h"
#import "MacOSaiXMosaic.h"
#import "MosaicView.h"

#import <AddressBook/AddressBook.h>


@interface NSObject (AboutBoxHack)
- (void)setTilesAcross:(int)tilesDown;
- (void)setTilesDown:(int)tilesAcross;
@end


@implementation MacOSaiXAboutBoxController


- (void)chooseNewPerson
{
	lastTileChangeCount = 0;
	[[MacOSaiXImageCache sharedImageCache] removeCachedImagesFromSource:[[[mosaicView mosaic] imageSources] lastObject]];
	
	NSArray		*personNames = [personImages allKeys];
	
	NSString	*newPersonName = [personNames objectAtIndex:random() % [personNames count]];
	[[mosaicView mosaic] setOriginalImage:[personImages objectForKey:newPersonName]];

	[mosaicView setToolTip:newPersonName];
	
	[[mosaicView mosaic] resume];
}


- (NSString *)windowNibName
{
	return @"About Box";
}


- (void)windowDidLoad
{
	NSString	*versionFormat = [versionField stringValue], 
				*version = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
	[versionField setStringValue:[NSString stringWithFormat:versionFormat, version]];
	
	CFURLRef	browserURL = nil;
	OSStatus	status = LSGetApplicationForURL((CFURLRef)[NSURL URLWithString:@"http://www.apple.com/"], 
												kLSRolesViewer,
												NULL,
												&browserURL);
	if (status == noErr)
	{
		NSImage	*browserIcon = [[NSWorkspace sharedWorkspace] iconForFile:[(NSURL *)browserURL path]];
		[browserIcon setSize:NSMakeSize(16.0, 16.0)];
		[homePageButton setImage:browserIcon];
	}
	
	[mosaicView setAllowsTileSelection:NO];
	[mosaicView setBackgroundMode:clearMode];
	[mosaicView setFade:1.0];
	
	MacOSaiXMosaic			*mosaic = [[[MacOSaiXMosaic alloc] init] autorelease];
	[mosaic setImageUseCount:1];
	[mosaic setImageCropLimit:100.0];
	[mosaicView setMosaic:mosaic];
	
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(tileImageDidChange:) 
												 name:MacOSaiXTileImageDidChangeNotification 
											   object:mosaic];
	
	id<MacOSaiXImageSource>	imageSource = [[NSClassFromString(@"MacOSaiXGlyphImageSource") alloc] init];
	[imageSource performSelector:@selector(addFontWithName:) 
					  withObject:[[NSFont systemFontOfSize:0.0] fontName]];
	[mosaic addImageSource:imageSource];
	[imageSource release];
	
	id<MacOSaiXTileShapes>	tileShapes = [[NSClassFromString(@"MacOSaiXHexagonalTileShapes") alloc] init];
	[(id)tileShapes setTilesAcross:20];
	[(id)tileShapes setTilesDown:17];
	[mosaic setTileShapes:tileShapes creatingTiles:YES];
	[tileShapes release];
	
	personImages = [[NSMutableDictionary dictionaryWithObject:[NSImage imageNamed:@"Application Icon"] 
													   forKey:@"MacOSaiX"] retain];
	personTags = [[NSMutableDictionary alloc] init];
	
		// Get the images of the people in the address book.
	NSEnumerator			*abPersonEnumerator = [[[ABAddressBook sharedAddressBook] people] objectEnumerator];
	ABPerson				*myRecord = [[ABAddressBook sharedAddressBook] me],
							*abPerson = nil;
	while (abPerson = [abPersonEnumerator nextObject])
	{
		NSString	*personName = nil;
		
		if (abPerson == myRecord)
			personName = NSLocalizedString(@"Me", @"");
		else
		{
			personName = [abPerson valueForProperty:kABNicknameProperty];
			if (!personName)
				personName = [NSString stringWithFormat:@"%@ %@", 
														[abPerson valueForProperty:kABFirstNameProperty], 
														[abPerson valueForProperty:kABLastNameProperty]];
		}
	
		NSImage	*personImage = nil;
		NSData	*imageData = [abPerson imageData];
		
		if (imageData)
		{
			personImage = [[[NSImage alloc] initWithData:imageData] autorelease];
			
			if ([personImage isValid])
				[personImages setObject:personImage forKey:personName];
		}
		
		if (!personImage)
		{
			int	tag = [abPerson beginLoadingImageDataForClient:self];
			
			[personTags setObject:personName forKey:[NSNumber numberWithInt:tag]];
		}
	}
			
	[self chooseNewPerson];
}


- (void)consumeImageData:(NSData *)imageData forTag:(int)imageTag
{
	NSString	*personName = [[[personTags objectForKey:[NSNumber numberWithInt:imageTag]] retain] autorelease];
	
	[personTags removeObjectForKey:[NSNumber numberWithInt:imageTag]];
	
	if (imageData)
	{
		NSImage	*personImage = [[[NSImage alloc] initWithData:imageData] autorelease];
		
		if ([personImage isValid])
			[personImages setObject:personImage forKey:personName];
	}
}


- (void)tileImageDidChange:(NSNotification *)notification
{
	int	currentCount = [[mosaicView mosaic] imagesFound];
	
//	NSLog(@"%d", currentCount - lastTileChangeCount);
	
	if (currentCount > lastTileChangeCount + 5)
	{
			// Switch to another person's image if the mosaic is not improving.
		lastTileChangeCount = currentCount + 1000;
		[self performSelectorOnMainThread:@selector(chooseNewPerson) withObject:nil waitUntilDone:NO];
	}
	else
		lastTileChangeCount = currentCount;
}


- (IBAction)openHomePage:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://homepage.mac.com/knarf/MacOSaiX"]];
}


- (void)windowWillClose:(NSNotification *)notification
{
	[[mosaicView mosaic] pause];
	[self autorelease];
}


- (void)dealloc
{
	[super dealloc];
}


@end
