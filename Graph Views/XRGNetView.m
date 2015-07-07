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
//  XRGNetView.m
//

#import "XRGGraphWindow.h"
#import "XRGNetView.h"
#import <mach/mach.h>
#import <mach/mach_error.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/sysctl.h>
#include <sys/un.h>
#include <unistd.h>
//#include <kvm.h>
#include <net/if.h>
#include <net/if_dl.h>
#include <net/if_var.h>
#include <net/route.h>
#include <err.h>
#include <fcntl.h>
#include "ppp_msg.h"

int read_ApplePPP_data(io_stats *i_net, io_stats *o_net);

@implementation XRGNetView

- (void)awakeFromNib {    
    currentIndex = 0;
    maxVal       = 0;
	totalBytesSinceBoot = 0;
    totalBytesSinceLoad = 0;
    graphSize    = NSMakeSize(90, 112);
              
    parentWindow = (XRGGraphWindow *)[self window];
    [parentWindow setNetView:self];
    [parentWindow initTimers];  
    appSettings = [parentWindow appSettings];
    moduleManager = [parentWindow moduleManager];
    networkInterfaces = [[NSMutableArray alloc] init];
    
    firstTimeStats = YES;
    numInterfaces = 0;
    
    // set mib variable for the BSD network stats routines
    mib[0] = CTL_NET;
    mib[1] = PF_ROUTE;
    mib[2] = 0;
    mib[3] = 0;
    mib[4] = NET_RT_IFLIST;
    mib[5] = 0;
    
    // add ppp0 to the interface list
    int i;
    [self setInterfaceBandwidth:"ppp0" inBytes:0 outBytes:0];
    for (i = 0; i < numInterfaces; i++) {
        if (strcmp(interfaceStats[i].if_name, "ppp0") == 0) {
            pppInterfaceNum = i;
            break;
        }
    }
    
    // flush out the first spike
    [self setCurrentBandwidth];
        
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];    
    m = [[XRGModule alloc] initWithName:@"Network" andReference:self];
	m.doesFastUpdate = NO;
	m.doesGraphUpdate = YES;
	m.doesMin5Update = NO;
	m.doesMin30Update = NO;
	m.displayOrder = 5;
    [self updateMinSize];
    [m setIsDisplayed: (bool)[defs boolForKey:XRG_showNetworkGraph]];

    [[parentWindow moduleManager] addModule:m];
    [self setGraphSize:[m currentSize]];
}

- (void)graphUpdate:(NSTimer *)aTimer {
    int i;
    currentIndex++;
    if (currentIndex == numSamples)
        currentIndex = 0;
        
    [self setCurrentBandwidth];
    int totalBandwidth = sendBytes + recvBytes;
    if (totalBandwidth >= maxVal) {
        maxVal = totalBandwidth;
        values[currentIndex] = totalBandwidth;
        rxValues[currentIndex] = recvBytes;
        txValues[currentIndex] = sendBytes;
    } else {
        if (values[currentIndex] == maxVal) {
            // set the new sample and find the new maxval
            values[currentIndex] = totalBandwidth;
            rxValues[currentIndex] = recvBytes;
            txValues[currentIndex] = sendBytes;
            maxVal = 0;
            for (i = 0; i < numSamples; i++)
                if (values[i] > maxVal) maxVal = values[i];
        }
        else {
            values[currentIndex] = totalBandwidth;
            rxValues[currentIndex] = recvBytes;
            txValues[currentIndex] = sendBytes;
        }
    }
    
    [self setNeedsDisplay: YES];   
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
        int *newVals, *newRXVals, *newTXVals;
        int newValIndex = newNumSamples - 1;
        newVals   = calloc(newNumSamples, sizeof(int));
        newRXVals = calloc(newNumSamples, sizeof(int));
        newTXVals = calloc(newNumSamples, sizeof(int));
        
        for (i = currentIndex; i >= 0; i--) {
            if (newValIndex < 0) break;
            newVals[newValIndex]   = values[i];
            newRXVals[newValIndex] = rxValues[i];
            newTXVals[newValIndex] = txValues[i];
            if (values[i] > maxVal) maxVal = values[i];
            
            newValIndex--;
        }
        
        for (i = numSamples - 1; i > currentIndex; i--) {
            if (newValIndex < 0) break;
            newVals[newValIndex]   = values[i];
            newRXVals[newValIndex] = rxValues[i];
            newTXVals[newValIndex] = txValues[i];
            if (values[i] > maxVal) maxVal = values[i];

            newValIndex--;
        }
                
        free(values);      values   = newVals;
        free(rxValues);    rxValues = newRXVals;
        free(txValues);    txValues = newTXVals;
        currentIndex = newNumSamples - 1;
    }
    else {
        values   = calloc(newNumSamples, sizeof(int));
        rxValues = calloc(newNumSamples, sizeof(int));
        txValues = calloc(newNumSamples, sizeof(int));
        currentIndex = 0;
    }
    numSamples  = newNumSamples;
}

