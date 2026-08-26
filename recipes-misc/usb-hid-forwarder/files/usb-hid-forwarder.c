// SPDX-License-Identifier: BSD-3-Clause
// Copyright 2026 NXP

#define _GNU_SOURCE

#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <linux/input.h>
#include <linux/netlink.h>
#include <poll.h>
#include <pthread.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <getopt.h>
#include <sys/stat.h>
#include <sys/ioctl.h>
#include <sys/socket.h>

#define PROGRAM_NAME             "usb-hid-forwarder"
#define INPUT_DEVICES_DIR        "/dev/input"

#define DEFAULT_KEYBOARD_GADGET  "/dev/hidg0"
#define DEFAULT_ABS_MOUSE_GADGET "/dev/hidg1"
#define DEFAULT_REL_MOUSE_GADGET "/dev/hidg2"

#define OBMC_UDC_SYSFS_PATH      "/sys/kernel/config/usb_gadget/obmc_hid/UDC"

#define MAX_INPUT_DEVICES        16
#define HOTPLUG_POLL_MS          500
#define UEVENT_BUFFER_SIZE       4096
#define UEVENT_RCVBUF_SIZE       (256 * 1024)

enum device_type {
	DEVICE_NONE      = 0,
	DEVICE_KEYBOARD  = 1,
	DEVICE_ABS_MOUSE = 2,
	DEVICE_REL_MOUSE = 3,
};

struct keyboard_report {
	uint8_t modifier;
	uint8_t reserved;
	uint8_t keycode[6];
} __attribute__((packed));

struct abs_mouse_report {
	uint8_t  buttons;
	uint16_t x;
	uint16_t y;
	int8_t   wheel;
} __attribute__((packed));

struct rel_mouse_report {
	uint8_t buttons;
	int8_t  x;
	int8_t  y;
	int8_t  wheel;
} __attribute__((packed));

struct input_device {
	int              fd;
	enum device_type type;
	int              pending_remove;
	char             path[PATH_MAX];
};

static volatile sig_atomic_t is_running = 1;
static _Atomic int obmc_udc_active;
static volatile sig_atomic_t udc_dirty = 1;

static struct keyboard_report  kbd_report;
static struct abs_mouse_report abs_report;
static struct rel_mouse_report rel_report;

static int keyboard_gadget_fd  = -1;
static int abs_mouse_gadget_fd = -1;
static int rel_mouse_gadget_fd = -1;

static const char *keyboard_gadget_path  = DEFAULT_KEYBOARD_GADGET;
static const char *abs_mouse_gadget_path = DEFAULT_ABS_MOUSE_GADGET;
static const char *rel_mouse_gadget_path = DEFAULT_REL_MOUSE_GADGET;


static struct input_device device_list[MAX_INPUT_DEVICES];
static int                 device_count;
static pthread_mutex_t     device_list_lock = PTHREAD_MUTEX_INITIALIZER;

static int wake_pipe[2] = { -1, -1 };

/* ------------------------------------------------------------------ */

static int udc_is_active(const char *udc_path)
{
	char    buf[64] = { 0 };
	int     fd;
	ssize_t bytes_read;

	fd = open(udc_path, O_RDONLY | O_CLOEXEC);
	if (fd < 0)
		return 0;

	bytes_read = read(fd, buf, sizeof(buf) - 1);
	close(fd);

	if (bytes_read <= 0)
		return 0;

	return (buf[0] != '\n' && buf[0] != '\0');
}

static int open_gadget_device(int *gadget_fd, const char *path, const char *label)
{
	if (*gadget_fd >= 0)
		return 0;

	*gadget_fd = open(path, O_WRONLY | O_NONBLOCK | O_CLOEXEC);
	if (*gadget_fd < 0) {
		printf("[ERROR] Cannot open %s (%s): %s\n", path, label, strerror(errno));
		return -1;
	}

	printf("[INFO] Opened gadget device: %-20s  (%s)\n", path, label);
	return 0;
}

static void close_gadget_device(int *gadget_fd, const char *path)
{
	if (gadget_fd == NULL || *gadget_fd < 0)
		return;

	close(*gadget_fd);
	*gadget_fd = -1;

	printf("[INFO] Closed gadget device: %s\n", path);
}

static void close_input_device_fd(int fd)
{
	if (fd < 0)
		return;

	if (ioctl(fd, EVIOCGRAB, 0) < 0) {
		perror("Failed to release device");
	}

	close(fd);
}

