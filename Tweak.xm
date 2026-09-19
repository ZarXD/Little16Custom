#import <UIKit/UIKit.h>
#import <objc/runtime.h>
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
// iPhone X style: split status bar look via UIKit preference
// override (RdarFix approach from bvnrepo.xyz).
//
// Writes UIStatusBarVisualProviderClassName =
// _UIStatusBarVisualProvider_Split1170 into com.apple.UIKit
// preferences. This tells UIKit to use a split provider
// (time left, indicators right) WITHOUT changing the screen
// resolution → no rdar:45025538 red bar.
// ============================================================

static NSString *const kUIKitDomain = @"com.apple.UIKit";
static NSString *const kProviderKey = @"UIStatusBarVisualProviderClassName";
static NSString *const kSplitProvider = @"_UIStatusBarVisualProvider_Split1242";

static void L16EnsureSplitProvider(void) {
    CFStringRef current = (CFStringRef)CFPreferencesCopyAppValue(
        (__bridge CFStringRef)kProviderKey,
        (__bridge CFStringRef)kUIKitDomain);

    BOOL needsWrite = YES;
    if (current) {
        if (CFGetTypeID(current) == CFStringGetTypeID() &&
            CFStringCompare(current, (__bridge CFStringRef)kSplitProvider, 0) == kCFCompareEqualTo) {
            needsWrite = NO;
        }
        CFRelease(current);
    }

    if (needsWrite) {
        L16DBG(@"Writing %@ = %@ into %@", kProviderKey, kSplitProvider, kUIKitDomain);
        CFPreferencesSetAppValue(
            (__bridge CFStringRef)kProviderKey,
            (__bridge CFStringRef)kSplitProvider,
            (__bridge CFStringRef)kUIKitDomain);
        CFPreferencesAppSynchronize((__bridge CFStringRef)kUIKitDomain);
    } else {
        L16DBG(@"Split provider already set, skipping write");
    }
}

static void L16RemoveSplitProvider(void) {
    CFStringRef current = (CFStringRef)CFPreferencesCopyAppValue(
        (__bridge CFStringRef)kProviderKey,
        (__bridge CFStringRef)kUIKitDomain);

    if (current) {
        if (CFGetTypeID(current) == CFStringGetTypeID()) {
            NSString *str = (__bridge NSString *)current;
            if ([str hasPrefix:@"_UIStatusBarVisualProvider_Split"]) {
                L16DBG(@"Removing %@ (%@) from %@", kProviderKey, str, kUIKitDomain);
                CFPreferencesSetAppValue(
                    (__bridge CFStringRef)kProviderKey,
                    NULL,
                    (__bridge CFStringRef)kUIKitDomain);
                CFPreferencesAppSynchronize((__bridge CFStringRef)kUIKitDomain);
            }
        }
        CFRelease(current);
    }
}

// ============================================================
// ============================================================
// iPhone X split status bar layout fix for iPhone 8 Plus:
// 1. Insets: leading=14.0 (clean 15pt margin for clock),
//    trailing=-39.0 (battery ends at 399pt, 15pt right margin),
//    leading=0.0 on trailing ear (expands trailing region width).
// 2. Fonts: Split provider clockFont returns 15.5pt bold.
//    _UIStatusBarStringView enforces 15.5pt bold + sizeToFit.
// 3. Spacing & No Overlap: itemSpacing returns 5.0pt.
//    _UIStatusBarForegroundView layoutSubviews guarantees:
//    - Clock at x=15.0, 15.5pt bold
//    - Battery anchored at W - 15.0 - width (hidden=NO, alpha=1.0)
//    - Trailing icons (WiFi, Cellular) laid out sequentially
//      with exact 5.0pt spacing (hidden=NO, alpha=1.0)
//    - ZERO overlapping, ZERO missing icons.
// ============================================================

@interface _UIStatusBarVisualProvider_FixedSplit : NSObject
- (NSDirectionalEdgeInsets)leadingEdgeInsets;
- (NSDirectionalEdgeInsets)trailingEdgeInsets;
@end

@interface _UIStatusBarVisualProvider_Split : NSObject
- (UIFont *)clockFont;
- (CGFloat)itemSpacing;
@end

@interface _UIStatusBarVisualProvider_Split1242 : _UIStatusBarVisualProvider_FixedSplit
- (CGFloat)itemSpacing;
@end

@interface _UIStatusBarStringView : UILabel
- (BOOL)_l16IsTimeString:(NSString *)txt;
- (void)_l16ApplyTimeFontIfNeeded;
@end

@interface _UIStatusBarForegroundView : UIView
@end

%group StatusBarSplitFix

%hook _UIStatusBarVisualProvider_Split

- (UIFont *)clockFont {
    return [UIFont boldSystemFontOfSize:15.5];
}

