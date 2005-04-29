//
//  GlyphTableColumn.m
//  MacOSaiX
//
//  Created by Frank Midgley on 4/9/05.
//  Copyright 2005 Frank M. Midgley. All rights reserved.
//

#import "GlyphTableColumn.h"
#import "GlyphImageSourceController.h"


@implementation MacOSaiXGlyphTableColumn


- (id)dataCellForRow:(int)rowIndex
{
	MacOSaiXGlyphImageSourceController	*dataSource = [[self tableView] dataSource];
	id									substituteCell = [dataSource tableView:[self tableView] 
														dataCellForTableColumn:self 
																		   row:rowIndex];
	
	return (substituteCell ? substituteCell : [self dataCell]);
}


@end
