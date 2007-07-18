//
//  MacOSaiX.m
//  MacOSaiX
//
//  Created by Frank Midgley on Thu Feb 21 2002.
//  Copyright (c) 2001 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiX.h"

#import "MacOSaiXAboutBoxController.h"
#import "MacOSaiXCrashReporterController.h"
#import "MacOSaiXDisallowedImage.h"
#import "MacOSaiXDocument.h"
#import "MacOSaiXExporter.h"
#import "MacOSaiXFullScreenController.h"
#import "MacOSaiXFullScreenWindow.h"
#import "MacOSaiXImageCache.h"
#import "MacOSaiXImageOrientations.h"
#import "MacOSaiXKioskController.h"
#import "MacOSaiXKioskSetupController.h"
#import "MacOSaiXScreenSetupController.h"
#import "MacOSaiXSourceImage.h"
#import "MacOSaiXUpdateAvailableController.h"
#import "MacPADSocket.h"
#import "PreferencesController.h"

#import "MacOSaiXPlugIn.h"
#import "MacOSaiXImageOrientations.h"
#import "MacOSaiXImageSource.h"
#import "MacOSaiXTileShapes.h"

#import <Carbon/Carbon.h>
#import <pthread.h>
#import <mach/mach.h>
#import <mach/shared_memory_server.h>


NSString	*MacOSaiXDisallowedImagesDidChangeNotification = @"MacOSaiXDisallowedImagesDidChangeNotification";


@implementation MacOSaiX


+ (void)initialize
{
	NSDictionary	*appDefaults = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"Defaults" ofType:@"plist"]];
	
    [[NSUserDefaults standardUserDefaults] registerDefaults:appDefaults];
}


- (id)init
{
	if (self = [super init])
	{
		tileShapesPlugIns = [[NSMutableArray array] retain];
		imageOrientationsPlugIns = [[NSMutableArray array] retain];
		imageSourcePlugIns = [[NSMutableArray array] retain];
		exporterPlugIns = [[NSMutableArray array] retain];
		loadedPlugInPaths = [[NSMutableArray array] retain];
		kioskMosaicControllers = [[NSMutableArray array] retain];
		
		[self discoverPlugIns];
		
		disallowedImages = [[NSMutableArray array] retain];
		NSEnumerator	*disallowedImageDictEnumerator = [(NSArray *)[[NSUserDefaults standardUserDefaults] objectForKey:@"Disallowed Images"] objectEnumerator];
		NSDictionary	*disallowedImageDict = nil;
		while (disallowedImageDict = [disallowedImageDictEnumerator nextObject])
		{
			Class	imageSourceClass = NSClassFromString([disallowedImageDict objectForKey:@"Image Source Class Name"]);
			id		universalIdentifier = [NSUnarchiver unarchiveObjectWithData:[disallowedImageDict objectForKey:@"Image Identifier Archive"]];
			
			if (imageSourceClass && universalIdentifier)
				[disallowedImages addObject:[MacOSaiXDisallowedImage imageWithSourceClass:imageSourceClass universalIdentifier:universalIdentifier]];
		}
	}
	
	return self;
}


- (void)applicationWillFinishLaunching:(NSNotification *)notification
{
	NSUserDefaults	*defaults = [NSUserDefaults standardUserDefaults];
	
	if ([defaults boolForKey:@"Perform Update Check at Launch"])
	{
		NSDate				*dateOfNextUpdateCheck = [defaults objectForKey:@"Update Check After Date"];
		NSString			*versionToSkip = [defaults objectForKey:@"Update Check Version to Skip"],
							*currentVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
		
			// Check if the user didn't previously click the "Ask Me Again Later" button or 
			// if it's been long enough to check again.
		if (!dateOfNextUpdateCheck || [dateOfNextUpdateCheck timeIntervalSinceNow] <= 0)
		{
				// Clear out the date now that we're past it.
			[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"Update Check After Date"];
			
			MacPADSocket	*macPAD = [[MacPADSocket alloc] init];
			[macPAD setDelegate:self];
			
			if ([macPAD compareVersion:currentVersion toVersion:versionToSkip] != NSOrderedDescending)
			{
					// Remove the version to skip from the prefs if the current version is newer.
				[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"Update Check Version to Skip"];
				versionToSkip = nil;
			}
			
				// Perform the update check based on the version to skip (if defined) or the current version.
			if (versionToSkip)
				[macPAD performCheck:[NSURL URLWithString:@"http://homepage.mac.com/knarf/MacOSaiX/Version.plist"]
						withVersion:versionToSkip];
			else
				[macPAD performCheckWithURL:[NSURL URLWithString:@"http://homepage.mac.com/knarf/MacOSaiX/Version.plist"]];
		}
	}
	
	if ([defaults boolForKey:@"Check For Crash at Launch"])
		[MacOSaiXCrashReporterController checkForCrash];
}


