//
//  WAReachabilityDetector.m
//  wammer
//
//  Created by Evadne Wu on 11/25/11.
//  Copyright (c) 2011 Waveface. All rights reserved.
//

#import "WAReachabilityDetector.h"
#import "IRRecurrenceMachine.h"
#import "WARemoteInterface.h"
#import "NSBlockOperation+NSCopying.h"
#import "IRAsyncOperation.h"
#import "WABackoffHandler.h"


NSString * const kWAReachabilityDetectorDidUpdateStatusNotification = @"WAReachabilityDetectorDidUpdateStatusNotification";
NSUInteger const kWAReachabliityDetectorDefaultLiveness = 3;


@interface WAReachabilityDetector ()

@property (nonatomic, readwrite, retain) NSURL *hostURL;
@property (nonatomic, readwrite, assign) WASocketAddress hostAddress;

@property (nonatomic, readwrite, retain) IRRecurrenceMachine *recurrenceMachine;
@property (nonatomic, readwrite, assign) SCNetworkReachabilityRef reachability;
@property (nonatomic, readwrite, assign) WAReachabilityState state;
@property (nonatomic, readwrite, strong) WABackoffHandler *backOffHandler;
@property (nonatomic, readwrite, assign) NSUInteger liveness;

- (void) handleApplicationDidEnterBackground:(NSNotification *)note;
- (void) noteReachabilityFlagsChanged:(SCNetworkReachabilityFlags)flags;

- (void) sendUpdateNotification;
- (void) recreateReachabilityRef;

- (IRAsyncOperation *) newPulseCheckerPrototype NS_RETURNS_RETAINED;

@end


static void WASCReachabilityCallback (SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void* info) {

  NSCAssert(info != NULL, @"info was NULL.");
  NSCAssert([(__bridge WAReachabilityDetector *)info isKindOfClass:[WAReachabilityDetector class]], @"info was wrong class.");
  
  @autoreleasepool {
    
    WAReachabilityDetector *self = (__bridge WAReachabilityDetector *)info;
		[self noteReachabilityFlagsChanged:flags];

  };

}


@implementation WAReachabilityDetector

@synthesize hostURL, hostAddress, delegate;
@synthesize recurrenceMachine;
@synthesize reachability;
@synthesize state;
@synthesize backOffHandler;
@synthesize liveness;

+ (void) load {

	__block id applicationDidFinishLaunchingListener = [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
	
		[WAReachabilityDetector sharedDetectorForInternet];
		[WAReachabilityDetector sharedDetectorForLocalWiFi];
		
		[[NSNotificationCenter defaultCenter] removeObserver:applicationDidFinishLaunchingListener];
		applicationDidFinishLaunchingListener = nil;
		
	}];

}

+ (id) sharedDetectorForInternet {

	static dispatch_once_t token = 0;
	static id instance = nil;
	dispatch_once(&token, ^{
		instance = [[self alloc] initWithAddress:WASocketAddressCreateZero()];
	});
	
	return instance;

}
 
+ (id) sharedDetectorForLocalWiFi {

	static dispatch_once_t token = 0;
	static id instance = nil;
	dispatch_once(&token, ^{
		instance = [[self alloc] initWithAddress:WASocketAddressCreateLinkLocal()];
	});
	
	return instance;

}

+ (id) detectorForURL:(NSURL *)aHostURL {

	if ([aHostURL isEqual:[WARemoteInterface sharedInterface].engine.context.baseURL]) {

		// ping cloud every 30 seconds

		return [[self alloc] initWithURL:aHostURL backOffHandler:[[WABackoffHandler alloc] initWithInitialBackoffInterval:30.0f valueFixed:YES]];

	} else {

		// use exponential back off to reduce unnecessary pings to unavailable stations
		
		WABackoffHandler *backoff = [[WABackoffHandler alloc] initWithInitialBackoffInterval:4.0f valueFixed:NO];
		
		WAReachabilityDetector *returnedObject = [[self alloc] initWithURL:aHostURL backOffHandler:backoff];
		
		return returnedObject;

	}

}

