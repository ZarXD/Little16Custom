#import <UIKit/UIKit.h>
#include <dlfcn.h>
#include <stdio.h>
#include <unistd.h>

// ============================================================
// Preferences
// ============================================================

static NSString *const kPrefsID = @"com.michaelmelita1.little16";
static NSString *const kNotification = @"com.michaelmelita1.little16/prefsUpdated";

static BOOL enabled = YES;
static NSInteger statusBarStyle = 1;      // 0 = Legacy, 1 = iPad, 2 = iPhone X (split: time left, indicators right), 3 = Rounded iPad
static NSInteger dockStyle = 1;           // 0 = Legacy, 1 = iPad (floating)
static NSInteger ccPosition = 3;          // 3 = Top Right (status bar), 1 = Bottom Right, 2 = Bottom Left, 0 = Disabled
static BOOL hideDockBackground = NO;
static BOOL enableRecents = YES;
static BOOL removeAppLibrary = NO;
static BOOL enableQuickActions = YES;
static CGFloat roundedAppSwitcherRadius = 0;  // 0 = off
static CGFloat roundedDockRecentsRadius = 0;  // 0 = off
static BOOL showHomeBar = NO;

#define MAX_DOCK_ICONS 4
#define MAX_RECENTS 3

static id PrefValue(NSString *key) {
    return (__bridge_transfer id)CFPreferencesCopyAppValue((__bridge CFStringRef)key, (__bridge CFStringRef)kPrefsID);
}

static void loadPreferences(void) {
    @autoreleasepool {
        CFPreferencesAppSynchronize((__bridge CFStringRef)kPrefsID);

        id v = PrefValue(@"enabled"); if (v) enabled = [v boolValue];
        v = PrefValue(@"statusBarStyle"); if (v) statusBarStyle = [v integerValue];
        v = PrefValue(@"dockStyle"); if (v) dockStyle = [v integerValue];
        v = PrefValue(@"ccPosition"); if (v) ccPosition = [v integerValue];
        v = PrefValue(@"hideDockBackground"); if (v) hideDockBackground = [v boolValue];
        v = PrefValue(@"enableRecents"); if (v) enableRecents = [v boolValue];
        v = PrefValue(@"removeAppLibrary"); if (v) removeAppLibrary = [v boolValue];
        v = PrefValue(@"enableQuickActions"); if (v) enableQuickActions = [v boolValue];
        v = PrefValue(@"roundedAppSwitcher");
        if ([v isKindOfClass:NSNumber.class]) roundedAppSwitcherRadius = [v floatValue];
        else if (v) roundedAppSwitcherRadius = [v boolValue] ? 14.0 : 0.0;
        v = PrefValue(@"roundedDockRecents");
        if ([v isKindOfClass:NSNumber.class]) roundedDockRecentsRadius = [v floatValue];
        else if (v) roundedDockRecentsRadius = [v boolValue] ? 14.0 : 0.0;
        v = PrefValue(@"showHomeBar"); if (v) showHomeBar = [v boolValue];
    }
}

// ============================================================
// Helpers
// ============================================================

static BOOL ViewContainsClass(UIView *view, Class targetClass, int depth) {
    if (!view || depth > 20) return NO;
    if ([view isKindOfClass:targetClass]) return YES;
    for (UIView *sub in view.subviews) {
        if (ViewContainsClass(sub, targetClass, depth + 1)) return YES;
    }
    return NO;
}

static void RoundIconsInView(UIView *view, CGFloat radius) {
    if (radius <= 0.5) return;
    for (UIView *sub in view.subviews) {
        if ([sub isKindOfClass:NSClassFromString(@"SBIconView")] ||
            [sub isKindOfClass:NSClassFromString(@"SBIconImageView")]) {
            sub.layer.cornerRadius = radius;
            sub.layer.masksToBounds = YES;
            sub.clipsToBounds = YES;
        }
        RoundIconsInView(sub, radius);
    }
}

// ============================================================
// Core: home gestures + home indicator
// ============================================================

%group Core

%hook SBHomeGestureSettings
- (bool)isHomeGestureEnabled {
    return 1;
}
%end