- (void)macPADErrorOccurred:(NSNotification *)notification
{
	MacPADSocket	*macPAD = [notification object];
//	NSDictionary	*updateCheckInfo = [notification userInfo];
	
	[macPAD release];
}


- (void)macPADCheckFinished:(NSNotification *)notification
{
	MacPADSocket	*macPAD = [notification object];
	NSDictionary	*updateCheckInfo = [notification userInfo];
	
	switch ([[updateCheckInfo objectForKey:MacPADErrorCode] intValue])
	{
		case kMacPADResultNoNewVersion:		// No new version available. Not an error
		case kMacPADResultMissingValues:	// One or both arguments to performCheck: were nil
		case kMacPADResultInvalidURL:		// URL was invalid or could not be contacted
		case kMacPADResultInvalidFile:		// XML file was missing or not well-formed
		case kMacPADResultBadSyntax:		// Version info was missing from XML file
			break;
		case kMacPADResultNewVersion:		// New version is available.
		{
			MacOSaiXUpdateAvailableController	*controller = [[MacOSaiXUpdateAvailableController alloc] initWithMacPADSocket:macPAD];
			[controller showWindow:self];
			break;
		}
	}
	
	[macPAD release];
	macPAD = nil;
}


- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)sender
{
	return ![self inKioskMode];
}


- (BOOL)application:(NSApplication *)theApplication openFile:(NSString *)filename
{
	NSImage	*image = [[NSImage alloc] initWithContentsOfFile:filename];
	if (!image)
	{
		NSData	*imageData = [NSData dataWithContentsOfMappedFile:filename];
		
		image = [[NSImage alloc] initWithData:imageData];
	}
	
	if ([image isValid])
	{
		MacOSaiXDocument	*newDocument = [[NSDocumentController sharedDocumentController] openUntitledDocumentOfType:@"MacOSaiX Project" display:NO];
		
		[[newDocument mosaic] setTargetImage:image];
		[[newDocument mosaic] setTargetImagePath:filename];
		[newDocument showWindows];
		
		return YES;
	}
	else
		return NO;
}


- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
	NSEnumerator	*itemEnumerator = [[editMenu itemArray] objectEnumerator];
	NSMenuItem		*item = nil;
	while (item = [itemEnumerator nextObject])
	{
		SEL	itemAction = [item action];
		
		if (itemAction == @selector(editTargetImage:))
			[item setImage:[MacOSaiXTargetImageEditor image]];
		else if (itemAction == @selector(editImageSources:))
			[item setImage:[MacOSaiXImageSourcesEditor image]];
		else if (itemAction == @selector(editTileShapes:))
			[item setImage:[MacOSaiXTileShapesEditor image]];
		else if (itemAction == @selector(editImageUsage:))
			[item setImage:[MacOSaiXImageUsageEditor image]];
		else if (itemAction == @selector(editImageOrientations:))
			[item setImage:[MacOSaiXImageOrientationsEditor image]];
		else if (itemAction == @selector(editTileContent:))
			[item setImage:[MacOSaiXTileContentEditor image]];
	}
	
		// To provide a service:
    //[NSApp setServicesProvider:[[MacOSaiXClass alloc] init]];
	
	#ifdef DEBUG
		[NSTimer scheduledTimerWithTimeInterval:15.0 
										 target:self 
									   selector:@selector(checkFreeMemory:) 
									   userInfo:nil 
										repeats:YES];
	#endif
	
	#if 0
		NSBezierPath	*dontUsePath = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(3.0, 3.0, 26.0, 26.0)];
		[dontUsePath moveToPoint:NSMakePoint(6.0, 6.0)];
		[dontUsePath lineToPoint:NSMakePoint(26.0, 26.0)];
		[dontUsePath setLineWidth:6.0];
		NSImage			*dontUseImage = [[NSImage alloc] initWithSize:NSMakeSize(32.0, 32.0)];
		[dontUseImage lockFocus];
			[[NSColor clearColor] set];
			NSRectFill(NSMakeRect(0.0, 0.0, 32.0, 32.0));
			[[NSColor redColor] set];
			[dontUsePath stroke];
			NSBitmapImageRep	*dontUseRep = [[NSBitmapImageRep alloc] initWithFocusedViewRect:NSMakeRect(0.0, 0.0, 32.0, 32.0)];
			[[dontUseRep representationUsingType:NSPNGFileType properties:nil] writeToFile:@"/Users/fmidgley/Desktop/Don't Use.png" atomically:NO];
		[dontUseImage unlockFocus];
	#endif
}