- (void)updateMinSize {
    float width, height;
    height = [appSettings textRectHeight] * 2;
    width = [@"N1023K Rx" sizeWithAttributes:[appSettings alignRightAttributes]].width + 6;

    [m setMinWidth: width];
    [m setMinHeight: height];
}

- (void)setCurrentBandwidth {
    int i;
    i_net.bytes = i_net.bytes_delta = 0;
    o_net.bytes = o_net.bytes_delta = 0;

    // First get the interface bandwidth for hardware interfaces.
    [self getInterfacesBandwidth];

    // Next get the interface bandwidth for ppp0
    read_ApplePPP_data(&interfaceStats[pppInterfaceNum].if_in, &interfaceStats[pppInterfaceNum].if_out); 
    
    // Now find out which interface we want to monitor and set the stats.
    char *s = (char *)[[appSettings networkInterface] cStringUsingEncoding:NSUTF8StringEncoding];
    for (i = 0; i < numInterfaces; i++) {
        if (strcmp("lo0", s) == 0) continue;
        
        if (strcmp("All", s) == 0 || strcmp(s, interfaceStats[i].if_name) == 0) {
            i_net.bytes += interfaceStats[i].if_in.bytes;
            i_net.bytes_delta += interfaceStats[i].if_in.bytes_delta;
            
            o_net.bytes += interfaceStats[i].if_out.bytes;
            o_net.bytes_delta += interfaceStats[i].if_out.bytes_delta;
        }
    }
        
    float refreshRate = [appSettings graphRefresh];

    sendBytes = o_net.bytes_delta / refreshRate;
    recvBytes = i_net.bytes_delta / refreshRate;

	
	
    if (!firstTimeStats) {
        totalBytesSinceLoad += i_net.bytes_delta + o_net.bytes_delta;
		
		if (totalBytesSinceBoot == 0) {
			totalBytesSinceBoot = i_net.bytes + o_net.bytes;
		}
		else {
			totalBytesSinceBoot += i_net.bytes_delta + o_net.bytes_delta;
		}
	}
    else {
        firstTimeStats = NO;
	}
}

// The code in this method is based on code from gkrellm.
- (void)getInterfacesBandwidth {
    struct if_msghdr	*ifm, *nextifm;
    struct sockaddr_dl	*sdl;
    char		*lim, *next;
    size_t		needed;
    char		s[32];

    if (sysctl(mib, 6, NULL, &needed, NULL, 0) < 0)
        return;
    if (alloc < needed) {
        if (buf != NULL)
            free(buf);
        buf = malloc(needed);
        if (buf == NULL)
            return;
        alloc = needed;
    }

    if (sysctl(mib, 6, buf, &needed, NULL, 0) < 0)
        return;
    lim = buf + needed;

    next = buf;
    while (next < lim) {
        ifm = (struct if_msghdr *)next;
        if (ifm->ifm_type != RTM_IFINFO)
            return;
        next += ifm->ifm_msglen;

        while (next < lim) {
            nextifm = (struct if_msghdr *)next;
            if (nextifm->ifm_type != RTM_NEWADDR)
                break;
            next += nextifm->ifm_msglen;
        }        
        
        if (ifm->ifm_flags & IFF_UP) {
            sdl = (struct sockaddr_dl *)(ifm + 1);
            if (sdl->sdl_family != AF_LINK)
                continue;
            strncpy(s, sdl->sdl_data, sdl->sdl_nlen);
            s[sdl->sdl_nlen] = '\0';
    
            [self setInterfaceBandwidth:s inBytes:(UInt64)ifm->ifm_data.ifi_ibytes outBytes:(UInt64)ifm->ifm_data.ifi_obytes];
        }
    }
}

