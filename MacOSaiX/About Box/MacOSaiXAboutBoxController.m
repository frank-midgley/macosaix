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


- (void)setMosaicPerson:(NSString *)personName
{
	lastTileChangeCount = 0;
	
	[currentPersonName autorelease];
	currentPersonName = [personName copy];
	
	[[MacOSaiXImageCache sharedImageCache] removeCachedImagesFromSource:[[[mosaicView mosaic] imageSources] lastObject]];
	
	[mosaicView setToolTip:personName];
	[[mosaicView mosaic] setOriginalImage:[personImages objectForKey:personName]];
	[[mosaicView mosaic] resume];
}


- (void)chooseNewPerson
{
	NSArray	*personNames = [personImages allKeys];
	
	[self setMosaicPerson:[personNames objectAtIndex:random() % [personNames count]]];
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
	
	personImages = [[NSMutableDictionary alloc] init];
	
	ABPerson				*myRecord = [[ABAddressBook sharedAddressBook] me];
	NSImage					*myImage = [[[NSImage alloc] initWithData:[myRecord imageData]] autorelease];
	if (myImage)
	{
		NSString	*personName = NSLocalizedString(@"Me", @"");
		
		[personImages setObject:myImage forKey:personName];
		[self setMosaicPerson:personName];
	}
	
	NSEnumerator			*abPersonEnumerator = [[[ABAddressBook sharedAddressBook] people] objectEnumerator];
	ABPerson				*abPerson = nil;
	while (abPerson = [abPersonEnumerator nextObject])
		if (abPerson != myRecord)
		{
			NSImage	*personImage = nil;
			NSData	*imageData = [abPerson imageData];
			
			if (imageData)
			{
				NSString	*personName = [abPerson valueForProperty:kABNicknameProperty];
				if (!personName)
					personName = [NSString stringWithFormat:@"%@ %@", 
															[abPerson valueForProperty:kABFirstNameProperty], 
															[abPerson valueForProperty:kABLastNameProperty]];
				
				personImage = [[[NSImage alloc] initWithData:imageData] autorelease];
				
				if ([personImage isValid])
					[personImages setObject:personImage forKey:personName];
			}
			
			if (!personImage)
				[abPerson beginLoadingImageDataForClient:self];
		}
	
	if (!currentPersonName)
		[self chooseNewPerson];
}


- (void)consumeImageData:(NSData *)imageData forTag:(int)imageTag
{
//	if (imageData)
//	{
//		NSImage	*personImage = [[[NSImage alloc] initWithData:imageData] autorelease];
//		
//		if ([personImage isValid])
//		{
//			[personImages setObject:personImage forKey:personName];
//			
//			if (!currentPersonName)
//				[self setMosaicPerson:personName];
//		}
//	}
//	else
//		[[mosaicView mosaic] setOriginalImage:[NSImage imageNamed:@"Application Icon"]];
}


- (void)tileImageDidChange:(NSNotification *)notification
{
	int	currentCount = [[mosaicView mosaic] imagesFound];
	
//	NSLog(@"%d", currentCount - lastTileChangeCount);
	
	if (currentCount > lastTileChangeCount + 10)
	{
			// Switch to another person's image.
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