#ifdef DEBUG
- (void)checkFreeMemory:(NSTimer *)timer
{
	struct task_basic_info	taskInfo;
	mach_msg_type_number_t	count = TASK_BASIC_INFO_COUNT;
	if (task_info(mach_task_self(), TASK_BASIC_INFO, (task_info_t)&taskInfo, &count) == KERN_SUCCESS)
		NSLog(@"%4.1f MB in use (cache = %3.1f MB for %5ld images)", 
			  (taskInfo.virtual_size - SHARED_TEXT_REGION_SIZE - SHARED_DATA_REGION_SIZE) / 1024.0 / 1024.0, 
			  [[MacOSaiXImageCache sharedImageCache] size] / 1024.0 / 1024.0, 
			  [[MacOSaiXImageCache sharedImageCache] count]);
	
	// MAX = 0xFFFFFFFF - SHARED_TEXT_REGION_SIZE - SHARED_DATA_REGION_SIZE = 3,758,096,383
}
#endif


//- (void)newMacOSaiXWithPasteboard:(NSPasteboard *)pBoard userObject:(id)userObj error:(NSString **)error
//{
//}

	
- (IBAction)showAboutBox:(id)sender
{
	MacOSaiXAboutBoxController	*controller = [[MacOSaiXAboutBoxController alloc] initWithWindow:nil];
	[controller showWindow:self];
	
	// controller will release itself when window closes
}


- (IBAction)openPreferences:(id)sender
{
	[[MacOSaiXPreferencesController sharedController] showWindow:self];

    // The windowController object will now take input and, if the user OK's, save the preferences
}


	// Check our Plug-Ins directory for tile setup and image source plug-ins and add any new ones to the known lists.
