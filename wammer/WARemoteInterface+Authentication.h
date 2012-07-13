//
//  WARemoteInterface+Authentication.h
//  wammer
//
//  Created by Evadne Wu on 11/8/11.
//  Copyright (c) 2011 Waveface. All rights reserved.
//

#import "WARemoteInterface.h"

@interface WARemoteInterface (Authentication)

- (IRWebAPIRequestContextTransformer) defaultV2AuthenticationSignatureBlock;
- (IRWebAPIResponseContextTransformer) defaultV2AuthenticationListeningBlock;

//	POST auth/login
- (void) retrieveTokenForUser:(NSString *)anIdentifier password:(NSString *)aPassword onSuccess:(void(^)(NSDictionary *userRep, NSString *token, NSArray *groupReps))successBlock onFailure:(void(^)(NSError *error))failureBlock;

//	POST auth/logout
- (void) discardToken:(NSString *)aToken onSuccess:(void(^)(void))successBlock onFailure:(void(^)(NSError *error))failureBlock;

@end
