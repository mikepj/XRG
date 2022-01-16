/*
 * XRG (X Resource Graph):  A system resource grapher for Mac OS X.
 * Copyright (C) 2002-2022 Gaucho Software, LLC.
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
//  XRGNetMiner.m
//

#import "XRGNetMiner.h"
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

@interface XRGNetMiner ()
@property NSInteger numSamples;
@property NSDate *lastUpdate;
@end

@implementation XRGNetMiner

- (instancetype)init {
    if (self = [super init]) {
        self.totalBytesSinceBoot = 0;
        self.totalBytesSinceLoad = 0;
        networkInterfaces = [[NSMutableArray alloc] init];
        
        _numInterfaces = 0;
        
        // set mib variable for the BSD network stats routines
        mib[0] = CTL_NET;
        mib[1] = PF_ROUTE;
        mib[2] = 0;
        mib[3] = 0;
        mib[4] = NET_RT_IFLIST;
        mib[5] = 0;
        
        // add ppp0 to the interface list
        [self setInterfaceBandwidth:"ppp0" inBytes:0 outBytes:0];
        for (NSInteger i = 0; i < _numInterfaces; i++) {
            if (strcmp(_interfaceStats[i].if_name, "ppp0") == 0) {
                pppInterfaceNum = i;
                break;
            }
        }
        
        firstTimeStats = YES;
        
        self.monitorNetworkInterface = @"All";
        
        // flush out the first spike
        [self setCurrentBandwidth];
        [self.rxValues setAllValues:0];
        [self.txValues setAllValues:0];
        [self.totalValues setAllValues:0];
    }
    return self;
}

- (void)getLatestNetInfo {
    if (!self.lastUpdate) {
        self.lastUpdate = [NSDate dateWithTimeIntervalSinceNow:-1];
    }
    NSTimeInterval interval = -[self.lastUpdate timeIntervalSinceNow];
    self.lastUpdate = [NSDate date];
    
    if (!firstTimeStats) {
        self.totalBytesSinceLoad += i_net.bytes_delta + o_net.bytes_delta;
        
        if (self.totalBytesSinceBoot == 0) {
            self.totalBytesSinceBoot = i_net.bytes + o_net.bytes;
        }
        else {
            self.totalBytesSinceBoot += i_net.bytes_delta + o_net.bytes_delta;
        }
    }
    else {
        firstTimeStats = NO;
    }
    
    [self setCurrentBandwidth];
    
    sendBytes = o_net.bytes_delta / interval;
    recvBytes = i_net.bytes_delta / interval;
    
    NSInteger totalBandwidth = sendBytes + recvBytes;
    [self.rxValues setNextValue:recvBytes];
    [self.txValues setNextValue:sendBytes];
    [self.totalValues setNextValue:totalBandwidth];
}

- (void)setDataSize:(NSInteger)newNumSamples {
    if (newNumSamples < 0) return;
    
    if (!self.rxValues) {
        _rxValues = [[XRGDataSet alloc] init];
    }
    if (!self.txValues) {
        _txValues = [[XRGDataSet alloc] init];
    }
    if (!self.totalValues) {
        _totalValues = [[XRGDataSet alloc] init];
    }
    
    [self.rxValues resize:newNumSamples];
    [self.txValues resize:newNumSamples];
    [self.totalValues resize:newNumSamples];
    
    self.numSamples  = newNumSamples;
}

- (CGFloat)maxBandwidth {
    return [self.totalValues max];
}

- (CGFloat)currentTX {
    return [self.txValues currentValue];
}

- (CGFloat)currentRX {
    return [self.rxValues currentValue];
}

- (void)reset {
    [self.rxValues reset];
    [self.txValues reset];
    [self.totalValues reset];
}

- (void)setCurrentBandwidth {
    i_net.bytes = i_net.bytes_delta = 0;
    o_net.bytes = o_net.bytes_delta = 0;
    
    // First get the interface bandwidth for hardware interfaces.
    [self getInterfacesBandwidth];
    
    // Next get the interface bandwidth for ppp0
    read_ApplePPP_data(&(_interfaceStats[pppInterfaceNum]).if_in, &(_interfaceStats[pppInterfaceNum]).if_out);
    
    // Now find out which interface we want to monitor and set the stats.
    char *s = (char *)[self.monitorNetworkInterface cStringUsingEncoding:NSUTF8StringEncoding];
    for (NSInteger i = 0; i < _numInterfaces; i++) {
        if (strcmp("lo0", s) == 0) continue;
        
        if (strcmp("All", s) == 0 || strcmp(s, _interfaceStats[i].if_name) == 0) {
            i_net.bytes += _interfaceStats[i].if_in.bytes;
            i_net.bytes_delta += _interfaceStats[i].if_in.bytes_delta;
            
            o_net.bytes += _interfaceStats[i].if_out.bytes;
            o_net.bytes_delta += _interfaceStats[i].if_out.bytes_delta;
        }
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
    
    
    if (_numInterfaces == 0) {
        _interfaceStats = (network_interface_stats *)malloc(sizeof(network_interface_stats));
        
        strncpy(_interfaceStats[0].if_name, interface_name, 32);
        
        _interfaceStats[0].if_in.bytes           = in_bytes;
        _interfaceStats[0].if_in.bytes_prev      = 0;
        _interfaceStats[0].if_in.bytes_delta     = zeroDelta ? 0 : in_bytes;
        _interfaceStats[0].if_in.bsd_bytes       = in_bytes;
        _interfaceStats[0].if_in.bsd_bytes_prev  = 0;
        
        _interfaceStats[0].if_out.bytes          = out_bytes;
        _interfaceStats[0].if_out.bytes_prev     = 0;
        _interfaceStats[0].if_out.bytes_delta    = zeroDelta ? 0 : out_bytes;
        _interfaceStats[0].if_out.bsd_bytes      = out_bytes;
        _interfaceStats[0].if_out.bsd_bytes_prev = 0;
        
        if (strcmp(interface_name, "lo0") != 0)
            [networkInterfaces addObject:@(interface_name)];
        
        _numInterfaces++;
    }
    else {
        BOOL found = NO;
        NSInteger i;
        
        // Check through our interface array for the named interface
        for (i = 0; i < _numInterfaces; i++) {
            if (strcmp(interface_name, _interfaceStats[i].if_name) == 0) {
                found = YES;
                break;
            }
        }
        
        if (found) {
            // We found the interface, the index is i.
            // Update the in-bound stats
            _interfaceStats[i].if_in.bsd_bytes_prev = _interfaceStats[i].if_in.bsd_bytes;
            _interfaceStats[i].if_in.bsd_bytes      = in_bytes;
            
            if (zeroDelta) {
                _interfaceStats[i].if_in.bytes_delta = 0;
            }
            else if (_interfaceStats[i].if_in.bsd_bytes < _interfaceStats[i].if_in.bsd_bytes_prev) {
                _interfaceStats[i].if_in.bytes_delta = _interfaceStats[i].if_in.bsd_bytes +
                (((unsigned int)-1) - _interfaceStats[i].if_in.bsd_bytes_prev);
            }
            else {
                _interfaceStats[i].if_in.bytes_delta = _interfaceStats[i].if_in.bsd_bytes -
                _interfaceStats[i].if_in.bsd_bytes_prev;
            }
            
            _interfaceStats[i].if_in.bytes_prev     = _interfaceStats[i].if_in.bytes;
            _interfaceStats[i].if_in.bytes         += _interfaceStats[i].if_in.bytes_delta;
            
            // Update the out-bound stats
            _interfaceStats[i].if_out.bsd_bytes_prev = _interfaceStats[i].if_out.bsd_bytes;
            _interfaceStats[i].if_out.bsd_bytes      = out_bytes;
            
            if (zeroDelta) {
                _interfaceStats[i].if_out.bytes_delta = 0;
            }
            else if (_interfaceStats[i].if_out.bsd_bytes < _interfaceStats[i].if_out.bsd_bytes_prev) {
                _interfaceStats[i].if_out.bytes_delta = _interfaceStats[i].if_out.bsd_bytes +
                (((unsigned int)-1) - _interfaceStats[i].if_out.bsd_bytes_prev);
            }
            else {
                _interfaceStats[i].if_out.bytes_delta = _interfaceStats[i].if_out.bsd_bytes -
                _interfaceStats[i].if_out.bsd_bytes_prev;
            }
            
            _interfaceStats[i].if_out.bytes_prev     = _interfaceStats[i].if_out.bytes;
            _interfaceStats[i].if_out.bytes         += _interfaceStats[i].if_out.bytes_delta;
        }
        else {
            // need to add an interface.
            network_interface_stats *new_stats = malloc((_numInterfaces + 1) * sizeof(network_interface_stats));
            
            // move the data to the new array
            for (i = 0; i < _numInterfaces; i++) {
                strncpy(new_stats[i].if_name, _interfaceStats[i].if_name, 32);
                
                new_stats[i].if_in.bytes           = _interfaceStats[i].if_in.bytes;
                new_stats[i].if_in.bytes_prev      = _interfaceStats[i].if_in.bytes_prev;
                new_stats[i].if_in.bytes_delta     = _interfaceStats[i].if_in.bytes_delta;
                new_stats[i].if_in.bsd_bytes       = _interfaceStats[i].if_in.bsd_bytes;
                new_stats[i].if_in.bsd_bytes_prev  = _interfaceStats[i].if_in.bsd_bytes_prev;
                
                new_stats[i].if_out.bytes          = _interfaceStats[i].if_out.bytes;
                new_stats[i].if_out.bytes_prev     = _interfaceStats[i].if_out.bytes_prev;
                new_stats[i].if_out.bytes_delta    = _interfaceStats[i].if_out.bytes_delta;
                new_stats[i].if_out.bsd_bytes      = _interfaceStats[i].if_out.bsd_bytes;
                new_stats[i].if_out.bsd_bytes_prev = _interfaceStats[i].if_out.bsd_bytes_prev;
            }
            
            // free interfaceStats and set it equal to new_stats
            free(_interfaceStats);
            _interfaceStats = new_stats;
            
            strncpy(_interfaceStats[_numInterfaces].if_name, interface_name, 32);
            
            _interfaceStats[_numInterfaces].if_in.bytes           = in_bytes;
            _interfaceStats[_numInterfaces].if_in.bytes_prev      = 0;
            _interfaceStats[_numInterfaces].if_in.bytes_delta     = in_bytes;
            _interfaceStats[_numInterfaces].if_in.bsd_bytes       = in_bytes;
            _interfaceStats[_numInterfaces].if_in.bsd_bytes_prev  = 0;
            
            _interfaceStats[_numInterfaces].if_out.bytes          = out_bytes;
            _interfaceStats[_numInterfaces].if_out.bytes_prev     = 0;
            _interfaceStats[_numInterfaces].if_out.bytes_delta    = out_bytes;
            _interfaceStats[_numInterfaces].if_out.bsd_bytes      = out_bytes;
            _interfaceStats[_numInterfaces].if_out.bsd_bytes_prev = 0;
            
            if (strcmp(interface_name, "lo0") != 0)
                [networkInterfaces addObject:@(interface_name)];
            
            _numInterfaces++;
        }
    }
}

- (NSArray *)networkInterfaces {
    return [NSArray arrayWithArray:networkInterfaces];
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
