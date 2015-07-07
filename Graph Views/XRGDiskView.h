/* 
 * XRG (X Resource Graph):  A system resource grapher for Mac OS X.
 * Copyright (C) 2002-2012 Gaucho Software, LLC.
 * You can view the complete license in the LICENSE file in the root
 * of the source tree.
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
 *
 */

//
//  XRGDiskView.h
//

#import <Cocoa/Cocoa.h>
#import <IOKit/IOKitLib.h>
#import <IOKit/storage/IOBlockStorageDriver.h>
#import "definitions.h"
#import "XRGGenericView.h"

@interface XRGDiskView : XRGGenericView {
@private
    NSSize					graphSize;
    int						numSamples;
    XRGModule				*m;
    
    int						*values;
    int						*readValues;
    int						*writeValues;
    int						currentIndex;
    int						maxVal;
    
    int						readBytes;
    int						writeBytes;
    int						totalDiskIO;
	long long				diskIOSinceLaunch;
    
    mach_port_t         	masterPort;
    io_iterator_t       	drivelist;  /* needs release */
	NSMutableArray			*volumeInfo;

    io_stats				i_dsk;
    io_stats				o_dsk;
}

- (void)setGraphSize:(NSSize)newSize;
- (void)setWidth:(int)newWidth;
- (void)updateMinSize;
- (int)convertHeight:(int) yComponent;
- (void)graphUpdate:(NSTimer *)aTimer;
- (void)min5Update:(NSTimer *)aTimer;
- (void)updateVolumeInfo;

- (NSString *)readBytesString;
- (NSString *)writeBytesString;

@end
