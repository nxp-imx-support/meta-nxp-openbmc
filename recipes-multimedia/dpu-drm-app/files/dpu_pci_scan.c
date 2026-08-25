// SPDX-License-Identifier: BSD-3-Clause
/*
 * Copyright 2026 NXP
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <signal.h>
#include <stdbool.h>
#include <dirent.h>
#include <limits.h>
#include <sys/stat.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <linux/netlink.h>

#include <xf86drm.h>
#include <xf86drmMode.h>
#include <drm/drm.h>
#include <drm/drm_mode.h>
#include <drm/drm_fourcc.h>

#define DRM_DEV "/dev/dri/card0"
#define RES_FILE "/tmp/last_res.conf"
#define UEVENT_BUF 4096

static int fd;

static uint32_t fb_id = 0;
static uint32_t handle = 0;
static void *map = NULL;
static uint32_t pitch = 0;
static uint64_t size = 0;

static uint32_t crtc_id;
static uint32_t conn_id;
static uint32_t plane_id;
static drmModeModeInfo mode;

static uint32_t p_fb;
static uint32_t p_src_x, p_src_y, p_src_w, p_src_h;
static uint32_t p_crtc_x, p_crtc_y, p_crtc_w, p_crtc_h;
static uint32_t p_crtc_id;
static uint32_t p_src_pitch;

/* crtc + connector props */
static uint32_t crtc_mode_id;
static uint32_t crtc_active;
static uint32_t conn_crtc_id;

static int default_w;
static int default_h;

static int last_w;
static int last_h;

static volatile sig_atomic_t running = 1;
static bool no_display_mode = false;

static bool dt_search_dir(const char *dirpath, const char *compat)
{
    DIR           *dir;
    struct dirent *entry;
    char           fullpath[PATH_MAX];
    struct stat    st;
    int            fd;
    char          *buf;
    ssize_t        n;
    size_t         i;
    bool           found;

    dir = opendir(dirpath);
    if (!dir)
        return false;

    while ((entry = readdir(dir)) != NULL) {

        if (entry->d_name[0] == '.' &&
            (entry->d_name[1] == '\0' ||
            (entry->d_name[1] == '.' && entry->d_name[2] == '\0')))
            continue;

        snprintf(fullpath, sizeof(fullpath), "%s/%s", dirpath, entry->d_name);

        if (stat(fullpath, &st) < 0)
            continue;

        if (S_ISDIR(st.st_mode)) {
            if (dt_search_dir(fullpath, compat)) {
                closedir(dir);
                return true;
            }
        } else if (S_ISREG(st.st_mode) && st.st_size > 0) {

            buf = malloc((size_t)st.st_size + 1);
            if (!buf)
                continue;

            fd = open(fullpath, O_RDONLY | O_CLOEXEC);
            if (fd < 0) { free(buf); continue; }

            n = read(fd, buf, (size_t)st.st_size);
            close(fd);

            if (n > 0) {
                for (i = 0; i < (size_t)n; i++)
                    if (buf[i] == '\0') buf[i] = '\n';
                buf[n] = '\0';
            }

            found = (n > 0 && strstr(buf, compat) != NULL);
            free(buf);

            if (found) { closedir(dir); return true; }
        }
    }

    closedir(dir);
    return false;
}

static bool dt_find_compatible(const char *compat)
{
    if (!compat || !*compat)
        return false;

    return dt_search_dir("/proc/device-tree", compat);
}

static void detect_display_mode(void)
{
    if (dt_find_compatible("adi,adv7535")) {
        printf("[MODE] DTB: adi,adv7535 found → display mode\n");
        no_display_mode = false;
        return;
    }

    if (dt_find_compatible("lontium,lt9611uxc")) {
        printf("[MODE] DTB: lontium,lt9611uxc found → display mode\n");
        no_display_mode = false;
        return;
    }

    printf("[MODE] DTB: no display bridge found → no-display mode\n");
    no_display_mode = true;
}

struct drm_imx_dpu_get_dma_address {
    __u32 handle;
    __u32 pad;
    __u64 dma_addr;
};

#define DRM_IOCTL_IMX_DPU_GET_DMA_ADDRESS \
    DRM_IOWR(0x44, struct drm_imx_dpu_get_dma_address)

static int is_display_connected(void);

static int log_error(const char *msg)
{
    printf("[ERR] %s: %s\n", msg, strerror(errno));
    return -1;
}

static void exit_app(const char *msg)
{
    perror(msg);
    exit(1);
}

