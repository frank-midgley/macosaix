#import "MacOSaiX.h"
#import "NewMacOSaiXDocument.h"
#import "DirectoryImageSource.h"
#import "PreferencesController.h"

@implementation MacOSaiX

+ (void)initialize
{
    NSUserDefaults	*defaults = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary	*appDefaults = [NSMutableDictionary dictionary];
    
    [appDefaults setObject:@"15" forKey:@"Autosave Frequency"];
    [appDefaults setObject:@"Rectangles" forKey:@"Tile Shapes"];
    [appDefaults setObject:@"20" forKey:@"Tiles Wide"];
    [appDefaults setObject:@"20" forKey:@"Tiles High"];
    [appDefaults setObject:[NSArchiver archivedDataWithRootObject:[NSMutableArray arrayWithObjects:
				    [[ImageSource alloc] init], 
				    [[DirectoryImageSource alloc]
					initWithObject:[NSHomeDirectory() stringByAppendingString:@"/Pictures"]],
				    nil]]
		    forKey:@"Image Sources"];
    [defaults registerDefaults:appDefaults];
    [defaults setBool:YES forKey:@"AppleDockIconEnabled"];
}


- (void)applicationDidFinishLaunching
{
    // To provide a service:
    //EncryptoClass *encryptor;
    //encryptor = [[EncryptoClass alloc] init];
    //[NSApp setServicesProvider:encryptor];
}


- (void)newMacOSaiXWithPasteboard:(NSPasteboard *)pBoard userObject:(id)userObj error:(NSString **)error
{
}

- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)sender
{
    return NO;
}


- (void)newMacOSaiXDocument:(id)sender
{
    NewMacOSaiXDocument	*windowController;
    
    windowController = [[NewMacOSaiXDocument alloc] initWithWindowNibName:@"NewMacOSaiXDocument"];
    [windowController showWindow:self];
    [[windowController window] makeKeyAndOrderFront:self];

    // The windowController object will now take input and, if the user OK's, create a new MacOSaiCDocument
}


- (void)openPreferences:(id)sender
{
    PreferencesController	*windowController;
    
    windowController = [[PreferencesController alloc] initWithWindowNibName:@"Preferences"];
    [windowController showWindow:self];
    [[windowController window] makeKeyAndOrderFront:self];

    // The windowController object will now take input and, if the user OK's, save the preferences
}

@end
