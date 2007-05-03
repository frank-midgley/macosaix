//
//  MacOSaiXSplitView.h
//  MacOSaiX
//
//  Created by Frank Midgley on 5/3/07.
//  Copyright 2007 Frank M. Midgley. All rights reserved.
//


@interface MacOSaiXSplitView : NSSplitView
{
	BOOL	adjustsLastViewOnly;
}

- (void)setAdjustsLastViewOnly:(BOOL)flag;
- (BOOL)adjustsLastViewOnly;

@end