static uint32_t get_prop(uint32_t obj_id, uint32_t type, const char *name)
{
    drmModeObjectProperties *props =
        drmModeObjectGetProperties(fd, obj_id, type);

    if (!props)
        return 0;

    for (uint32_t i = 0; i < props->count_props; i++) {

        drmModePropertyPtr p = drmModeGetProperty(fd, props->props[i]);

        if (p && !strcmp(p->name, name)) {
            uint32_t id = p->prop_id;
            drmModeFreeProperty(p);
            drmModeFreeObjectProperties(props);
            return id;
        }

        if (p)
            drmModeFreeProperty(p);
    }

    drmModeFreeObjectProperties(props);
    return 0;
}

static void send_dma_to_stream(uint64_t dma_addr)
{
    char val[32];
    FILE *f;

    snprintf(val, sizeof(val), "0x%llx",
             (unsigned long long)dma_addr);

    f = fopen("/sys/module/pci_epf_imx9_vga/parameters/offset", "w");
    if (!f) {
        perror("fopen");
        return;
    }

    fprintf(f, "%s", val);
    fclose(f);

    printf("DMA address sent to kernel: %s\n", val);
}

static void create_fb(int w, int h)
{
    struct drm_mode_create_dumb creq = {0};
    creq.width = w;
    creq.height = h;
    creq.bpp = 32;

    if (ioctl(fd, DRM_IOCTL_MODE_CREATE_DUMB, &creq)) {
        log_error("CREATE_DUMB");
        return;
    }

    handle = creq.handle;
    pitch  = creq.pitch;
    size   = creq.size;

    struct drm_imx_dpu_get_dma_address dma = {0};

    dma.handle = handle;

    if (ioctl(fd, DRM_IOCTL_IMX_DPU_GET_DMA_ADDRESS, &dma)) {
        log_error("GET_DMA");
        return;
    }
        
    send_dma_to_stream(dma.dma_addr);

    struct drm_mode_map_dumb mreq = {0};
    mreq.handle = handle;

    if (ioctl(fd, DRM_IOCTL_MODE_MAP_DUMB, &mreq)) {
        log_error("MAP_DUMB");
        return;
    }

    map = mmap(0, size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, mreq.offset);
    if (map == MAP_FAILED) {
        log_error("mmap");
        map = NULL;
        return;
    }

    uint32_t handles[4] = { handle };
    uint32_t pitches[4] = { pitch };
    uint32_t offsets[4] = { 0 };

    if (drmModeAddFB2(fd,
                    w,
                    h,
                    DRM_FORMAT_XRGB8888,
                    handles,
                    pitches,
                    offsets,
                    &fb_id,
                    0))
    {
        log_error("AddFB2");
        return;
    }

    printf("[DRM] FB created %dx%d\n", w, h);
}

static uint32_t find_plane(uint32_t crtc_index)
{
    drmModePlaneRes *pres = drmModeGetPlaneResources(fd);
    if (!pres) {
        log_error("plane res");
        return 0;
    }

    for (uint32_t i = 0; i < pres->count_planes; i++) {

        drmModePlane *p =
            drmModeGetPlane(fd, pres->planes[i]);

        if (!p) continue;

        if (p->possible_crtcs & (1 << crtc_index)) {
            uint32_t id = p->plane_id;
            drmModeFreePlane(p);
            drmModeFreePlaneResources(pres);
            return id;
        }

        drmModeFreePlane(p);
    }

    drmModeFreePlaneResources(pres);
    log_error("no compatible plane");
    return 0;
}