- (id) init {

	self = [super init];
	if (!self)
		return nil;
	
	state = WAReachabilityStateUnknown;
	liveness = kWAReachabliityDetectorDefaultLiveness;
	return self;

}

- (id) initWithAddress:(struct sockaddr_in)hostAddressRef {

	self = [self init];
	if (!self)
		return nil;
	
	self.hostAddress = hostAddressRef;
	[self recreateReachabilityRef];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleApplicationDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
	
	return self;

}

- (id) initWithURL:(NSURL *)aHostURL backOffHandler:(WABackoffHandler *)aBackOffHandler
{

  NSParameterAssert(aHostURL);
  
  self = [self init];
  if (!self)
    return nil;
      
	self.hostURL = aHostURL;
	self.backOffHandler = aBackOffHandler;
	[self.recurrenceMachine setRecurrenceInterval:[self.backOffHandler firstInterval]];
	[self.recurrenceMachine addRecurringOperation:[self newPulseCheckerPrototype]];
	[self.recurrenceMachine scheduleOperationsNow];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleApplicationDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
	
	return self;
	
}

- (void) handleApplicationDidEnterBackground:(NSNotification *)note {

	if (self.backOffHandler) {
		
		[self.recurrenceMachine setRecurrenceInterval:[self.backOffHandler firstInterval]];
		
	}

}

- (IRRecurrenceMachine *) recurrenceMachine {

	if (recurrenceMachine)
		return recurrenceMachine;
	
	recurrenceMachine = [[IRRecurrenceMachine alloc] init];
	
	return recurrenceMachine;

}

- (IRAsyncOperation *) newPulseCheckerPrototype {

	NSAssert1(self.hostURL, @"%s should only be invoked for detectors with an URL and no Internet address", __PRETTY_FUNCTION__);
	
	__weak WAReachabilityDetector *wSelf = self;
	
	return [IRAsyncOperation operationWithWorkerBlock:^(void(^aCallback)(id)) {
	
		WARemoteInterface * const ri = [WARemoteInterface sharedInterface];
		if (!ri.userToken)
			return;
    
		[wSelf.recurrenceMachine beginPostponingOperations];

//		if (![ri hasWiFiConnection] && ![self.hostURL isEqual:ri.engine.context.baseURL]) {
//			[wSelf.recurrenceMachine endPostponingOperations];
//			return;
//		}

    [ri.engine fireAPIRequestNamed:@"reachability" withArguments:[NSDictionary dictionaryWithObjectsAndKeys:
    
      ri.userIdentifier, @"user_id",
      [hostURL absoluteString], @"for_host",
    
    nil] options:[NSDictionary dictionaryWithObjectsAndKeys:
    
      [NSURL URLWithString:@"reachability/ping" relativeToURL:hostURL], kIRWebAPIEngineRequestHTTPBaseURL,
				  [NSNumber numberWithDouble:([self.hostURL isEqual:ri.engine.context.baseURL] ? 10.0f : 3.0f)], kIRWebAPIRequestTimeout,
    
    nil] validator:^(NSDictionary *inResponseOrNil, IRWebAPIRequestContext *inResponseContext) {
    
      //  Must have returned status value 200
      NSNumber *httpStatusCode = [inResponseOrNil objectForKey:@"status"];
      if (httpStatusCode) {
          if ([httpStatusCode integerValue] == 200) {
							[self.recurrenceMachine setRecurrenceInterval:[self.backOffHandler firstInterval]];
              return YES;
          }
      }
      return NO;
      
    } successHandler:^(NSDictionary *inResponseOrNil, IRWebAPIRequestContext *inResponseContext) {

      aCallback((id)kCFBooleanTrue);
			
    } failureHandler:^(NSDictionary *inResponseOrNil, IRWebAPIRequestContext *inResponseContext) {
    
	  [self.recurrenceMachine setRecurrenceInterval:[self.backOffHandler nextInterval]];
      aCallback((id)kCFBooleanFalse);
      
    }];
		
	} completionBlock: ^ (id results) {
	
		dispatch_async(dispatch_get_main_queue(), ^ {

			[wSelf.recurrenceMachine endPostponingOperations];
			
			if ([results isEqual:(id)kCFBooleanTrue]) {
			
				wSelf.liveness = kWAReachabliityDetectorDefaultLiveness;
				wSelf.state = WAReachabilityStateAvailable;
			
			} else {
			
				if (wSelf.liveness > 0) {
					wSelf.liveness -= 1;
				}

				if (wSelf.liveness == 0) {
					wSelf.state = WAReachabilityStateNotAvailable;
				}
			
			}
		
		});
		
	}];

}