- (CGFloat)itemSpacing {
    return 5.0;
}

%end

%hook _UIStatusBarVisualProvider_Split1242

- (CGFloat)itemSpacing {
    return 5.0;
}

%end

%hook _UIStatusBarVisualProvider_FixedSplit

- (NSDirectionalEdgeInsets)leadingEdgeInsets {
    NSDirectionalEdgeInsets insets = %orig;
    insets.leading = 14.0;
    L16DBG(@"leadingEdgeInsets: new.lead=%.1f (top=%.1f)", insets.leading, insets.top);
    return insets;
}

- (NSDirectionalEdgeInsets)trailingEdgeInsets {
    NSDirectionalEdgeInsets insets = %orig;
    insets.trailing = -39.0;
    insets.leading = 0.0;
    L16DBG(@"trailingEdgeInsets: new.trail=%.1f lead=%.1f (top=%.1f)", insets.trailing, insets.leading, insets.top);
    return insets;
}

%end

%hook _UIStatusBarStringView

- (void)didMoveToWindow {
    %orig;
    [self _l16ApplyTimeFontIfNeeded];
}

- (void)setText:(NSString *)text {
    %orig(text);
    [self _l16ApplyTimeFontIfNeeded];
}

- (void)setFont:(UIFont *)font {
    NSString *txt = ((UILabel *)self).text;
    if (txt && [self _l16IsTimeString:txt]) {
        %orig([UIFont boldSystemFontOfSize:15.5]);
        return;
    }
    %orig(font);
}

%new
- (BOOL)_l16IsTimeString:(NSString *)txt {
    if (!txt || txt.length < 3 || txt.length > 8) return NO;
    if (!([txt containsString:@":"] || [txt containsString:@"."])) return NO;
    unichar first = [txt characterAtIndex:0];
    return (first >= '0' && first <= '9');
}

%new
- (void)_l16ApplyTimeFontIfNeeded {
    UILabel *lbl = (UILabel *)self;
    NSString *txt = lbl.text;
    if ([self _l16IsTimeString:txt]) {
        lbl.font = [UIFont boldSystemFontOfSize:15.5];
        [lbl sizeToFit];
    }
}

%end

%hook _UIStatusBarForegroundView

