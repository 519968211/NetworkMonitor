//
//  NetworkMonitor.h
//
//
//  Created by 5199 on 2022/2/24.
//

#import <Foundation/Foundation.h>


#define NetworkMonitorInternetAvailableNotification     @"networkMonitor-internet-connected"
#define NetworkMonitorInternetUnavailableNotification   @"networkMonitor-internet-disconnected"

NS_ASSUME_NONNULL_BEGIN

@interface NetworkMonitor : NSObject

@property (nonatomic) BOOL internetConnected;
@property (nonatomic, strong) void(^networkChangedBlock)(BOOL available);

+ (instancetype)sharedInstance;
- (void)startMonitorNetwork;
- (void)stopMonitorNetwork;

- (void)setInternetConnectedYES;

@end

NS_ASSUME_NONNULL_END
