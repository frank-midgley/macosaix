//
//  GlyphImageSource.h
//  MacOSaiX
//
//  Created by Frank Midgley on Thu Apr 04 2002.
//  Copyright (c) 2001 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ImageSource.h"

@interface GlyphImageSource : ImageSource {
    NSArray	*_fontNames;
    NSWindow	*_focusWindow;	// for offscreen drawing
    NSLock	*_focusWindowLock;
}

@end
