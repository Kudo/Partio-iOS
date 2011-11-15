//
//  WARemoteInterface.m
//  wammer-iOS
//
//  Created by Evadne Wu on 7/21/11.
//  Copyright 2011 Waveface. All rights reserved.
//

#include <AvailabilityMacros.h>
#import "WADataStore.h"
#import "WADefines.h"

#import "IRWebAPIEngine.h"
#import "IRWebAPIEngine+FormMultipart.h"
#import "IRWebAPIEngine+LocalCaching.h"
#import "IRWebAPIEngine+FormURLEncoding.h"

#import "WAAppDelegate.h"

#import "WADataStore+WARemoteInterfaceAdditions.h"
#import "WARemoteInterfaceContext.h"
#import "WARemoteInterface.h"


@interface WARemoteInterface ()

+ (IRWebAPIResponseParser) defaultParser;

+ (IRWebAPIRequestContextTransformer) defaultBeginNetworkActivityTransformer;
+ (IRWebAPIResponseContextTransformer) defaultEndNetworkActivityTransformer;

@end


@implementation WARemoteInterface

@synthesize userIdentifier, userToken, primaryGroupIdentifier, defaultBatchSize;
@synthesize apiKey;

+ (WARemoteInterface *) sharedInterface {

	static WARemoteInterface *returnedInterface = nil;
	static dispatch_once_t onceToken = 0;
	dispatch_once(&onceToken, ^{
	
		returnedInterface = [[self alloc] init];
    
	});

	return returnedInterface;

}

+ (JSONDecoder *) sharedDecoder {

	static JSONDecoder *returnedDecoder = nil;
	static dispatch_once_t onceToken = 0;
	
	dispatch_once(&onceToken, ^{
		JKParseOptionFlags sloppy = JKParseOptionComments|JKParseOptionUnicodeNewlines|JKParseOptionLooseUnicode|JKParseOptionPermitTextAfterValidJSON;
		returnedDecoder = [JSONDecoder decoderWithParseOptions:sloppy];
		[returnedDecoder retain];
	});

	return returnedDecoder;

}

+ (id) decodedJSONObjectFromData:(NSData *)data {
	
	return [[self sharedDecoder] objectWithData:data];

}

+ (IRWebAPIResponseParser) defaultParser {

	__block __typeof__(self) nrSelf = self;

	return [[ ^ (NSData *incomingData) {
	
		NSError *parsingError = nil;
		id anObject = [[nrSelf sharedDecoder] objectWithData:incomingData error:&parsingError];
		
		if (!anObject) {
			NSLog(@"Error parsing: %@", parsingError);
			NSLog(@"Original content is %@", incomingData);
			return (NSDictionary *)nil;
		}
		
		return (NSDictionary *)([anObject isKindOfClass:[NSDictionary class]] ? anObject : [NSDictionary dictionaryWithObject:anObject forKey:@"response"]);
	
	} copy] autorelease];

}

+ (IRWebAPIRequestContextTransformer) defaultBeginNetworkActivityTransformer {

	return [[ ^ (NSDictionary *inOriginalContext) {
		dispatch_async(dispatch_get_main_queue(), ^ { [((WAAppDelegate *)[UIApplication sharedApplication].delegate) beginNetworkActivity]; });
		return inOriginalContext;
	} copy] autorelease];

}

+ (IRWebAPIResponseContextTransformer) defaultEndNetworkActivityTransformer {

	return [[ ^ (NSDictionary *inParsedResponse, NSDictionary *inResponseContext) {
		dispatch_async(dispatch_get_main_queue(), ^ { [((WAAppDelegate *)[UIApplication sharedApplication].delegate) endNetworkActivity]; });
		return inParsedResponse;
	} copy] autorelease];

}

- (void) dealloc {

	[apiKey release];
	
	[userIdentifier release];
	[userToken release];
	[primaryGroupIdentifier release];
		
	[super dealloc];

}

- (id) init {

	self = [self initWithEngine:[[[IRWebAPIEngine alloc] initWithContext:[WARemoteInterfaceContext context]] autorelease] authenticator:nil];
	if (!self)
		return nil;
	
	self.defaultBatchSize = 200;
	self.dataRetrievalInterval = 30;
	self.apiKey = kWARemoteEndpointApplicationKey;
	
	[self addRepeatingDataRetrievalBlocks:[self defaultDataRetrievalBlocks]];
	[self rescheduleAutomaticRemoteUpdates];
	
	return self;

}

- (id) initWithEngine:(IRWebAPIEngine *)engine authenticator:(IRWebAPIAuthenticator *)inAuthenticator {

	self = [super initWithEngine:engine authenticator:inAuthenticator];
	if (!self)
		return nil;

	[engine.globalRequestPreTransformers addObject:[[self class] defaultBeginNetworkActivityTransformer]];
	[engine.globalResponsePostTransformers addObject:[[self class] defaultEndNetworkActivityTransformer]];
		
	[engine.globalRequestPreTransformers addObject:[self defaultV2AuthenticationSignatureBlock]];
	//	[engine.globalRequestPreTransformers addObject:[self defaultV1AuthenticationSignatureBlock]];
	//	[engine.globalRequestPreTransformers addObject:[self defaultV1QueryHack]];

	[engine.globalRequestPreTransformers addObject:[[engine class] defaultFormMultipartTransformer]];
	[engine.globalRequestPreTransformers addObject:[[engine class] defaultFormURLEncodingTransformer]];
	[engine.globalResponsePostTransformers addObject:[[engine class] defaultCleanUpTemporaryFilesResponseTransformer]];
	
	engine.parser = [[self class] defaultParser];
	
	return self;

}

@end
