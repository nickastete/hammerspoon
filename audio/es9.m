#import <Foundation/Foundation.h>
#import <IOKit/IOKitLib.h>
#import <IOUSBHost/IOUSBHost.h>
#import <CoreAudio/CoreAudio.h>
#include <signal.h>
#include <stdatomic.h>
#include <unistd.h>

// Exit codes shared with recovery.lua. A failed hardware check differs from
// an error enumerating devices: only a confirmed ES-9 may be reset.
enum { Absent = 10, Stalled = 11, Failed = 12 };
static volatile sig_atomic_t deadlineStatus = Failed;
static void timeout(int signalNumber) {
    (void)signalNumber;
    _exit(deadlineStatus);
}

static int findUSB(io_service_t *service, uint64_t *entry) {
    NSMutableDictionary *match = CFBridgingRelease(IOServiceMatching("IOUSBHostDevice"));
    match[@(kIOPropertyMatchKey)] = @{@"idVendor": @0x2485, @"idProduct": @0x50e0,
                                     @"USB Product Name": @"ES-9"};
    io_iterator_t iterator = 0;
    if (IOServiceGetMatchingServices(kIOMainPortDefault, (__bridge_retained CFDictionaryRef)match,
                                     &iterator) != KERN_SUCCESS) return Failed;
    *service = IOIteratorNext(iterator);
    io_service_t extra = IOIteratorNext(iterator);
    IOObjectRelease(iterator);
    if (!*service) return Absent;
    if (extra) {
        IOObjectRelease(extra);
        fprintf(stderr, "Multiple ES-9 devices found.\n");
        return Failed;
    }
    return IORegistryEntryGetRegistryEntryID(*service, entry) == KERN_SUCCESS ? 0 : Failed;
}

static atomic_uint callbacks;
static OSStatus silence(AudioDeviceID device, const AudioTimeStamp *now, const AudioBufferList *input,
                        const AudioTimeStamp *inputTime, AudioBufferList *out,
                        const AudioTimeStamp *outputTime, void *context) {
    (void)device; (void)now; (void)input; (void)inputTime; (void)outputTime; (void)context;
    bool hasFrames = false;
    for (UInt32 i = 0; i < out->mNumberBuffers; i++) {
        AudioBuffer *buffer = &out->mBuffers[i];
        if (buffer->mData && buffer->mDataByteSize) {
            memset(buffer->mData, 0, buffer->mDataByteSize);
            hasFrames = true;
        }
    }
    if (hasFrames) atomic_fetch_add_explicit(&callbacks, 1, memory_order_relaxed);
    return noErr;
}

static int probe(void) {
    AudioObjectPropertyAddress a = { kAudioHardwarePropertyDevices, kAudioObjectPropertyScopeGlobal,
                                    kAudioObjectPropertyElementMain };
    UInt32 size = 0;
    if (AudioObjectGetPropertyDataSize(kAudioObjectSystemObject, &a, 0, NULL, &size)) return Failed;
    NSMutableData *storage = [NSMutableData dataWithLength:size];
    AudioDeviceID *ids = storage.mutableBytes, target = kAudioObjectUnknown;
    if (AudioObjectGetPropertyData(kAudioObjectSystemObject, &a, 0, NULL, &size, ids)) return Failed;
    a.mSelector = kAudioObjectPropertyName;
    for (unsigned i = 0; i < size / sizeof(*ids); i++) {
        CFStringRef name = NULL;
        UInt32 length = sizeof(name);
        if (AudioObjectGetPropertyData(ids[i], &a, 0, NULL, &length, &name) || !name) continue;
        bool matches = CFEqual(name, CFSTR("ES-9"));
        CFRelease(name);
        if (matches) {
            if (target != kAudioObjectUnknown) return Failed;
            target = ids[i];
        }
    }
    if (target == kAudioObjectUnknown) return Stalled;
    AudioDeviceIOProcID proc = NULL;
    OSStatus status = AudioDeviceCreateIOProcID(target, silence, NULL, &proc);
    if (status) { fprintf(stderr, "Create audio client: %d\n", (int)status); return Failed; }
    deadlineStatus = Stalled;
    status = AudioDeviceStart(target, proc);
    bool flowing = false;
    if (!status) {
        usleep(350000);
        unsigned before = atomic_load(&callbacks);
        usleep(350000);
        flowing = atomic_load(&callbacks) > before;
        AudioDeviceStop(target, proc);
    }
    AudioDeviceDestroyIOProcID(target, proc);
    if (status) fprintf(stderr, "Start audio: %d\n", (int)status);
    return flowing ? 0 : Stalled;
}

int main(int argc, const char **argv) { @autoreleasepool {
    signal(SIGALRM, timeout);
    alarm(6);
    io_service_t usb = 0;
    uint64_t entry = 0;
    int status = findUSB(&usb, &entry);
    if (status) return status;
    NSString *identity = [NSString stringWithFormat:@"%llx", (unsigned long long)entry];
    if (argc == 2 && !strcmp(argv[1], "id")) {
        puts(identity.UTF8String);
        return 0;
    }
    if (argc == 2 && !strcmp(argv[1], "probe")) return probe();
    if (argc != 3 || strcmp(argv[1], "reset")) return Failed;
    if (strcmp(argv[2], identity.UTF8String)) {
        fprintf(stderr, "ES-9 instance changed before reset.\n"); return Failed;
    }
    NSError *error = nil;
    IOUSBHostDevice *device = [[IOUSBHostDevice alloc] initWithIOService:usb
        options:IOUSBHostObjectInitOptionsNone queue:nil error:&error interestHandler:nil];
    IOObjectRelease(usb);
    if (!device) { fprintf(stderr, "USB open: %s\n", error.localizedDescription.UTF8String); return Failed; }
    BOOL ok = [device resetWithError:&error];
    [device destroy];
    if (!ok) fprintf(stderr, "USB reset: %s\n", error.localizedDescription.UTF8String);
    return ok ? 0 : Failed;
}}
