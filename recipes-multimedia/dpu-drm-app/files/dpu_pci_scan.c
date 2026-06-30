#define _GNU_SOURCE

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <signal.h>
#include <stdbool.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <sys/socket.h>
#include <linux/netlink.h>

#include <xf86drm.h>
#include <xf86drmMode.h>
#include <drm/drm.h>
#include <drm/drm_mode.h>

#define DRM_DEV "/dev/dri/card0"
#define STREAM_DEV "/dev/stream"
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

struct drm_imx_dpu_get_dma_address {
    __u32 handle;
    __u32 pad;
    __u64 dma_addr;
};

#define DRM_IOCTL_IMX_DPU_GET_DMA_ADDRESS    DRM_IOWR(0x44, struct drm_imx_dpu_get_dma_address)
#define STREAM_IOC_SET_OFFSET _IOW('S', 2, uint64_t)

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
    int sfd;
    uint64_t off;

    sfd = open(STREAM_DEV, O_RDWR);
    if (sfd < 0)
        exit_app("open /dev/streme");

    off = dma_addr;
    
    if (ioctl(sfd, STREAM_IOC_SET_OFFSET, &off) < 0)
        exit_app("STREAM_IOC_SET_OFFSET");

    close(sfd);
}

static void create_fb(int w, int h)
{
    struct drm_mode_create_dumb creq = {0};
    creq.width = w;
    creq.height = h;
    creq.bpp = 32;

    if (ioctl(fd, DRM_IOCTL_MODE_CREATE_DUMB, &creq))
        exit_app("CREATE_DUMB");

    handle = creq.handle;
    pitch  = creq.pitch;
    size   = creq.size;

    struct drm_imx_dpu_get_dma_address dma = {0};

    dma.handle = handle;

    if (ioctl(fd, DRM_IOCTL_IMX_DPU_GET_DMA_ADDRESS, &dma))
        exit_app("GET_DMA");
        
    send_dma_to_stream(dma.dma_addr);

    struct drm_mode_map_dumb mreq = {0};
    mreq.handle = handle;

    if (ioctl(fd, DRM_IOCTL_MODE_MAP_DUMB, &mreq))
        exit_app("MAP_DUMB");

    map = mmap(0, size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, mreq.offset);
    if (map == MAP_FAILED)
        exit_app("mmap");


    if (drmModeAddFB(fd, w, h, 24, 32, pitch, handle, &fb_id))
        exit_app("AddFB");

    printf("[DRM] FB created %dx%d\n", w, h);
}

static uint32_t find_plane(uint32_t crtc_index)
{
    drmModePlaneRes *pres = drmModeGetPlaneResources(fd);
    if (!pres) exit_app("plane res");

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
    exit_app("no compatible plane");
    return 0;
}

static void init_display()
{
    drmSetClientCap(fd, DRM_CLIENT_CAP_ATOMIC, 1);

    drmModeRes *res = drmModeGetResources(fd);
    if (!res) exit_app("resources");

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

    exit_app("no display");

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
    drmModeAtomicReq *req = drmModeAtomicAlloc();
    if (!req) exit_app("atomic alloc");

    uint32_t blob_id;

    if (drmModeCreatePropertyBlob(fd, &mode,
        sizeof(mode), &blob_id))
        exit_app("blob");

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
    last_w = w;
    last_h = h;

    printf("[UPDATE] %dx%d\n", last_w, last_h);
}

void restore_default(void)
{
    printf("[RESTORE] default %dx%d\n", default_w, default_h);

    atomic_modeset(default_w, default_h);
}

static void handle_event(char *buf, int len)
{
    int i = 0;

    while (i < len) {

        char *msg = buf + i;

        if (strncmp(msg, "RESOLUTION=", 11) == 0) {

            int w, h;

            if (sscanf(msg, "RESOLUTION=%dx%d", &w, &h) == 2) {

                printf("[UEVENT] %dx%d\n", w, h);
                update_last_resolution(w, h);
                atomic_modeset(w, h);
            }
        }

        i += strlen(msg) + 1;
    }
}

static void uevent_loop()
{
    struct sockaddr_nl addr = {0};

    int sock = socket(AF_NETLINK, SOCK_RAW, NETLINK_KOBJECT_UEVENT);

    addr.nl_family = AF_NETLINK;
    addr.nl_pid = getpid();
    addr.nl_groups = 1;

    if (bind(sock, (struct sockaddr *)&addr, sizeof(addr)))
        exit_app("netlink");

    char buf[UEVENT_BUF];

    printf("[UEVENT] listening\n");

    while (running) {
        int len = recv(sock, buf, sizeof(buf), 0);
        if (len > 0)
            handle_event(buf, len);
    }
}

static void cleanup()
{
    save_resolution();
    restore_default();

    if (map && map != MAP_FAILED)
        munmap(map, size);

    if (fb_id)
        drmModeRmFB(fd, fb_id);

    if (handle) {
        struct drm_mode_destroy_dumb d = {0};
        d.handle = handle;
        ioctl(fd, DRM_IOCTL_MODE_DESTROY_DUMB, &d);
    }

    if (fd >= 0)
        close(fd);

    printf("[APP] cleaned\n");
}

static void stop_handler(int sig)
{
    running = 0;
    cleanup();
    printf("\n[SYSTEMD] stop requested\n");
}

int main()
{
    while (access(DRM_DEV, F_OK) != 0)
        usleep(100000);

    struct sigaction sa = {0};
    sa.sa_handler = stop_handler;
    sigaction(SIGTERM, &sa, NULL);
    sigaction(SIGINT, &sa, NULL);

    fd = open(DRM_DEV, O_RDWR | O_CLOEXEC);
    if (fd < 0)
        exit_app("open drm");

    init_display();
    
    load_resolution();

    create_fb(mode.hdisplay, mode.vdisplay);

    atomic_modeset(last_w, last_h);

    uevent_loop();

    return 0;
}
