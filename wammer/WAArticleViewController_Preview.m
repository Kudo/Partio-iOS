//
//  WAArticleViewController_Preview.m
//  wammer
//
//  Created by Evadne Wu on 1/30/12.
//  Copyright (c) 2012 Waveface. All rights reserved.
//

#import "WAArticleViewController_Preview.h"
#import "WADataStore.h"

#import "WAScrollView.h"

#import "WADefines.h"

#import "UIView+IRAdditions.h"
#import "UIScrollView+IRAdditions.h"

#import "WAArticleTextStackCell.h"

#import <UIKit/UIGestureRecognizerSubclass.h>


enum {

	WAArticleViewControllerSummaryState,
	WAArticleViewControllerWebState,
	
	WAArticleViewControllerDefaultState = WAArticleViewControllerSummaryState

}; typedef NSUInteger WAArticleViewControllerState;


@interface WAArticleViewController_Preview () <UIWebViewDelegate, UIGestureRecognizerDelegate>

- (WAPreview *) preview;

@property (nonatomic, readwrite, assign) WAArticleViewControllerState state;

@property (nonatomic, readwrite, retain) UIWebView *webView;
@property (nonatomic, readwrite, retain) UIWebView *summaryWebView;
@property (nonatomic, readwrite, retain) UIView *webViewWrapper;

@property (nonatomic, readwrite, retain) UIActivityIndicatorView *webViewActivityIndicator;
@property (nonatomic, readwrite, retain) IRBarButtonItem *webViewBackBarButtonItem;
@property (nonatomic, readwrite, retain) IRBarButtonItem *webViewForwardBarButtonItem;
@property (nonatomic, readwrite, retain) IRBarButtonItem *webViewActivityIndicatorBarButtonItem;
@property (nonatomic, readwrite, retain) IRBarButtonItem *webViewReloadBarButtonItem;

- (UIView *) wrappedView;
- (void) updateWrapperView;

- (void) updateWebViewBarButtonItems;

@property (nonatomic, readwrite, retain) WAPreviewBadge *previewBadge;
@property (nonatomic, readwrite, retain) UIView *previewBadgeWrapper;

- (NSArray *) previewActionsWithSender:(UIBarButtonItem *)sender;
@property (nonatomic, readwrite, retain) IRActionSheetController *previewActionSheetController;

@end


@implementation WAArticleViewController_Preview
@synthesize state;
@synthesize webView, summaryWebView, webViewWrapper, previewBadge, previewBadgeWrapper;
@synthesize webViewActivityIndicator, webViewBackBarButtonItem, webViewForwardBarButtonItem, webViewActivityIndicatorBarButtonItem, webViewReloadBarButtonItem;
@synthesize previewActionSheetController;

- (void) dealloc {

	NSURLRequest *blankRequest = [NSURLRequest requestWithURL:[NSURL URLWithString:@"about:blank"]];
	
	[webView setDelegate:nil];
	[webView loadRequest:blankRequest];
	[webView setDelegate:self];
	
	[summaryWebView setDelegate:nil];
	[summaryWebView loadRequest:blankRequest];
	[summaryWebView setDelegate:self];

	webView.delegate = nil;
	summaryWebView.delegate = nil;
	
	[webView release];
	[summaryWebView release];
	[webViewWrapper release];
	
	[webViewActivityIndicator release];
	[webViewBackBarButtonItem release];
	[webViewForwardBarButtonItem release];
	[webViewActivityIndicatorBarButtonItem release];
	[webViewReloadBarButtonItem release];

	[previewBadge release];
	[previewBadgeWrapper release];
	
	[previewActionSheetController release];
	
	[super dealloc];

}

- (void) didReceiveMemoryWarning {

	if ([self isViewLoaded]) {
	
		if (!summaryWebView.superview)
			self.summaryWebView = nil;
		
		if (!webView.superview)
			self.webView = nil;
	
	}

	[super didReceiveMemoryWarning];
	
}

- (WAPreview *) preview {

	return (WAPreview *)[self.article.previews anyObject];

}