%hook SBFHomeGrabberSettings
- (BOOL)isEnabled {
    return showHomeBar;
}

- (void)setEnabled:(BOOL)arg1 {
    %orig(showHomeBar);
}
%end

%end

// ============================================================
// Status Bar
// ============================================================

static void L16DBG(NSString *fmt, ...);

%group StatusBarPad

%hook _UIStatusBarVisualProvider_iOS
+ (Class)class {
    return %c(_UIStatusBarVisualProvider_Pad_ForcedCellular);
}
%end

%end

// Rounded iPad style (exists on iOS 16; used by LittleXS for round-corner screens)
%group StatusBarRoundedPad

%hook _UIStatusBarVisualProvider_iOS
+ (Class)class {
    return %c(_UIStatusBarVisualProvider_RoundedPad_ForcedCellular);
}
%end

%end

// ============================================================
// iPhone X style: white "split" status bar look — time stays on
// the LEFT, all other indicators (cellular, wifi, battery) are
// pushed to the RIGHT. iOS16 removed the split providers, so we
// do view-layout instead of provider swap (no rdar red bar).
// ============================================================

@interface _UIStatusBar : UIView
@end

@interface _UIStatusBarForegroundView : UIView
@end

static UIView *L16FindClassInView(UIView *root, NSString *klass, int depth) {
    if (!root || depth > 8) return nil;
    if ([root isKindOfClass:NSClassFromString(klass)]) return root;
    for (UIView *sub in root.subviews) {
        UIView *found = L16FindClassInView(sub, klass, depth + 1);
        if (found) return found;
    }
    return nil;
}

static void L16PlaceXRight(CGFloat *xEdge, UIView *v, UIView *root, CGFloat gap) {
    if (!v || !v.superview) return;
    CGRect fr = [v.superview convertRect:v.frame toView:root];
    *xEdge -= fr.size.width;
    fr.origin.x = *xEdge;
    v.frame = [root convertRect:fr toView:v.superview];
    *xEdge -= gap;
}

static void L16DumpViewTree(UIView *root, int depth) {
    if (!root || depth > 5) return;
    NSMutableString *pad = [NSMutableString string];
    for (int i = 0; i < depth; i++) [pad appendString:@"  "];
    L16DBG(@"%@%@", pad, NSStringFromClass([root class]));
    for (UIView *sub in root.subviews) L16DumpViewTree(sub, depth + 1);
}

static int L16SplitLogCount = 0;
static void L16LogItemFrames(UIView *root, NSString *tag) {
    if (L16SplitLogCount >= 30) return;
    L16SplitLogCount++;
    NSMutableString *s = [NSMutableString string];
    for (UIView *v in root.subviews) {
        if ([v isKindOfClass:NSClassFromString(@"_UIStatusBarCellularSignalView")] ||
            [v isKindOfClass:NSClassFromString(@"_UIStatusBarWifiSignalView")] ||
            [v isKindOfClass:NSClassFromString(@"_UIStaticBatteryView")] ||
            [v isKindOfClass:NSClassFromString(@"_UIStatusBarStringView")]) {
            [s appendFormat:@"%@=%.0f,%.0f %.0fx%.0f | ",
                NSStringFromClass([v class]), v.frame.origin.x, v.frame.origin.y,
                v.frame.size.width, v.frame.size.height];
        }
    }
    L16DBG(@"FG[%@] %@", tag, s);
}

static void L16LayoutSplit(UIView *root) {
    CGFloat W = root.bounds.size.width;
    if (W <= 0) return;

    UIView *batt = L16FindClassInView(root, @"_UIStaticBatteryView", 0);
    UIView *wifi = L16FindClassInView(root, @"_UIStatusBarWifiSignalView", 0);
    UIView *cell = L16FindClassInView(root, @"_UIStatusBarCellularSignalView", 0);

    // Right "ear": battery far right, wifi left of it, cellular left of wifi.
    CGFloat x = W - 6.0;
    CGFloat gap = 4.0;
    L16PlaceXRight(&x, batt, root, gap);
    L16PlaceXRight(&x, wifi, root, gap);
    L16PlaceXRight(&x, cell, root, gap);

    // Everything else stacks from the far left (time + any extra items),
    // so new items can't pile up at (0,0) since %orig is skipped here.
    CGFloat lx = 7.0;
    NSArray *subs = [root.subviews copy];
    for (UIView *v in subs) {
        if (v == batt || v == wifi || v == cell) continue;
        if (!v.superview) continue;
        CGRect fr = [v.superview convertRect:v.frame toView:root];
        fr.origin.x = lx;
        v.frame = [root convertRect:fr toView:v.superview];
        lx += fr.size.width;
    }
}