- (void)discoverPlugIns
{
	NSString				*plugInsPath = [[NSBundle mainBundle] builtInPlugInsPath];
	NSDirectoryEnumerator	*pathEnumerator = [[NSFileManager defaultManager] enumeratorAtPath:plugInsPath];
	NSString				*plugInSubPath;
	
	[tileShapesPlugIns removeAllObjects];
	[imageOrientationsPlugIns removeAllObjects];
	[imageSourcePlugIns removeAllObjects];
	[exporterPlugIns removeAllObjects];
	
	while (plugInSubPath = [pathEnumerator nextObject])
	{
		NSString	*plugInPath = [plugInsPath stringByAppendingPathComponent:plugInSubPath];
		
		if ([loadedPlugInPaths containsObject:plugInPath])
			[pathEnumerator skipDescendents];
		else
		{
			NSBundle	*plugInBundle = [NSBundle bundleWithPath:plugInPath];
			
			if (plugInBundle) // then the path is a valid bundle
			{
					// Check if this plug-in can run on this system.
				BOOL		plugInCompatible = YES;
				NSString	*minOSXString = [plugInBundle objectForInfoDictionaryKey:@"LSMinimumSystemVersion"];
				if (minOSXString)
				{
					NSArray		*versionComponents = [minOSXString componentsSeparatedByString:@"."];
					SInt32		minOSX = 0x0600 + [[versionComponents objectAtIndex:0] intValue] * 0x0100;
					if ([versionComponents count] > 1)
						minOSX += [[versionComponents objectAtIndex:1] intValue] * 0x010;
					if ([versionComponents count] > 2)
						minOSX += [[versionComponents objectAtIndex:2] intValue] * 0x001;
					
					SInt32		curOSX;
					plugInCompatible = (Gestalt(gestaltSystemVersion, &curOSX) == noErr && curOSX >= minOSX);
					
					// TBD: also check for conflicting class names?
				}
				
					// Make sure this copy of MacOSaiX is new enough to handle the plug-in.
				NSString	*minMacOSaiXString = [plugInBundle objectForInfoDictionaryKey:@"Minimum MacOSaiX Version"];
				if (plugInCompatible && minMacOSaiXString)
				{
					NSString		*versionString = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
					MacPADSocket	*macPAD = [[MacPADSocket alloc] init];
					plugInCompatible = ([macPAD compareVersion:minMacOSaiXString 
													toVersion:versionString] != NSOrderedAscending);
				}
				
				if (plugInCompatible)
				{
					Class	plugInClass = [plugInBundle principalClass];
					
					if ([plugInClass conformsToProtocol:@protocol(MacOSaiXPlugIn)])
					{
						if ([[plugInClass dataSourceClass] conformsToProtocol:@protocol(MacOSaiXTileShapes)])
						{
							[tileShapesPlugIns addObject:plugInClass];
							[loadedPlugInPaths addObject:plugInsPath];
						}

						if ([[plugInClass dataSourceClass] conformsToProtocol:@protocol(MacOSaiXImageOrientations)])
						{
							[imageOrientationsPlugIns addObject:plugInClass];
							[loadedPlugInPaths addObject:plugInsPath];
						}

						if ([[plugInClass dataSourceClass] conformsToProtocol:@protocol(MacOSaiXImageSource)])
						{
							[imageSourcePlugIns addObject:plugInClass];
							[loadedPlugInPaths addObject:plugInsPath];
						}

						if ([[plugInClass dataSourceClass] conformsToProtocol:@protocol(MacOSaiXExportSettings)])
						{
							[exporterPlugIns addObject:plugInClass];
							[loadedPlugInPaths addObject:plugInsPath];
						}
					}
				}

					// don't look inside this bundle for other bundles
				[pathEnumerator skipDescendents];
			}
		}
	}
}


- (NSArray *)tileShapesPlugIns
{
	[self discoverPlugIns];
	
	return tileShapesPlugIns;
}


- (NSArray *)imageOrientationsPlugIns
{
	[self discoverPlugIns];
	
	return imageOrientationsPlugIns;
}


- (NSArray *)imageSourcePlugIns
{
	[self discoverPlugIns];
	
	return imageSourcePlugIns;
}


- (NSArray *)exporterPlugIns
{
	[self discoverPlugIns];
	
	return exporterPlugIns;
}


- (NSArray *)allPlugIns
{
	[self discoverPlugIns];
	
	return [[[tileShapesPlugIns arrayByAddingObjectsFromArray:imageSourcePlugIns] arrayByAddingObjectsFromArray:imageOrientationsPlugIns] arrayByAddingObjectsFromArray:exporterPlugIns];
}


- (Class)plugInForDataSourceClass:(Class)dataSourceClass
{
	return [[NSBundle bundleForClass:dataSourceClass] principalClass];
}


#pragma mark


- (BOOL)isQuitting
{
	return quitting;
}


#pragma mark
#pragma mark Kiosk methods


- (void)openKioskSettingsWindowOnScreen:(NSScreen *)screen
							  tileCount:(int)tileCount
								message:(NSAttributedString *)message
				 messageBackgroundColor:(NSColor *)messageBackgroundColor
{
	kioskController = [[MacOSaiXKioskController alloc] initWithWindow:nil];
	
	NSWindow					*nibWindow = [kioskController window];
	MacOSaiXFullScreenWindow	*kioskWindow = [[MacOSaiXFullScreenWindow alloc] initWithContentRect:[screen frame] 
																						   styleMask:NSBorderlessWindowMask 
																							 backing:NSBackingStoreBuffered 
																							   defer:NO 
																							  screen:screen];
	[nibWindow setFrame:[screen frame] display:NO];
	[kioskWindow setContentView:[nibWindow contentView]];
	[kioskWindow setInitialFirstResponder:[nibWindow initialFirstResponder]];
	[kioskController setWindow:kioskWindow];
	[kioskWindow setDelegate:kioskController];
	[kioskController setTileCount:tileCount];
	[kioskController setMessage:message];
	[kioskController setMessageBackgroundColor:messageBackgroundColor];
	[kioskWindow makeKeyAndOrderFront:self];
}


