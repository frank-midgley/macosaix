#import "MacOSaiX.h"
#import "NewMacOSaiXDocument.h"

@implementation MacOSaiX

- (void)applicationDidFinishLaunching
{
    // allocate locks?
    
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

@end