- (void)setInterfaceBandwidth:(char *)interface_name inBytes:(UInt64)in_bytes outBytes:(UInt64)out_bytes {
    bool zeroDelta = NO;
    if (in_bytes == 0 || out_bytes == 0) {
        // Patch for bug noticed in ppp0 when making a second+ connection (4Gb would be added to inbytes and outbytes).
        // As far as I can tell, this is a bug in Apple's code.
        zeroDelta = YES;
    }
    

    if (numInterfaces == 0) {
        interfaceStats = (network_interface_stats *)malloc(sizeof(network_interface_stats));
        
        strncpy(interfaceStats[0].if_name, interface_name, 32);
        
        interfaceStats[0].if_in.bytes           = in_bytes;
        interfaceStats[0].if_in.bytes_prev      = 0;
        interfaceStats[0].if_in.bytes_delta     = zeroDelta ? 0 : in_bytes;
        interfaceStats[0].if_in.bsd_bytes       = in_bytes;
        interfaceStats[0].if_in.bsd_bytes_prev  = 0;
        
        interfaceStats[0].if_out.bytes          = out_bytes;
        interfaceStats[0].if_out.bytes_prev     = 0;
        interfaceStats[0].if_out.bytes_delta    = zeroDelta ? 0 : out_bytes;
        interfaceStats[0].if_out.bsd_bytes      = out_bytes;
        interfaceStats[0].if_out.bsd_bytes_prev = 0;
        
        if (strcmp(interface_name, "lo0") != 0)
            [networkInterfaces addObject:@(interface_name)];

        numInterfaces++;
    }
    else {
        bool found = NO;
        int i;
        
        // Check through our interface array for the named interface
        for (i = 0; i < numInterfaces; i++) {
            if (strcmp(interface_name, interfaceStats[i].if_name) == 0) {
                found = YES;
                break;
            }
        }
        
        if (found) {
            // We found the interface, the index is i.
            // Update the in-bound stats
            interfaceStats[i].if_in.bsd_bytes_prev = interfaceStats[i].if_in.bsd_bytes;
            interfaceStats[i].if_in.bsd_bytes      = in_bytes;
            
            if (zeroDelta) {
                interfaceStats[i].if_in.bytes_delta = 0;
            }
            else if (interfaceStats[i].if_in.bsd_bytes < interfaceStats[i].if_in.bsd_bytes_prev) {
                interfaceStats[i].if_in.bytes_delta = interfaceStats[i].if_in.bsd_bytes + 
                                                      (((unsigned int)-1) - interfaceStats[i].if_in.bsd_bytes_prev);
            }
            else {
                interfaceStats[i].if_in.bytes_delta = interfaceStats[i].if_in.bsd_bytes - 
                                                      interfaceStats[i].if_in.bsd_bytes_prev;
            }

            interfaceStats[i].if_in.bytes_prev     = interfaceStats[i].if_in.bytes;
            interfaceStats[i].if_in.bytes         += interfaceStats[i].if_in.bytes_delta;
            
            // Update the out-bound stats
            interfaceStats[i].if_out.bsd_bytes_prev = interfaceStats[i].if_out.bsd_bytes;
            interfaceStats[i].if_out.bsd_bytes      = out_bytes;
            
            if (zeroDelta) {
                interfaceStats[i].if_out.bytes_delta = 0;
            }
            else if (interfaceStats[i].if_out.bsd_bytes < interfaceStats[i].if_out.bsd_bytes_prev) {
                interfaceStats[i].if_out.bytes_delta = interfaceStats[i].if_out.bsd_bytes + 
                                                       (((unsigned int)-1) - interfaceStats[i].if_out.bsd_bytes_prev);
            }
            else {
                interfaceStats[i].if_out.bytes_delta = interfaceStats[i].if_out.bsd_bytes - 
                                                       interfaceStats[i].if_out.bsd_bytes_prev;
            }

            interfaceStats[i].if_out.bytes_prev     = interfaceStats[i].if_out.bytes;
            interfaceStats[i].if_out.bytes         += interfaceStats[i].if_out.bytes_delta;
        }
        else {
            // need to add an interface.
            network_interface_stats *new_stats = malloc((numInterfaces + 1) * sizeof(network_interface_stats));

            // move the data to the new array
            for (i = 0; i < numInterfaces; i++) {
                strncpy(new_stats[i].if_name, interfaceStats[i].if_name, 32);
                
                new_stats[i].if_in.bytes           = interfaceStats[i].if_in.bytes;
                new_stats[i].if_in.bytes_prev      = interfaceStats[i].if_in.bytes_prev;
                new_stats[i].if_in.bytes_delta     = interfaceStats[i].if_in.bytes_delta;
                new_stats[i].if_in.bsd_bytes       = interfaceStats[i].if_in.bsd_bytes;
                new_stats[i].if_in.bsd_bytes_prev  = interfaceStats[i].if_in.bsd_bytes_prev;
                
                new_stats[i].if_out.bytes          = interfaceStats[i].if_out.bytes;
                new_stats[i].if_out.bytes_prev     = interfaceStats[i].if_out.bytes_prev;
                new_stats[i].if_out.bytes_delta    = interfaceStats[i].if_out.bytes_delta;
                new_stats[i].if_out.bsd_bytes      = interfaceStats[i].if_out.bsd_bytes;
                new_stats[i].if_out.bsd_bytes_prev = interfaceStats[i].if_out.bsd_bytes_prev;
            }
            
            // free interfaceStats and set it equal to new_stats
            free(interfaceStats);
            interfaceStats = new_stats;
            
            strncpy(interfaceStats[numInterfaces].if_name, interface_name, 32);
            
            interfaceStats[numInterfaces].if_in.bytes           = in_bytes;
            interfaceStats[numInterfaces].if_in.bytes_prev      = 0;
            interfaceStats[numInterfaces].if_in.bytes_delta     = in_bytes;
            interfaceStats[numInterfaces].if_in.bsd_bytes       = in_bytes;
            interfaceStats[numInterfaces].if_in.bsd_bytes_prev  = 0;
            
            interfaceStats[numInterfaces].if_out.bytes          = out_bytes;
            interfaceStats[numInterfaces].if_out.bytes_prev     = 0;
            interfaceStats[numInterfaces].if_out.bytes_delta    = out_bytes;
            interfaceStats[numInterfaces].if_out.bsd_bytes      = out_bytes;
            interfaceStats[numInterfaces].if_out.bsd_bytes_prev = 0;
            
            if (strcmp(interface_name, "lo0") != 0)
                [networkInterfaces addObject:@(interface_name)];
            
            numInterfaces++;
        }
    }
}

