//
//  WAGalleryViewController.h
//  wammer-iOS
//
//  Created by Evadne Wu on 8/3/11.
//  Copyright 2011 Waveface. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>
#import "UIKit+IRAdditions.h"

extern NSString * const kWAGalleryViewControllerContextPreferredFileObjectURI;

@interface WAGalleryViewController : UIViewController

+ (WAGalleryViewController *) controllerRepresentingArticleAtURI:(NSURL *)anArticleURI;
+ (WAGalleryViewController *) controllerRepresentingArticleAtURI:(NSURL *)anArticleURI context:(NSDictionary *)context;

@property (nonatomic, readwrite, retain) IRView *view;
@property (nonatomic, readonly, assign) BOOL contextControlsShown;
@property (nonatomic, readwrite, copy) void (^onDismiss)();
@property (nonatomic, readwrite, copy) void (^onComplete)();

- (id) initWithImageFiles:(NSArray *)files atIndex:(NSUInteger)index;
- (void) setContextControlsHidden:(BOOL)willHide animated:(BOOL)animate completion:(void(^)(void))callback;
- (void) setContextControlsHidden:(BOOL)willHide animated:(BOOL)animate barringInteraction:(BOOL)barringInteraction completion:(void(^)(void))callback;

- (UIImage *) currentImage;

@end
                                                                                                                                                                                                                                                                                     