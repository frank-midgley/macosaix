//
//  MacOSaiXEventCatchingPanel.h
//  MacOSaiX
//
//  Created by Frank Midgley on 4/2/06.
//  Copyright 2006 Frank M. Midgley. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface MacOSaiXEventCatchingPanel : NSWindow
{

}

@end


@interface NSWindowController (MacOSaiXEventCatchingPanel)
- (void)windowEventDidOccur:(NSEvent *)event;
@end
