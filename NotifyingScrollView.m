//
//  NotifyingScrollView.m
//  MacOSaiX
//
//  Created by Frank Midgley on Thu Mar 21 2002.
//  Copyright (c) 2001 __MyCompanyName__. All rights reserved.
//

#import "NotifyingScrollView.h"

@implementation NotifyingScrollView

- (void)reflectScrolledClipView:(NSClipView *)cView
{
    [super reflectScrolledClipView:cView];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"View Did Scroll" object:self];
}

@end
