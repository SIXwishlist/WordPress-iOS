#import "WPAddCategoryViewController.h"
#import "EditSiteViewController.h"
#import "WordPressAppDelegate.h"

@implementation WPAddCategoryViewController
@synthesize blog;

#pragma mark -
#pragma mark LifeCycle Methods

- (void)viewDidLoad {
    DDLogInfo(@"%@ %@", self, NSStringFromSelector(_cmd));
	[super viewDidLoad];
    catTableView.sectionFooterHeight = 0.0;

    saveButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Save", @"Save button label (saving content, ex: Post, Page, Comment, Category).") style:[WPStyleGuide barButtonStyleForDone] target:self action:@selector(saveAddCategory:)];

    newCatNameField.font = [UIFont fontWithName:@"OpenSans" size:17];
    parentCatNameLabel.font = [WPStyleGuide tableviewSectionHeaderFont];
    parentCatNameLabel.textColor = [WPStyleGuide whisperGrey];
    parentCatNameField.font = [WPStyleGuide tableviewTextFont];
    parentCatNameField.textColor = [WPStyleGuide whisperGrey];
    parentCatNameLabel.text = NSLocalizedString(@"Parent Category", @"Placeholder to set a parent category for a new category.");
    parentCatNameField.placeholder = NSLocalizedString(@"Optional", @"Placeholder to indicate that filling out the field is optional.");
    newCatNameField.placeholder = NSLocalizedString(@"Title", @"Title of the new Category being created.");
    
    cancelButtonItem.title = NSLocalizedString(@"Cancel", @"Cancel button label.");

    parentCat = nil;
    [WPStyleGuide configureColorsForView:self.view andTableView:catTableView];
}

- (void)viewWillAppear:(BOOL)animated {
    self.title = NSLocalizedString(@"Add Category", @"Button to add category.");
	// only show "cancel" button if we're presented in a modal view controller
	// that is, if we are the root item of a UINavigationController
	if ([self.parentViewController isKindOfClass:[UINavigationController class]]) {
		UINavigationController *parent = (UINavigationController *)self.parentViewController;
		if ([[parent viewControllers] objectAtIndex:0] == self) {
			self.navigationItem.leftBarButtonItem = cancelButtonItem;
        } else {
            if (IS_IPAD) {
                if ([[parent viewControllers] objectAtIndex:1] == self)
                    self.navigationItem.leftBarButtonItem = cancelButtonItem;
            } else {
                if ([[parent viewControllers] objectAtIndex:0] == self) {
                    self.navigationItem.leftBarButtonItem = cancelButtonItem;
                }
            }

        }
	}
    self.navigationItem.rightBarButtonItem = saveButtonItem;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return [super shouldAutorotateToInterfaceOrientation:interfaceOrientation];
}

- (void)didReceiveMemoryWarning {
    DDLogWarn(@"%@ %@", self, NSStringFromSelector(_cmd));
    [super didReceiveMemoryWarning]; // Releases the view if it doesn't have a superview
    // Release anything that's not essential, such as cached data
}


#pragma mark -
#pragma mark Instance Methods

- (void)clearUI {
    newCatNameField.text = @"";
    parentCatNameField.text = @"";
}

- (void)addProgressIndicator {
    UIActivityIndicatorView *aiv = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    UIBarButtonItem *activityButtonItem = [[UIBarButtonItem alloc] initWithCustomView:aiv];
	activityButtonItem.title = @"foobar!";
    [aiv startAnimating];
    
    self.navigationItem.rightBarButtonItem = activityButtonItem;
}

- (void)removeProgressIndicator {
	self.navigationItem.rightBarButtonItem = saveButtonItem;
	
}
- (void)dismiss {
    WPFLogMethod();
    if (IS_IPAD) {
        [(WPSelectionTableViewController *)self.parentViewController popViewControllerAnimated:YES];
    } else {
        [self.parentViewController dismissViewControllerAnimated:YES completion:nil];
    }
}

- (IBAction)cancelAddCategory:(id)sender {
    [self clearUI];
    [self dismiss];
}

