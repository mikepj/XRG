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
//  XRGDiskView.m
//

#import "XRGDiskView.h"
#import "XRGGraphWindow.h"
#import <CoreFoundation/CoreFoundation.h>
#include <sys/time.h>
#include <sys/param.h>
#include <sys/ucred.h>
#include <sys/mount.h>

void getDISKcounters(io_iterator_t drivelist, io_stats *i_dsk, io_stats *o_dsk);

@implementation XRGDiskView

- (void)awakeFromNib {    
    currentIndex = 0;
    maxVal       = 0;
              
    parentWindow = (XRGGraphWindow *)[self window];
    [parentWindow setDiskView:self];
    [parentWindow initTimers]; 
    appSettings = [parentWindow appSettings]; 
    moduleManager = [parentWindow moduleManager];

    drivelist  = IO_OBJECT_NULL;  /* needs release */
    masterPort = IO_OBJECT_NULL;

    /* get ports and services for drive stats */
    /* Obtain the I/O Kit communication handle */
    IOMasterPort(bootstrap_port, &masterPort);

    /* Obtain the list of all drive objects */
    IOServiceGetMatchingServices(masterPort, 
                                 IOServiceMatching("IOBlockStorageDriver"), 
                                 &drivelist);
	
	volumeInfo = [NSMutableArray arrayWithCapacity:10];
	[self updateVolumeInfo];
                                     
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];    
    m = [[XRGModule alloc] initWithName:@"Disk" andReference:self];
	m.doesFastUpdate = NO;
	m.doesGraphUpdate = YES;
	m.doesMin5Update = YES;
	m.doesMin30Update = NO;
	m.displayOrder = 6;
    [self updateMinSize];
    [m setIsDisplayed: (bool)[defs boolForKey:XRG_showDiskGraph]];

    [[parentWindow moduleManager] addModule:m];
    [self setGraphSize:[m currentSize]];
    
    // cut out the initial spike
    [self graphUpdate:nil];
    values[currentIndex] = 0;
    readValues[currentIndex] = 0;
    writeValues[currentIndex] = 0;
    maxVal = 0;
	diskIOSinceLaunch = 0;
}

- (void)setGraphSize:(NSSize)newSize {
    NSSize tmpSize;
    tmpSize.width = newSize.width;
    tmpSize.height = newSize.height;
    if (tmpSize.width < 1) tmpSize.width = 1;
    if (tmpSize.width > 2000) tmpSize.width = 2000;
    [self setWidth:tmpSize.width];
    graphSize = tmpSize;
}

- (void)setWidth:(int)newWidth {
    int i;
    int newNumSamples = newWidth;
    maxVal = 0;
    
    if (values) {
        int *newVals, *newReadVals, *newWriteVals;
        int newValIndex = newNumSamples - 1;
        newVals = calloc(newNumSamples, sizeof(int));
        newReadVals = calloc(newNumSamples, sizeof(int));
        newWriteVals = calloc(newNumSamples, sizeof(int));
        
        for (i = currentIndex; i >= 0; i--) {
            if (newValIndex < 0) break;
            newVals[newValIndex] = values[i];
            newReadVals[newValIndex] = readValues[i];
            newWriteVals[newValIndex] = writeValues[i];
            
            if (values[i] > maxVal) maxVal = values[i];

            newValIndex--;
        }
        
        for (i = numSamples - 1; i > currentIndex; i--) {
            if (newValIndex < 0) break;
            newVals[newValIndex] = values[i];
            newReadVals[newValIndex] = readValues[i];
            newWriteVals[newValIndex] = writeValues[i];
            
            if (values[i] > maxVal) maxVal = values[i];

            newValIndex--;
        }
                
        free(values);
        free(readValues);
        free(writeValues);
        values = newVals;
        readValues = newReadVals;
        writeValues = newWriteVals;
        currentIndex = newNumSamples - 1;
    }
    else {
        values = calloc(newNumSamples, sizeof(int));
        readValues = calloc(newNumSamples, sizeof(int));
        writeValues = calloc(newNumSamples, sizeof(int));
        currentIndex = 0;
    }
    numSamples = newNumSamples;
}

- (void)updateMinSize {
    float width, height;
    height = [appSettings textRectHeight] * 2;
    width = [@"D1023K W" sizeWithAttributes:[appSettings alignRightAttributes]].width + 6;
    
    [m setMinWidth: width];
    [m setMinHeight: height];
}