- (void) setState:(WAReachabilityState)newState {

  if (state == newState)
    return;
  
  [self willChangeValueForKey:@"state"];
  state = newState;
  [self didChangeValueForKey:@"state"];
	
	[self sendUpdateNotification];
 
}

- (void) noteReachabilityFlagsChanged:(SCNetworkReachabilityFlags)flags {

	[self sendUpdateNotification];

}

- (void) sendUpdateNotification {

	[self.delegate reachabilityDetectorDidUpdate:self];
	[[NSNotificationCenter defaultCenter] postNotificationName:kWAReachabilityDetectorDidUpdateStatusNotification object:self];

}

- (void) setHostURL:(NSURL *)newHostURL {

  if (newHostURL == hostURL)
    return;
  
  [self willChangeValueForKey:@"hostURL"];
  
  hostURL = newHostURL;
	
	[self recreateReachabilityRef];
  
  [self didChangeValueForKey:@"hostURL"];
  
}

- (void) recreateReachabilityRef {

  if (reachability) {
    SCNetworkReachabilitySetDispatchQueue(reachability, NULL);
    CFRelease(reachability);
    reachability = NULL;
  }
	
	if (hostURL) {
		const char *hostName = [[hostURL host] UTF8String];
		reachability = SCNetworkReachabilityCreateWithName(NULL, hostName);
	} else {
		reachability = SCNetworkReachabilityCreateWithAddress(NULL, (const struct sockaddr *)&hostAddress);
	}
	
	NSAssert1(reachability, @"Must have created a SCNetworkReachabilityRef with URL %@", hostURL);

  SCNetworkReachabilityContext context = { 0, (__bridge void *)(self), NULL, NULL, NULL };
  SCNetworkReachabilitySetCallback(reachability, WASCReachabilityCallback, &context);
  SCNetworkReachabilitySetDispatchQueue(reachability, dispatch_get_main_queue());

}

- (SCNetworkReachabilityFlags) networkStateFlags {
  
  SCNetworkReachabilityFlags foundFlags = 0;
  if (!SCNetworkReachabilityGetFlags(self.reachability, &foundFlags))
    NSLog(@"Found flags are bad!");
  
  return foundFlags;

}

- (void) dealloc {

  if (reachability) {
    SCNetworkReachabilitySetDispatchQueue(reachability, NULL);
    CFRelease(reachability);
  }
  
	[[NSNotificationCenter defaultCenter] removeObserver:self];

}

- (NSString *) description {

  return [NSString stringWithFormat:@"<%@: 0x%x { Host: %@; App Layer Alive: %x; Network Reachability Flags: %x; Requires Connection: %x; Reachable: %x; Is Directly Reachable: %x; Reachable Thru WiFi: %x; Reachable Thru WWAN: %x }>",
  
    NSStringFromClass([self class]),
    (unsigned int)self,
    self.hostURL,
    (self.state == WAReachabilityStateAvailable),
    self.networkStateFlags,
    WASCNetworkRequiresConnection(self.networkStateFlags),
    WASCNetworkReachable(self.networkStateFlags),
    WASCNetworkReachableDirectly(self.networkStateFlags),
    WASCNetworkReachableViaWifi(self.networkStateFlags),
    WASCNetworkReachableViaWWAN(self.networkStateFlags)
  
  ];

}

