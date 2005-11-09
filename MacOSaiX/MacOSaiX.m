//
//  MacOSaiX.m
//  MacOSaiX
//
//  Created by Frank Midgley on Thu Feb 21 2002.
//  Copyright (c) 2001 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiX.h"
#import "PreferencesController.h"
#import "MacOSaiXTileShapes.h"
#import "MacOSaiXImageSource.h"
#import "MacOSaiXDocument.h"
#import "MacPADSocket.h"
#import "MacOSaiXUpdateAvailableController.h"
#import "MacOSaiXCrashReporterController.h"
#import "MacOSaiXKioskController.h"
#import "MacOSaiXKioskSetupController.h"
#import "MacOSaiXKioskWindow.h"
#import "MacOSaiXMosaicController.h"
#import "MacOSaiXScreenSetupController.h"

#import <Carbon/Carbon.h>
#import <pthread.h>
#import <mach/mach.h>
#import <mach/shared_memory_server.h>


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
		tileShapesClasses = [[NSMutableArray array] retain];
		imageSourceClasses = [[NSMutableArray array] retain];
		loadedPlugInPaths = [[NSMutableArray array] retain];
		kioskMosaicControllers = [[NSMutableArray array] retain];
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
	
	[self discoverPlugIns];
	
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
			MacOSaiXUpdateAvailableController	*controller = [[MacOSaiXUpdateAvailableController alloc] 
																	initWithMacPADSocket:macPAD];
			[controller showWindow:self];
			break;
		}
	}
	
	[macPAD release];
	macPAD = nil;
}


- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)sender
{
	return NO;
}


- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
		// To provide a service:
    //[NSApp setServicesProvider:[[EncryptoClass alloc] init]];
	
	[NSTimer scheduledTimerWithTimeInterval:10.0 
									 target:self 
								   selector:@selector(checkFreeMemory:) 
								   userInfo:nil 
									repeats:YES];
	
	[self enterKioskMode:self];
}


- (void)checkFreeMemory:(NSTimer *)timer
{
	struct task_basic_info	taskInfo;
	mach_msg_type_number_t	count = TASK_BASIC_INFO_COUNT;
	if (task_info(mach_task_self(), TASK_BASIC_INFO, (task_info_t)&taskInfo, &count) == KERN_SUCCESS)
		NSLog(@"%ld bytes in use", taskInfo.virtual_size - SHARED_TEXT_REGION_SIZE - SHARED_DATA_REGION_SIZE);
	
	// MAX = 0xFFFFFFFF - SHARED_TEXT_REGION_SIZE - SHARED_DATA_REGION_SIZE = 3,758,096,383
}


//- (void)newMacOSaiXWithPasteboard:(NSPasteboard *)pBoard userObject:(id)userObj error:(NSString **)error
//{
//}


- (void)openPreferences:(id)sender
{
    MacOSaiXPreferencesController	*windowController;
    
    windowController = [[MacOSaiXPreferencesController alloc] initWithWindowNibName:@"Preferences"];
    [windowController showWindow:self];
    [[windowController window] makeKeyAndOrderFront:self];

    // The windowController object will now take input and, if the user OK's, save the preferences
}


	// Check our Plug-Ins directory for tile setup and image source plug-ins and add any new ones to the known lists.
- (void)discoverPlugIns
{
	NSString				*plugInsPath = [[NSBundle mainBundle] builtInPlugInsPath];
	NSDirectoryEnumerator	*pathEnumerator = [[NSFileManager defaultManager]
 enumeratorAtPath:plugInsPath];
	NSString				*plugInSubPath;
	
	[tileShapesClasses removeAllObjects];
	[imageSourceClasses removeAllObjects];
	
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
				Class	plugInPrincipalClass = [plugInBundle principalClass];
				
				if (plugInPrincipalClass && [plugInPrincipalClass conformsToProtocol:@protocol(MacOSaiXTileShapes)])
				{
					[tileShapesClasses addObject:plugInPrincipalClass];
					[loadedPlugInPaths addObject:plugInsPath];
				}

				if (plugInPrincipalClass && [plugInPrincipalClass conformsToProtocol:@protocol(MacOSaiXImageSource)])
				{
					[imageSourceClasses addObject:plugInPrincipalClass];
					[loadedPlugInPaths addObject:plugInsPath];
				}

					// don't look inside this bundle for other bundles
				[pathEnumerator skipDescendents];
			}
		}
	}
}


- (NSArray *)tileShapesClasses
{
	return tileShapesClasses;
}


- (NSArray *)imageSourceClasses
{
	return imageSourceClasses;
}


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
	
	NSWindow			*nibWindow = [kioskController window];
	MacOSaiXKioskWindow	*kioskWindow = [[MacOSaiXKioskWindow alloc] initWithContentRect:[screen frame] 
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


- (void)openKioskMosaicWindowOnScreen:(NSScreen *)screen
{
	MacOSaiXMosaicController	*mosaicController = [[MacOSaiXMosaicController alloc] initWithWindow:nil];
	NSWindow					*nibWindow = [mosaicController window];
	MacOSaiXKioskWindow			*mosaicWindow = [[MacOSaiXKioskWindow alloc] initWithContentRect:[screen frame] 
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
	
	[kioskMosaicControllers addObject:mosaicController];
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
		MacOSaiXKioskWindow				*setupWindow = [[MacOSaiXKioskWindow alloc] initWithContentRect:[nibWindow frame] 
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
				[self openKioskMosaicWindowOnScreen:menuBarScreen];
		
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
					[self openKioskMosaicWindowOnScreen:[[controller window] screen]];
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


@end