static void refresh_udc_state(void)
{
	int udc_now;
	int state_changed;

	if (!udc_dirty)
		return;

	udc_dirty   = 0;
	udc_now     = udc_is_active(OBMC_UDC_SYSFS_PATH);
	state_changed = (udc_now != obmc_udc_active);

	if (!state_changed)
		return;

	obmc_udc_active = udc_now;

	if (udc_now) {
		printf("[INFO] obmc_hid UDC active — opening gadget devices\n");
		open_gadget_device(&keyboard_gadget_fd,  keyboard_gadget_path,  "keyboard");
		open_gadget_device(&abs_mouse_gadget_fd, abs_mouse_gadget_path, "abs mouse");
		open_gadget_device(&rel_mouse_gadget_fd, rel_mouse_gadget_path, "rel mouse");
	} else {
		printf("[INFO] obmc_hid UDC inactive — closing gadget devices\n");
		close_gadget_device(&keyboard_gadget_fd,  keyboard_gadget_path);
		close_gadget_device(&abs_mouse_gadget_fd, abs_mouse_gadget_path);
		close_gadget_device(&rel_mouse_gadget_fd, rel_mouse_gadget_path);
	}
}

/* ------------------------------------------------------------------ */

static const uint8_t keycode_to_hid_table[256] = {
	[KEY_A]          = 0x04,  [KEY_B]          = 0x05,
	[KEY_C]          = 0x06,  [KEY_D]          = 0x07,
	[KEY_E]          = 0x08,  [KEY_F]          = 0x09,
	[KEY_G]          = 0x0a,  [KEY_H]          = 0x0b,
	[KEY_I]          = 0x0c,  [KEY_J]          = 0x0d,
	[KEY_K]          = 0x0e,  [KEY_L]          = 0x0f,
	[KEY_M]          = 0x10,  [KEY_N]          = 0x11,
	[KEY_O]          = 0x12,  [KEY_P]          = 0x13,
	[KEY_Q]          = 0x14,  [KEY_R]          = 0x15,
	[KEY_S]          = 0x16,  [KEY_T]          = 0x17,
	[KEY_U]          = 0x18,  [KEY_V]          = 0x19,
	[KEY_W]          = 0x1a,  [KEY_X]          = 0x1b,
	[KEY_Y]          = 0x1c,  [KEY_Z]          = 0x1d,
	[KEY_1]          = 0x1e,  [KEY_2]          = 0x1f,
	[KEY_3]          = 0x20,  [KEY_4]          = 0x21,
	[KEY_5]          = 0x22,  [KEY_6]          = 0x23,
	[KEY_7]          = 0x24,  [KEY_8]          = 0x25,
	[KEY_9]          = 0x26,  [KEY_0]          = 0x27,
	[KEY_ENTER]      = 0x28,  [KEY_ESC]        = 0x29,
	[KEY_BACKSPACE]  = 0x2a,  [KEY_TAB]        = 0x2b,
	[KEY_SPACE]      = 0x2c,  [KEY_MINUS]      = 0x2d,
	[KEY_EQUAL]      = 0x2e,  [KEY_LEFTBRACE]  = 0x2f,
	[KEY_RIGHTBRACE] = 0x30,  [KEY_BACKSLASH]  = 0x31,
	[KEY_SEMICOLON]  = 0x33,  [KEY_APOSTROPHE] = 0x34,
	[KEY_GRAVE]      = 0x35,  [KEY_COMMA]      = 0x36,
	[KEY_DOT]        = 0x37,  [KEY_SLASH]      = 0x38,
	[KEY_CAPSLOCK]   = 0x39,
	[KEY_F1]         = 0x3a,  [KEY_F2]         = 0x3b,
	[KEY_F3]         = 0x3c,  [KEY_F4]         = 0x3d,
	[KEY_F5]         = 0x3e,  [KEY_F6]         = 0x3f,
	[KEY_F7]         = 0x40,  [KEY_F8]         = 0x41,
	[KEY_F9]         = 0x42,  [KEY_F10]        = 0x43,
	[KEY_F11]        = 0x44,  [KEY_F12]        = 0x45,
	[KEY_SYSRQ]      = 0x46,  [KEY_SCROLLLOCK] = 0x47,
	[KEY_PAUSE]      = 0x48,  [KEY_INSERT]     = 0x49,
	[KEY_HOME]       = 0x4a,  [KEY_PAGEUP]     = 0x4b,
	[KEY_DELETE]     = 0x4c,  [KEY_END]        = 0x4d,
	[KEY_PAGEDOWN]   = 0x4e,  [KEY_RIGHT]      = 0x4f,
	[KEY_LEFT]       = 0x50,  [KEY_DOWN]       = 0x51,
	[KEY_UP]         = 0x52,  [KEY_NUMLOCK]    = 0x53,
	[KEY_KPSLASH]    = 0x54,  [KEY_KPASTERISK] = 0x55,
	[KEY_KPMINUS]    = 0x56,  [KEY_KPPLUS]     = 0x57,
	[KEY_KPENTER]    = 0x58,
	[KEY_KP1]        = 0x59,  [KEY_KP2]        = 0x5a,
	[KEY_KP3]        = 0x5b,  [KEY_KP4]        = 0x5c,
	[KEY_KP5]        = 0x5d,  [KEY_KP6]        = 0x5e,
	[KEY_KP7]        = 0x5f,  [KEY_KP8]        = 0x60,
	[KEY_KP9]        = 0x61,  [KEY_KP0]        = 0x62,
	[KEY_KPDOT]      = 0x63,  [KEY_102ND]      = 0x64,
	[KEY_COMPOSE]    = 0x65,  [KEY_POWER]      = 0x66,
	[KEY_F13]        = 0x68,  [KEY_F14]        = 0x69,
	[KEY_F15]        = 0x6a,  [KEY_F16]        = 0x6b,
	[KEY_F17]        = 0x6c,  [KEY_F18]        = 0x6d,
	[KEY_F19]        = 0x6e,  [KEY_F20]        = 0x6f,
	[KEY_F21]        = 0x70,  [KEY_F22]        = 0x71,
	[KEY_F23]        = 0x72,  [KEY_F24]        = 0x73,
	[KEY_LEFTCTRL]   = 0xe0,  [KEY_LEFTSHIFT]  = 0xe1,
	[KEY_LEFTALT]    = 0xe2,  [KEY_LEFTMETA]   = 0xe3,
	[KEY_RIGHTCTRL]  = 0xe4,  [KEY_RIGHTSHIFT] = 0xe5,
	[KEY_RIGHTALT]   = 0xe6,  [KEY_RIGHTMETA]  = 0xe7,
};