- (int)getSendBytes {
    return sendBytes;
}

- (int)getRecvBytes {
    return recvBytes;
}

- (int)getMaxValue {
    return maxVal;
}

- (void)setNetworkInterfaces:(char **)interfaces {
    int i = 0;
    
    networkInterfaces = [[NSMutableArray alloc] init];
    while (interfaces[i][0] != '\0') {
        [networkInterfaces addObject:@(interfaces[i++])];
    }
}

- (NSArray *)networkInterfaces {
    return networkInterfaces;
}

- (void)drawRect:(NSRect)rect {
    if ([self isHidden]) return;

    #ifdef XRG_DEBUG
        NSLog(@"In Network DrawRect."); 
    #endif

    NSGraphicsContext *gc = [NSGraphicsContext currentContext]; 

    NSInteger i, max, tx, rx;
    NSInteger textRectHeight = [appSettings textRectHeight];
    max = [self getMaxValue];
    max = (max > [appSettings netMinGraphScale]) ? max : [appSettings netMinGraphScale];

    [[appSettings graphBGColor] set];    
    NSRectFill([self bounds]);
    
    NSRect tmpRect = NSMakeRect(0, 0, graphSize.width, textRectHeight * 2);    
    tmpRect.origin.x   += 3;
    tmpRect.size.width -= 6;
    tmpRect.size.height = textRectHeight;
    
    [gc setShouldAntialias:[appSettings antiAliasing]];

    CGFloat *data = (CGFloat *)alloca(numSamples * sizeof(CGFloat));
    
    NSInteger netGraphMode = [appSettings netGraphMode];


    /* received data */
    if (netGraphMode == 0) {
        for (i = 0; i < numSamples; ++i) data[i] = (CGFloat)values[i]; /* values = rxValues + txValues */
    }
    else {
        for (i = 0; i < numSamples; ++i) data[i] = (CGFloat)rxValues[i];
    }

    [self drawGraphWithData:data size:numSamples currentIndex:currentIndex maxValue:max inRect:rect flipped:(netGraphMode == 2) color:[appSettings graphFG2Color]];


    /* sent data */
    for (i = 0; i < numSamples; ++i) data[i] = (CGFloat)txValues[i];
        
    [self drawGraphWithData:data size:numSamples currentIndex:currentIndex maxValue:max inRect:rect flipped:(netGraphMode == 1) color:[appSettings graphFG1Color]];

    [gc setShouldAntialias:YES];

        
    // draw the text
    [gc setShouldAntialias:[appSettings antialiasText]];

    NSMutableString *s = [[NSMutableString alloc] init];
	
	if ([@"Net1023K Rx" sizeWithAttributes:[appSettings alignRightAttributes]].width + 6 > [self frame].size.width) {
		[s appendFormat:@"N"];
	}
	else {
		[s appendFormat:@"Net"];
	}
    //[s appendFormat:@"Net - %@", [appSettings networkInterface]];
    tmpRect.origin.y = graphSize.height - textRectHeight;
    
    // draw the scale if there is room
    if (tmpRect.origin.y - textRectHeight > 0) {
        tmpRect.origin.y -= textRectHeight;
        tmpRect.size.height += textRectHeight;
        if (max >= 1048576)
            [s appendFormat:@"\n%3.2fM/s", ((CGFloat)max / 1048576.)];
        else if (max >= 1024)
            [s appendFormat:@"\n%4.1fK/s", ((CGFloat)max / 1024.)];
        else
            [s appendFormat:@"\n%ldB/s", (long)max];
    }
    
    // draw the total bandwidth used if there is room
    if ([appSettings showTotalBandwidthSinceBoot]) {
        if (tmpRect.origin.y - textRectHeight > 0) {
            tmpRect.origin.y -= textRectHeight;
            tmpRect.size.height += textRectHeight;
            if (totalBytesSinceBoot >= 1073741824)
                [s appendFormat:@"\n%3.2fG", ((CGFloat)totalBytesSinceBoot / 1073741824.)];
            else if (totalBytesSinceBoot >= 1048576)
                [s appendFormat:@"\n%3.2fM", ((CGFloat)totalBytesSinceBoot / 1048576.)];
            else if (totalBytesSinceBoot >= 1024)
                [s appendFormat:@"\n%4.1fK", ((CGFloat)totalBytesSinceBoot / 1024.)];
            else
                [s appendFormat:@"\n%quB", totalBytesSinceBoot];
        }
    }
    if ([appSettings showTotalBandwidthSinceLoad]) {
        if (tmpRect.origin.y - textRectHeight > 0) {
            tmpRect.origin.y -= textRectHeight;
            tmpRect.size.height += textRectHeight;
            if (totalBytesSinceLoad >= 1073741824)
                [s appendFormat:@"\n%3.2fG", ((CGFloat)totalBytesSinceLoad / 1073741824.)];
            else if (totalBytesSinceLoad >= 1048576)
                [s appendFormat:@"\n%3.2fM", ((CGFloat)totalBytesSinceLoad / 1048576.)];
            else if (totalBytesSinceLoad >= 1024)
                [s appendFormat:@"\n%4.1fK", ((CGFloat)totalBytesSinceLoad / 1024.)];
            else
                [s appendFormat:@"\n%quB", totalBytesSinceLoad];
        }
    }

    [s drawInRect:tmpRect withAttributes:[appSettings alignLeftAttributes]];
        
    if (netGraphMode == 0) {
        tmpRect.origin.y = 0;
        tmpRect.size.height = textRectHeight * 2;
        [s setString:@""];
        
        rx = [self getRecvBytes];
		if (rx >= 104857600) 
			[s appendFormat:@"%3.1fM Rx", ((CGFloat)rx / 1048576.)];
        else if (rx >= 1048576)
            [s appendFormat:@"%3.2fM Rx", ((CGFloat)rx / 1048576.)];
        else if (rx >= 102400)
            [s appendFormat:@"%4.0fK Rx", ((CGFloat)rx / 1024.)];
        else if (rx >= 1024)
            [s appendFormat:@"%4.1fK Rx", ((CGFloat)rx / 1024.)];
        else
            [s appendFormat:@"%ldB Rx", (long)rx];
        
        
        tx = [self getSendBytes];
		if (tx >= 104857600) 
			[s appendFormat:@"\n%3.1fM Tx", ((CGFloat)tx / 1048576.)];
        else if (tx >= 1048576)
            [s appendFormat:@"\n%3.2fM Tx", ((CGFloat)tx / 1048576.)];
        else if (rx >= 102400)
            [s appendFormat:@"\n%4.0fK Tx", ((CGFloat)tx / 1024.)];
        else if (tx >= 1024)
            [s appendFormat:@"\n%4.1fK Tx", ((CGFloat)tx / 1024.)];
        else
            [s appendFormat:@"\n%ldB Tx", (long)tx];
        
        [s drawInRect:tmpRect withAttributes:[appSettings alignRightAttributes]];
    }
    else if (netGraphMode == 1) {
        tmpRect.origin.y = 0;
        tmpRect.size.height = textRectHeight;
        [s setString:@""];
        rx = [self getRecvBytes];
		if (rx >= 104857600) 
			[s appendFormat:@"%3.1fM Rx", ((CGFloat)rx / 1048576.)];
        else if (rx >= 1048576)
            [s appendFormat:@"%3.2fM Rx", ((CGFloat)rx / 1048576.)];
        else if (rx >= 102400)
            [s appendFormat:@"%4.0fK Rx", ((CGFloat)rx / 1024.)];
        else if (rx >= 1024)
            [s appendFormat:@"%4.1fK Rx", ((CGFloat)rx / 1024.)];
        else
            [s appendFormat:@"%ldB Rx", (long)rx];
		
        [s drawInRect:tmpRect withAttributes:[appSettings alignRightAttributes]];
        
        tmpRect.origin.y = graphSize.height - textRectHeight;
        [s setString:@""];
        tx = [self getSendBytes];
		if (tx >= 104857600) 
			[s appendFormat:@"%3.1fM Tx", ((CGFloat)tx / 1048576.)];
        else if (tx >= 1048576)
            [s appendFormat:@"%3.2fM Tx", ((CGFloat)tx / 1048576.)];
        else if (tx >= 102400)
            [s appendFormat:@"%4.0fK Tx", ((CGFloat)tx / 1024.)];
        else if (tx >= 1024)
            [s appendFormat:@"%4.1fK Tx", ((CGFloat)tx / 1024.)];
        else
            [s appendFormat:@"%ldB Tx", (long)tx];
		
        [s drawInRect:tmpRect withAttributes:[appSettings alignRightAttributes]];
    }
    else { // netGraphMode == 2
        tmpRect.origin.y = 0;
        tmpRect.size.height = textRectHeight;
        [s setString:@""];
        tx = [self getSendBytes];
		if (tx >= 104857600) 
			[s appendFormat:@"%3.1fM Tx", ((CGFloat)tx / 1048576.)];
        else if (tx >= 1048576)
            [s appendFormat:@"%3.2fM Tx", ((CGFloat)tx / 1048576.)];
        else if (tx >= 102400)
            [s appendFormat:@"%4.0fK Tx", ((CGFloat)tx / 1024.)];
        else if (tx >= 1024)
            [s appendFormat:@"%4.1fK Tx", ((CGFloat)tx / 1024.)];
        else
            [s appendFormat:@"%ldB Tx", (long)tx];
		
        [s drawInRect:tmpRect withAttributes:[appSettings alignRightAttributes]];
        
        tmpRect.origin.y = graphSize.height - textRectHeight;
        [s setString:@""];
        rx = [self getRecvBytes];
		if (rx >= 104857600) 
			[s appendFormat:@"%3.1fM Rx", ((CGFloat)rx / 1048576.)];
        else if (rx >= 1048576)
            [s appendFormat:@"%3.2fM Rx", ((CGFloat)rx / 1048576.)];
        else if (rx >= 102400)
            [s appendFormat:@"%4.0fK Rx", ((CGFloat)rx / 1024.)];
        else if (rx >= 1024)
            [s appendFormat:@"%4.1fK Rx", ((CGFloat)rx / 1024.)];
        else
            [s appendFormat:@"%ldB Rx", (long)rx];
		
        [s drawInRect:tmpRect withAttributes:[appSettings alignRightAttributes]];
    }


    [gc setShouldAntialias:YES];
}

