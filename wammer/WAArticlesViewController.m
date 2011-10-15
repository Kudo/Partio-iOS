//
//  WAArticlesViewController.m
//  wammer-iOS
//
//  Created by Evadne Wu on 8/31/11.
//  Copyright 2011 Iridia Productions. All rights reserved.
//

#import "WAArticlesViewController.h"
#import "WADataStore.h"
#import "WARemoteInterface.h"
#import "WACompositionViewController.h"

#import "IRBarButtonItem.h"
#import "IRTransparentToolbar.h"
#import "IRActionSheetController.h"
#import "IRActionSheet.h"
#import "IRAlertView.h"
#import "IRMailComposeViewController.h"

#import "WAOverlayBezel.h"
#import "UIApplication+CrashReporting.h"

#import "WAView.h"
#import "UIImage+IRAdditions.h"

@interface WAArticlesViewController () <NSFetchedResultsControllerDelegate>

- (void) sharedInit;

@property (nonatomic, readwrite, retain) NSFetchedResultsController *fetchedResultsController;
@property (nonatomic, readwrite, retain) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, readwrite, retain) IRActionSheetController *debugActionSheetController;

@property (nonatomic, readwrite, assign) BOOL updatesViewOnControllerChangeFinish;

@property (nonatomic, readwrite, assign) int interfaceUpdateOperationSuppressionCount;
@property (nonatomic, readwrite, retain) NSOperationQueue *interfaceUpdateOperationQueue;

@end


@implementation WAArticlesViewController
@synthesize delegate, fetchedResultsController, managedObjectContext;
@synthesize debugActionSheetController;
@synthesize updatesViewOnControllerChangeFinish;
@synthesize interfaceUpdateOperationSuppressionCount, interfaceUpdateOperationQueue;

- (id) initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {

	self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
	if (!self)
		return nil;
	
	[self sharedInit];
	
	return self;

}

- (id) initWithCoder:(NSCoder *)aDecoder {

	self = [super initWithCoder:aDecoder];
	if (!self)
		return nil;
	
	[self sharedInit];

	return self;

}

- (void) sharedInit {

	__block __typeof__(self) nrSelf = self;

	self.managedObjectContext = [[WADataStore defaultStore] defaultAutoUpdatedMOC];
	self.fetchedResultsController = [[[NSFetchedResultsController alloc] initWithFetchRequest:((^ {
	
		NSFetchRequest *returnedRequest = [[[NSFetchRequest alloc] init] autorelease];
		returnedRequest.entity = [NSEntityDescription entityForName:@"WAArticle" inManagedObjectContext:self.managedObjectContext];
		returnedRequest.predicate = [NSPredicate predicateWithFormat:@"(self != nil) AND (draft == NO)"];	//	 AND (files.@count > 1) tests image gallery animations
		returnedRequest.sortDescriptors = [NSArray arrayWithObjects:
			[NSSortDescriptor sortDescriptorWithKey:@"timestamp" ascending:YES],
		nil];
				
		return returnedRequest;
	
	})()) managedObjectContext:self.managedObjectContext sectionNameKeyPath:nil cacheName:nil] autorelease];
	
	self.fetchedResultsController.delegate = self;
	[self.fetchedResultsController performFetch:nil];
	
	self.navigationItem.titleView = (( ^ {
	
		UILabel *label = [[[UILabel alloc] initWithFrame:CGRectZero] autorelease];
		label.text = @"Wammer";
		label.textColor = [UIColor colorWithWhite:0.35 alpha:1];
		label.font = [UIFont fontWithName:@"Sansus Webissimo" size:24.0f];
		label.shadowColor = [UIColor whiteColor];
		label.shadowOffset = (CGSize){ 0, 1 };
		label.backgroundColor = nil;
		label.opaque = NO;
		[label sizeToFit];
		return label;
	
	})());
	
	self.navigationItem.rightBarButtonItem = [IRBarButtonItem itemWithCustomView:((^ {
	
		UIButton * (^buttonForImage)(UIImage *) = ^ (UIImage *anImage) {
			UIButton *returnedButton = [UIButton buttonWithType:UIButtonTypeCustom];
			[returnedButton setImage:anImage forState:UIControlStateNormal];
			[returnedButton setAdjustsImageWhenHighlighted:YES];
			[returnedButton setShowsTouchWhenHighlighted:YES];
			[returnedButton setContentEdgeInsets:(UIEdgeInsets){ 0, 5, 0, 0 }];
			[returnedButton sizeToFit];
			return returnedButton;
		};
		
		UIImage * (^barButtonImageFromImageNamed)(NSString *) = ^ (NSString *aName) {
			return [[UIImage imageNamed:aName] irSolidImageWithFillColor:[UIColor colorWithRed:.3 green:.3 blue:.3 alpha:1] shadow:[IRShadow shadowWithColor:[UIColor colorWithRed:1 green:1 blue:1 alpha:0.75f] offset:(CGSize){ 0, 1 } spread:0]];
		};
		
		IRTransparentToolbar *toolbar = [[[IRTransparentToolbar alloc] initWithFrame:(CGRect){ 0, 0, 120, 44 }] autorelease];
		
		toolbar.usesCustomLayout = NO;
		toolbar.items = [NSArray arrayWithObjects:
		
			[[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil] autorelease],
		
			[IRBarButtonItem itemWithButton:buttonForImage(barButtonImageFromImageNamed(@"WASettingsGlyph")) wiredAction: ^ (UIButton *senderButton, IRBarButtonItem *senderItem) {
				[self performSelector:@selector(handleAction:) withObject:senderItem];
			}],
		
			[IRBarButtonItem itemWithCustomView:[[[UIView alloc] initWithFrame:(CGRect){ 0, 0, 8.0f, 44 }] autorelease]],
			
			[IRBarButtonItem itemWithButton:buttonForImage(barButtonImageFromImageNamed(@"UIButtonBarCompose")) wiredAction: ^ (UIButton *senderButton, IRBarButtonItem *senderItem) {
				[self performSelector:@selector(handleCompose:) withObject:senderItem];
			}],
			
		nil];
		
		return toolbar;
	
	})())];
	
	self.title = @"Articles";
	
	self.interfaceUpdateOperationQueue = [[[NSOperationQueue alloc] init] autorelease];
	
}