static void init_display()
{
    drmSetClientCap(fd, DRM_CLIENT_CAP_ATOMIC, 1);

    if (no_display_mode) {
        printf("[INIT] no-display mode, skipping connector init\n");
        return;
    }

    drmModeRes *res = drmModeGetResources(fd);
    if (!res) {
        log_error("resources");
        return;
    }

    for (int i = 0; i < res->count_connectors; i++) {

        drmModeConnector *c = drmModeGetConnector(fd, res->connectors[i]);
        if (!c) continue;

        if (c->connection == DRM_MODE_CONNECTED && c->count_modes) {

            conn_id = c->connector_id;
            mode = c->modes[0];
            crtc_id = res->crtcs[0];
            plane_id = find_plane(0);

            drmModeFreeConnector(c);
            drmModeFreeResources(res);
            goto props;
        }

        drmModeFreeConnector(c);
    }

    log_error("no display");

    return;

props:

    p_fb      = get_prop(plane_id, DRM_MODE_OBJECT_PLANE, "FB_ID");
    p_src_x   = get_prop(plane_id, DRM_MODE_OBJECT_PLANE, "SRC_X");
    p_src_y   = get_prop(plane_id, DRM_MODE_OBJECT_PLANE, "SRC_Y");
    p_src_w   = get_prop(plane_id, DRM_MODE_OBJECT_PLANE, "SRC_W");
    p_src_h   = get_prop(plane_id, DRM_MODE_OBJECT_PLANE, "SRC_H");
    p_crtc_x  = get_prop(plane_id, DRM_MODE_OBJECT_PLANE, "CRTC_X");
    p_crtc_y  = get_prop(plane_id, DRM_MODE_OBJECT_PLANE, "CRTC_Y");
    p_crtc_w  = get_prop(plane_id, DRM_MODE_OBJECT_PLANE, "CRTC_W");
    p_crtc_h  = get_prop(plane_id, DRM_MODE_OBJECT_PLANE, "CRTC_H");
    p_crtc_id = get_prop(plane_id, DRM_MODE_OBJECT_PLANE, "CRTC_ID");
    p_src_pitch = get_prop(plane_id, DRM_MODE_OBJECT_PLANE, "STRIDE_OVERRIDE");

    crtc_mode_id = get_prop(crtc_id, DRM_MODE_OBJECT_CRTC, "MODE_ID");
    crtc_active  = get_prop(crtc_id, DRM_MODE_OBJECT_CRTC, "ACTIVE");

    conn_crtc_id = get_prop(conn_id, DRM_MODE_OBJECT_CONNECTOR, "CRTC_ID");

    default_w = mode.hdisplay;
    default_h = mode.vdisplay;

    last_w = default_w;
    last_h = default_h;

    printf("[INIT] ready %dx%d\n", mode.hdisplay, mode.vdisplay);
}

static void atomic_modeset(int src_w, int src_h)
{
    if (no_display_mode) {
        printf("[MODESET] no-display mode, skipping (%dx%d)\n",
               src_w, src_h);
        return;
    }

    if (!is_display_connected()) {
        printf("[INFO] HDMI disconnected. "
               "Skipping atomic commit (%dx%d)\n",
               src_w, src_h);
        return;
    }
    
    if (src_w <= 0 || src_h <= 0) {
        printf("[ERR] invalid src size %dx%d\n",
               src_w, src_h);
        return;
    }

    drmModeAtomicReq *req = drmModeAtomicAlloc();
    if (!req) {
        log_error("atomic alloc");
        return;
    }

    uint32_t blob_id;

    if (drmModeCreatePropertyBlob(fd, &mode, sizeof(mode), &blob_id)) {
        log_error("blob");
        drmModeAtomicFree(req);
        return;
    }

    drmModeAtomicAddProperty(req, conn_id, conn_crtc_id, crtc_id);
    drmModeAtomicAddProperty(req, crtc_id, crtc_mode_id, blob_id);
    drmModeAtomicAddProperty(req, crtc_id, crtc_active, 1);
    drmModeAtomicAddProperty(req, plane_id, p_crtc_id, crtc_id);
    drmModeAtomicAddProperty(req, plane_id, p_fb, fb_id);

    /* source = input resolution */
    drmModeAtomicAddProperty(req, plane_id, p_src_x, 0);
    drmModeAtomicAddProperty(req, plane_id, p_src_y, 0);
    drmModeAtomicAddProperty(req, plane_id, p_src_w, src_w << 16);
    drmModeAtomicAddProperty(req, plane_id, p_src_h, src_h << 16);


    /* destination ALWAYS 1080p */
    drmModeAtomicAddProperty(req, plane_id, p_crtc_x, 0);
    drmModeAtomicAddProperty(req, plane_id, p_crtc_y, 0);
    drmModeAtomicAddProperty(req, plane_id, p_crtc_w, default_w);
    drmModeAtomicAddProperty(req, plane_id, p_crtc_h, default_h);

    if (p_src_pitch)
        drmModeAtomicAddProperty(req,
            plane_id, p_src_pitch, src_w * 4);

    int ret = drmModeAtomicCommit(fd, req, DRM_MODE_ATOMIC_ALLOW_MODESET, NULL);

    if (ret)
        printf("[ERR] atomic: %s\n", strerror(errno));
    else
        printf("[OK] %dx%d → 1080p\n", src_w, src_h);

    drmModeAtomicFree(req);
    drmModeDestroyPropertyBlob(fd, blob_id);
}