- (id) initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {

	self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
	if (!self)
		return nil;
	
	self.state = WAArticleViewControllerSummaryState;
	
	return self;

}

- (UIView *) scrollableStackElementWrapper {

	return self.webViewWrapper;

}

- (UIScrollView *) scrollableStackElement {

	return [(UIWebView *)self.wrappedView scrollView];

}

- (void) viewDidLoad {

	[super viewDidLoad];
	
	__block __typeof__(self) nrSelf = self;
	
	WAPreview *anyPreview = [self preview];
	
	if (!anyPreview)
		return;
		
	NSMutableArray *stackElements = [self.stackView mutableStackElements];
	
	[stackElements addObject:self.webViewWrapper];
	
	self.stackView.delaysContentTouches = NO;
	self.stackView.canCancelContentTouches = YES;
	self.stackView.onTouchesShouldBeginWithEventInContentView = ^ (NSSet *touches, UIEvent *event, UIView *contentView) {
	
		UIView *currentWrapperView = [nrSelf scrollableStackElementWrapper];
		UIView *currentWrappedView = [nrSelf scrollableStackElement];
		
		if (contentView != currentWrappedView)
		if (![contentView isDescendantOfView:currentWrappedView])
			return [contentView isKindOfClass:[UIControl class]];
			
		WAStackView *sv = nrSelf.stackView;
		UIView *svContainer = nrSelf.stackView.superview;
		
		if (CGRectContainsRect([svContainer convertRect:sv.bounds fromView:sv], [svContainer convertRect:currentWrapperView.bounds fromView:currentWrapperView]))
			return YES;
		
		return NO;
	
	};
	
	self.stackView.onTouchesShouldCancelInContentView = ^ (UIView *view) {
	
		return NO;
	
	};
	
	self.stackView.onGestureRecognizerShouldRecognizeSimultaneouslyWithGestureRecognizer = ^ (UIGestureRecognizer *aGR, UIGestureRecognizer *otherGR, BOOL superAnswer) {
	
		if ((otherGR.view == [nrSelf scrollableStackElementWrapper]) || [otherGR.view isDescendantOfView:[nrSelf scrollableStackElementWrapper]])
			return NO;
		
		return YES;
	
	};
	
	self.stackView.panGestureRecognizer.delaysTouchesBegan = NO;
	self.stackView.panGestureRecognizer.delaysTouchesEnded = NO;
		
	if ([self isViewLoaded])
		[self updateWrapperView];

}

- (void) viewDidUnload {

	[super viewDidUnload];
	
	self.webView.delegate = nil;
	self.webView = nil;
	
	self.summaryWebView.delegate = nil;
	self.summaryWebView = nil;
	
	self.webViewWrapper = nil;
	
	self.webViewActivityIndicator = nil;
	self.webViewBackBarButtonItem = nil;
	self.webViewForwardBarButtonItem = nil;
	self.webViewActivityIndicatorBarButtonItem = nil;
	self.webViewReloadBarButtonItem = nil;

	self.previewBadge = nil;
	self.previewBadgeWrapper = nil;
	
	self.previewActionSheetController = nil;

	//	self.toolbar = nil;

}

- (void) viewWillAppear:(BOOL)animated {

	[super viewWillAppear:animated];
	
	[self.navigationController setToolbarHidden:NO animated:animated];

}

- (void) viewWillDisappear:(BOOL)animated {

	[super viewWillDisappear:animated];
	
	[self.navigationController setToolbarHidden:YES animated:animated];

}

- (UIWebView *) webView {

	if (webView)
		return webView;
	
	webView = [[UIWebView alloc] initWithFrame:CGRectZero];
	
	webView.backgroundColor = [UIColor scrollViewTexturedBackgroundColor];
	webView.delegate = self;
	webView.scrollView.directionalLockEnabled = NO;
		
	[webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:[self preview].graphElement.url]]];
	
	return webView;

}

