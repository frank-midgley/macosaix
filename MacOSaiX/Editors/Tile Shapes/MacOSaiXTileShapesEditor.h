//
//  MacOSaiXTileShapesEditor.h
//  MacOSaiX
//
//  Created by Frank Midgley on 12/22/06.
//  Copyright 2006 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXEditor.h"
#import "MacOSaiXPlugIn.h"

@protocol MacOSaiXTileShapes, MacOSaiXTileShapesEditor;


@interface MacOSaiXTileShapesEditor : MacOSaiXMosaicEditor
{
	IBOutlet NSTextField	*tileCountField;
	
	NSMutableArray			*tilesToEmbellish;
}

@end
