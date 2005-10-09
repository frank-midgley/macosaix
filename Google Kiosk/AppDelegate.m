//
//  AppDelegate.m
//  MacOSaiX Google Kiosk
//
//  Created by Frank Midgley on Sat Oct. 8, 2005
//  Copyright (c) 2005 Frank M. Midgley. All rights reserved.
//

#import "AppDelegate.h"
#import "MacPADSocket.h"
#import "MacOSaiXUpdateAvailableController.h"
#import "MacOSaiXCrashReporterController.h"
#import "MacOSaiXGoogleKioskController.h"
#import "MacOSaiXKioskSetupController.h"
#import "MacOSaiXScreenSetupController.h"


@implementation AppDelegate


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
		// Present a screen setup panel on all screens but the menu bar screen.
	NSEnumerator	*screenEnumerator = [[NSScreen screens] objectEnumerator];
	NSScreen		*screen = [screenEnumerator nextObject];	// the menu bar screen is always first
	while (screen = [screenEnumerator nextObject])
	{
		MacOSaiXScreenSetupController	*setupController = [[MacOSaiXScreenSetupController alloc] initWithWindow:nil];
		NSPanel							*nibWindow = (NSPanel *)[setupController window],
										*borderlessWindow = [[NSPanel alloc] initWithContentRect:[nibWindow frame] 
																					   styleMask:NSBorderlessWindowMask 
																						 backing:NSBackingStoreBuffered 
																						   defer:NO 
																						  screen:screen];
		[borderlessWindow setFloatingPanel:YES];
		[borderlessWindow setWorksWhenModal:YES];
		[borderlessWindow setFrame:[nibWindow frame] display:NO];
		[borderlessWindow setContentView:[nibWindow contentView]];
		[setupController setWindow:borderlessWindow];
		[borderlessWindow setFrameOrigin:NSMakePoint(NSMidX([screen frame]), NSMidY([screen frame]))];
		[borderlessWindow center];
		[borderlessWindow makeKeyAndOrderFront:self];
	}
	
		// Run the main setup window modally on the menu bar screen.
	MacOSaiXKioskSetupController	*setupController = [[MacOSaiXKioskSetupController alloc] initWithWindow:nil];
	int								result = [NSApp runModalForWindow:[setupController window]];
	[setupController release];
	if (result == NSRunStoppedResponse)
	{
		MacOSaiXGoogleKioskController	*kioskController = [[MacOSaiXGoogleKioskController alloc] initWithWindow:nil];
		[kioskController showWindow:self];
	}
	else
		[NSApp terminate:self];
}


@end