static uint8_t get_modifier_bit(uint8_t hid_usage)
{
	if (hid_usage >= 0xe0 && hid_usage <= 0xe7)
		return (uint8_t)(1u << (hid_usage - 0xe0));
	return 0;
}

static inline int evbit_is_set(const uint8_t *bitmap, unsigned int bit)
{
	return (bitmap[bit / 8] & (1u << (bit % 8))) != 0;
}

static enum device_type classify_input_device(int fd)
{
	uint8_t ev_bits[EV_MAX / 8 + 1]   = { 0 };
	uint8_t key_bits[KEY_MAX / 8 + 1] = { 0 };
	uint8_t abs_bits[ABS_MAX / 8 + 1] = { 0 };
	uint8_t rel_bits[REL_MAX / 8 + 1] = { 0 };

	if (ioctl(fd, EVIOCGBIT(0, sizeof(ev_bits)), ev_bits) < 0)
		return DEVICE_NONE;

	if (!evbit_is_set(ev_bits, EV_KEY))
		return DEVICE_NONE;

	if (ioctl(fd, EVIOCGBIT(EV_KEY, sizeof(key_bits)), key_bits) < 0)
		return DEVICE_NONE;

	if (evbit_is_set(ev_bits, EV_ABS)) {
		if (ioctl(fd, EVIOCGBIT(EV_ABS, sizeof(abs_bits)), abs_bits) < 0)
			return DEVICE_NONE;
		if (evbit_is_set(abs_bits, ABS_X))
			return DEVICE_ABS_MOUSE;
	}

	if (evbit_is_set(ev_bits, EV_REL)) {
		if (ioctl(fd, EVIOCGBIT(EV_REL, sizeof(rel_bits)), rel_bits) < 0)
			return DEVICE_NONE;
		if (evbit_is_set(rel_bits, REL_X) && evbit_is_set(key_bits, BTN_LEFT))
			return DEVICE_REL_MOUSE;
	}

	if (evbit_is_set(key_bits, KEY_A))
		return DEVICE_KEYBOARD;

