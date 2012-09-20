//
//  WAFilterPickerViewController.m
//  wammer
//
//  Created by Evadne Wu on 4/20/12.
//  Copyright (c) 2012 Waveface. All rights reserved.
//

#import "WAFilterPickerViewController.h"
#import "WADataStore.h"
#import "CoreData+IRAdditions.h"

static NSString * const kWAFilterPickerViewSelectedRowIndex = @"kWAFilterPickerViewSelectedRowIndex";

@interface WAFilterPickerViewController ()

@property (nonatomic, readwrite, copy) void(^callback)(NSFetchRequest *);
@property (nonatomic, readwrite, strong) NSArray *fetchRequests;

@end

@implementation WAFilterPickerViewController
@synthesize callback;
@synthesize pickerView;
@synthesize fetchRequests;

+ (id) controllerWithCompletion:(void(^)(NSFetchRequest *))block {

	WAFilterPickerViewController *controller = [[self alloc] initWithNibName:nil bundle:nil];
	if (!controller)
		return nil;
	
	controller.callback = block;
	return controller;

}

- (id) initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {

	self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
	if (!self)
		return nil;
	
	WADataStore *dataStore = [WADataStore defaultStore];
	
	fetchRequests = @[
		[dataStore newFetchRequestForAllArticles],
		[dataStore newFetchRequestForArticlesWithPhotos],
		[dataStore newFetchRequestForArticlesWithPreviews],
		[dataStore newFetchRequestForUrlHistories],
	];
	
	return self;

}

- (void)viewDidLoad {
	[super viewDidLoad];
	NSInteger lastRowIndex = [[NSUserDefaults standardUserDefaults] integerForKey:kWAFilterPickerViewSelectedRowIndex];
	[self.pickerView selectRow:lastRowIndex inComponent:0 animated:YES];	
}


- (void) viewDidUnload {

	[self setPickerView:nil];
	[super viewDidUnload];

}

- (NSInteger) numberOfComponentsInPickerView:(UIPickerView *)pickerView {

	return 1;

}

- (NSInteger) pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {

	return [self.fetchRequests count];

}

- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component {

	NSFetchRequest *fr = [self.fetchRequests objectAtIndex:row];
	NSString *displayTitle = fr.displayTitle;
	
	return displayTitle ? displayTitle : [fr.predicate predicateFormat];

}

- (IBAction) handleCancel:(UIBarButtonItem *)sender {

	[self runDismissingAnimationWithCompletion:^{
	
		if (self.callback)
			self.callback(nil);
		
	}];
	
}

- (IBAction) handleDone:(UIBarButtonItem *)sender {
	
	NSInteger rowIndex = [self.pickerView selectedRowInComponent:0];
	
	if (rowIndex != -1) {
		
		if (self.callback)
			self.callback([self.fetchRequests objectAtIndex:rowIndex]);
		
	} else {
		
		if (self.callback)
			self.callback(nil);
		
	}
	
	[[NSUserDefaults standardUserDefaults] setInteger:rowIndex forKey:kWAFilterPickerViewSelectedRowIndex];
	
}

#pragma UIPickerViewDelegate

- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component {
	
	[self performSelector:@selector(handleDone:) withObject:nil afterDelay:(NSTimeInterval)0.5];
}

@end
