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
    NSString *killall = [[NSFileManager defaultManager] fileExistsAtPath:@"/var/jb/usr/bin/killall"]
        ? @"/var/jb/usr/bin/killall"
        : @"/usr/bin/killall";
    pid_t pid;
    const char *args[] = {[killall UTF8String], "-9", "SpringBoard", NULL};
    posix_spawn(&pid, args[0], NULL, NULL, (char *const *)args, NULL);
}

@end