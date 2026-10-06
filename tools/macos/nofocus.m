// Loaded into Godot by tools/godot (DYLD_INSERT_LIBRARIES; Godot's signature allows it with
// allow-dyld-environment-variables and disable-library-validation). Godot asks macOS to activate it whenever it shows
// its main window (DisplayServerMacOS::show_window -> activateApplication), which takes focus from the owner. Here
// those requests do nothing, the app stays an accessory (no Dock icon, no menu bar) and its windows open behind the
// owner's. Owner decision 2026-10-06. NOFOCUS_LOG=1 prints each blocked call.
#import <AppKit/AppKit.h>
#import <objc/runtime.h>
#include <ApplicationServices/ApplicationServices.h>

static BOOL nf_log;
static BOOL (*nf_set_policy_orig)(id, SEL, NSApplicationActivationPolicy);

static void nf_note(const char *what) {
	if (nf_log) {
		fprintf(stderr, "nofocus: blocked %s\n", what);
	}
}

static void nf_activate_ignoring(id self, SEL _cmd, BOOL flag) { nf_note("activateIgnoringOtherApps:"); }
static void nf_activate(id self, SEL _cmd) { nf_note("activate"); }
static BOOL nf_activate_with_options(id self, SEL _cmd, NSApplicationActivationOptions options) {
	nf_note("activateWithOptions:");
	return NO;
}
static BOOL nf_set_policy(id self, SEL _cmd, NSApplicationActivationPolicy policy) {
	return nf_set_policy_orig(self, _cmd, NSApplicationActivationPolicyAccessory);
}
static void nf_order_back(id self, SEL _cmd, id sender) { [(NSWindow *)self orderBack:sender]; }
static void nf_order_back_regardless(id self, SEL _cmd) { [(NSWindow *)self orderBack:nil]; }

// Godot's "unbundled activation hack" turns the process into a foreground app before activating it; AppKit's own
// switch to an accessory goes through here too and is let through.
static OSStatus nf_transform(const ProcessSerialNumber *psn, ProcessApplicationTransformState state) {
	if (state != kProcessTransformToForegroundApplication) {
		return TransformProcessType(psn, state);
	}
	nf_note("TransformProcessType to foreground");
	return noErr;
}
__attribute__((used)) static struct {
	const void *replacement;
	const void *original;
} nf_interpose __attribute__((section("__DATA,__interpose"))) = { (const void *)&nf_transform, (const void *)&TransformProcessType };

static void nf_replace(Class cls, SEL sel, IMP imp) {
	Method m = class_getInstanceMethod(cls, sel);
	if (m) {
		method_setImplementation(m, imp);
	}
}

__attribute__((constructor)) static void nf_init(void) {
	nf_log = getenv("NOFOCUS_LOG") != NULL;
	Class app = [NSApplication class];
	nf_replace(app, @selector(activateIgnoringOtherApps:), (IMP)nf_activate_ignoring);
	nf_replace(app, @selector(activate), (IMP)nf_activate);
	nf_replace([NSRunningApplication class], @selector(activateWithOptions:), (IMP)nf_activate_with_options);
	Method policy = class_getInstanceMethod(app, @selector(setActivationPolicy:));
	nf_set_policy_orig = (BOOL (*)(id, SEL, NSApplicationActivationPolicy))method_setImplementation(policy, (IMP)nf_set_policy);
	Class win = [NSWindow class];
	nf_replace(win, @selector(makeKeyAndOrderFront:), (IMP)nf_order_back);
	nf_replace(win, @selector(orderFront:), (IMP)nf_order_back);
	nf_replace(win, @selector(orderFrontRegardless), (IMP)nf_order_back_regardless);
}