- (void) dealloc {

	[fetchedResultsController release];
	[managedObjectContext release];
	[debugActionSheetController release];
	
	[interfaceUpdateOperationQueue release];

	[super dealloc];

}





//	Implicitly trigger a remote data refresh after view load

- (void) viewDidLoad {

	[super viewDidLoad];

}

- (void) viewWillAppear:(BOOL)animated {

	[super viewWillAppear:animated];
	[self reloadViewContents];	
	[self refreshData];

}

- (void) viewWillDisappear:(BOOL)animated {

	[super viewWillDisappear:animated];

	if (self.debugActionSheetController.managedActionSheet.visible)
		[self.debugActionSheetController.managedActionSheet dismissWithClickedButtonIndex:self.debugActionSheetController.managedActionSheet.cancelButtonIndex animated:animated];

}

- (void) viewDidUnload {

	self.debugActionSheetController = nil;
	
	[super viewDidUnload];

}

- (void) refreshData {

	__block __typeof__(self) nrSelf = self;
	
	[nrSelf retain];

	NSParameterAssert([NSThread isMainThread]);
	[nrSelf remoteDataLoadingWillBeginForOperation:@"refreshData"];
	
	[[WARemoteInterface sharedInterface] retrieveLastReadArticleRemoteIdentifierOnSuccess:^(NSString *lastID, NSDate *modDate) {
	
		//	NSLog(@"For the current user, the last read article # is %@ at %@", lastID, modDate);
		
	} onFailure: ^ (NSError *error) {
	
		//	Nothing, since this is implicit
		
	}];
	
	[[WADataStore defaultStore] updateUsersOnSuccess: ^ {
	
		[[WADataStore defaultStore] updateArticlesOnSuccess: ^ {
		
			dispatch_async(dispatch_get_main_queue(), ^ {
			
				//	if ([nrSelf isViewLoaded])
				//	if (nrSelf.view.window)
				//		[nrSelf reloadViewContents];
				
				[nrSelf remoteDataLoadingDidEnd];
				[nrSelf reloadViewContents];
				[nrSelf autorelease];
				
			});	
			
		} onFailure: ^ {
		
			dispatch_async(dispatch_get_main_queue(), ^ {
			
				[nrSelf remoteDataLoadingDidFailWithError:[NSError errorWithDomain:@"waveface.wammer" code:0 userInfo:nil]];
				[nrSelf autorelease];
				
			});
			
		}];
	
	} onFailure: ^ {
		
		dispatch_async(dispatch_get_main_queue(), ^ {
		
			[self remoteDataLoadingDidFailWithError:[NSError errorWithDomain:@"waveface.wammer" code:0 userInfo:nil]];

			[self autorelease];
			
		});
		
	}];

}


