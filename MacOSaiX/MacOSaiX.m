#import "MacOSaiX.h"
#import "PreferencesController.h"
#import <MacOSaiXPlugins/TilesSetupController.h>
#import <MacOSaiXPlugins/ImageSourceController.h>

@implementation MacOSaiX

+ (void)initialize
{
	isalpha('a');	// get rid of weak linking warning

    NSUserDefaults	*defaults = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary	*appDefaults = [NSMutableDictionary dictionary];
    
    [appDefaults setObject:@"15" forKey:@"Autosave Frequency"];
//    [appDefaults setObject:@"Rectangles" forKey:@"Tile Shapes"];
//    [appDefaults setObject:@"20" forKey:@"Tiles Wide"];
//    [appDefaults setObject:@"20" forKey:@"Tiles High"];
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


- (id)init
{
	if (self = [super init])
	{
		_tilesSetupControllerClasses = [[NSMutableArray arrayWithCapacity:1] retain];
		_imageSourceControllerClasses = [[NSMutableArray arrayWithCapacity:4] retain];
		_loadedPlugInPaths = [[NSMutableArray arrayWithCapacity:5] retain];
	}
	return self;
}


- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
		// Do an initial discovery of plug-ins
//	[self discoverPlugIns];

    // To provide a service:
    //[NSApp setServicesProvider:[[EncryptoClass alloc] init]];
}


- (void)newMacOSaiXWithPasteboard:(NSPasteboard *)pBoard userObject:(id)userObj error:(NSString **)error
{
}


- (void)openPreferences2:(id)sender
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
					[_tilesSetupControllerClasses addObject:plugInPrincipalClass];
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


- (NSArray *)tilesSetupControllerClasses
{
	return _tilesSetupControllerClasses;
}


- (NSArray *)imageSourceControllerClasses
{
	return _imageSourceControllerClasses;
}


@end
