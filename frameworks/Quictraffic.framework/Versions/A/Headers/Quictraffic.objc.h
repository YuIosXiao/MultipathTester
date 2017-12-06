// Objective-C API for talking to bitbucket.org/qdeconinck/quic-traffic Go package.
//   gobind -lang=objc bitbucket.org/qdeconinck/quic-traffic
//
// File is generated by gobind. Do not edit.

#ifndef __Quictraffic_H__
#define __Quictraffic_H__

@import Foundation;
#include "Universe.objc.h"


@protocol QuictrafficRunConfig;
@class QuictrafficRunConfig;

@protocol QuictrafficRunConfig <NSObject>
- (BOOL)cache;
- (NSString*)logFile;
- (long)logPeriodMs;
- (long)maxPathID;
- (NSString*)notifyID;
- (NSString*)output;
- (BOOL)printBody;
- (NSString*)traffic;
- (NSString*)url;
@end

/**
 * NotifyReachability change for the notifyID
 */
FOUNDATION_EXPORT void QuictrafficNotifyReachability(NSString* notifyID);

/**
 * Run the QUIC traffic experiment
 */
FOUNDATION_EXPORT NSString* QuictrafficRun(id<QuictrafficRunConfig> runcfg);

@class QuictrafficRunConfig;

/**
 * RunConfig provides needed configuration
 */
@interface QuictrafficRunConfig : NSObject <goSeqRefInterface, QuictrafficRunConfig> {
}
@property(strong, readonly) id _ref;

- (instancetype)initWithRef:(id)ref;
- (BOOL)cache;
- (NSString*)logFile;
- (long)logPeriodMs;
- (long)maxPathID;
- (NSString*)notifyID;
- (NSString*)output;
- (BOOL)printBody;
- (NSString*)traffic;
- (NSString*)url;
@end

#endif