- (int)convertHeight:(int) yComponent {
    return (yComponent >= 0 ? yComponent : 0) * (graphSize.height - ([appSettings textRectHeight] * 2)) / 100;
}

- (NSMenu *)menuForEvent:(NSEvent *)theEvent {
    NSMenu *myMenu = [[NSMenu allocWithZone:[NSMenu menuZone]] initWithTitle:@"Network View"];
    NSMenuItem *tMI;
    int i;

    tMI = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:@"Network Interface Traffic" action:@selector(emptyEvent:) keyEquivalent:@""];
    [myMenu addItem:tMI];

    for (i = 0; i < numInterfaces; i++) {
        tMI = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:[NSString stringWithFormat:@"%s: RX(%1.1fM) TX(%1.1fM)", interfaceStats[i].if_name, interfaceStats[i].if_in.bytes / 1024. / 1024., interfaceStats[i].if_out.bytes / 1024. / 1024.] action:@selector(emptyEvent:) keyEquivalent:@""];
        [myMenu addItem:tMI];
    }
    
    [myMenu addItem:[NSMenuItem separatorItem]];
    
    tMI = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:@"Open Network System Preferences..." action:@selector(openNetworkSystemPreferences:) keyEquivalent:@""];
    [myMenu addItem:tMI];
    
    tMI = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:@"Open Network Utility..." action:@selector(openNetworkUtility:) keyEquivalent:@""];
    [myMenu addItem:tMI];
    
    [myMenu addItem:[NSMenuItem separatorItem]];
    
    tMI = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:@"Open XRG Network Preferences..." action:@selector(openNetworkPreferences:) keyEquivalent:@""];
    [myMenu addItem:tMI];
    
    return myMenu;
}