- (UIWebView *) summaryWebView {

	if (summaryWebView)
		return summaryWebView;
	
	summaryWebView = [[UIWebView alloc] initWithFrame:CGRectZero];
	
	summaryWebView.backgroundColor = [UIColor scrollViewTexturedBackgroundColor];
	summaryWebView.delegate = self;
	summaryWebView.scrollView.directionalLockEnabled = NO;
	
	NSString *tidyString = [summaryWebView stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:
	
		@"(function tidy (string) { var element = document.createElement('DIV'); element.innerHTML = string; return element.innerHTML; })(unescape(\"%@\"));",
		[self.article.summary stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]
		
	]];
	
	NSString *summaryTemplatePath = [[NSBundle mainBundle] pathForResource:@"WFPreviewTemplate" ofType:@"html"];
	NSString *summaryTemplateDirectoryPath = [summaryTemplatePath stringByDeletingLastPathComponent];

	#if DEBUG
	
		NSFileManager * const fileManager = [NSFileManager defaultManager];
		
		BOOL fileIsDirectory = NO;
		NSParameterAssert([fileManager fileExistsAtPath:summaryTemplatePath isDirectory:&fileIsDirectory] && !fileIsDirectory);
		NSParameterAssert([fileManager fileExistsAtPath:summaryTemplateDirectoryPath isDirectory:&fileIsDirectory] && fileIsDirectory);				
	
	#endif
	
	WAPreview *preview = [self.article.previews anyObject];
	NSString *usedTitle = preview.graphElement.title;
	NSString *usedProviderName = [preview.graphElement providerCaption];
	
	NSString *usedSummary = (tidyString ? tidyString : self.article.summary);
	NSString *templatedSummary = [NSString stringWithContentsOfFile:summaryTemplatePath usedEncoding:NULL error:nil];
	NSURL *summaryTemplateBaseURL = templatedSummary ? [NSURL fileURLWithPath:summaryTemplateDirectoryPath] : nil;
		
	templatedSummary = [templatedSummary stringByReplacingOccurrencesOfString:@"$ADDITIONAL_STYLES" withString:@""];

	templatedSummary = [templatedSummary stringByReplacingOccurrencesOfString:@"$BODY" withString:(usedSummary ? usedSummary : @"")];
	templatedSummary = [templatedSummary stringByReplacingOccurrencesOfString:@"$TITLE" withString:(usedTitle ? usedTitle : @"")];
	templatedSummary = [templatedSummary stringByReplacingOccurrencesOfString:@"$SOURCE" withString:(usedProviderName ? usedProviderName : @"")];
	
	[summaryWebView loadHTMLString:(templatedSummary ? templatedSummary : usedSummary) baseURL:summaryTemplateBaseURL];
	
	return summaryWebView;

}

- (IRBarButtonItem *) webViewBackBarButtonItem {

	if (webViewBackBarButtonItem)
		return webViewBackBarButtonItem;
	
	__block __typeof__(self) nrSelf = self;
	
	UIColor *glyphColor = nil;
	
	switch ([UIDevice currentDevice].userInterfaceIdiom) {	
		case UIUserInterfaceIdiomPad: {
			glyphColor = [UIColor colorWithWhite:0.3 alpha:1];
			break;
		}		
		case UIUserInterfaceIdiomPhone: {
			glyphColor = [UIColor whiteColor];
			break;
		}
	}
	
	UIImage *leftImage = WABarButtonImageWithOptions(@"UIButtonBarArrowLeft", glyphColor, kWADefaultBarButtonTitleShadow);
	UIImage *leftLandscapePhoneImage = WABarButtonImageWithOptions(@"UIButtonBarArrowLeftLandscape", glyphColor, kWADefaultBarButtonTitleShadow);
		
	webViewBackBarButtonItem = [[IRBarButtonItem itemWithCustomImage:leftImage landscapePhoneImage:leftLandscapePhoneImage highlightedImage:nil highlightedLandscapePhoneImage:nil] retain];
	
	webViewBackBarButtonItem.block = ^ {
	
		UIWebView *currentWebView = (UIWebView *)[nrSelf wrappedView];
		
		if (![currentWebView isKindOfClass:[UIWebView class]])
			return;
		
		[currentWebView goBack];
	
	};
	
	return webViewBackBarButtonItem;

}