- (void)layoutSubviews {
    %orig;

    CGFloat W = self.bounds.size.width;
    if (W < 300.0) return;

    // 1. Time view
    for (UIView *sub in self.subviews) {
        if ([sub isKindOfClass:NSClassFromString(@"_UIStatusBarStringView")]) {
            UILabel *lbl = (UILabel *)sub;
            NSString *txt = lbl.text;
            if (txt && [txt length] >= 3 && [txt length] <= 8 &&
                ([txt containsString:@":"] || [txt containsString:@"."]) &&
                [txt characterAtIndex:0] >= '0' && [txt characterAtIndex:0] <= '9') {
                lbl.font = [UIFont boldSystemFontOfSize:15.5];
                [lbl sizeToFit];
                CGRect tf = lbl.frame;
                tf.origin.x = 15.0;
                lbl.frame = tf;
                lbl.hidden = NO;
                lbl.alpha = 1.0;
            }
        }
    }

    // 2. Find battery view
    UIView *batt = nil;
    for (UIView *sub in self.subviews) {
        if ([NSStringFromClass([sub class]) containsString:@"Battery"]) {
            batt = sub;
            break;
        }
    }

    // 3. Find other trailing icon views (wifi, cellular, etc.)
    NSMutableArray<UIView *> *trailingIcons = [NSMutableArray array];
    for (UIView *sub in self.subviews) {
        if (sub == batt) continue;
        BOOL isIconClass = [sub isKindOfClass:[UIImageView class]] ||
            [NSStringFromClass([sub class]) containsString:@"Image"] ||
            [NSStringFromClass([sub class]) containsString:@"Signal"] ||
            [NSStringFromClass([sub class]) containsString:@"Wifi"] ||
            [NSStringFromClass([sub class]) containsString:@"Cellular"];
        if (isIconClass) {
            BOOL hasContent = NO;
            if ([sub respondsToSelector:@selector(image)]) {
                UIImage *img = [(UIImageView *)sub image];
                if (img != nil) hasContent = YES;
            } else if ([NSStringFromClass([sub class]) containsString:@"Signal"] ||
                       [NSStringFromClass([sub class]) containsString:@"Cellular"] ||
                       [NSStringFromClass([sub class]) containsString:@"Wifi"]) {
                hasContent = YES;
            }
            if (hasContent && sub.frame.origin.x > W * 0.4) {
                if (sub.frame.size.width == 0) [sub sizeToFit];
                if (sub.frame.size.width > 0) {
                    [trailingIcons addObject:sub];
                }
            }
        }
    }

    // Sort trailing icons from left to right by their current X position
    [trailingIcons sortUsingComparator:^NSComparisonResult(UIView *a, UIView *b) {
        if (a.frame.origin.x < b.frame.origin.x) return NSOrderedAscending;
        if (a.frame.origin.x > b.frame.origin.x) return NSOrderedDescending;
        return NSOrderedSame;
    }];

    // 4. Position battery at far right (15pt margin from screen right edge)
    CGFloat currentRight = W - 15.0;
    if (batt) {
        CGRect bf = batt.frame;
        bf.origin.x = currentRight - bf.size.width;
        batt.frame = bf;
        batt.hidden = NO;
        batt.alpha = 1.0;
        currentRight = bf.origin.x - 5.0;
    }

    // 5. Position other trailing icons sequentially from right to left (wifi, cellular, etc.)
    for (NSInteger i = (NSInteger)trailingIcons.count - 1; i >= 0; i--) {
        UIView *icon = trailingIcons[i];
        CGRect f = icon.frame;
        f.origin.x = currentRight - f.size.width;
        icon.frame = f;
        icon.hidden = NO;
        icon.alpha = 1.0;
        currentRight = f.origin.x - 5.0;
    }
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
        L16DBG(@"providers: S58=%d S61=%d PAD=%d RPAD=%d S1170=%d", 
            NSClassFromString(@"_UIStatusBarVisualProvider_Split58") != nil,
            NSClassFromString(@"_UIStatusBarVisualProvider_Split61") != nil,
            NSClassFromString(@"_UIStatusBarVisualProvider_Pad_ForcedCellular") != nil,
            NSClassFromString(@"_UIStatusBarVisualProvider_RoundedPad_ForcedCellular") != nil,
            NSClassFromString(@"_UIStatusBarVisualProvider_Split1170") != nil);
        Class cls = NSClassFromString(kSplitProvider);
        while (cls && cls != [NSObject class]) {
            L16DBG(@"=== Class %@ (super %@) ===", NSStringFromClass(cls), NSStringFromClass(class_getSuperclass(cls)));
            Class metaCls = object_getClass((id)cls);
            unsigned int mcount = 0;
            Method *methods = class_copyMethodList(metaCls, &mcount);
            for (unsigned int i = 0; i < mcount; i++) {
                SEL sel = method_getName(methods[i]);
                const char *name = sel_getName(sel);
                L16DBG(@"class method: +[%@ %s]", NSStringFromClass(cls), name);
            }
            free(methods);

            unsigned int icount = 0;
            Method *imethods = class_copyMethodList(cls, &icount);
            for (unsigned int i = 0; i < icount; i++) {
                SEL sel = method_getName(imethods[i]);
                const char *name = sel_getName(sel);
                if (strstr(name, "margin") || strstr(name, "offset") || strstr(name, "padding") || 
                    strstr(name, "cutout") || strstr(name, "layout") || strstr(name, "item") || 
                    strstr(name, "edge") || strstr(name, "width") || strstr(name, "height") || 
                    strstr(name, "notch") || strstr(name, "lead") || strstr(name, "trail") || 
                    strstr(name, "time") || strstr(name, "clock") || strstr(name, "pill") ||
                    strstr(name, "inset") || strstr(name, "region")) {
                    L16DBG(@"instance method: -[%@ %s]", NSStringFromClass(cls), name);
                }
            }
            free(imethods);
            cls = class_getSuperclass(cls);
        }
        loadPreferences();
        %init(Diagnostics);

        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL,
            (CFNotificationCallback)loadPreferences, (CFStringRef)kNotification, NULL,
            CFNotificationSuspensionBehaviorCoalesce);

        if (!enabled) return;

        %init(Core);

        if (statusBarStyle == 1) {
            %init(StatusBarPad);
            L16RemoveSplitProvider();   // clean up if switching away from style 2
        } else if (statusBarStyle == 2) {
            L16EnsureSplitProvider();   // RdarFix approach: preference-based split
            %init(StatusBarSplitFix,
                _UIStatusBarVisualProvider_FixedSplit = NSClassFromString(@"_UIStatusBarVisualProvider_FixedSplit"),
                _UIStatusBarVisualProvider_Split1242 = NSClassFromString(@"_UIStatusBarVisualProvider_Split1242"),
                _UIStatusBarVisualProvider_Split = NSClassFromString(@"_UIStatusBarVisualProvider_Split"),
                _UIStatusBarStringView = NSClassFromString(@"_UIStatusBarStringView"),
                _UIStatusBarForegroundView = NSClassFromString(@"_UIStatusBarForegroundView"));
        } else if (statusBarStyle == 3) {
            %init(StatusBarRoundedPad);
            L16RemoveSplitProvider();   // clean up if switching away from style 2
        } else {
            L16RemoveSplitProvider();   // style 0 (Legacy): clean up
        }

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