- (void)emptyEvent:(NSEvent *)theEvent {
}

- (void)openNetworkSystemPreferences:(NSEvent *)theEvent {
    [NSTask 
      launchedTaskWithLaunchPath:@"/usr/bin/open"
      arguments:@[@"/System/Library/PreferencePanes/Network.prefPane"]
    ];
}

- (void)openNetworkUtility:(NSEvent *)theEvent {
    [NSTask 
      launchedTaskWithLaunchPath:@"/usr/bin/open"
      arguments:@[@"/Applications/Utilities/Network Utility.app"]
    ];
}

- (void)openNetworkPreferences:(NSEvent *)theEvent {
    [[parentWindow controller] showPrefsWithPanel:@"Network"];
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

@end

/*** PPPlib stuff ***/

/* Stevens code */
ssize_t readn(int fd, void *vptr, size_t n)
{
    size_t nleft;
    ssize_t nread;
    char *ptr;

    ptr = vptr;
    nleft = n;
    while (nleft > 0)
    {
        if ( (nread = read(fd, ptr, nleft)) < 0)
            return(nread);	/* error, return < 0 */
        else if (nread == 0)
            break;		/* EOF */

        nleft -= nread;
        ptr += nread;
    }
    return (n-nleft);	/* return >= 0 */
}

ssize_t writen(int fd, const void *vptr, size_t n)
{
    size_t	nleft;
    ssize_t	nwritten;
    const char	*ptr;

    ptr = vptr;	/* can't do pointer arithmetic on void * */
    nleft = n;
    while (nleft > 0)
    {
        if ( (nwritten = write(fd, ptr, nleft)) <= 0)
            return(nwritten);	/* error */

        nleft -= nwritten;
        ptr += nwritten;
    }
    return (n);
}

int read_ApplePPP_data(io_stats *i_net, io_stats *o_net)
{
/*    int ref;
    struct ppp_status *state;
    PPPInit(&ref);

    PPPStatus(ref, 0, &state);

    if (state->status == PPP_RUNNING)
    {
        i_net->bytes += state->s.run.inBytes;
        o_net->bytes += state->s.run.outBytes;
    }

    PPPDispose(ref);
*/

    int sock;
    struct sockaddr_un sun;
    struct ppp_msg_hdr msg;
    struct ppp_status status;
    int link = 0; //Assume using ppp0
    size_t len;

    sock = socket(AF_LOCAL, SOCK_STREAM, 0);
    if (sock == -1)
    {
        perror("Could not create socket");
        return -1;
    }

    bzero(&sun, sizeof(sun));
    sun.sun_family = AF_LOCAL;
    strncpy(sun.sun_path, PPP_PATH, sizeof(sun.sun_path));

    if (connect(sock, (struct sockaddr *)&sun, sizeof(sun)) < 0)
    {
        perror("Could not connect to pppconfd");
        return -1;
    }

    bzero(&msg, sizeof(msg));
    msg.m_type = PPP_STATUS;
    msg.m_link = link;
    msg.m_len = 0;

    if (writen(sock, &msg, sizeof(msg)) < 0)
    {
        perror("Could not send query to pppdconf");
        return -1;
    }

    len = readn(sock, &msg, sizeof(msg));
    if (len == -1 || len != sizeof(msg))
    {
        perror("Could not get response from pppconfd");
        return -1;
    }

    if (msg.m_len != 0) /* if the ppp port is turned off, we don't get a message */
    {

        if (msg.m_len != sizeof(struct ppp_status))
        {
            fprintf(stderr, "Message length no good: %d.\n", msg.m_len);
            return -1;
        }

        len = readn(sock, &status, msg.m_len);
        if (len == -1 || len != msg.m_len)
        {
            perror("Could not receive message in response from pppconfd");
            return -1;
        }

        if (status.status == PPP_RUNNING)
        {
            i_net->bytes += status.s.run.inBytes;
            o_net->bytes += status.s.run.outBytes;
        }        
    }
    close(sock);

    return 0;
}