void save_resolution(void)
{
    FILE *f = fopen(RES_FILE, "w");
    if (!f) {
        perror("save_resolution");
        return;
    }

    fprintf(f, "%d %d\n", last_w, last_h);
    fclose(f);

    printf("[SAVE] %dx%d\n", last_w, last_h);
}

void load_resolution(void)
{
    FILE *f = fopen(RES_FILE, "r");

    last_w = default_w;
    last_h = default_h;

    if (!f) {
        printf("[LOAD] no saved resolution, using default %dx%d\n",
               default_w, default_h);
        return;
    }

    if (fscanf(f, "%d %d", &last_w, &last_h) != 2) {
        last_w = default_w;
        last_h = default_h;
    }

    fclose(f);

    printf("[LOAD] restored %dx%d\n", last_w, last_h);
}

void update_last_resolution(int w, int h)
{
    if (w <= 0 || h <= 0) {
        printf("[WARN] invalid resolution %dx%d\n", w, h);
        return;
    }

    last_w = w;
    last_h = h;

    printf("[UPDATE] %dx%d\n", last_w, last_h);
}

void restore_default(void)
{
    printf("[RESTORE] default %dx%d\n", default_w, default_h);

    atomic_modeset(default_w, default_h);
}

static int is_display_connected(void)
{
    drmModeRes *res = drmModeGetResources(fd);

    if (!res)
        return 0;

    for (int i = 0; i < res->count_connectors; i++) {

        drmModeConnector *c =
            drmModeGetConnector(fd, res->connectors[i]);

        if (!c)
            continue;

        if (c->connection == DRM_MODE_CONNECTED &&
            c->count_modes > 0) {

            drmModeFreeConnector(c);
            drmModeFreeResources(res);

            return 1;
        }

        drmModeFreeConnector(c);
    }

    drmModeFreeResources(res);

    return 0;
}

static int wait_for_fb0(void)
{
    int retry = 50;

    if (no_display_mode) {
        printf("[FB] no-display mode, skipping /dev/fb0 wait\n");
        return 0;
    }

    while (retry-- && running) {

        if (access("/dev/fb0", F_OK) == 0) {

            printf("[FB] /dev/fb0 ready\n");

            return 0;
        }

        usleep(100000);
    }

    printf("[FB] timeout waiting for /dev/fb0\n");

    return -1;
}

static void reinit_display(void)
{
    printf("[HOTPLUG] reinitializing display\n");

    if (map && map != MAP_FAILED) {
        munmap(map, size);
        map = NULL;
    }

    if (fb_id) {
        drmModeRmFB(fd, fb_id);
        fb_id = 0;
    }

    if (handle) {

        struct drm_mode_destroy_dumb d = {0};

        d.handle = handle;

        ioctl(fd, DRM_IOCTL_MODE_DESTROY_DUMB, &d);

        handle = 0;
    }

    if (!running)
        return;

    if (wait_for_fb0() < 0)
        return;

    if (!running)
        return;

    init_display();

    load_resolution();

    create_fb(mode.hdisplay, mode.vdisplay);

    if (last_w <= 0 || last_h <= 0) {
        last_w = default_w;
        last_h = default_h;
    }

    if (running)
        atomic_modeset(last_w, last_h);

    printf("[HOTPLUG] done\n");
}

static void handle_event(char *buf, int len)
{
    int i = 0;
    int hotplug = 0;

    while (i < len) {

        char *msg = buf + i;

        if (strncmp(msg, "change@", 7) == 0 && strstr(msg, "/drm/card0"))
        {
            hotplug = 1;
        }

        if (strncmp(msg, "RESOLUTION=", 11) == 0) {

            int w, h;

            if (sscanf(msg, "RESOLUTION=%dx%d", &w, &h) == 2) {

                printf("[UEVENT] %dx%d\n", w, h);
                update_last_resolution(w, h);
                save_resolution();

                if (running && !no_display_mode)
                    atomic_modeset(w, h);
                /* Update stream2v4l2 resolution via sysfs */
                {
                    char val[32];
                    FILE *f;
                    snprintf(val, sizeof(val), "%dx%d:%d", w, h, (int)w * 4);
                    if ((f = fopen("/sys/module/stream2v4l2/parameters/resolution", "w"))) {
                        fputs(val, f); fclose(f);
                    }
                }
            }
        }

        i += strlen(msg) + 1;
    }

    if (hotplug && running && !no_display_mode) {

        printf("[HOTPLUG DETECTED]\n");
        if (is_display_connected()) {
            printf("[HDMI] connected\n");
            reinit_display();
        } else {
            printf("[HDMI] disconnected\n");
            save_resolution();
            if (map && map != MAP_FAILED) {
                munmap(map, size);
                map = NULL;
            }

            if (fb_id) {
                drmModeRmFB(fd, fb_id);
                fb_id = 0;
            }

            if (handle) {
                struct drm_mode_destroy_dumb d = {0};
                d.handle = handle;
                ioctl(fd, DRM_IOCTL_MODE_DESTROY_DUMB, &d);
                handle = 0;
            }
        }
    }
}

