#import "MacOSaiX.h"


@implementation MacOSaiX

- (void)newMacOSaiXDocument:(id)sender
{
    NewMacOSaiXDocument	*windowController;
    
    [[NewMacOSaiXDocument alloc] initWithNibNamed:@"NewMacOSaiXDocument"];
    
    if ([windowController userCancelled])
	return;
	
    [[NSDocumentController sharedDocumentController] openUntitledDocumentOfType:]
}

@end
