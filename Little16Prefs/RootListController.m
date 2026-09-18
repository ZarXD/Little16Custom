#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#include <spawn.h>

static void L16Log(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    NSData *data = [[message stringByAppendingString:@"\n"] dataUsingEncoding:NSUTF8StringEncoding];
    NSString *path = @"/tmp/little16debug.log";
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        [data writeToFile:path atomically:YES];
    } else {
        NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:path];
        [fh seekToEndOfFile];
        [fh writeData:data];
        [fh closeFile];
    }
    NSLog(@"Little16Prefs: %@", message);
}

@interface Little16PrefsListController : PSListController
@end

@implementation Little16PrefsListController {
    BOOL _logged;
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
    L16Log(@"specifiers entered");
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
        L16Log(@"specifiers loaded count=%lu", (unsigned long)[_specifiers count]);
    }
    if (!_logged) {
        _logged = YES;
        L16Log(@"bundle=%@ exec=%@ cwd=%@", [[NSBundle mainBundle] bundleIdentifier], [[[NSBundle mainBundle] executablePath] lastPathComponent], [[NSFileManager defaultManager] currentDirectoryPath]);
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