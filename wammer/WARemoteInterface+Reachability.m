//
//  WARemoteInterface+Reachability.m
//  wammer
//
//  Created by Evadne Wu on 11/25/11.
//  Copyright (c) 2011 Waveface. All rights reserved.
//

#import <objc/runtime.h>

#import "WARemoteInterface+Reachability.h"
#import "WAReachabilityDetector.h"

#import "Foundation+IRAdditions.h"

#import "WADefines.h"
#import "WAAppDelegate.h"

#import "WARemoteInterfaceContext.h"

#import "WARemoteInterface+WebSocket.h"
#import "WARemoteInterface+Notification.h"


@interface WARemoteInterface (Reachability_Private) <WAReachabilityDetectorDelegate>
NSURL *refiningStationLocation(NSString *stationUrlString, NSURL *baseUrl) ;
@property (nonatomic, readonly, retain) NSMutableDictionary *monitoredHostsToReachabilityDetectors;

@end


static NSString * const kAvailableHosts = @"-[WARemoteInterface(Reachability) availableHosts]";
static NSString * const kNetworkState = @"-[WARemoteInterface(Reachability) networkState]";
static NSString * const kMonitoredHostNames = @"-[WARemoteInterface(Reachability) monitoredHostNames]";


@implementation WARemoteInterface (Reachability)
@dynamic monitoredHostNames;

+ (void) load {
  
  __weak NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
  
  __block id appLoaded = [center addObserverForName:WAApplicationDidFinishLaunchingNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
    
    [center removeObserver:appLoaded];
    objc_setAssociatedObject([WARemoteInterface class], &WAApplicationDidFinishLaunchingNotification, nil, OBJC_ASSOCIATION_ASSIGN);
    
    __block id baseURLChanged = [center addObserverForName:kWARemoteInterfaceContextDidChangeBaseURLNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
      
      NSURL *oldURL = [[note userInfo] objectForKey:kWARemoteInterfaceContextOldBaseURL];
      NSURL *newURL = [[note userInfo] objectForKey:kWARemoteInterfaceContextNewBaseURL];
      
      WARemoteInterface *ri = [WARemoteInterface sharedInterface];
      
      NSArray *monitoredHosts = ri.monitoredHosts;
      NSMutableArray *updatedHosts = [monitoredHosts mutableCopy];
      
      for (NSURL *anURL in ri.monitoredHosts)
        if ([anURL isEqual:oldURL] || [anURL isEqual:newURL])
	[updatedHosts removeObject:anURL];
      
      [updatedHosts insertObject:newURL atIndex:0];
      
      ri.monitoredHosts = updatedHosts;
      
    }];
    
    objc_setAssociatedObject([WARemoteInterface class], &kWARemoteInterfaceContextDidChangeBaseURLNotification, baseURLChanged, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
  }];
  
  objc_setAssociatedObject([WARemoteInterface class], &WAApplicationDidFinishLaunchingNotification, appLoaded, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  
}

- (NSArray *)monitoredHostNames {
  
  return objc_getAssociatedObject(self, &kMonitoredHostNames);
  
}