- (void)graphUpdate:(NSTimer *)aTimer{
    int i;
    currentIndex++;
    if (currentIndex == numSamples)
        currentIndex = 0;
    
    getDISKcounters(drivelist, &i_dsk, &o_dsk);    

    i_dsk.bytes_delta = i_dsk.bytes - i_dsk.bytes_prev;
    o_dsk.bytes_delta = o_dsk.bytes - o_dsk.bytes_prev;
    
    writeBytes = o_dsk.bytes_delta / [appSettings graphRefresh];
    readBytes = i_dsk.bytes_delta / [appSettings graphRefresh];

    i_dsk.bytes_prev = i_dsk.bytes; 
    o_dsk.bytes_prev = o_dsk.bytes;
    
    totalDiskIO = readBytes + writeBytes;
	diskIOSinceLaunch += totalDiskIO;
    
    readValues[currentIndex] = readBytes;
    writeValues[currentIndex] = writeBytes;
    if (totalDiskIO >= maxVal) {
        maxVal = totalDiskIO;
        values[currentIndex] = totalDiskIO;
    } else {
        if (values[currentIndex] == maxVal) {
            // set the new sample and find the new maxval
            values[currentIndex] = totalDiskIO;
            maxVal = 0;
            for (i = 0; i < numSamples; i++)
                if (values[i] > maxVal) maxVal = values[i];
        }
        else {
            values[currentIndex] = totalDiskIO;
        }
    }
    
	// Update the volume information.
	[self updateVolumeInfo];
	//NSLog(@"Volume: %@", volumeInfo);
	
    [self setNeedsDisplay: YES];       
}

- (void)min5Update:(NSTimer *)aTimer{
    /* Obtain the list of all drive objects */
    if (drivelist) {
        IOObjectRelease(drivelist);
        drivelist = IO_OBJECT_NULL;
    }
    
    IOServiceGetMatchingServices(masterPort, 
                                 IOServiceMatching("IOBlockStorageDriver"), 
                                 &drivelist);
}

- (void) updateVolumeInfo {
	[volumeInfo removeAllObjects];
	
	struct statfs *buf;
	int bufsize = 0;
	
	int numFS = getfsstat(NULL, bufsize, MNT_NOWAIT);
	
	bufsize = numFS * sizeof(struct statfs);
	buf = malloc(bufsize);
	
	getfsstat(buf, bufsize, MNT_NOWAIT);
	
	int i;
	for (i = 0; i < numFS; i++) {
		long blockSize = buf[i].f_bsize;
		
		NSMutableDictionary *d = [NSMutableDictionary dictionaryWithCapacity:5];
		d[@"FS Type"] = @(buf[i].f_fstypename);
		d[@"Total Bytes"] = @((long long)buf[i].f_blocks * (long long)blockSize);
		d[@"Free Bytes"] = @((long long)buf[i].f_bfree * (long long)blockSize);
		d[@"Mount Point"] = @(buf[i].f_mntonname);
		d[@"Total Files"] = [NSNumber numberWithLongLong:buf[i].f_files - buf[i].f_ffree];
		
		if ([d[@"FS Type"] isEqualToString:@"devfs"]) continue;
		if ([d[@"FS Type"] isEqualToString:@"autofs"]) continue;
		[volumeInfo addObject:d];
	}
	
	//printf("%s\n", [[volumeInfo description] lossyCString]);
	
	free(buf);
}