- (MacOSaiXFullScreenController *)openMosaicWindowOnScreen:(NSScreen *)screen
{
	MacOSaiXFullScreenController	*mosaicController = [[MacOSaiXFullScreenController alloc] initWithWindow:nil];
	NSWindow						*nibWindow = [mosaicController window];
	MacOSaiXFullScreenWindow		*mosaicWindow = [[MacOSaiXFullScreenWindow alloc] initWithContentRect:[screen frame] 
																								styleMask:NSBorderlessWindowMask 
																								  backing:NSBackingStoreBuffered 
																									defer:NO 
																								   screen:screen];
	[mosaicWindow setContentView:[nibWindow contentView]];
	[mosaicWindow setInitialFirstResponder:[nibWindow initialFirstResponder]];
	[mosaicController setWindow:mosaicWindow];
	[mosaicWindow setDelegate:mosaicController];
	[mosaicWindow setFrame:[screen frame] display:NO];
	[mosaicWindow makeKeyAndOrderFront:self];
	
	return mosaicController;
}


- (IBAction)enterKioskMode:(id)sender
{
	// TBD: require no open documents?
	
		// Present a screen setup panel on all screens but the menu bar screen.
	NSMutableArray	*nonMainSetupControllers = [NSMutableArray array];
	NSEnumerator	*screenEnumerator = [[NSScreen screens] objectEnumerator];
	NSScreen		*screen = [screenEnumerator nextObject];	// the menu bar screen is always first
	while (screen = [screenEnumerator nextObject])
	{
		MacOSaiXScreenSetupController	*setupController = [[MacOSaiXScreenSetupController alloc] initWithWindow:nil];
		NSWindow						*nibWindow = [setupController window];
		MacOSaiXFullScreenWindow		*setupWindow = [[MacOSaiXFullScreenWindow alloc] initWithContentRect:[nibWindow frame] 
																								   styleMask:NSBorderlessWindowMask 
																									 backing:NSBackingStoreBuffered 
																									   defer:NO 
																									  screen:screen];
		[setupWindow setFloatingPanel:YES];
		[setupWindow setWorksWhenModal:YES];
		[setupWindow setHasShadow:YES];
		[setupWindow setFrame:[nibWindow frame] display:NO];
		[setupWindow setContentView:[nibWindow contentView]];
		[setupController setWindow:setupWindow];
		[setupWindow setFrameOrigin:NSMakePoint(NSMidX([screen frame]) - NSWidth([setupWindow frame]) / 2.0, 
												NSMidY([screen frame]) - NSHeight([setupWindow frame]) / 2.0)];
		[setupWindow makeKeyAndOrderFront:self];
		
		[nonMainSetupControllers addObject:setupController];
		[setupController release];
	}
	
		// Run the main setup window modally on the menu bar screen.
	MacOSaiXKioskSetupController	*mainSetupController = [[MacOSaiXKioskSetupController alloc] initWithWindow:nil];
	[mainSetupController setNonMainSetupControllers:nonMainSetupControllers];
	NSWindow						*setupWindow = [mainSetupController window];
	screen = [[NSScreen screens] objectAtIndex:0];
	[setupWindow setFrameOrigin:NSMakePoint(NSMidX([screen frame]) - NSWidth([setupWindow frame]) / 2.0, 
											NSMidY([screen frame]) - NSHeight([setupWindow frame]) / 2.0)];
	[mainSetupController showWindow:self];
	int								result = [NSApp runModalForWindow:[mainSetupController window]];
	[mainSetupController close];
	if (result == NSRunStoppedResponse)
	{
		OSStatus	status = SetSystemUIMode(kUIModeAllHidden, 0);
		if (status == noErr)
		{
			NSScreen						*menuBarScreen = [[NSScreen screens] objectAtIndex:0];
			
				// Open the kiosk window on the indicated screen.
			if ([mainSetupController shouldDisplayMosaicAndSettings])
				[self openKioskSettingsWindowOnScreen:menuBarScreen 
											tileCount:[mainSetupController tileCount] 
											  message:[mainSetupController message] 
							   messageBackgroundColor:[mainSetupController messageBackgroundColor]];
			else if ([mainSetupController shouldDisplayMosaicOnly])
				[kioskMosaicControllers addObject:[self openMosaicWindowOnScreen:menuBarScreen]];
		
				// Open mosaic windows on the other indicated screens
			NSEnumerator					*controllerEnumerator = [nonMainSetupControllers objectEnumerator];
			MacOSaiXScreenSetupController	*controller = nil;
			while (controller = [controllerEnumerator nextObject])
			{
				if ([controller shouldDisplayMosaicAndSettings])
					[self openKioskSettingsWindowOnScreen:[[controller window] screen]
												tileCount:[mainSetupController tileCount] 
												  message:[mainSetupController message] 
								   messageBackgroundColor:[mainSetupController messageBackgroundColor]];
				else if ([controller shouldDisplayMosaicOnly])
					[kioskMosaicControllers addObject:[self openMosaicWindowOnScreen:[[controller window] screen]]];
			}
			
			[kioskController setMosaicControllers:kioskMosaicControllers];
		}
	}
	
		// Close all of the screen setup windows.
	NSEnumerator					*controllerEnumerator = [nonMainSetupControllers objectEnumerator];
	MacOSaiXScreenSetupController	*controller = nil;
	while (controller = [controllerEnumerator nextObject])
		[[controller window] close];
	
	[mainSetupController release];
}


