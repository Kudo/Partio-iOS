//
//  WAArticlesViewController.h
//  wammer-iOS
//
//  Created by Evadne Wu on 8/31/11.
//  Copyright 2011 Waveface Inc. All rights reserved.
//

//	The WAArticlesViewController is now refactored as a shared superclass used by both the root view controller for the iPhone and the iPad — it only works with Core Data, and provides persistence layer support for different view controllers to use.  It does not manage any view hierarchy on its own.

#import "WADefines.h"
#import "WAApplicationRootViewControllerDelegate.h"
#import "WASlidingMenuViewController.h"

@interface WAArticlesViewController : UIViewController <WAApplicationRootViewController, NSFetchedResultsControllerDelegate>

@property (nonatomic, readonly, retain) NSFetchedResultsController *fetchedResultsController;
@property (nonatomic, readonly, retain) NSManagedObjectContext *managedObjectContext;

- (void) refreshData;
- (void) reloadViewContents;

- (NSURL *) representedObjectURIForInterfaceItem:(UIView *)aView;
- (UIView *) interfaceItemForRepresentedObjectURI:(NSURL *)anURI createIfNecessary:(BOOL)createsOffsecreenItemIfNecessary;	//	 Might return nil if the item is not there


//	Overriding points for introducing additional user interface notifications

- (void) remoteDataLoadingWillBegin __deprecated;
- (void) remoteDataLoadingWillBeginForOperation:(NSString *)aMethodName;
- (void) remoteDataLoadingDidEnd;
- (void) remoteDataLoadingDidFailWithError:(NSError *)anError;

- (void) performInterfaceUpdate:(void(^)(void))aBlock;
- (void) beginDelayingInterfaceUpdates;
- (void) endDelayingInterfaceUpdates;
- (BOOL) isDelayingInterfaceUpdates;

- (NSArray *) debugActionSheetControllerActions;

@end