- (void) controllerWillChangeContent:(NSFetchedResultsController *)controller {
	
	//	NSLog(@"%s %@ %@", __PRETTY_FUNCTION__, [NSThread currentThread], controller);
	
}

- (void) controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type newIndexPath:(NSIndexPath *)newIndexPath {
	
	switch (type) {
		
		case NSFetchedResultsChangeDelete:
		case NSFetchedResultsChangeInsert:
		case NSFetchedResultsChangeMove: {
			self.updatesViewOnControllerChangeFinish = YES;
			break;
		}
		
		case NSFetchedResultsChangeUpdate:
			break;
		
	};

}

- (void) controllerDidChangeContent:(NSFetchedResultsController *)controller {
	
	if (self.updatesViewOnControllerChangeFinish) {
	
		if ([self isViewLoaded]) {
			[self reloadViewContents];
		}
	}
		
	self.updatesViewOnControllerChangeFinish = NO;
	
}

- (void) reloadViewContents {

	[NSException raise:NSInternalInconsistencyException format:@"%@ shall be implemented in a subclass only, and you should not call super.", NSStringFromSelector(_cmd)];

}

- (NSURL *) representedObjectURIForInterfaceItem:(UIView *)aView {

	[NSException raise:NSInternalInconsistencyException format:@"%@ shall be implemented in a subclass only, and you should not call super.", NSStringFromSelector(_cmd)];
	return nil;

}

- (UIView *) interfaceItemForRepresentedObjectURI:(NSURL *)anURI createIfNecessary:(BOOL)createsOffsecreenItemIfNecessary {

	[NSException raise:NSInternalInconsistencyException format:@"%@ shall be implemented in a subclass only, and you should not call super.", NSStringFromSelector(_cmd)];
	return nil;

}





- (NSArray *) debugActionSheetControllerActions {
	
	__block __typeof__(self) nrSelf = self;

	return [NSArray arrayWithObjects:
	
		[IRAction actionWithTitle:@"Sign Out" block: ^ {
		
			[[IRAlertView alertViewWithTitle:@"Sign Out" message:@"Really sign out?" cancelAction:[IRAction actionWithTitle:@"Cancel" block:nil] otherActions:[NSArray arrayWithObjects:
			
				[IRAction actionWithTitle:@"Sign Out" block: ^ {
				
					dispatch_async(dispatch_get_main_queue(), ^ {
					
						[nrSelf.delegate applicationRootViewControllerDidRequestReauthentication:nrSelf];
							
					});

				}],
			
			nil]] show];
		
		}],
	
		[IRAction actionWithTitle:@"Feedback" block:^ {
		
			if (![IRMailComposeViewController canSendMail]) {
				[[[[IRAlertView alloc] initWithTitle:@"Email Disabled" message:@"Add a mail account to enable this." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] autorelease] show];
				return;
			}
			
			__block IRMailComposeViewController *composeViewController;
			composeViewController = [IRMailComposeViewController controllerWithMessageToRecipients:[NSArray arrayWithObjects:@"ev@waveface.com",	nil] withSubject:@"Wammer Feedback" messageBody:nil inHTML:NO completion:^(MFMailComposeViewController *controller, MFMailComposeResult result, NSError *error) {
				[composeViewController dismissModalViewControllerAnimated:YES];
			}];
			
			if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
				composeViewController.modalPresentationStyle = UIModalPresentationFormSheet;
			
			[nrSelf presentModalViewController:composeViewController animated:YES];
		
		}],
		
		[IRAction actionWithTitle:@"Crash" block: ^ {
		
			((char *)NULL)[1] = 0;
		
		}],
	
	nil];

}

- (IRActionSheetController *) debugActionSheetController {

	if (debugActionSheetController)
		return debugActionSheetController;
		
	debugActionSheetController = [[IRActionSheetController actionSheetControllerWithTitle:nil cancelAction:nil destructiveAction:nil otherActions:[self debugActionSheetControllerActions]] retain];
	
	return debugActionSheetController;

}

- (void) handleAction:(UIBarButtonItem *)sender {

	[self.debugActionSheetController.managedActionSheet showFromBarButtonItem:sender animated:YES];

}