%group StatusBarModern

%hook _UIStatusBarForegroundView
- (void)layoutSubviews {
    static BOOL dumped = NO;
    if (!dumped) {
        dumped = YES;
        L16DBG(@"--- status bar tree ---");
        L16DumpViewTree(self, 0);
        L16DBG(@"--- end tree ---");
    }

    L16LogItemFrames(self, @"pre");
    L16LayoutSplit(self);
    L16LogItemFrames(self, @"post");
}
%end

%end

// ============================================================
// Dock (iPad / floating)
// ============================================================

#pragma mark Dock interfaces

@interface SBIconListGridLayoutConfiguration : NSObject
@property (nonatomic) unsigned long long numberOfPortraitRows;
@property (nonatomic) unsigned long long numberOfPortraitColumns;
@end

@interface SBIconListView : UIView
@property (nonatomic, strong) NSString *iconLocation;
@end

@interface SBBestAppSuggestion : NSObject
- (BOOL)isHandoff;
@end

@interface SBFloatingDockSuggestionsModel : NSObject
@property (nonatomic, readonly) SBBestAppSuggestion *currentAppSuggestion;
- (BOOL)_shouldProcessAppSuggestion:(id)arg1;
- (void)_setRecentsEnabled:(BOOL)arg1;
-(unsigned long long)maxSuggestions;
@end

@interface SBFloatingDockSuggestionsViewController : UIViewController
@end

@interface SBFloatingDockController : NSObject
+ (BOOL)isFloatingDockSupported;
@end

@interface SBFloatingDockDefaults : NSObject
- (void)setRecentsEnabled:(BOOL)arg1;
- (BOOL)recentsEnabled;
- (void)setAppLibraryEnabled:(BOOL)arg1;
- (BOOL)appLibraryEnabled;
@end

%group DockiPad

%hook SBFloatingDockController
+ (BOOL)isFloatingDockSupported {
    return YES;
}
- (void)_configureFloatingDockBehaviorAssertionForOpenFolder:(id)arg1 atLevel:(NSUInteger)arg2 {
}
%end

%hook SBFloatingDockDefaults
- (void)setRecentsEnabled:(BOOL)arg1 {
    %orig(enableRecents);
}
- (BOOL)recentsEnabled {
    return enableRecents;
}
- (void)setAppLibraryEnabled:(BOOL)arg1 {
    %orig(!removeAppLibrary);
}
- (BOOL)appLibraryEnabled {
    return !removeAppLibrary;
}
%end

%hook SBIconListGridLayoutConfiguration
- (unsigned long long)numberOfPortraitColumns {
    unsigned long long o = %orig;
    if ([self numberOfPortraitRows] == 1 && o == 4) {
        return MAX_DOCK_ICONS;
    }
    return o;
}
%end

%hook SBIconListView
- (unsigned long long)maximumIconCount {
    if ([self.iconLocation isEqual:@"SBIconLocationDock"]) {
        return MAX_DOCK_ICONS;
    }
    return %orig;
}
%end

%hook SBFloatingDockSuggestionsModel
- (BOOL)recentDisplayItemsController:(id)arg1 shouldAddItem:(id)arg2 {
    if ([self.currentAppSuggestion isHandoff]) return NO;
    return %orig;
}

// iOS 16
- (id)initWithMaximumNumberOfSuggestions:(NSUInteger)arg1 iconController:(id)arg2 recentsController:(id)arg3 recentsDataStore:(id)arg4 recentsDefaults:(id)arg5 floatingDockDefaults:(id)arg6 appSuggestionManager:(id)arg7 applicationController:(id)arg8 {
    return %orig(MAX_RECENTS, arg2, arg3, arg4, arg5, arg6, arg7, arg8);
}

