#import <Cocoa/Cocoa.h>
#import <sys/time.h>
#import <sys/resource.h>

int main(int argc, const char *argv[])
{
		// Re-nice ourself to the lowest priority so we don't take over the user's machine.
	setpriority(PRIO_PROCESS, 0, PRIO_MAX);
	
    return NSApplicationMain(argc, argv);
}
