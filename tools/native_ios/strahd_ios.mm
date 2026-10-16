// iOS-only GDExtension. UIKit stays on the main queue; Godot polls completed events on its own thread.
#import <UIKit/UIKit.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/godot.hpp>
using namespace godot;

static NSMutableArray<NSDictionary *> *events;
static void event(NSString *kind, NSString *value) {
    @synchronized(events) { [events addObject:@{@"kind": kind, @"value": value ?: @""}]; }
}
static UIViewController *presenter() {
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (scene.activationState != UISceneActivationStateForegroundActive || ![scene isKindOfClass:UIWindowScene.class]) continue;
        for (UIWindow *window in ((UIWindowScene *)scene).windows) {
            if (!window.isKeyWindow) continue;
            UIViewController *vc = window.rootViewController;
            while (vc.presentedViewController) vc = vc.presentedViewController;
            return vc;
        }
    }
    return nil;
}
@interface StrahdDocumentDelegate : NSObject <UIDocumentPickerDelegate>
@property(nonatomic, copy) NSString *destination;
@property(nonatomic) BOOL busy;
@end
@implementation StrahdDocumentDelegate
- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
    self.busy = NO;
    event(@"file_cancelled", @"");
}
- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    self.busy = NO;
    NSURL *url = urls.firstObject;
    if (!url) { event(@"file_cancelled", @""); return; }
    BOOL access = [url startAccessingSecurityScopedResource];
    __block NSError *problem = nil;
    NSFileCoordinator *coordinator = [[NSFileCoordinator alloc] init];
    [coordinator coordinateReadingItemAtURL:url options:0 error:&problem byAccessor:^(NSURL *readURL) {
        NSNumber *size = nil;
        [readURL getResourceValue:&size forKey:NSURLFileSizeKey error:&problem];
        if (problem) return;
        if (size.unsignedLongLongValue > 16 * 1024 * 1024) {
            problem = [NSError errorWithDomain:@"StrahdFiles" code:1 userInfo:@{NSLocalizedDescriptionKey:@"This save is too large."}];
            return;
        }
        NSData *data = [NSData dataWithContentsOfURL:readURL options:0 error:&problem];
        if (data) [data writeToFile:self.destination options:NSDataWritingAtomic error:&problem];
    }];
    if (access) [url stopAccessingSecurityScopedResource];
    event(problem ? @"file_error" : @"file_imported", problem ? problem.localizedDescription : self.destination);
}
@end
static StrahdDocumentDelegate *documents;

@interface StrahdAccessibilityElement : UIAccessibilityElement
@property(nonatomic, copy) NSString *command;
@end
@implementation StrahdAccessibilityElement
- (BOOL)accessibilityActivate {
    if ((self.accessibilityTraits & UIAccessibilityTraitNotEnabled) != 0) return NO;
    event(@"access_activate", self.command);
    return YES;
}
- (void)accessibilityIncrement { event(@"access_increment", self.command); }
- (void)accessibilityDecrement { event(@"access_decrement", self.command); }
@end
@interface StrahdAccessibilityView : UIView
@property(nonatomic, copy) NSString *revision;
@end
@implementation StrahdAccessibilityView
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event { return nil; }
- (BOOL)accessibilityScroll:(UIAccessibilityScrollDirection)direction {
    if (direction != UIAccessibilityScrollDirectionUp && direction != UIAccessibilityScrollDirectionDown) return NO;
    event(@"access_scroll", [NSString stringWithFormat:@"%@:%@", self.revision, direction == UIAccessibilityScrollDirectionUp ? @"up" : @"down"]);
    return YES;
}
@end
static StrahdAccessibilityView *accessibilityView;
static NSMutableDictionary<NSString *, StrahdAccessibilityElement *> *accessibilityItems;
static NSArray<NSString *> *accessibilityOrder;


