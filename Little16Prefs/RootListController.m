#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#include <spawn.h>
#include <stdio.h>
#include <unistd.h>

static void L16Log(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    NSString *line = [NSString stringWithFormat:@"uid=%d %@\n", getuid(), message];
    const char *s = [line UTF8String];
    NSString *tmp = NSTemporaryDirectory();
    NSString *home = NSHomeDirectory();
    NSArray *paths = @[
        @"/tmp/little16debug.log",
        @"/var/mobile/little16debug.log",
        @"/var/mobile/Media/little16debug.log",
        [NSString stringWithFormat:@"%@little16debug.log", tmp ?: @""],
        [NSString stringWithFormat:@"%@/little16debug.log", tmp ?: @""],
        [NSString stringWithFormat:@"%@/little16debug.log", home ?: @""],
    ];
    for (NSString *path in paths) {
        FILE *f = fopen([path UTF8String], "ab");
        if (f) {
            fputs(s, f);
            fclose(f);
        }
    }
    NSLog(@"Little16Prefs: %@", message);
}

@interface Little16PrefsListController : PSListController
@end

@implementation Little16PrefsListController {
    BOOL _logged;
}

+ (void)load {
    L16Log(@"+load fired home=%@ tmp=%@", NSHomeDirectory(), NSTemporaryDirectory());
}

- (instancetype)init {
    L16Log(@"init entered");
    self = [super init];
    if (self) L16Log(@"init exit ok");
    return self;
}

- (void)loadView {
    L16Log(@"loadView entered");
    [super loadView];
    L16Log(@"loadView exit");
}

- (void)viewDidLoad {
    L16Log(@"viewDidLoad entered");
    [super viewDidLoad];
    L16Log(@"viewDidLoad exit");
}

- (NSArray *)specifiers {
    if (!_logged) {
        _logged = YES;
        L16Log(@"specifiers entered bundle=%@ exec=%@", [[NSBundle mainBundle] bundleIdentifier], [[[NSBundle mainBundle] executablePath] lastPathComponent]);
    }
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
        L16Log(@"specifiers loaded count=%lu", (unsigned long)[_specifiers count]);
    }
    return _specifiers;
}

- (void)respring {
    L16Log(@"respring tapped");
    NSString *killall = nil;
    NSArray *candidates = @[@"/var/jb/usr/bin/killall", @"/usr/bin/killall"];
    for (NSString *path in candidates) {
        if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
            killall = path;
            break;
        }
    }
    pid_t pid;
    if (killall) {
        const char *args[] = {[killall UTF8String], "-9", "SpringBoard", NULL};
        posix_spawn(&pid, args[0], NULL, NULL, (char *const *)args, NULL);
    } else {
        const char *args[] = {"/bin/launchctl", "kickstart", "-k", "system/com.apple.SpringBoard", NULL};
        posix_spawn(&pid, args[0], NULL, NULL, (char *const *)args, NULL);
    }
}

@end