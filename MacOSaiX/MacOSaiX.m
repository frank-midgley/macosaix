#import "MacOSaiX.h"
#import "PreferencesController.h"
#import <MacOSaiXPlugins/TilesSetupController.h>
#import <MacOSaiXPlugins/ImageSourceController.h>

@implementation MacOSaiX

+ (void)initialize
{
    NSUserDefaults	*defaults = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary	*appDefaults = [NSMutableDictionary dictionary];
    
    [appDefaults setObject:@"15" forKey:@"Autosave Frequency"];
    [appDefaults setObject:@"Rectangles" forKey:@"Tile Shapes"];
    [appDefaults setObject:@"20" forKey:@"Tiles Wide"];
    [appDefaults setObject:@"20" forKey:@"Tiles High"];
/*
    [appDefaults setObject:[NSArchiver archivedDataWithRootObject:[NSMutableArray arrayWithObjects:
				    [[ImageSource alloc] init], 
				    [[DirectoryImageSource alloc]
					initWithObject:[NSHomeDirectory() stringByAppendingString:@"/Pictures"]],
				    nil]]
		    forKey:@"Image Sources"];
*/
    [defaults registerDefaults:appDefaults];
    [defaults setBool:YES forKey:@"AppleDockIconEnabled"];
}


- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
		// Do an initial discovery of plug-ins
	[self discoverPlugIns];

    // To provide a service:
    //EncryptoClass *encryptor;
    //encryptor = [[EncryptoClass alloc] init];
    //[NSApp setServicesProvider:encryptor];
}


- (void)newMacOSaiXWithPasteboard:(NSPasteboard *)pBoard userObject:(id)userObj error:(NSString **)error
{
}


- (void)openPreferences:(id)sender
{
    PreferencesController	*windowController;
    
    windowController = [[PreferencesController alloc] initWithWindowNibName:@"Preferences"];
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
	
	while (plugInSubPath = [pathEnumerator nextObject])
	{
		NSString	*plugInPath = [plugInsPath stringByAppendingPathComponent:plugInSubPath];
		
		if ([_loadedPlugInPaths containsObject:plugInPath])
			[pathEnumerator skipDescendents];
		else
		{
			NSBundle	*plugInBundle = [NSBundle bundleWithPath:plugInPath];
			
			if (plugInBundle) // then the path is a valid bundle
			{
				Class	plugInPrincipalClass = [plugInBundle principalClass];
				
				if (plugInPrincipalClass && [plugInPrincipalClass isSubclassOfClass:[TilesSetupController class]])
				{
					[_tileSetupControllerClasses addObject:plugInPrincipalClass];
					[_loadedPlugInPaths addObject:plugInsPath];
				}

				if (plugInPrincipalClass && [plugInPrincipalClass isSubclassOfClass:[ImageSourceController class]])
				{
					[_imageSourceControllerClasses addObject:plugInPrincipalClass];
					[_loadedPlugInPaths addObject:plugInsPath];
				}

					// don't look inside this bundle for other bundles
				[pathEnumerator skipDescendents];
			}
		}
	}
}


- (NSArray *)tileSetupControllerClasses
{
	return _tileSetupControllerClasses;
}


@end
