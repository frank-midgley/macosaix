#import "MacOSaiX.h"
#import "PreferencesController.h"
#import "MacOSaiXTileShapes.h"
#import "MacOSaiXImageSource.h"
#import "MacOSaiXDocument.h"
#import <pthread.h>


@implementation MacOSaiX


+ (void)initialize
{
    NSUserDefaults		*defaults = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary	*appDefaults = [NSMutableDictionary dictionary];
    
    [appDefaults setObject:@"15" forKey:@"Autosave Frequency"];
    [defaults registerDefaults:appDefaults];
    [defaults setBool:YES forKey:@"AppleDockIconEnabled"];
}


- (id)init
{
	if (self = [super init])
	{
		tileShapesClasses = [[NSMutableArray arrayWithCapacity:1] retain];
		imageSourceClasses = [[NSMutableArray arrayWithCapacity:4] retain];
		loadedPlugInPaths = [[NSMutableArray arrayWithCapacity:5] retain];
		
//		[[NSNotificationCenter defaultCenter] addObserver:self
//												 selector:@selector(documentDidFinishSaving:)
//													 name:MacOSaiXDocumentDidSaveNotification
//												   object:nil];
	}
	return self;
}


- (void)applicationWillFinishLaunching:(NSNotification *)notification
{
}


- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
	// TODO: version check
	
		// Do an initial discovery of plug-ins
		// (Now done lazily in MacOSaiXWindowController.)
	//[self discoverPlugIns];

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