- (void) handleCompose:(UIBarButtonItem *)sender {

	WACompositionViewController *compositionVC = [WACompositionViewController controllerWithArticle:nil completion:^(NSURL *anArticleURLOrNil) {
	
		WAOverlayBezel *busyBezel = [WAOverlayBezel bezelWithStyle:WAActivityIndicatorBezelStyle];
		[busyBezel show];
	
		[[WADataStore defaultStore] uploadArticle:anArticleURLOrNil onSuccess: ^ {
		
			dispatch_async(dispatch_get_main_queue(), ^ {
			
				[self refreshData];
				[busyBezel dismiss];

				WAOverlayBezel *doneBezel = [WAOverlayBezel bezelWithStyle:WACheckmarkBezelStyle];
				[doneBezel show];
				dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2.0 * NSEC_PER_SEC), dispatch_get_main_queue(), ^ {
					[doneBezel dismiss];
				});
				
			});		
		
		} onFailure: ^ {
		
			dispatch_async(dispatch_get_main_queue(), ^ {
			
				NSLog(@"Article upload failed.  Help!");
				[busyBezel dismiss];
				
				WAOverlayBezel *errorBezel = [WAOverlayBezel bezelWithStyle:WAErrorBezelStyle];
				[errorBezel show];
				dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2.0 * NSEC_PER_SEC), dispatch_get_main_queue(), ^ {
					[errorBezel dismiss];
				});
			
			});
					
		}];
	
	}];
	
	UINavigationController *wrapperNC = [[[UINavigationController alloc] initWithRootViewController:compositionVC] autorelease];
	wrapperNC.modalPresentationStyle = UIModalPresentationFullScreen;
	
	[(self.navigationController ? self.navigationController : self) presentModalViewController:wrapperNC animated:YES];

}





NSString * const kLoadingBezel = @"loadingBezel";

- (void) remoteDataLoadingWillBegin {

	[self remoteDataLoadingWillBeginForOperation:nil];

}

- (void) remoteDataLoadingWillBeginForOperation:(NSString *)aMethodName {

	NSParameterAssert([NSThread isMainThread]);
		
	if ([aMethodName isEqualToString:@"refreshData"]) {
		//	Only show on first load, when there is nothing displayed yet
		if ([self.fetchedResultsController.fetchedObjects count])
			return;
	}

	WAOverlayBezel *bezel = [WAOverlayBezel bezelWithStyle:WADefaultBezelStyle];
	bezel.caption = @"Loading";
	
	[bezel show];
	
	objc_setAssociatedObject(self, &kLoadingBezel, bezel, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

}

- (void) remoteDataLoadingDidEnd {

	WAOverlayBezel *bezel = objc_getAssociatedObject(self, &kLoadingBezel);
	
	[[bezel retain] autorelease];
	objc_setAssociatedObject(self, &kLoadingBezel, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	
	[bezel dismiss];

}

- (void) remoteDataLoadingDidFailWithError:(NSError *)anError {

	WAOverlayBezel *loadingBezel = objc_getAssociatedObject(self, &kLoadingBezel);
	[loadingBezel dismiss];
	
	WAOverlayBezel *errorBezel = [WAOverlayBezel bezelWithStyle:WAErrorBezelStyle];
	[errorBezel show];
	
	double delayInSeconds = 2.0;
	dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
	dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
    [errorBezel dismissWithAnimation:WAOverlayBezelAnimationZoom];
	});

}





- (void) performInterfaceUpdate:(void(^)(void))aBlock {

	[self.interfaceUpdateOperationQueue addOperation:[NSBlockOperation blockOperationWithBlock: ^ {
	
		dispatch_async(dispatch_get_main_queue(), ^ {
		
			if (aBlock)
				aBlock();
		
		});
		
	}]];

}

- (void) beginDelayingInterfaceUpdates {

	self.interfaceUpdateOperationSuppressionCount += 1;
	
	if (self.interfaceUpdateOperationSuppressionCount)
		[self.interfaceUpdateOperationQueue setSuspended:YES];

}

- (void) endDelayingInterfaceUpdates {

	self.interfaceUpdateOperationSuppressionCount -= 1;
	
	if (!self.interfaceUpdateOperationSuppressionCount)
		[self.interfaceUpdateOperationQueue setSuspended:NO];

}

- (BOOL) isDelayingInterfaceUpdates {

	return [self.interfaceUpdateOperationQueue isSuspended];

}





- (void) didReceiveMemoryWarning {

	[self retain];
	[super didReceiveMemoryWarning];
	[self release];

}

@end
