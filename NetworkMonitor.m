//
//  NetworkMonitor.m
//
//
//  Created by 5199 on 2022/2/24.
//

#import "NetworkMonitor.h"
#import <RealReachability/RealReachability.h>


#define RealReachabilityPingHost @"time.apple.com"
#define RealReachabilityCheckHost @"www.google.com"

@interface NetworkMonitor ()

@property (nonatomic, strong) AFHTTPSessionManager *afnManager;//用于RealReachability检测到无网络时的验证
@property (nonatomic, strong) AFHTTPSessionManager *autoCheckManager;//用于自动循环检测

@end

@implementation NetworkMonitor

+ (instancetype)sharedInstance
{
    static NetworkMonitor *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init
{
    self = [super init];
    if(self)
    {
        _internetConnected = YES;
    }
    
    return self;
}

- (void)startMonitorNetwork
{
    GLobalRealReachability.hostForPing = RealReachabilityPingHost;
    GLobalRealReachability.hostForCheck = RealReachabilityCheckHost;
    GLobalRealReachability.autoCheckInterval = 0.3;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(networkChanged:) name:kRealReachabilityChangedNotification object:nil];
    [GLobalRealReachability startNotifier];
    
    if(!GLobalRealReachability.localObserver.isReachable)
    {
        [self checkHttpConnectionWhenRealStatusNotReachable];
    }
    
    _autoCheckManager = [AFHTTPSessionManager manager];
    [self autoCheckPhoneNetwork];
}

- (void)stopMonitorNetwork
{
    [GLobalRealReachability stopNotifier];
    
    [_autoCheckManager invalidateSessionCancelingTasks:YES resetSession:NO];
}

- (void)networkChanged:(NSNotification *)notification
{
    RealReachability *reachability = (RealReachability *)notification.object;
    if(reachability.currentReachabilityStatus == RealStatusViaWiFi ||
       reachability.currentReachabilityStatus == RealStatusViaWWAN)
    {
        [self internetAvailable];
    }
    else{
        [self checkHttpConnectionWhenRealStatusNotReachable];
    }
}

- (void)checkHttpConnectionWhenRealStatusNotReachable
{
    __weak typeof(self) weakSelf = self;
    [_afnManager invalidateSessionCancelingTasks:YES resetSession:NO];
    _afnManager = [AFHTTPSessionManager manager];
    
    _afnManager.requestSerializer = [AFHTTPRequestSerializer serializer];
    _afnManager.requestSerializer.cachePolicy = NSURLRequestReloadIgnoringLocalAndRemoteCacheData;
    _afnManager.requestSerializer.timeoutInterval = 5;
    _afnManager.responseSerializer = [AFHTTPResponseSerializer serializer];
    _afnManager.responseSerializer.acceptableContentTypes = [NSSet setWithObjects:@"text/html", nil];
    [_afnManager GET:"https://www.apple.com" parameters:nil headers:nil progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        [weakSelf.afnManager invalidateSessionCancelingTasks:YES resetSession:NO];
        weakSelf.internetConnected = YES;
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        [weakSelf.afnManager invalidateSessionCancelingTasks:YES resetSession:NO];
        [weakSelf internetUnavailable];
    }];
}

- (void)internetAvailable
{
    if(_internetConnected){return;}
    
    if(self.networkChangedBlock)
    {
        self.networkChangedBlock(YES);
    }
    _internetConnected = YES;
    
    NSNotificationQueue *queue = [NSNotificationQueue defaultQueue];
    NSNotification *notification = [NSNotification notificationWithName:NetworkMonitorInternetAvailableNotification object:nil];
    [queue enqueueNotification:notification postingStyle:NSPostASAP];
}

- (void)internetUnavailable
{
    if(!_internetConnected){return;}
    
    if(self.networkChangedBlock)
    {
        self.networkChangedBlock(NO);
    }
    self.internetConnected = NO;
    
    NSNotificationQueue *queue = [NSNotificationQueue defaultQueue];
    NSNotification *notification = [NSNotification notificationWithName:NetworkMonitorInternetUnavailableNotification object:nil];
    [queue enqueueNotification:notification postingStyle:NSPostASAP];
    
    [self autoCheckPhoneNetwork];
}

- (void)setInternetConnectedYES
{
    if(_internetConnected){return;}
    [self internetAvailable];
}

#pragma mark - 自动循环通过HTTP检查网络连接
- (void)autoCheckPhoneNetwork
{
    __weak typeof(self) weakSelf = self;
    
    _autoCheckManager.requestSerializer = [AFHTTPRequestSerializer serializer];
    _autoCheckManager.requestSerializer.cachePolicy = NSURLRequestReloadIgnoringLocalAndRemoteCacheData;
    _autoCheckManager.requestSerializer.timeoutInterval = 5;
    _autoCheckManager.responseSerializer = [AFHTTPResponseSerializer serializer];
    _autoCheckManager.responseSerializer.acceptableContentTypes = [NSSet setWithObjects:@"text/html", nil];
    [_autoCheckManager GET:"https://www.apple.com" parameters:nil headers:nil progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        if(!weakSelf.internetConnected)
        {
            [self internetAvailable];
        }
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        if(!GLobalRealReachability.localObserver.isReachable)
        {
            [weakSelf performSelector:@selector(autoCheckPhoneNetwork) withObject:nil afterDelay:5];
        }
        else{
            [weakSelf autoCheckPhoneNetwork];
        }
    }];
}

@end