- (BOOL) networkRequiresConnection {

	return WASCNetworkRequiresConnection(self.networkStateFlags);

}

- (BOOL) networkReachable {

	return WASCNetworkReachable(self.networkStateFlags);

}
- (BOOL) networkReachableDirectly {

	return WASCNetworkReachableDirectly(self.networkStateFlags);

}
- (BOOL) networkReachableViaWiFi {

	return WASCNetworkReachableViaWifi(self.networkStateFlags);

}
- (BOOL) networkReachableViaWWAN {

	return WASCNetworkReachableViaWWAN(self.networkStateFlags);

}

@end





WASocketAddress WASocketAddressCreateLinkLocal (void) {

	struct sockaddr_in linkLocalAddress;
	bzero(&linkLocalAddress, sizeof(linkLocalAddress));
	linkLocalAddress.sin_len = sizeof(linkLocalAddress);
	linkLocalAddress.sin_family = AF_INET;
	linkLocalAddress.sin_addr.s_addr = htonl(IN_LINKLOCALNETNUM);
	
	return linkLocalAddress;

}

WASocketAddress WASocketAddressCreateZero (void) { 

	struct sockaddr_in zeroAddress;
	bzero(&zeroAddress, sizeof(zeroAddress));
	zeroAddress.sin_len = sizeof(zeroAddress);
	zeroAddress.sin_family = AF_INET;

	return zeroAddress;

}

NSString * NSLocalizedStringFromWAReachabilityState (WAReachabilityState aState) {

  switch (aState) {
    case WAReachabilityStateUnknown:
      return NSLocalizedString(@"REACHABILITY_STATE_UNKNOWN", @"REACHABILITY_STATE_UNKNOWN");
    case WAReachabilityStateAvailable:
      return NSLocalizedString(@"REACHABILITY_STATE_AVAILABLE", @"REACHABILITY_STATE_AVAILABLE");
    case WAReachabilityStateNotAvailable:
      return NSLocalizedString(@"REACHABILITY_STATE_NOT_AVAILABLE", @"REACHABILITY_STATE_NOT_AVAILABLE");
    default:
      return [NSString stringWithFormat:@"%ld", (long)aState];
  };

}

BOOL WASCNetworkRequiresConnection (SCNetworkReachabilityFlags flags) {

  return (BOOL)!!(flags & kSCNetworkReachabilityFlagsConnectionRequired);

}

BOOL WASCNetworkReachable (SCNetworkReachabilityFlags flags) {

  return (BOOL)!!(flags & kSCNetworkReachabilityFlagsReachable);

}

BOOL WASCNetworkReachableDirectly (SCNetworkReachabilityFlags flags) {

  if (flags & kSCNetworkReachabilityFlagsReachable)
  if (flags & kSCNetworkReachabilityFlagsIsDirect)
    return YES;
  
  return NO;

}

BOOL WASCNetworkReachableViaWifi (SCNetworkReachabilityFlags flags) {

  if (!WASCNetworkReachable(flags))
    return NO;
  
  if (!(flags & kSCNetworkReachabilityFlagsConnectionOnDemand))
  if (!(flags & kSCNetworkReachabilityFlagsConnectionOnTraffic))
    return NO;
  
  //  At this point, if no user intervention comes it will go through
  //  If the calling site is from CFSocket +
  
  return (BOOL)!(flags & kSCNetworkReachabilityFlagsInterventionRequired);

}

BOOL WASCNetworkReachableViaWWAN (SCNetworkReachabilityFlags flags) {

#if (TARGET_OS_IPHONE || TARGET_IPHONE_SIMULATOR)

  if (!WASCNetworkReachable(flags))
    return NO;
  
  return (BOOL)!!(flags & kSCNetworkReachabilityFlagsIsWWAN);

#else

	//	We don’t really need to handle this on a Mac
	
	return NO;

#endif

}