- (IRBarButtonItem *) webViewForwardBarButtonItem {

	if (webViewForwardBarButtonItem)
		return webViewForwardBarButtonItem;
	
	__block __typeof__(self) nrSelf = self;
		
	UIColor *glyphColor = nil;
	
	switch ([UIDevice currentDevice].userInterfaceIdiom) {	
		case UIUserInterfaceIdiomPad: {
			glyphColor = [UIColor colorWithWhite:0.3 alpha:1];
			break;
		}		
		case UIUserInterfaceIdiomPhone: {
			glyphColor = [UIColor whiteColor];
			break;
		}
	}
	
	UIImage *rightImage = WABarButtonImageWithOptions(@"UIButtonBarArrowRight", glyphColor, kWADefaultBarButtonTitleShadow);
	UIImage *rightLandscapePhoneImage = WABarButtonImageWithOptions(@"UIButtonBarArrowRightLandscape", glyphColor, kWADefaultBarButtonTitleShadow);
		
	webViewForwardBarButtonItem = [[IRBarButtonItem itemWithCustomImage:rightImage landscapePhoneImage:rightLandscapePhoneImage highlightedImage:nil highlightedLandscapePhoneImage:nil] retain];
	
	webViewForwardBarButtonItem.block = ^ {
	
		UIWebView *currentWebView = (UIWebView *)[nrSelf wrappedView];
		
		if (![currentWebView isKindOfClass:[UIWebView class]])
			return;
		
		[currentWebView goForward];
	
	};
	
	return webViewForwardBarButtonItem;

}

- (UIActivityIndicatorView *) webViewActivityIndicator {

	if (webViewActivityIndicator)
		return webViewActivityIndicator;
	
	webViewActivityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
	[webViewActivityIndicator startAnimating];
	
	return webViewActivityIndicator;

}

- (IRBarButtonItem *) webViewActivityIndicatorBarButtonItem {

	if (webViewActivityIndicatorBarButtonItem)
		return webViewActivityIndicatorBarButtonItem;
	
	webViewActivityIndicatorBarButtonItem = [[IRBarButtonItem itemWithCustomView:self.webViewActivityIndicator] retain];
	
	return webViewActivityIndicatorBarButtonItem;

}

- (BOOL) webView:(UIWebView *)aWebView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {

	return YES;

}

- (void) webViewDidStartLoad:(UIWebView *)aWebView {

	[self updateWebViewBarButtonItems];

}

- (void) webViewDidFinishLoad:(UIWebView *)aWebView {

	[self updateWebViewBarButtonItems];

}

- (void) webView:(UIWebView *)aWebView didFailLoadWithError:(NSError *)error {

	[self updateWebViewBarButtonItems];

}

- (void) updateWebViewBarButtonItems {

	if (![self isViewLoaded])
		return;
		
	UIWebView *currentWebView = (UIWebView *)[self wrappedView];
	if (![currentWebView isKindOfClass:[UIWebView class]])
		return;
	
	self.webViewReloadBarButtonItem.enabled = !currentWebView.loading;
	self.webViewActivityIndicator.alpha = currentWebView.loading ? 1 : 0;
	
	self.webViewBackBarButtonItem.enabled = currentWebView.canGoBack;
	self.webViewForwardBarButtonItem.enabled = currentWebView.canGoForward;

}

- (UIView *) wrappedView {

	switch (self.state) {
	
		case WAArticleViewControllerSummaryState:
			return self.summaryWebView;
		
		case WAArticleViewControllerWebState:
			return self.webView;
	
	};
	
	return nil;

}