static void uevent_loop()
{
    struct sockaddr_nl addr = {0};

    int sock = socket(AF_NETLINK, SOCK_RAW, NETLINK_KOBJECT_UEVENT);
    if (sock < 0)
        exit_app("netlink socket");

    addr.nl_family = AF_NETLINK;
    addr.nl_pid = getpid();
    addr.nl_groups = 1;

    if (bind(sock, (struct sockaddr *)&addr, sizeof(addr))) 
    {
        close(sock);
        exit_app("netlink");
    }

    struct timeval tv = {
        .tv_sec = 1,
        .tv_usec = 0
    };

    if (setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv)) < 0) {
        close(sock);
        exit_app("SO_RCVTIMEO");
    }

    char buf[UEVENT_BUF];

    printf("[UEVENT] listening\n");

    while (running) {

        int len = recv(sock, buf, sizeof(buf), 0);
        if (len > 0) {
            handle_event(buf, len);
        } else if (len < 0) {
            if (errno == EAGAIN ||
                errno == EWOULDBLOCK) {

                continue;
            }

            if (errno == EINTR)
                continue;

            perror("[UEVENT] recv");
            break;
        }
    }

    close(sock);
    printf("[UEVENT] stopped\n");
}

static void cleanup()
{
    save_resolution();

    if (map && map != MAP_FAILED) {
        munmap(map, size);
        map = NULL;
    }

    if (fb_id) {
        drmModeRmFB(fd, fb_id);
        fb_id = 0;
    }

    if (handle) {
        struct drm_mode_destroy_dumb d = {0};
        d.handle = handle;
        ioctl(fd, DRM_IOCTL_MODE_DESTROY_DUMB, &d);
        handle = 0;
    }

    if (fd >= 0) {
        close(fd);
        fd = -1;
    }

    printf("[APP] cleaned\n");
}

static void stop_handler(int sig)
{
    
    (void)sig;
    running = 0;
}

int main()
{
    detect_display_mode();

    /* Wait for /dev/dri/card0 to appear */
    while (running && access(DRM_DEV, F_OK) != 0)
        usleep(100000);

    struct sigaction sa = {0};
    sa.sa_handler = stop_handler;
    sigemptyset(&sa.sa_mask);
    sigaction(SIGTERM, &sa, NULL);
    sigaction(SIGINT, &sa, NULL);

    if (!running)
        return 0;

    /* Wait for /dev/fb0 — ensures DRM subsystem is fully initialised */
    if (wait_for_fb0() < 0) {
        printf("[MAIN] /dev/fb0 not ready, aborting\n");
        return 1;
    }

    if (!running)
        return 0;

    if (!no_display_mode) {
        fd = open(DRM_DEV, O_RDWR | O_CLOEXEC);
        if (fd < 0) {
            log_error("open drm");
            return 1;
        }

        /* Retry init_display() until connector is fully enumerated */
        int retries = 20;
        while (running && retries-- > 0) {
            init_display();
            if (conn_id && crtc_id && plane_id)
                break;
            printf("[MAIN] display not ready yet, retrying...\n");
            usleep(500000); /* 500 ms */
        }

        if (!conn_id || !crtc_id || !plane_id) {
            printf("[MAIN] display init failed after retries\n");
            close(fd);
            return 1;
        }
        load_resolution();

        create_fb(mode.hdisplay, mode.vdisplay);
    }
    else {
        printf("[MAIN] mode : no-display \n");
        load_resolution();
    }
    /* Update stream2v4l2 resolution via sysfs */
    if (last_w != 0 || last_h != 0 ) {
        char val[32];
        FILE *f;
        snprintf(val, sizeof(val), "%dx%d:%d", last_w, last_h, (int)last_w * 4);
        if ((f = fopen("/sys/module/stream2v4l2/parameters/resolution", "w")))
        {
            fputs(val, f);
            fclose(f);
        }
    }

    if (running) {
        if (!no_display_mode)
            atomic_modeset(last_w, last_h);
        uevent_loop();
    }

    cleanup();

    return 0;
}
