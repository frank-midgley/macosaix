#import "MacOSaiX.h"
#import "NewMacOSaiXDocument.h"

@implementation MacOSaiX

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