	return DEVICE_NONE;
}

static const char *device_type_name(enum device_type type)
{
	switch (type) {
	case DEVICE_KEYBOARD:
		return "keyboard";

	case DEVICE_ABS_MOUSE:
		return "abs-mouse";

	case DEVICE_REL_MOUSE:
		return "rel-mouse";

	default:
		return "unknown";
	}
}

/* ------------------------------------------------------------------ */

static int add_device_to_list(int fd, enum device_type type, const char *path)
{
	char device_name[256] = { 0 };
	int  index;

	if (ioctl(fd, EVIOCGRAB, 1) < 0) {
		perror("Failed to grab device");
		close(fd);
		return 1;
	}

	ioctl(fd, EVIOCGNAME(sizeof(device_name) - 1), device_name);

	pthread_mutex_lock(&device_list_lock);

	for (index = 0; index < device_count; index++) {
		if (strcmp(device_list[index].path, path) == 0) {
			pthread_mutex_unlock(&device_list_lock);
			close(fd);
			return -1;
		}
	}

	if (device_count >= MAX_INPUT_DEVICES) {
		pthread_mutex_unlock(&device_list_lock);
		printf("[WARN] Device list full, ignoring: %s\n", path);
		close(fd);
		return -1;
	}

	device_list[device_count].fd             = fd;
	device_list[device_count].type           = type;
	device_list[device_count].pending_remove = 0;
	snprintf(device_list[device_count].path,
	         sizeof(device_list[device_count].path), "%s", path);
	device_count++;

	pthread_mutex_unlock(&device_list_lock);

	printf("[INFO] Added: %-30s  %-12s  name=\"%s\"\n",
	       path, device_type_name(type), device_name);
	return 0;
}

static void mark_device_for_removal(const char *path)
{
	int index;

	pthread_mutex_lock(&device_list_lock);

	for (index = 0; index < device_count; index++) {
		if (strcmp(device_list[index].path, path) == 0) {
			device_list[index].pending_remove = 1;
			break;
		}
	}

	pthread_mutex_unlock(&device_list_lock);
}

static void scan_input_devices(void)
{
	DIR           *input_dir;
	struct dirent *dir_entry;
	char           device_path[PATH_MAX];
	int            fd;
	enum device_type type;

	printf("[INFO] Scanning %s for HID input devices...\n", INPUT_DEVICES_DIR);

	input_dir = opendir(INPUT_DEVICES_DIR);
	if (!input_dir) {
		printf("[ERROR] opendir(%s): %s\n", INPUT_DEVICES_DIR, strerror(errno));
		return;
	}

	while ((dir_entry = readdir(input_dir)) != NULL) {
		if (strncmp(dir_entry->d_name, "event", 5) != 0)
			continue;

		snprintf(device_path, sizeof(device_path), "%s/%s",
		         INPUT_DEVICES_DIR, dir_entry->d_name);

		fd = open(device_path, O_RDONLY | O_NONBLOCK | O_CLOEXEC);
		if (fd < 0)
			continue;

		type = classify_input_device(fd);
		if (type == DEVICE_NONE) {
			close(fd);
			continue;
		}

		add_device_to_list(fd, type, device_path);
	}

	closedir(input_dir);
	printf("[INFO] Scan complete: %d device(s) registered\n", device_count);
}

/* ------------------------------------------------------------------ */

static void wake_up_event_loop(void)
{
	char    wake_byte = 'w';
	ssize_t bytes_written;

	if (wake_pipe[1] < 0)
		return;

	bytes_written = write(wake_pipe[1], &wake_byte, 1);
	(void)bytes_written;
}

static void handle_hotplug_add(const char *path)
{
	enum device_type type;
	int fd;

	fd = open(path, O_RDONLY | O_NONBLOCK | O_CLOEXEC);
	if (fd < 0) {
		printf("[WARN] Hotplug add open(%s): %s\n", path, strerror(errno));
		return;
	}

	type = classify_input_device(fd);
	if (type == DEVICE_NONE) {
		close(fd);
		return;
	}

	add_device_to_list(fd, type, path);
	wake_up_event_loop();
}

static void handle_hotplug_remove(const char *path)
{
	mark_device_for_removal(path);
	wake_up_event_loop();
}

