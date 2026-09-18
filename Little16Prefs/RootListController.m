#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#include <spawn.h>

@interface Little16PrefsListController : PSListController
@end

@implementation Little16PrefsListController

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    }
    return _specifiers;
}

- (void)respring {
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