- (void)drawRect:(NSRect)rect {
    if ([self isHidden]) return;

    #ifdef XRG_DEBUG
        NSLog(@"In Disk DrawRect."); 
    #endif

    NSGraphicsContext *gc = [NSGraphicsContext currentContext]; 

    int i, max;
    NSInteger textRectHeight = [appSettings textRectHeight];
    
    [[appSettings graphBGColor] set];    
    NSRectFill([self bounds]);
    
    [gc setShouldAntialias:[appSettings antiAliasing]];

    CGFloat *data = (CGFloat *)alloca(numSamples * sizeof(CGFloat));

    if ([appSettings diskGraphMode]) {
        for (i = 0; i < numSamples; ++i) data[i] = (CGFloat)readValues[i];
    }
    else {
        for (i = 0; i < numSamples; ++i) data[i] = (CGFloat)values[i];
    }
    
    [self drawGraphWithData:data size:numSamples currentIndex:currentIndex maxValue:maxVal inRect:rect flipped:([appSettings diskGraphMode] == 1) color: [appSettings graphFG2Color]];
    
    for (i = 0; i < numSamples; ++i) data[i] = (float)writeValues[i];

    [self drawGraphWithData:data size:numSamples currentIndex:currentIndex maxValue:maxVal inRect:rect flipped:([appSettings diskGraphMode] == 2) color: [appSettings graphFG1Color]];

    [gc setShouldAntialias:YES];

    
    // draw the text
    [gc setShouldAntialias:[appSettings antialiasText]];

    NSMutableString *s = [[NSMutableString alloc] init];
	
	if ([@"Disk1023.9K W" sizeWithAttributes:[appSettings alignRightAttributes]].width + 6 > [self frame].size.width) {
		[s setString:@"D"];
	}
	else {
		[s setString:@"Disk"];
	}
    
    NSRect tmpRect = NSMakeRect(3, graphSize.height - textRectHeight, graphSize.width - 6, textRectHeight);    
    
    if (tmpRect.origin.y - textRectHeight > 0) {
        tmpRect.origin.y -= textRectHeight;
        tmpRect.size.height += textRectHeight;
        max = maxVal;
        if (max >= 1048576)
            [s appendFormat:@"\n%3.2fM/s",((float)max / 1048576.)];
        else if (max >= 1024)
            [s appendFormat:@"\n%4.1fK/s",((float)max / 1024.)];
        else
            [s appendFormat:@"\n%dB/s",max];
    }
    if (tmpRect.origin.y - textRectHeight > 0) {
        tmpRect.origin.y -= textRectHeight;
        tmpRect.size.height += textRectHeight;
		if (diskIOSinceLaunch >= 109951162777600.) 
            [s appendFormat:@"\n%.0fT", ((float)diskIOSinceLaunch / 1099511627776.)];
		else if (diskIOSinceLaunch >= 1099511627776.) 
            [s appendFormat:@"\n%.1fT", ((float)diskIOSinceLaunch / 1099511627776.)];
		else if (diskIOSinceLaunch >= 107374182400.) 
            [s appendFormat:@"\n%.0fG", ((float)diskIOSinceLaunch / 1073741824)];
		else if (diskIOSinceLaunch >= 1073741824) 
            [s appendFormat:@"\n%.1fG", ((float)diskIOSinceLaunch / 1073741824)];
        else if (diskIOSinceLaunch >= 104857600)
            [s appendFormat:@"\n%.0fM", ((float)diskIOSinceLaunch / 1048576.)];
        else if (diskIOSinceLaunch >= 1048576)
            [s appendFormat:@"\n%.1fM", ((float)diskIOSinceLaunch / 1048576.)];
        else if (diskIOSinceLaunch >= 1024)
            [s appendFormat:@"\n%.0fK", ((float)diskIOSinceLaunch / 1024.)];
        else
            [s appendFormat:@"%dB", (int)diskIOSinceLaunch];
    }
    [s drawInRect:tmpRect withAttributes:[appSettings alignLeftAttributes]];
    
    if ([appSettings diskGraphMode] == 0) {
        tmpRect.origin.y = 0;
        tmpRect.size.height = textRectHeight * 2;
		
		[s setString:@""];
		[s appendString:[self readBytesString]];
		[s appendString:@"\n"];
		[s appendString:[self writeBytesString]];
	
        [s drawInRect:tmpRect withAttributes:[appSettings alignRightAttributes]];
    }
    else if ([appSettings diskGraphMode] == 1) {
        tmpRect.origin.y = 0;
        tmpRect.size.height = textRectHeight;
        [[self writeBytesString] drawInRect:tmpRect withAttributes:[appSettings alignRightAttributes]];

        tmpRect.origin.y = graphSize.height - textRectHeight;
        [[self readBytesString] drawInRect:tmpRect withAttributes:[appSettings alignRightAttributes]];
    }
    else { // [appSettings diskGraphMode] == 2
        tmpRect.origin.y = 0;
        tmpRect.size.height = textRectHeight;
        [[self readBytesString] drawInRect:tmpRect withAttributes:[appSettings alignRightAttributes]];

        tmpRect.origin.y = graphSize.height - textRectHeight;
        [[self writeBytesString] drawInRect:tmpRect withAttributes:[appSettings alignRightAttributes]];
    }
    

    [gc setShouldAntialias:YES];
}

- (int)convertHeight:(int) yComponent {
    return (yComponent >= 0 ? yComponent : 0) * (graphSize.height - ([appSettings textRectHeight] * 2)) / 100;
}