static void parse_uevent_message(const char *buf, ssize_t len)
{
	const char *ptr     = buf;
	const char *buf_end = buf + len;
	char        action[16]  = { 0 };
	char        devname[64] = { 0 };
	char        device_path[PATH_MAX];
	size_t      field_len;

	while (ptr < buf_end) {
		field_len = strnlen(ptr, (size_t)(buf_end - ptr));
		if (strncmp(ptr, "ACTION=", 7) == 0 && field_len > 7)
			snprintf(action, sizeof(action), "%.*s",
					(int)(field_len - 7), ptr + 7);
		else if (strncmp(ptr, "DEVNAME=", 8) == 0 && field_len > 8)
			snprintf(devname, sizeof(devname), "%.*s",
					(int)(field_len - 8), ptr + 8);
		ptr += field_len + 1;
		if (ptr > buf_end)
			break;
	}

	if (strncmp(devname, "input/event", 11) != 0)
		return;

	snprintf(device_path, sizeof(device_path), "/dev/%s", devname);

	if (strcmp(action, "add") == 0)
		handle_hotplug_add(device_path);
	else if (strcmp(action, "remove") == 0)
		handle_hotplug_remove(device_path);
}

static void *hotplug_listener_thread(void *arg)
{
	struct sockaddr_nl netlink_addr  = { 0 };
	int                netlink_fd;
	int                rcvbuf_size   = UEVENT_RCVBUF_SIZE;
	char               recv_buf[UEVENT_BUFFER_SIZE];
	ssize_t            bytes_received;

	(void)arg;

	netlink_fd = socket(AF_NETLINK, SOCK_RAW | SOCK_CLOEXEC, NETLINK_KOBJECT_UEVENT);
	if (netlink_fd < 0) {
		printf("[ERROR] Hotplug socket: %s\n", strerror(errno));
		return NULL;
	}

	netlink_addr.nl_family = AF_NETLINK;
	netlink_addr.nl_groups = 1;

	if (bind(netlink_fd, (struct sockaddr *)&netlink_addr, sizeof(netlink_addr)) < 0) {
		printf("[ERROR] Hotplug bind: %s\n", strerror(errno));
		close(netlink_fd);
		return NULL;
	}

	if (setsockopt(netlink_fd, SOL_SOCKET, SO_RCVBUF, &rcvbuf_size, sizeof(rcvbuf_size)) < 0)
		printf("[WARN] Hotplug SO_RCVBUF: %s (continuing)\n", strerror(errno));

	while (is_running) {
		struct pollfd poll_fd = { .fd = netlink_fd, .events = POLLIN };

		if (poll(&poll_fd, 1, HOTPLUG_POLL_MS) <= 0)
			continue;

		while ((bytes_received = recv(netlink_fd, recv_buf,
		                              sizeof(recv_buf) - 1, MSG_DONTWAIT)) > 0) {
			recv_buf[bytes_received] = '\0';
			udc_dirty = 1;
			parse_uevent_message(recv_buf, bytes_received);
		}
	}

	close(netlink_fd);
	return NULL;
}

/* ------------------------------------------------------------------ */

static void write_hid_report(int gadget_fd, const void *report_buf,
                              size_t report_len, const char *gadget_name)
{
	ssize_t bytes_written;

	if (gadget_fd < 0)
		return;

	bytes_written = write(gadget_fd, report_buf, report_len);
	if (bytes_written < 0 && errno != EAGAIN && errno != EWOULDBLOCK)
		printf("[WARN] %s: write failed: %s\n", gadget_name, strerror(errno));
}

static void send_keyboard_report(void)
{
	if (obmc_udc_active)
		write_hid_report(keyboard_gadget_fd, &kbd_report,
		                 sizeof(kbd_report), keyboard_gadget_path);
}

static void send_abs_mouse_report(void)
{
	if (obmc_udc_active)
		write_hid_report(abs_mouse_gadget_fd, &abs_report,
		                 sizeof(abs_report), abs_mouse_gadget_path);
}

static void send_rel_mouse_report(void)
{
	if (obmc_udc_active)
		write_hid_report(rel_mouse_gadget_fd, &rel_report,
		                 sizeof(rel_report), rel_mouse_gadget_path);
	rel_report.x     = 0;
	rel_report.y     = 0;
	rel_report.wheel = 0;
}

/* ------------------------------------------------------------------ */

