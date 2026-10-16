// The editor/export process runs on macOS; iOS services are deliberately absent on the host.
#include <gdextension_interface.h>
static void noop(void *data, GDExtensionInitializationLevel level) {}
__attribute__((visibility("default")))
GDExtensionBool strahd_ios_init(GDExtensionInterfaceGetProcAddress address, GDExtensionClassLibraryPtr library, GDExtensionInitialization *initialization) {
    initialization->minimum_initialization_level = GDEXTENSION_INITIALIZATION_SCENE;
    initialization->userdata = 0;
    initialization->initialize = noop;
    initialization->deinitialize = noop;
    return 1;
}