- (void)setMonitoredHostNames:(NSArray *)monitoredHostNames {
  
  objc_setAssociatedObject(self, &kMonitoredHostNames, monitoredHostNames, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  
}

- (NSArray *) monitoredHosts {
  
  return objc_getAssociatedObject(self, &kAvailableHosts);
  
}

- (void) setMonitoredHosts:(NSArray *)newAvailableHosts {
  
  NSURL *cloudURL = self.engine.context.baseURL;
  
  objc_setAssociatedObject(self, &kAvailableHosts, newAvailableHosts, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  
  if (!newAvailableHosts) {
    
    [self.monitoredHostsToReachabilityDetectors removeObjectForKey:cloudURL];
    
  } else {
    
    NSParameterAssert([newAvailableHosts[0] isEqual:cloudURL]);
    
    if (!self.monitoredHostsToReachabilityDetectors[cloudURL]) {
      WAReachabilityDetector *detector = [WAReachabilityDetector detectorForURL:cloudURL];
      detector.delegate = self;
      self.monitoredHostsToReachabilityDetectors[cloudURL] = detector;
    }
    
  }
  
}

- (BOOL) canHost:(NSURL *)aHost handleRequestNamed:(NSString *)aRequestName {
  
  NSString *cloudHost = [self.engine.context.baseURL host];
  BOOL incomingURLIsCloud = [[aHost host] isEqualToString:cloudHost];
  
  if ([aRequestName hasPrefix:@"reachability"])
    return incomingURLIsCloud;
  
  if ([aRequestName hasPrefix:@"auth/"])
    return incomingURLIsCloud;
  
  if ([aRequestName hasPrefix:@"stations/"])
    return incomingURLIsCloud;
  
  if ([aRequestName hasPrefix:@"users/"])
    return incomingURLIsCloud;
  
  if ([aRequestName hasPrefix:@"groups/"])
    return incomingURLIsCloud;
  
  return YES;
  
}

- (NSURL *) bestHostForRequestNamed:(NSString *)aRequestName {
  
  for (int i = [self.monitoredHosts count]-1; i >= 0; i--) {
    if ([self canHost:self.monitoredHosts[i] handleRequestNamed:aRequestName]) {
      return self.monitoredHosts[i];
    }
  }
  
  return self.engine.context.baseURL;
  
}

NSURL *refiningStationLocation(NSString *stationUrlString, NSURL *baseUrl) {
  NSURL *givenURL = [NSURL URLWithString:stationUrlString];
  if (!givenURL)
    return (id)nil;
  
  if (![givenURL host])
    return (id)nil;
  
  NSString *baseURLString = [[NSArray arrayWithObjects:
			
			[givenURL scheme] ? [[givenURL scheme] stringByAppendingString:@"://"] :
			[baseUrl scheme] ? [[baseUrl scheme] stringByAppendingString:@"://"] : @"",
			[baseUrl host] ? [givenURL host] : @"",
			[givenURL port] ? [@":" stringByAppendingString:[[givenURL port] stringValue]] :
			[baseUrl port] ? [@":" stringByAppendingString:[[baseUrl port] stringValue]] : @"",
			[baseUrl path] ? [baseUrl path] : @"",
			@"/", //  path needs trailing slash
			
			//	[givenURL query] ? [@"?" stringByAppendingString:[givenURL query]] : @"",
			//	[givenURL fragment] ? [@"#" stringByAppendingString:[givenURL fragment]] : @"",
			
			nil] componentsJoinedByString:@""];
  
  //  only take the location (host) + port, nothing else
  
  return (id)[NSURL URLWithString:baseURLString];
  
  
}

- (void(^)(void)) defaultScheduledMonitoredHostsUpdatingBlock {
  
  __weak WARemoteInterface *wSelf = self;
  
  return [^ {
    
    if (!wSelf.userToken)
      return;
    
    [wSelf beginPostponingDataRetrievalTimerFiring];
    //[((WAAppDelegate *)[UIApplication sharedApplication].delegate) beginNetworkActivity];
    
    [wSelf retrieveAssociatedStationsOfCurrentUserOnSuccess:^(NSArray *stationReps) {
      
      dispatch_async(dispatch_get_main_queue(), ^ {
        
        NSArray *wsStations = [NSArray arrayWithArray:[stationReps irMap: ^(NSDictionary *aStationRep, NSUInteger index, BOOL *stop) {
	NSString *wsStationURLString = aStationRep[@"ws_location"];
	
	if (!wsStationURLString)
	  return (id)nil;
	if ([wsStationURLString isEqualToString:@""])
	  return (id)nil;
	
	NSURL *wsURL = [NSURL URLWithString:wsStationURLString];
	
	NSURL *stationURL = refiningStationLocation(aStationRep[@"location"], wSelf.engine.context.baseURL);
	
	NSString *computerName = aStationRep[@"computer_name"];
	
	return (id)@{@"location":stationURL, @"ws_location":wsURL, @"computer_name":computerName};
	
        }]];
        
        if ([wsStations count] > 0) {
	// cloud says we have at least one station supports websocket
	
	// then we try to connect to one of available
	[[WARemoteInterface sharedInterface] connectAvaliableWSStation:wsStations onSucces:^(NSURL *wsURL, NSURL *stURL, NSString *computerName){
	  
	  // any success connect to websocket goes to this block
	  
	  [[WARemoteInterface sharedInterface] stopAutomaticRemoteUpdates];
	  
	  [[WARemoteInterface sharedInterface] subscribeNotification];
	  
	  // We only scan the reachability detector for cloud and the first available station that supports websocket
	  wSelf.monitoredHostNames = @[NSLocalizedString(@"Stream Cloud", @"Cloud Name"), computerName];
	  wSelf.monitoredHosts = @[wSelf.engine.context.baseURL, stURL];
	  
	} onFailure:^(NSError *error) {
	  
	  // no websocket station available or any failure during connection goes to this block
	  
	  //							wSelf.monitoredHosts = [[NSArray arrayWithObject:wSelf.engine.context.baseURL] arrayByAddingObjectsFromArray:[stationReps irMap: ^ (NSDictionary *aStationRep, NSUInteger index, BOOL *stop) {
	  //
	  //								NSString *stationURLString = [aStationRep valueForKeyPath:@"location"];
	  //								if (!stationURLString)
	  //									return (id)nil;
	  //
	  //								return (id)refiningStationLocation(stationURLString, wSelf.engine.context.baseURL);
	  //							}]];
	  
	  wSelf.monitoredHostNames = @[NSLocalizedString(@"Stream Cloud", @"Cloud Name")];
	  wSelf.monitoredHosts = @[wSelf.engine.context.baseURL];
	  
	  [[WARemoteInterface sharedInterface] enableAutomaticRemoteUpdatesTimer];
	  
	}];
	
        } else {
	
	//					wSelf.monitoredHosts = [[NSArray arrayWithObject:wSelf.engine.context.baseURL] arrayByAddingObjectsFromArray:[stationReps irMap: ^ (NSDictionary *aStationRep, NSUInteger index, BOOL *stop) {
	//
	//						NSString *stationURLString = [aStationRep valueForKeyPath:@"location"];
	//						if (!stationURLString)
	//							return (id)nil;
	//
	//						return (id)refiningStationLocation(stationURLString, wSelf.engine.context.baseURL);
	//					}]];
	wSelf.monitoredHostNames = @[NSLocalizedString(@"Stream Cloud", @"Cloud Name")];
	wSelf.monitoredHosts = @[wSelf.engine.context.baseURL];
	
        }
        
        [wSelf endPostponingDataRetrievalTimerFiring];
        
        //[AppDelegate() endNetworkActivity];
        
      });
      
    } onFailure:^(NSError *error) {
      
      dispatch_async(dispatch_get_main_queue(), ^ {
        
        // for network unavailable case while entering app
        if (!wSelf.monitoredHosts) {
	wSelf.monitoredHostNames = @[NSLocalizedString(@"Stream Cloud", @"Cloud Name")];
	wSelf.monitoredHosts = @[wSelf.engine.context.baseURL];
        }
        
        [wSelf endPostponingDataRetrievalTimerFiring];
        
        //[AppDelegate() endNetworkActivity];
        
      });
      
    }];
    
  } copy];
  
}

- (IRWebAPIRequestContextTransformer) defaultHostSwizzlingTransformer {
  
  __weak WARemoteInterface *wSelf = self;
  
  return [^ (IRWebAPIRequestContext *context) {
    
    NSString *originalMethodName = context.engineMethod;
    NSURL *originalURL = context.baseURL;
    
    if ([originalMethodName hasPrefix:@"reachability"])
      return context;
    
    if ([originalMethodName hasPrefix:@"loadedResource"]) {
      
      if (![[originalURL host] isEqualToString:[[WARemoteInterface sharedInterface].engine.context.baseURL host]])
        return context;
      
      //	if ([[inOriginalContext objectForKey:@"target"] isEqual:@"image"])
      //		return inOriginalContext;
      
    }
    
    NSURL *bestHostURL = [wSelf bestHostForRequestNamed:originalMethodName];
    
    NSURL *swizzledURL = [NSURL URLWithString:[[NSArray arrayWithObjects:
				        
				        [bestHostURL scheme] ? [[bestHostURL scheme] stringByAppendingString:@"://"] :
				        [originalURL scheme] ? [[originalURL scheme] stringByAppendingString:@"://"] : @"",
				        
				        [originalURL host] ? [bestHostURL host] : @"",
				        
				        [bestHostURL port] ? [@":" stringByAppendingString:[[bestHostURL port] stringValue]] :
				        [originalURL port] ? [@":" stringByAppendingString:[[originalURL port] stringValue]] : @"",
				        
				        [originalURL path] ? [originalURL path] : @"/",
				        [originalURL query] ? [@"?" stringByAppendingString:[originalURL query]] : @"",
				        [originalURL fragment] ? [@"#" stringByAppendingString:[originalURL fragment]] : @"",
				        
				        nil] componentsJoinedByString:@""]];
    
    context.baseURL = swizzledURL;
    
    return context;
    
  } copy];
  
}

- (WAReachabilityState) reachabilityStateForHost:(NSURL *)aBaseURL {
  
  WAReachabilityDetector *detector = [self reachabilityDetectorForHost:aBaseURL];
  return detector ? detector.state : WAReachabilityStateUnknown;
  
}

- (WAReachabilityDetector *) reachabilityDetectorForHost:(NSURL *)aBaseURL {
  
  WAReachabilityDetector *detector = self.monitoredHostsToReachabilityDetectors[aBaseURL];
  return detector;
  
}

+ (NSSet *)keyPathsForValuesAffectingNetworkState {
  
  return [NSSet setWithObject:@"monitoredHosts"];
  
}

- (WANetworkState) networkState {
  
  NSURL *cloudHost = self.engine.context.baseURL;
  BOOL hasStationAvailable = self.webSocketConnected, hasCloudAvailable = NO;
  
  WAReachabilityState state = [self reachabilityStateForHost:cloudHost];
  if (state == WAReachabilityStateAvailable || state == WAReachabilityStateUnknown) {
    hasCloudAvailable = YES;
  }
  
  WANetworkState answer = (hasCloudAvailable ? WACloudReachable : 0) | (hasStationAvailable ? WAStationReachable : 0);
  
  return answer;
  
}

@end





@implementation WARemoteInterface (Reachability_Private)

- (NSMutableDictionary *) monitoredHostsToReachabilityDetectors {
  
  NSMutableDictionary *returnedDictionary = objc_getAssociatedObject(self, _cmd);
  if (!returnedDictionary) {
    returnedDictionary = [NSMutableDictionary dictionary];
    objc_setAssociatedObject(self, _cmd, returnedDictionary, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  }
  
  return returnedDictionary;
  
}

- (void) reachabilityDetectorDidUpdate:(WAReachabilityDetector *)aDetector {
  
  [self willChangeValueForKey:@"networkState"];
  
  [self didChangeValueForKey:@"networkState"];
  
  
}

@end