static void process_keyboard_event(const struct input_event *ev)
{
	uint8_t hid_code, modifier_bit;
	int     slot;

	if (ev->type == EV_SYN) {
		if (ev->code == SYN_REPORT) {
			send_keyboard_report();
		} else if (ev->code == SYN_DROPPED) {
			printf("[WARN] Keyboard SYN_DROPPED — resetting state\n");
			memset(&kbd_report, 0, sizeof(kbd_report));
			send_keyboard_report();
		}
		return;
	}

	if (ev->type != EV_KEY || ev->code >= 256)
		return;

	hid_code = keycode_to_hid_table[ev->code];
	if (!hid_code)
		return;

	modifier_bit = get_modifier_bit(hid_code);
	if (modifier_bit) {
		if (ev->value)
			kbd_report.modifier |= modifier_bit;
		else
			kbd_report.modifier &= ~modifier_bit;
		return;
	}

	if (ev->value == 1) {
		for (slot = 0; slot < 6; slot++) {
			if (!kbd_report.keycode[slot]) {
				kbd_report.keycode[slot] = hid_code;
				break;
			}
		}
		if (slot == 6)
			printf("[WARN] Keyboard 6-KRO overflow, key 0x%02x dropped\n", hid_code);
	} else if (ev->value == 0) {
		for (slot = 0; slot < 6; slot++) {
			if (kbd_report.keycode[slot] == hid_code) {
				kbd_report.keycode[slot] = 0;
				break;
			}
		}
	}
}

static void process_abs_mouse_event(const struct input_event *ev)
{
	if (ev->type == EV_SYN) {
		if (ev->code == SYN_REPORT) {
			send_abs_mouse_report();
		} else if (ev->code == SYN_DROPPED) {
			printf("[WARN] Abs mouse SYN_DROPPED — resetting state\n");
			memset(&abs_report, 0, sizeof(abs_report));
			send_abs_mouse_report();
		}
		return;
	}

	if (ev->type == EV_ABS) {
		switch (ev->code) {
		case ABS_X:
			abs_report.x = (uint16_t)(ev->value & 0x7fff);
			break;
		case ABS_Y:
			abs_report.y = (uint16_t)(ev->value & 0x7fff);
			break;
		}
		return;
	}

	if (ev->type == EV_REL && ev->code == REL_WHEEL) {
		abs_report.wheel = (int8_t)ev->value;
		return;
	}

	if (ev->type == EV_KEY && ev->value != 2) {
		switch (ev->code) {
		case BTN_LEFT:
			if (ev->value) abs_report.buttons |=  (1u << 0);
			else           abs_report.buttons &= ~(1u << 0);
			break;
		case BTN_RIGHT:
			if (ev->value) abs_report.buttons |=  (1u << 1);
			else           abs_report.buttons &= ~(1u << 1);
			break;
		case BTN_MIDDLE:
			if (ev->value) abs_report.buttons |=  (1u << 2);
			else           abs_report.buttons &= ~(1u << 2);
			break;
		}
	}
}

static void process_rel_mouse_event(const struct input_event *ev)
{
	int8_t clamped_value;

	if (ev->type == EV_SYN) {
		if (ev->code == SYN_REPORT) {
			send_rel_mouse_report();
		} else if (ev->code == SYN_DROPPED) {
			printf("[WARN] Rel mouse SYN_DROPPED — resetting state\n");
			memset(&rel_report, 0, sizeof(rel_report));
			send_rel_mouse_report();
		}
		return;
	}

	if (ev->type == EV_REL) {
		clamped_value = (int8_t)(ev->value < -127 ? -127 :
		                         ev->value >  127 ?  127 : ev->value);
		switch (ev->code) {
		case REL_X:     rel_report.x     = clamped_value; break;
		case REL_Y:     rel_report.y     = clamped_value; break;
		case REL_WHEEL: rel_report.wheel = clamped_value; break;
		}
		return;
	}

	if (ev->type == EV_KEY && ev->value != 2) {
		switch (ev->code) {
		case BTN_LEFT:
			if (ev->value) rel_report.buttons |=  (1u << 0);
			else           rel_report.buttons &= ~(1u << 0);
			break;
		case BTN_RIGHT:
			if (ev->value) rel_report.buttons |=  (1u << 1);
			else           rel_report.buttons &= ~(1u << 1);
			break;
		case BTN_MIDDLE:
			if (ev->value) rel_report.buttons |=  (1u << 2);
			else           rel_report.buttons &= ~(1u << 2);
			break;
		}
	}
}

