//
//  WARemoteInterfaceDefines.m
//  wammer
//
//  Created by Evadne Wu on 11/7/11.
//  Copyright (c) 2011 Waveface. All rights reserved.
//

#import "IRWebAPIKit.h"
#import "WARemoteInterfaceDefines.h"
#import "IRWebAPIEngine+FormURLEncoding.h"

NSString *kWARemoteInterfaceDomain = @"com.waveface.wammer.remoteInterface";
NSString *kWARemoteInterfaceUnderlyingContext = @"WARemoteInterfaceUnderlyingContext";
NSString *kWARemoteInterfaceRemoteErrorCode = @"WARemoteInterfaceRemoteErrorCode";

void WARemoteInterfaceNotPorted (void) {

	[NSException raise:NSObjectNotAvailableException format:@"%s has not been modified to use v.2 API methods.  Returning immediately.", __PRETTY_FUNCTION__];

}

NSUInteger WARemoteInterfaceEndpointReturnCode (NSDictionary *response) {

	return [[response valueForKeyPath:@"api_ret_code"] unsignedIntValue];

};

NSString * WARemoteInterfaceEndpointReturnMessage (NSDictionary *response) {

	return IRWebAPIKitStringValue([response valueForKeyPath:@"api_ret_message"]);

};

NSError * WARemoteInterfaceGenericError (NSDictionary *response, IRWebAPIRequestContext *context) {

	NSMutableDictionary *errorUserInfo = [NSMutableDictionary dictionary];
	NSUInteger errorCode = WARemoteInterfaceEndpointReturnCode(response);
	
	[errorUserInfo setObject:[NSNumber numberWithUnsignedInt:WARemoteInterfaceEndpointReturnCode(response)] forKey:kWARemoteInterfaceRemoteErrorCode];
	
	if (context.error)
		[errorUserInfo setObject:context.error forKey:NSUnderlyingErrorKey];
	
	if (context)
		[errorUserInfo setObject:context forKey:kWARemoteInterfaceUnderlyingContext];
		
	[errorUserInfo setObject:WARemoteInterfaceEndpointReturnMessage(response) forKey:NSLocalizedDescriptionKey];

	return [NSError errorWithDomain:kWARemoteInterfaceDomain code:errorCode userInfo:errorUserInfo];

}

IRWebAPICallback WARemoteInterfaceGenericFailureHandler (void(^aFailureBlock)(NSError *)) {

	if (!aFailureBlock)
		return (IRWebAPICallback)nil;
	
	return ^ (NSDictionary *inResponseOrNil, IRWebAPIRequestContext *inResponseContext) {
		
		NSError *error = WARemoteInterfaceGenericError(inResponseOrNil, inResponseContext);
		
		aFailureBlock(error);
		
	};

};

IRWebAPIResponseValidator WARemoteInterfaceGenericNoErrorValidator () {

	return ^ (NSDictionary *inResponseOrNil, IRWebAPIRequestContext *inResponseContext) {
	
		BOOL answer = [[inResponseOrNil valueForKey:@"api_ret_code"] isEqual:[NSNumber numberWithInt:WASuccess]];
		answer &= (inResponseContext.urlResponse.statusCode == 200);
		
		return answer;
	
	};

};

NSDictionary *WARemoteInterfaceRFC3986EncodedDictionary (NSDictionary *encodedDictionary) {

	NSMutableDictionary *returnedDictionary = [NSMutableDictionary dictionaryWithCapacity:[encodedDictionary count]];
	
	[encodedDictionary enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
		[returnedDictionary setObject:IRWebAPIKitRFC3986EncodedStringMake(obj) forKey:key];
	}];
	
	return returnedDictionary;

}

NSDictionary *WARemoteInterfaceEnginePostFormEncodedOptionsDictionary (NSDictionary *parameters, NSDictionary *mergedOtherOptionsOrNil) {

	NSMutableDictionary *returnedDictionary = [NSMutableDictionary dictionary];
	
	if (parameters)
		[returnedDictionary setObject:parameters forKey:kIRWebAPIEngineRequestContextFormURLEncodingFieldsKey];
	
	[returnedDictionary setObject:@"POST" forKey:kIRWebAPIEngineRequestHTTPMethod];
	
	if (mergedOtherOptionsOrNil)
		[returnedDictionary addEntriesFromDictionary:mergedOtherOptionsOrNil];
	
	return returnedDictionary;

}