- (UIView *) webViewWrapper {

	if (webViewWrapper)
		return webViewWrapper;
	
	webViewWrapper = [[[WAView alloc] initWithFrame:CGRectZero] autorelease];
	webViewWrapper.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;

	IRGradientView *topShadow = [[[IRGradientView alloc] initWithFrame:IRGravitize(webViewWrapper.bounds, (CGSize){
		CGRectGetWidth(webViewWrapper.bounds),
		3
	}, kCAGravityTop)] autorelease];
	topShadow.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleBottomMargin;
	[topShadow setLinearGradientFromColor:[UIColor colorWithWhite:0 alpha:0.125] anchor:irTop toColor:[UIColor colorWithWhite:0 alpha:0] anchor:irBottom];
	[webViewWrapper addSubview:topShadow];
	
	__block __typeof__(self) nrSelf = self;
	__block WAView * nrWebViewWrapper = (WAView *)webViewWrapper;
	
	nrWebViewWrapper.onPointInsideWithEvent = ^ (CGPoint aPoint, UIEvent *anEvent, BOOL superAnswer) {
	
		UIView *wrappedView = [nrSelf wrappedView];
		
		if (!wrappedView)
			return superAnswer;
	
		NSCParameterAssert([wrappedView isDescendantOfView:nrWebViewWrapper]);
		
		BOOL customAnswer = CGRectContainsPoint([nrWebViewWrapper convertRect:wrappedView.bounds fromView:wrappedView], aPoint);
		return customAnswer;
	
	};
	
	nrWebViewWrapper.onHitTestWithEvent = ^ (CGPoint aPoint, UIEvent *anEvent, UIView *superAnswer) {
	
		if (![nrWebViewWrapper pointInside:aPoint withEvent:anEvent])
			return superAnswer;
		
		UIView *wrappedView = [nrSelf wrappedView];
		if (!wrappedView)
			return superAnswer;
		
		return [wrappedView hitTest:[wrappedView convertPoint:aPoint fromView:nrWebViewWrapper] withEvent:anEvent];
	
	};

	[self updateWrapperView];
	
	return webViewWrapper;
	
}

- (WAPreviewBadge *) previewBadge {

	if (previewBadge)
		return previewBadge;
	
	previewBadge = [[WAPreviewBadge alloc] initWithFrame:CGRectZero];
	previewBadge.backgroundView = nil;
	previewBadge.titleFont = [UIFont boldSystemFontOfSize:24.0f];
	previewBadge.titleColor = [UIColor colorWithWhite:0.35 alpha:1];
	previewBadge.textFont = [UIFont systemFontOfSize:18.0f];
	previewBadge.textColor = [UIColor colorWithWhite:0.4 alpha:1];
	previewBadge.userInteractionEnabled = NO;
	
	return previewBadge;

}

- (UIView *) previewBadgeWrapper {

	if (previewBadgeWrapper)
		return previewBadgeWrapper;
	
	previewBadgeWrapper = [[[UIView alloc] initWithFrame:(CGRect){
		CGPointZero,
		(CGSize){
			384,
			384
		}
	}] autorelease];
	UIView *backgroundView = WAStandardArticleStackCellCenterBackgroundView();
	backgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
	backgroundView.frame = previewBadgeWrapper.bounds;
	[previewBadgeWrapper addSubview:backgroundView];
	
	self.previewBadge.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
	self.previewBadge.frame = CGRectInset(previewBadgeWrapper.bounds, 16, 0);
	[previewBadgeWrapper addSubview:self.previewBadge];
	
	return previewBadgeWrapper;

}