static void dispatch_input_event(enum device_type type, const struct input_event *ev)
{
	switch (type) {
	case DEVICE_KEYBOARD:  process_keyboard_event(ev);  break;
	case DEVICE_ABS_MOUSE: process_abs_mouse_event(ev); break;
	case DEVICE_REL_MOUSE: process_rel_mouse_event(ev); break;
	default:               break;
	}
}

/* ------------------------------------------------------------------ */

static void signal_handler(int sig)
{
	(void)sig;
	is_running = 0;
}

static void cleanup_all_fds(void)
{
	int index, tmp_fd;

	tmp_fd = wake_pipe[0]; wake_pipe[0] = -1; if (tmp_fd >= 0) close(tmp_fd);
	tmp_fd = wake_pipe[1]; wake_pipe[1] = -1; if (tmp_fd >= 0) close(tmp_fd);

	close_gadget_device(&keyboard_gadget_fd,  keyboard_gadget_path);
	close_gadget_device(&abs_mouse_gadget_fd, abs_mouse_gadget_path);
	close_gadget_device(&rel_mouse_gadget_fd, rel_mouse_gadget_path);

	pthread_mutex_lock(&device_list_lock);
	for (index = 0; index < device_count; index++) {
		int saved_fd = device_list[index].fd;
		device_list[index].fd = -1;
		close_input_device_fd(saved_fd);
	}
	device_count = 0;
	pthread_mutex_unlock(&device_list_lock);
}

static void print_usage(const char *program_name)
{
	printf("Usage: %s [OPTIONS]\n"
	       "\n"
	       "Forward USB HID input events to the obmc_hid USB gadget.\n"
	       "Routing is determined at runtime by reading UDC sysfs state:\n"
	       "\n"
	       "  obmc_hid active   -> hidg0 (kbd) + hidg1 (abs mouse) + hidg2 (rel mouse)\n"
	       "  obmc_hid inactive -> events dropped\n"
	       "\n"
	       "UDC state file:\n"
	       "  %s\n"
	       "\n"
	       "Options:\n"
	       "  --hidg0 PATH   keyboard  (default: /dev/hidg0)\n"
	       "  --hidg1 PATH   abs mouse (default: /dev/hidg1)\n"
	       "  --hidg2 PATH   rel mouse (default: /dev/hidg2)\n"
	       "  -h, --help     show this help and exit\n",
	       program_name, OBMC_UDC_SYSFS_PATH);
}

/* ------------------------------------------------------------------ */

