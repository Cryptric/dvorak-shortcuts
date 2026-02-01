//
// Created by gawain on 1/24/26.
//

#include <unistd.h>
#include <systemd/sd-bus.h>
#include <stdatomic.h>

#include "dvorak_dbus.h"

#include <pthread.h>


static int method_disable(sd_bus_message *m, void *userdata, sd_bus_error *ret_error) {
    bool* isDvorak = (bool*) userdata;
    atomic_store(isDvorak, true);
    return sd_bus_reply_method_return(m, NULL);
}

static int method_enable(sd_bus_message *m, void *userdata, sd_bus_error *ret_error) {
    bool* isDvorak = (bool*) userdata;
    atomic_store(isDvorak, false);
    return sd_bus_reply_method_return(m, NULL);
}

static const sd_bus_vtable keyboard_vtable[] = {
    SD_BUS_VTABLE_START(0),
    SD_BUS_METHOD("Disable", NULL, NULL, method_disable, SD_BUS_VTABLE_UNPRIVILEGED),
    SD_BUS_METHOD("Enable", NULL, NULL, method_enable, SD_BUS_VTABLE_UNPRIVILEGED),
    SD_BUS_VTABLE_END
};

void* create_dvorak_dbus(void* arg) {
    bool* isDvorak = (bool*) arg;

    sd_bus_slot* slot = NULL;
    sd_bus* bus = NULL;
    int ret = 0;
    ret = sd_bus_open_system(&bus);
    if (ret < 0) {
        fprintf(stderr, "Failed to open system bus: %s\n", strerror(errno));
    }


    ret = sd_bus_add_object_vtable(bus, &slot, "/com/dvorak/Keyboard", "com.dvorak.Keyboard", keyboard_vtable, isDvorak);
    if (ret < 0) {
        fprintf(stderr, "Failed to add object vtable: %s\n", strerror(-ret));
    }

    ret = sd_bus_request_name(bus, "com.dvorak.Keyboard", 0);
    if (ret < 0) {
        fprintf(stderr, "Failed to request name: %s\n", strerror(-ret));
    }


    while (true) {
        pthread_testcancel();

        bool active = atomic_load(isDvorak);
        sd_bus_emit_signal(bus, "/com/dvorak/Keyboard", "com.dvorak.Keyboard", "Status", "b", active);


        ret = sd_bus_process(bus, NULL);
        if (ret < 0) {
            fprintf(stderr, "Failed to process bus: %s\n", strerror(-ret));
            break;
        }

        ret = sd_bus_wait(bus, (uint64_t) 500 * 1000);
        if (ret < 0) {
            fprintf(stderr, "Failed to wait for process bus: %s\n", strerror(-ret));
        }
    }

    sd_bus_slot_unref(slot);
    sd_bus_unref(bus);
    return NULL;
}