class StrahdIOS : public RefCounted {
    GDCLASS(StrahdIOS, RefCounted)
protected:
    static void _bind_methods() {
        ClassDB::bind_method(D_METHOD("take_events"), &StrahdIOS::take_events);
        ClassDB::bind_method(D_METHOD("import_save", "destination"), &StrahdIOS::import_save);
        ClassDB::bind_method(D_METHOD("share_save", "path"), &StrahdIOS::share_save);
        ClassDB::bind_method(D_METHOD("haptic"), &StrahdIOS::haptic);
        ClassDB::bind_method(D_METHOD("set_accessibility", "json"), &StrahdIOS::set_accessibility);
    }
public:
    String take_events() {
        NSData *json;
        @synchronized(events) {
            json = [NSJSONSerialization dataWithJSONObject:events options:0 error:nil];
            [events removeAllObjects];
        }
        return String::utf8([[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding].UTF8String);
    }
    void import_save(String destination) {
        NSString *path = [NSString stringWithUTF8String:destination.utf8().get_data()];
        dispatch_async(dispatch_get_main_queue(), ^{
            UIViewController *vc = presenter();
            if (!vc || documents.busy) { event(@"file_error", @"Another system window is open. Close it and try again."); return; }
            documents.busy = YES;
            accessibilityView.hidden = YES;
            documents.destination = path;
            UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[UTTypeJSON] asCopy:YES];
            picker.allowsMultipleSelection = NO;
            picker.delegate = documents;
            [vc presentViewController:picker animated:YES completion:nil];
        });
    }
    void share_save(String source) {
        NSString *path = [NSString stringWithUTF8String:source.utf8().get_data()];
        dispatch_async(dispatch_get_main_queue(), ^{
            UIViewController *vc = presenter();
            if (!vc || documents.busy) { event(@"file_error", @"Another system window is open. Close it and try again."); return; }
            documents.busy = YES;
            accessibilityView.hidden = YES;
            UIActivityViewController *sheet = [[UIActivityViewController alloc] initWithActivityItems:@[[NSURL fileURLWithPath:path]] applicationActivities:nil];
            sheet.completionWithItemsHandler = ^(UIActivityType type, BOOL completed, NSArray *items, NSError *error) {
                documents.busy = NO;
                event(error ? @"file_error" : completed ? @"file_shared" : @"file_cancelled", error.localizedDescription);
            };
            sheet.popoverPresentationController.sourceView = vc.view;
            sheet.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(vc.view.bounds), CGRectGetMidY(vc.view.bounds), 1, 1);
            [vc presentViewController:sheet animated:YES completion:nil];
        });
    }
    void set_accessibility(String json) {
        NSData *data = [[NSString stringWithUTF8String:json.utf8().get_data()] dataUsingEncoding:NSUTF8StringEncoding];
        dispatch_async(dispatch_get_main_queue(), ^{
            NSDictionary *snapshot = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            UIViewController *vc = presenter();
            if (!snapshot || !vc || documents.busy) return;
            while (vc.presentingViewController) vc = vc.presentingViewController;
            UIView *container = vc.view.window;
            if (!container) return;
            if (!accessibilityView || accessibilityView.superview != container) {
                [accessibilityView removeFromSuperview];
                accessibilityView = [[StrahdAccessibilityView alloc] initWithFrame:container.bounds];
                accessibilityView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
                accessibilityView.isAccessibilityElement = NO;
                [container addSubview:accessibilityView];
                accessibilityItems = [NSMutableDictionary dictionary];
            }
            accessibilityView.hidden = NO;
            accessibilityView.revision = snapshot[@"revision"];
            NSMutableArray *order = [NSMutableArray array];
            NSMutableArray *elements = [NSMutableArray array];
            NSMutableDictionary *next = [NSMutableDictionary dictionary];
            for (NSDictionary *item in snapshot[@"items"]) {
                NSString *key = [item[@"id"] description];
                StrahdAccessibilityElement *element = accessibilityItems[key];
                if (!element) element = [[StrahdAccessibilityElement alloc] initWithAccessibilityContainer:accessibilityView];
                element.command = [NSString stringWithFormat:@"%@:%@", snapshot[@"revision"], key];
                element.accessibilityIdentifier = key;
                element.accessibilityLabel = item[@"label"];
                element.accessibilityValue = item[@"value"];
                element.accessibilityHint = item[@"hint"];
                NSString *role = item[@"role"];
                UIAccessibilityTraits traits = UIAccessibilityTraitStaticText;
                if ([role isEqualToString:@"button"] || [role isEqualToString:@"input"]) traits = UIAccessibilityTraitButton;
                if ([role isEqualToString:@"slider"]) traits = UIAccessibilityTraitAdjustable;
                if ([item[@"disabled"] boolValue]) traits |= UIAccessibilityTraitNotEnabled;
                if ([item[@"selected"] boolValue]) traits |= UIAccessibilityTraitSelected;
                element.accessibilityTraits = traits;
                NSArray *frame = item[@"frame"];
                CGRect bounds = accessibilityView.bounds;
                element.accessibilityFrameInContainerSpace = CGRectMake([frame[0] doubleValue] * bounds.size.width,
                    [frame[1] doubleValue] * bounds.size.height, [frame[2] doubleValue] * bounds.size.width,
                    [frame[3] doubleValue] * bounds.size.height);
                [elements addObject:element];
                [order addObject:key];
                next[key] = element;
            }
            BOOL changed = ![accessibilityOrder isEqualToArray:order];
            accessibilityOrder = order;
            accessibilityItems = next;
            accessibilityView.accessibilityElements = elements;
            if (changed && UIAccessibilityIsVoiceOverRunning()) UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, nil);
        });
    }
    void haptic() {
        dispatch_async(dispatch_get_main_queue(), ^{ [[[UISelectionFeedbackGenerator alloc] init] selectionChanged]; });
    }
};
static void initialize(ModuleInitializationLevel level) {
    if (level != MODULE_INITIALIZATION_LEVEL_SCENE) return;
    events = [NSMutableArray array];
    documents = [[StrahdDocumentDelegate alloc] init];
    GDREGISTER_CLASS(StrahdIOS);
}
static void terminate(ModuleInitializationLevel level) {}
extern "C" GDExtensionBool GDE_EXPORT strahd_ios_init(GDExtensionInterfaceGetProcAddress address, GDExtensionClassLibraryPtr library, GDExtensionInitialization *initialization) {
    GDExtensionBinding::InitObject init(address, library, initialization);
    init.register_initializer(initialize);
    init.register_terminator(terminate);
    init.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
    return init.init();
}