- (NSMenu *)menuForEvent:(NSEvent *)theEvent {
    NSMenu *myMenu = [[NSMenu allocWithZone:[NSMenu menuZone]] initWithTitle:@"Disk View"];
    NSMenuItem *tMI = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:@"Open Disk Utility..." action:@selector(openDiskUtility:) keyEquivalent:@""];
    [myMenu addItem:tMI];
    
    [myMenu addItem:[NSMenuItem separatorItem]];
    
    tMI = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:@"Open XRG Disk Preferences..." action:@selector(openDiskPreferences:) keyEquivalent:@""];
    [myMenu addItem:tMI];
    
    return myMenu;
}

- (void)openDiskUtility:(NSEvent *)theEvent {
    [NSTask 
      launchedTaskWithLaunchPath:@"/usr/bin/open"
      arguments:@[@"/Applications/Utilities/Disk Utility.app"]
    ];
}

- (void)openDiskPreferences:(NSEvent *)theEvent {
    [[parentWindow controller] showPrefsWithPanel:@"Disk"];
}

- (BOOL)acceptsFirstMouse:(NSEvent *)theEvent {       
    return YES;
}

- (void)mouseDown:(NSEvent *)theEvent {
    [parentWindow mouseDown:theEvent];
}

- (void)mouseDragged:(NSEvent *)theEvent {
    [parentWindow mouseDragged:theEvent];
}

- (void)mouseUp:(NSEvent *)theEvent {
    [parentWindow mouseUp:theEvent];
}

- (NSString *)readBytesString {
	if (readBytes >= 104857600)
		return [NSString stringWithFormat:@"%3.1fM R",((float)readBytes / 1048576.)];
	else if (readBytes >= 1048576)
		return [NSString stringWithFormat:@"%3.2fM R",((float)readBytes / 1048576.)];
	else if (readBytes >= 102400)
		return [NSString stringWithFormat:@"%4.0fK R",((float)readBytes / 1024.)];
	else if (readBytes >= 1024)
		return [NSString stringWithFormat:@"%4.1fK R",((float)readBytes / 1024.)];
	else
		return [NSString stringWithFormat:@"%dB R", readBytes];
}

- (NSString *)writeBytesString {
	if (writeBytes >= 104857600)
		return [NSString stringWithFormat:@"%3.1fM W", ((float)writeBytes / 1048576.)];
	else if (writeBytes >= 1048576)
		return [NSString stringWithFormat:@"%3.2fM W", ((float)writeBytes / 1048576.)];
	else if (writeBytes >= 102400)
		return [NSString stringWithFormat:@"%4.0fK W", ((float)writeBytes / 1024.)];
	else if (writeBytes >= 1024)
		return [NSString stringWithFormat:@"%4.1fK W", ((float)writeBytes / 1024.)];
	else
		return [NSString stringWithFormat:@"%dB W", writeBytes];
}

@end

void getDISKcounters(io_iterator_t drivelist, io_stats *i_dsk, io_stats *o_dsk)
{
    io_registry_entry_t	drive      	= 0;  /* needs release */
    UInt64         	totalReadBytes  = 0;
    UInt64         	totalWriteBytes = 0;
    
    while ((drive = IOIteratorNext(drivelist))) {
        CFNumberRef 	number      = 0;  /* don't release */
        CFDictionaryRef properties  = 0;  /* needs release */
        CFDictionaryRef statistics  = 0;  /* don't release */
        UInt64 		value       = 0;

        /* Obtain the properties for this drive object */

        IORegistryEntryCreateCFProperties(drive, (CFMutableDictionaryRef *) &properties, kCFAllocatorDefault, kNilOptions);

        /* Obtain the statistics from the drive properties */
        statistics = (CFDictionaryRef) CFDictionaryGetValue(properties, CFSTR(kIOBlockStorageDriverStatisticsKey));

        if (statistics) {
            /* Obtain the number of bytes read from the drive statistics */
            number = (CFNumberRef) CFDictionaryGetValue(statistics, CFSTR(kIOBlockStorageDriverStatisticsBytesReadKey));
            if (number) {
                CFNumberGetValue(number, kCFNumberSInt64Type, &value);
                totalReadBytes += value;
            }
            
            /* Obtain the number of bytes written from the drive statistics */
            number = (CFNumberRef) CFDictionaryGetValue (statistics, CFSTR(kIOBlockStorageDriverStatisticsBytesWrittenKey));
            if (number) {
                CFNumberGetValue(number, kCFNumberSInt64Type, &value);
                totalWriteBytes += value;
            }
        }
        /* Release resources */
        
        CFRelease(properties); properties = 0;
        IOObjectRelease(drive); drive = 0;

    }
    IOIteratorReset(drivelist);
	  
    i_dsk->bytes = totalReadBytes;
    o_dsk->bytes = totalWriteBytes;
}

