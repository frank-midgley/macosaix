#import "MacOSaiX.h"
#import "PreferencesController.h"
#import "MacOSaiXTileShapes.h"
#import "MacOSaiXImageSource.h"
#import "MacOSaiXDocument.h"
#import "MacPADSocket.h"
#import "MacOSaiXUpdateAvailableController.h"
#import <pthread.h>


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
		
//		[[NSNotificationCenter defaultCenter] addObserver:self
//												 selector:@selector(documentDidFinishSaving:)
//													 name:MacOSaiXDocumentDidSaveNotification
//												   object:nil];
	}
	return self;
}


- (void)applicationWillFinishLaunching:(NSNotification *)notification
{
	NSDate				*dateOfNextUpdateCheck = [[NSUserDefaults standardUserDefaults] objectForKey:@"Update Check After Date"];
	NSString			*versionToSkip = [[NSUserDefaults standardUserDefaults] objectForKey:@"Update Check Version to Skip"],
						*currentVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
	
	if (!dateOfNextUpdateCheck || [dateOfNextUpdateCheck timeIntervalSinceNow] <= 0)
	{
		[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"Update Check After Date"];
		
		MacPADSocket	*macPAD = [[MacPADSocket alloc] init];
		[macPAD setDelegate:self];
		
		if ([macPAD compareVersion:currentVersion toVersion:versionToSkip] != NSOrderedDescending)
		{
			[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"Update Check Version to Skip"];
			versionToSkip = nil;
		}
		
		if (versionToSkip)
			[macPAD performCheck:[NSURL URLWithString:@"http://homepage.mac.com/knarf/MacOSaiX/Version.plist"]
					withVersion:versionToSkip];
		else
			[macPAD performCheckWithURL:[NSURL URLWithString:@"http://homepage.mac.com/knarf/MacOSaiX/Version.plist"]];
	}
	
	[self discoverPlugIns];
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


- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
		// To provide a service:
    //[NSApp setServicesProvider:[[EncryptoClass alloc] init]];
}


//- (void)newMacOSaiXWithPasteboard:(NSPasteboard *)pBoard userObject:(id)userObj error:(NSString **)error
//{
//}


- (void)openPreferences:(id)sender
{
#if 1
	NSRunAlertPanel(@"Preferences" , @"Preferences are not available in this version.", @"Drat", nil, nil);
#else
    PreferencesController	*windowController;
    
    windowController = [[PreferencesController alloc] initWithWindowNibName:@"Preferences"];
    [windowController showWindow:self];
    [[windowController window] makeKeyAndOrderFront:self];

    // The windowController object will now take input and, if the user OK's, save the preferences
#endif
}


	// Check our Plug-Ins directory for tile setup and image source plug-ins and add any new ones to the known lists.
- (void)discoverPlugIns
{
	NSString				*plugInsPath = [[NSBundle mainBundle] builtInPlugInsPath];
	NSDirectoryEnumerator	*pathEnumerator = [[NSFileManager defaultManager]
 enumeratorAtPath:plugInsPath];
	NSString				*plugInSubPath;
	
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


//- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
//{
//	NSApplicationTerminateReply	reply = NSTerminateNow;
//	
//	quitting = YES;
//	
//		// If any documents are still saving then we need to wait for them to finish.
//	NSEnumerator				*documentEnumerator = [[[NSDocumentController sharedDocumentController] 
//															documents] objectEnumerator];
//	MacOSaiXDocument			*document = nil;
//	while (document = [documentEnumerator nextObject])
//		if ([document isSaving])
//		{
//			NSLog(@"Termination delayed");
//			reply = NSTerminateLater;
//		}
//
//	return reply;
//}


- (BOOL)isQuitting
{
	return quitting;
}


//- (void)documentDidFinishSaving:(NSNotification *)notification
//{
//	if (!quitting)
//		return;
//	
//		// Only react on the main thread.
//	if (pthread_main_np())
//	{
//		BOOL	wasCancelled = [[[notification userInfo] objectForKey:@"User Cancelled"] boolValue];
//		
//		if (wasCancelled)
//		{
//			quitting = NO;
//			[NSApp replyToApplicationShouldTerminate:NO];
//		}
//		else
//		{
//				// If any other documents are still saving then we need to wait.
//			NSEnumerator				*documentEnumerator = [[[NSDocumentController sharedDocumentController] 
//																	documents] objectEnumerator];
//			MacOSaiXDocument			*document = nil;
//			while (document = [documentEnumerator nextObject])
//				if ([document isSaving])
//					return;
//			
//			[NSApp replyToApplicationShouldTerminate:YES];
//		}
//	}
//	else
//		[self performSelectorOnMainThread:@selector(documentDidFinishSaving:) withObject:notification waitUntilDone:NO];
//}


@end