- (NSArray *) toolbarItems {

	if ([[super toolbarItems] count])
		return [super toolbarItems];
	
	__block __typeof__(self) nrSelf = self;
	
	self.toolbarItems = ((^ {
	
		NSMutableArray *returnedArray = [NSMutableArray array];
		
		[returnedArray addObject:[IRBarButtonItem itemWithCustomView:((^ {
		
			UISegmentedControl *segmentedControl = [[[UISegmentedControl alloc] initWithItems:nil] autorelease];
			segmentedControl.segmentedControlStyle = UISegmentedControlStyleBar;
			[segmentedControl addTarget:nrSelf action:@selector(handleSegmentedControlValueChanged:) forControlEvents:UIControlEventValueChanged];
			
			[segmentedControl insertSegmentWithTitle:@"Summary" atIndex:0 animated:NO];
			[segmentedControl insertSegmentWithTitle:@"Web" atIndex:1 animated:NO];
			
			[segmentedControl setSelectedSegmentIndex:0];
			[segmentedControl sendActionsForControlEvents:UIControlEventValueChanged];
			
			return segmentedControl;
		
		})())]];
		
		BOOL const isPhone = [UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone;

		[returnedArray addObject:[IRBarButtonItem itemWithSystemItem:UIBarButtonSystemItemFlexibleSpace wiredAction:nil]];
		
		if (isPhone) {
			
			[returnedArray addObject:nrSelf.webViewBackBarButtonItem];
			[returnedArray addObject:[IRBarButtonItem itemWithSystemItem:UIBarButtonSystemItemFlexibleSpace wiredAction:nil]];
			//	[returnedArray addObject:nrSelf.webViewActivityIndicatorBarButtonItem];
			[returnedArray addObject:nrSelf.webViewForwardBarButtonItem];

		} else {
			
			[returnedArray addObject:nrSelf.webViewBackBarButtonItem];
			[returnedArray addObject:[IRBarButtonItem itemWithCustomView:[[[UIView alloc] initWithFrame:(CGRect){ 0, 0, 10, 44}] autorelease]]];
			[returnedArray addObject:nrSelf.webViewActivityIndicatorBarButtonItem];
			[returnedArray addObject:[IRBarButtonItem itemWithCustomView:[[[UIView alloc] initWithFrame:(CGRect){ 0, 0, 10, 44}] autorelease]]];
			[returnedArray addObject:nrSelf.webViewForwardBarButtonItem];
			
		}
		
		[returnedArray addObject:[IRBarButtonItem itemWithSystemItem:UIBarButtonSystemItemFlexibleSpace wiredAction:nil]];
		
		[returnedArray addObject:[IRBarButtonItem itemWithSystemItem:UIBarButtonSystemItemAction wiredAction:^(IRBarButtonItem *senderItem) {
		
			IRActionSheet *actionSheet = nrSelf.previewActionSheetController.managedActionSheet;
			
			if (![actionSheet isVisible]) {
			
				nrSelf.previewActionSheetController.otherActions = [self previewActionsWithSender:senderItem];
				[nrSelf.previewActionSheetController.managedActionSheet showFromBarButtonItem:senderItem animated:YES];
				
			}
		
		}]];
		
		return returnedArray;
	
	})());
		
	return self.toolbarItems;

}

- (IRActionSheetController *) previewActionSheetController {

	if (previewActionSheetController)
		return previewActionSheetController;
	
	previewActionSheetController = [[IRActionSheetController actionSheetControllerWithTitle:nil cancelAction:nil destructiveAction:nil otherActions:nil] retain];
	
	return previewActionSheetController;

}

- (NSArray *) previewActionsWithSender:(UIBarButtonItem *)sender {
	
	__block __typeof__(self) nrSelf = self;

	NSMutableArray *returnedActions = [NSMutableArray arrayWithObjects:
	
		[IRAction actionWithTitle:NSLocalizedString(@"ACTION_OPEN_IN_SAFARI", nil) block:^{

			[[UIApplication sharedApplication] openURL:[nrSelf externallyVisibleURL]];
			
		}],
	
	nil];
	
	if ([UIPrintInteractionController isPrintingAvailable]) {
	
		[returnedActions addObject:[IRAction actionWithTitle:NSLocalizedString(@"ACTION_PRINT", nil) block:^{
			
			UIPrintInteractionController *printIC = [UIPrintInteractionController sharedPrintController];
			printIC.printFormatter = [[nrSelf wrappedView] viewPrintFormatter];
			
			UIPrintInteractionCompletionHandler completionHandler = ^ (UIPrintInteractionController *controller, BOOL completed, NSError *error) {
			
			};
			
			switch ([UIDevice currentDevice].userInterfaceIdiom) {
				case UIUserInterfaceIdiomPad: {
					[printIC presentFromBarButtonItem:sender animated:YES completionHandler:completionHandler];
					break;
				}
				case UIUserInterfaceIdiomPhone: {
					[printIC presentAnimated:YES completionHandler:completionHandler];
					break;
				}
			}
		
		}]];
	
	}
	
	return returnedActions;

}

- (NSURL *) externallyVisibleURL {

	if ([self wrappedView] == webView)
		return [NSURL URLWithString:[webView stringByEvaluatingJavaScriptFromString:@"document.location.href"]];

	return [NSURL URLWithString:self.preview.graphElement.url];

}

- (void) setState:(WAArticleViewControllerState)newState {

	BOOL didChange = (state != newState);
	
	if (didChange) {
		[self willChangeValueForKey:@"state"];
		state = newState;
		[self didChangeValueForKey:@"state"];
	}
	
	if ([self isViewLoaded])
		[self updateWrapperView];

}

- (void) updateWrapperView {

	UIView * const wrapperView = self.webViewWrapper;
	UIView * const contentView = [self wrappedView];
	
	if ([contentView isDescendantOfView:wrapperView])
		return;
	
	for (UIView *aSubview in [[wrapperView.subviews copy] autorelease])
	if (aSubview == summaryWebView || aSubview == webView)
		[aSubview removeFromSuperview];
	
	contentView.frame = wrapperView.bounds;
	contentView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
	
	[wrapperView addSubview:contentView];
	[wrapperView sendSubviewToBack:contentView];
	
	[self updateWebViewBarButtonItems];

}

- (void) handleSegmentedControlValueChanged:(UISegmentedControl *)sender {

	WAArticleViewControllerState wantedState = self.state;
	
	switch (sender.selectedSegmentIndex) {
		
		case 0: {
			wantedState = WAArticleViewControllerSummaryState;
			break;
		}
		
		case 1: {
			wantedState = WAArticleViewControllerWebState;
			break;
		}
		
		default: {
			break;
		}
	
	}
	
	self.state = wantedState;

}

- (CGSize) sizeThatFitsElement:(UIView *)anElement inStackView:(WAStackView *)aStackView {

	CGFloat minWrappedViewHeight = ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) ? 384 : CGRectGetHeight(aStackView.bounds);
	
	if ([[self wrappedView] isDescendantOfView:anElement])
		return (CGSize){ CGRectGetWidth(aStackView.bounds), minWrappedViewHeight };	//	Stretchable
			
	if ((self.previewBadge == anElement) || [self.previewBadge isDescendantOfView:anElement]) {
	
		UIView *furthestWrapper = [self.previewBadge irAncestorInView:anElement.superview];
		
		CGSize sizeDelta = (CGSize){
			CGRectGetWidth(furthestWrapper.bounds) - CGRectGetWidth(self.previewBadge.bounds),
			CGRectGetHeight(furthestWrapper.bounds) - CGRectGetHeight(self.previewBadge.bounds),
		};
		
		CGSize previewSize = [self.previewBadge sizeThatFits:(CGSize){
			CGRectGetWidth(aStackView.bounds) - sizeDelta.width,
			48 - sizeDelta.height
		}];
		
		return (CGSize){
			CGRectGetWidth(aStackView.bounds),
			previewSize.height + sizeDelta.height
		};
		
	}
	
	if ([self irHasDifferentSuperInstanceMethodForSelector:_cmd])
		return [super sizeThatFitsElement:anElement inStackView:aStackView];
	
	return CGSizeZero;	

}

- (BOOL) stackView:(WAStackView *)aStackView shouldStretchElement:(UIView *)anElement {

	if ([[self wrappedView] isDescendantOfView:anElement])
		return YES;
	
	if ([self irHasDifferentSuperInstanceMethodForSelector:_cmd])
		return [super stackView:aStackView shouldStretchElement:anElement];
	
	return NO;

}

- (void) willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {

	[super willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];

}

@end
