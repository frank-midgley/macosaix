//
//  MacOSaiX.h
//  MacOSaiX
//
//  Created by Frank Midgley on Thu Feb 21 2002.
//  Copyright (c) 2001 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>


@interface MacOSaiX : NSObject {
    
}

- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)sender;
- (void)newMacOSaiXDocument:(id)sender;

@end