// iOS 15
- (id)initWithMaximumNumberOfSuggestions:(unsigned long long)arg1 iconController:(id)arg2 recentsController:(id)arg3 recentsDataStore:(id)arg4 recentsDefaults:(id)arg5 floatingDockDefaults:(id)arg6 appSuggestionManager:(id)arg7 analyticsClient:(id)arg8 applicationController:(id)arg9 {
    return %orig(MAX_RECENTS, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9);
}

- (unsigned long long)maxSuggestions {
    return MAX_RECENTS;
}
%end

%hook SBFloatingDockSuggestionsViewController
- (id)initWithNumberOfRecents:(unsigned long long)arg1 iconController:(id)arg2 applicationController:(id)arg3 layoutStateTransitionCoordinator:(id)arg4 suggestionsModel:(id)arg5 iconViewProvider:(id)arg6 {
    return %orig(MAX_RECENTS, arg2, arg3, arg4, arg5, arg6);
}
%end

%end

%group NoRecents

%hook SBFloatingDockSuggestionsModel
- (BOOL)_shouldProcessAppSuggestion:(id)arg1 {
    return NO;
}

- (void)_setRecentsEnabled:(BOOL)arg1 {
    %orig(NO);
}
%end

%end

// ============================================================
// Dock background (hide)
// ============================================================

@interface SBFloatingDockPlatterView : UIView
@property (nonatomic, strong) UIView *backgroundView;
@end

%group DockPlatter

%hook SBFloatingDockPlatterView
- (void)setBackgroundView:(UIView *)arg1 {
    %orig;
    if (hideDockBackground) {
        self.backgroundView.hidden = YES;
    }
}
%end

%end

// ============================================================
// Rounded dock recents
// ============================================================

@interface SBFloatingDockSuggestionsView : UIView
@end

%group RoundedRecents

%hook SBFloatingDockSuggestionsView
- (void)layoutSubviews {
    %orig;
    RoundIconsInView(self, roundedDockRecentsRadius);
}
%end

%end

// ============================================================
// Control Center
// ============================================================

%group CCHomeGesture

%hook CCSControlCenterDefaults
- (unsigned long long)_defaultPresentationGesture {
    return 1;
}
%end

%end

%group CCBottomRight

%hook SBControlCenterController
- (unsigned long long)presentingEdge {
    return 1;
}
%end

%end

%group CCBottomLeft

%hook SBControlCenterController
- (unsigned long long)presentingEdge {
    return 2;
}
%end

%end

%group CCDisabled

%hook CCSControlCenterDefaults
- (unsigned long long)_defaultPresentationGesture {
    return 0;
}
%end

%end

// ============================================================
// Lock screen quick actions
// ============================================================

@interface CSQuickActionsView : UIView
- (UIEdgeInsets)_buttonOutsets;
@property (nonatomic, strong) UIControl *flashlightButton;
@property (nonatomic, strong) UIControl *cameraButton;
@end

@interface CSQuickActionsViewController : NSObject
@end

@interface NCNotificationListView : UIView
@end

@interface CSFullscreenNotificationView : UIView
@end

%group QuickActions

%hook UIWindow
- (UIEdgeInsets)safeAreaInsets {
    UIEdgeInsets orig = %orig;
    if (orig.bottom <= 0.0) {
        Class qaCls = NSClassFromString(@"CSQuickActionsButton");
        if (qaCls && ViewContainsClass(self, qaCls, 0)) {
            orig.bottom = 20;
        }
    }
    return orig;
}
%end

%hook CSQuickActionsView
- (BOOL)wantsQuickActions {
    return YES;
}

- (BOOL)_prototypingAllowsButtons {
    return YES;
}

- (void)_layoutQuickActionButtons {
    CGRect const screenBounds = [UIScreen mainScreen].bounds;
    CGFloat const y = screenBounds.size.height - 90 - [self _buttonOutsets].top;
    [self flashlightButton].frame = CGRectMake(46, y, 50, 50);
    [self cameraButton].frame = CGRectMake(screenBounds.size.width - 96, y, 50, 50);
}
%end