int main(int argc, char *argv[])
{
	struct sigaction  signal_action = { 0 };
	pthread_t         hotplug_thread_id;
	struct pollfd     poll_fds[MAX_INPUT_DEVICES + 1];
	int               num_poll_fds;
	int               index;

	static struct option long_opts[] = {
		{ "hidg0", required_argument, NULL, '0' },
		{ "hidg1", required_argument, NULL, '1' },
		{ "hidg2", required_argument, NULL, '2' },
		{ "help",  no_argument,       NULL, 'h' },
		{ NULL,    0,                 NULL,  0  }
	};
	int opt;

	while ((opt = getopt_long(argc, argv, "h", long_opts, NULL)) != -1) {
		switch (opt) {
		case '0':
			keyboard_gadget_path = optarg;
			break;
		case '1':
			abs_mouse_gadget_path = optarg;
			break;
		case '2':
			rel_mouse_gadget_path = optarg;
			break;
		case 'h':
			print_usage(argv[0]);
			return EXIT_SUCCESS;
		default:
			fprintf(stderr, "%s: unknown option\n", argv[0]);
			print_usage(argv[0]);
			return EXIT_FAILURE;
		}
	}

	printf("[INFO] %s starting\n", PROGRAM_NAME);

	signal(SIGPIPE, SIG_IGN);

	signal_action.sa_handler = signal_handler;
	sigemptyset(&signal_action.sa_mask);
	signal_action.sa_flags = 0;

	if (sigaction(SIGTERM, &signal_action, NULL) < 0) {
		printf("[ERROR] sigaction(SIGTERM): %s\n", strerror(errno));
		return EXIT_FAILURE;
	}
	if (sigaction(SIGINT, &signal_action, NULL) < 0) {
		printf("[ERROR] sigaction(SIGINT): %s\n", strerror(errno));
		return EXIT_FAILURE;
	}

	if (pipe2(wake_pipe, O_NONBLOCK | O_CLOEXEC) < 0) {
		printf("[ERROR] pipe2: %s\n", strerror(errno));
		return EXIT_FAILURE;
	}

	refresh_udc_state();

	if (!obmc_udc_active)
		printf("[WARN] obmc_hid UDC not active at startup — waiting for UDC bind\n");

	scan_input_devices();

	if (device_count == 0)
		printf("[WARN] No input devices found at startup — waiting for hotplug\n");

	if (pthread_create(&hotplug_thread_id, NULL, hotplug_listener_thread, NULL) != 0) {
		printf("[ERROR] pthread_create: %s\n", strerror(errno));
		cleanup_all_fds();
		return EXIT_FAILURE;
	}

	printf("[INFO] Event loop started — forwarding to obmc_hid (hidg0/1/2)\n");

	while (is_running) {
		ssize_t          bytes_read;
		int              poll_ret;

		struct {
			int              fd;
			enum device_type type;
		} snap[MAX_INPUT_DEVICES];
		int snap_count;

		pthread_mutex_lock(&device_list_lock);
		for (index = 0; index < device_count; ) {
			if (!device_list[index].pending_remove) {
				index++;
				continue;
			}
			printf("[INFO] Removed: %s (%s)\n",
			       device_list[index].path,
			       device_type_name(device_list[index].type));
			int removed_fd = device_list[index].fd;
			device_list[index].fd = -1;
			memmove(&device_list[index], &device_list[index + 1],
			        (size_t)(device_count - index - 1) * sizeof(device_list[0]));
			device_count--;
			close_input_device_fd(removed_fd);
		}

		snap_count = device_count;
		for (index = 0; index < snap_count; index++) {
			snap[index].fd   = device_list[index].fd;
			snap[index].type = device_list[index].type;
			poll_fds[index].fd     = snap[index].fd;
			poll_fds[index].events = POLLIN | POLLERR | POLLHUP;
		}
		pthread_mutex_unlock(&device_list_lock);

		num_poll_fds = snap_count;
		poll_fds[num_poll_fds].fd     = wake_pipe[0];
		poll_fds[num_poll_fds].events = POLLIN;
		num_poll_fds++;

		poll_ret = poll(poll_fds, (nfds_t)num_poll_fds, -1);
		if (poll_ret < 0) {
			if (errno == EINTR)
				continue;
			printf("[ERROR] poll: %s\n", strerror(errno));
			break;
		}

		refresh_udc_state();

		/* Drain wake pipe */
		if (poll_fds[num_poll_fds - 1].revents & POLLIN) {
			char drain_buf[64];
			bytes_read = read(wake_pipe[0], drain_buf, sizeof(drain_buf));
			(void)bytes_read;
		}

		for (index = 0; index < snap_count; index++) {
			struct input_event ev;

			if (poll_fds[index].revents & (POLLERR | POLLHUP)) {
				printf("[WARN] Input device error/hangup on fd %d\n",
				       snap[index].fd);

				pthread_mutex_lock(&device_list_lock);
				for (int j = 0; j < device_count; j++) {
					if (device_list[j].fd == snap[index].fd) {
						device_list[j].pending_remove = 1;
						break;
					}
				}
				pthread_mutex_unlock(&device_list_lock);
				wake_up_event_loop();
				continue;
			}

			if (!(poll_fds[index].revents & POLLIN))
				continue;

			while ((bytes_read = read(snap[index].fd, &ev, sizeof(ev)))
			       == (ssize_t)sizeof(ev)) {
				dispatch_input_event(snap[index].type, &ev);
			}

			if (bytes_read < 0 && errno != EAGAIN && errno != EWOULDBLOCK)
				printf("[WARN] read(fd=%d): %s\n",
				       snap[index].fd, strerror(errno));
		}
	}

	printf("[INFO] %s shutting down\n", PROGRAM_NAME);

	pthread_join(hotplug_thread_id, NULL);

	memset(&kbd_report, 0, sizeof(kbd_report));
	memset(&abs_report, 0, sizeof(abs_report));
	memset(&rel_report, 0, sizeof(rel_report));

	if (obmc_udc_active) {
		send_keyboard_report();
		send_abs_mouse_report();
		send_rel_mouse_report();
	}

	cleanup_all_fds();

	printf("[INFO] %s stopped\n", PROGRAM_NAME);
	return EXIT_SUCCESS;
}

