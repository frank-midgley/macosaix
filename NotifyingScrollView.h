//
//  NotifyingScrollView.h
//  MacOSaiX
//
//  Created by Frank Midgley on Thu Mar 21 2002.
//  Copyright (c) 2001 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

@interface NotifyingScrollView : NSScrollView {
}

- (void)reflectScrolledClipView:(NSClipView *)cView;

@end