%hook CSQuickActionsViewController
+ (BOOL)deviceSupportsButtons {
    return YES;
}
- (BOOL)hasCamera { return YES; }
- (BOOL)hasFlashlight { return YES; }
%end

%hook NCNotificationListView
- (void)setFrame:(CGRect)frame {
    if ([[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion){16, 0, 0}]) {
        frame = CGRectMake(0, -100, frame.size.width, frame.size.height);
    }
    %orig(frame);
}
%end

%hook CSFullscreenNotificationView
- (void)setFrame:(CGRect)frame {
    frame = CGRectMake(0, -50, frame.size.width, frame.size.height);
    %orig(frame);
}
%end

%end

// ============================================================
// Rounded app switcher
// ============================================================

%group RoundedSwitcher

%hook SBFluidSwitcherViewController
- (double)displayCornerRadius {
    return roundedAppSwitcherRadius;
}
%end

%end

// ============================================================
// Constructor
// ============================================================

static void L16DBG(NSString *fmt, ...) {
    va_list args;
    va_start(args, fmt);
    NSString *msg = [[NSString alloc] initWithFormat:fmt arguments:args];
    va_end(args);
    NSString *tmp = NSTemporaryDirectory();
    NSString *line = [NSString stringWithFormat:@"[L16T:%d] %@\n", getpid(), msg];
    NSString *paths[] = {
        @"/tmp/little16tweak.log",
        [NSString stringWithFormat:@"%@little16tweak.log", tmp ?: @""],
        [NSString stringWithFormat:@"%@/little16tweak.log", NSHomeDirectory() ?: @""],
    };
    for (int i = 0; i < 3; i++) {
        FILE *f = fopen([paths[i] UTF8String], "ab");
        if (f) { fputs([line UTF8String], f); fclose(f); }
    }
    NSLog(@"L16Tweak: %@", msg);
}

%group Diagnostics

%hookf(void *, dlopen, const char *path, int mode) {
    void *h = %orig(path, mode);
    if (path != NULL && (strstr(path, "Little16") || strstr(path, "PreferenceBundles"))) {
        L16DBG(@"dlopen(%s) -> %p err=%s", path, h, dlerror());
    }
    return h;
}

%end

%ctor {
    @autoreleasepool {
        L16DBG(@"ctor in %@ pid=%d", [[NSBundle mainBundle] bundleIdentifier], getpid());
        L16DBG(@"providers: S58=%d S61=%d PAD=%d RPAD=%d", 
            NSClassFromString(@"_UIStatusBarVisualProvider_Split58") != nil,
            NSClassFromString(@"_UIStatusBarVisualProvider_Split61") != nil,
            NSClassFromString(@"_UIStatusBarVisualProvider_Pad_ForcedCellular") != nil,
            NSClassFromString(@"_UIStatusBarVisualProvider_RoundedPad_ForcedCellular") != nil);
        loadPreferences();
        %init(Diagnostics);

        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL,
            (CFNotificationCallback)loadPreferences, (CFStringRef)kNotification, NULL,
            CFNotificationSuspensionBehaviorCoalesce);

        if (!enabled) return;

        %init(Core);

        if (statusBarStyle == 1) %init(StatusBarPad);
        else if (statusBarStyle == 2) %init(StatusBarModern);
        else if (statusBarStyle == 3) %init(StatusBarRoundedPad);

        if (dockStyle == 1) {
            %init(DockiPad);
            if (!enableRecents) %init(NoRecents);
            if (hideDockBackground) %init(DockPlatter);
            if (roundedDockRecentsRadius > 0.5) %init(RoundedRecents);
        }

        if (enableQuickActions) %init(QuickActions);
        if (roundedAppSwitcherRadius > 0.5) %init(RoundedSwitcher);

        if (ccPosition == 0) {
            %init(CCDisabled);
        } else {
            %init(CCHomeGesture);
            if (ccPosition == 1 || ccPosition == 3) %init(CCBottomRight);
            if (ccPosition == 2) %init(CCBottomLeft);
        }
    }
}