- (IBAction)saveAddCategory:(id)sender {
    NSString *catName = newCatNameField.text;
    
    if (!catName ||[catName length] == 0) {
        UIAlertView *alert2 = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Category title missing.", @"Error popup title to indicate that there was no category title filled in.")
                                                         message:NSLocalizedString(@"Title for a category is mandatory.", @"Error popup message to indicate that there was no category title filled in.")
                                                        delegate:self cancelButtonTitle:NSLocalizedString(@"OK", @"") otherButtonTitles:nil];
        
        [alert2 show];
        WordPressAppDelegate *delegate = (WordPressAppDelegate*)[[UIApplication sharedApplication] delegate];
        [delegate setAlertRunning:YES];
        
        return;
    }
    
    if ([Category existsName:catName forBlog:self.blog withParentId:parentCat.categoryID]) {
        UIAlertView *alert2 = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Category name already exists.", @"Error popup title to show that a category already exists.")
                                                         message:NSLocalizedString(@"There is another category with that name.", @"Error popup message to show that a category already exists.")
                                                        delegate:self cancelButtonTitle:NSLocalizedString(@"OK", @"OK button label.") otherButtonTitles:nil];
		
        [alert2 show];
        WordPressAppDelegate *delegate = (WordPressAppDelegate*)[[UIApplication sharedApplication] delegate];
        [delegate setAlertRunning:YES];
        
        return;
    }
    
    [self addProgressIndicator];
    
    [Category createCategory:catName parent:parentCat forBlog:self.blog success:^(Category *category) {
        //re-syncs categories this is necessary because the server can change the name of the category!!!
		[self.blog syncCategoriesWithSuccess:nil failure:nil];
        [[NSNotificationCenter defaultCenter] postNotificationName:WPNewCategoryCreatedAndUpdatedInBlogNotificationName
                                                            object:self
                                                          userInfo:[NSDictionary dictionaryWithObject:category forKey:@"category"]];
        [self clearUI];
        [self removeProgressIndicator];
        [self dismiss];
    } failure:^(NSError *error) {
		[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
		[self removeProgressIndicator];
		
		if ([error code] == 403) {

			UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Couldn't Connect", @"")
																message:NSLocalizedString(@"The username or password stored in the app may be out of date. Please re-enter your password in the settings and try again.", @"")
															   delegate:nil
													  cancelButtonTitle:nil
													  otherButtonTitles:NSLocalizedString(@"OK", @""), nil];
			[alertView show];
			
			// bad login/pass combination
			EditSiteViewController *editSiteViewController = [[EditSiteViewController alloc] initWithBlog:self.blog];
			[self.navigationController pushViewController:editSiteViewController animated:YES];
			
		} else {
			NSDictionary *errInfo = [NSDictionary dictionaryWithObjectsAndKeys:self.blog, @"currentBlog", nil];
			[[NSNotificationCenter defaultCenter] postNotificationName:kXML_RPC_ERROR_OCCURS object:error userInfo:errInfo];
		}
    }];
}


#pragma mark - functionalmethods

- (void)selectionTableViewController:(WPSelectionTableViewController *)selctionController completedSelectionsWithContext:(void *)selContext selectedObjects:(NSArray *)selectedObjects haveChanges:(BOOL)isChanged {
    if (!isChanged) {
        [selctionController clean];
        return;
    }

    if (selContext == kParentCategoriesContext) {
        Category *curCat = [selectedObjects lastObject];

        if (parentCat) {
            parentCat = nil;
        }

        if (curCat) {
            parentCat = curCat;
            parentCatNameField.text = curCat.categoryName;
            [catTableView reloadData];
        }

    }

    [selctionController clean];
}


- (void)populateSelectionsControllerWithCategories {
    WPSelectionTableViewController *selectionTableViewController = [[WPSegmentedSelectionTableViewController alloc] initWithNibName:@"WPSelectionTableViewController" bundle:nil];

    NSArray *selObjs = ((parentCat == nil) ? [NSArray array] : [NSArray arrayWithObject:parentCat]);
    
	NSArray *cats = [self.blog sortedCategories];
	
	[selectionTableViewController populateDataSource:cats
     havingContext:kParentCategoriesContext
     selectedObjects:selObjs
     selectionType:kRadio
     andDelegate:self];

    selectionTableViewController.title = NSLocalizedString(@"Parent Category", @"");

    [self.navigationController pushViewController:selectionTableViewController animated:YES];
}

#pragma mark - tableviewDelegates/datasources

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        return newCatNameCell;
    } else {
        return parentCatNameCell;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:[tableView indexPathForSelectedRow] animated:YES];

    if (indexPath.section == 1) {
        [self populateSelectionsControllerWithCategories];
    }
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
}

#pragma mark textfied deletage

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}


#pragma mark -
#pragma mark UIAlertView Delegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    WordPressAppDelegate *delegate = (WordPressAppDelegate*)[[UIApplication sharedApplication] delegate];
    [delegate setAlertRunning:NO];
}

@end