- (BOOL)inKioskMode
{
	return (kioskController != nil);
}


#pragma mark -
#pragma mark "Don't Use" support


- (void)saveDisallowedImages
{
		// Create an array of dictionaries capturing the disallowed images.
	NSMutableArray			*disallowedImagesDefault = [NSMutableArray array];
	NSEnumerator			*disallowedImageEnumerator = [disallowedImages objectEnumerator];
	MacOSaiXDisallowedImage	*disallowedImage = nil;
	while (disallowedImage = [disallowedImageEnumerator nextObject])
		[disallowedImagesDefault addObject:[NSDictionary dictionaryWithObjectsAndKeys:
												NSStringFromClass([disallowedImage imageSourceClass]), @"Image Source Class Name", 
												[NSArchiver archivedDataWithRootObject:[disallowedImage universalIdentifier]], @"Image Identifier Archive", 
												nil]];
	
	NSUserDefaults			*defaults = [NSUserDefaults standardUserDefaults];
	[defaults setObject:disallowedImagesDefault forKey:@"Disallowed Images"];
	[defaults synchronize];
}


- (void)disallowImage:(MacOSaiXSourceImage *)image
{
	MacOSaiXDisallowedImage	*disallowedImage = [MacOSaiXDisallowedImage imageWithSourceImage:image];
	
	[disallowedImages addObject:disallowedImage];
	
	[self saveDisallowedImages];
	
		// Let anyone who cares know that the disallowed images have changed.
	[[NSNotificationCenter defaultCenter] postNotificationName:MacOSaiXDisallowedImagesDidChangeNotification object:disallowedImage];
}


- (NSArray *)disallowedImages
{
	return [NSArray arrayWithArray:disallowedImages];
}


- (void)allowImage:(MacOSaiXDisallowedImage *)allowedImage
{
	unsigned	imageIndex = [disallowedImages indexOfObject:allowedImage];
	
	if (imageIndex != NSNotFound)
	{
		[disallowedImages removeObjectAtIndex:imageIndex];
		
		[self saveDisallowedImages];
		
			// Let anyone who cares know that the disallowed images have changed.
		[[NSNotificationCenter defaultCenter] postNotificationName:MacOSaiXDisallowedImagesDidChangeNotification object:allowedImage];
	}
}


@end
