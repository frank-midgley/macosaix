//
//  MacOSaiXImageOrientationsEditor.h
//  MacOSaiX
//
//  Created by Frank Midgley on 12/22/06.
//  Copyright 2006 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXEditor.h"


@interface MacOSaiXImageOrientationsEditor : MacOSaiXMosaicEditor
{
	IBOutlet NSTabView	*tabView;
	IBOutlet NSBox		*warningBox;
	
	BOOL				allTilesHaveOrientations, 
						noTilesHaveOrientations;
}

@end
