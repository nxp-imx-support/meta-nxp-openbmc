// SPDX-License-Identifier: GPL-2.0
// Copyright 2026 NXP
//
// fpga_pldm_mctp - a minimal PLDM-over-MCTP responder that presents the FPGA
// SIM as a PLDM terminus with one numeric temperature sensor.
//
// Why this exists
// ---------------
// The imx9-qspi-mailbox is a sensor-register protocol (DISCOVERY /
// CONFIGURATION / SENSOR_DATA / ALERTS / ...); it is not an MCTP packet
// transport, and the kernel driver exposes hwmon / i2c / gpio sub-devices
// rather than an MCTP network device. So a real host cannot tunnel PLDM
// inside the mailbox today. This responder instead sits on the BMC's already
// enabled MCTP stack (AF_MCTP) and answers PLDM requests, sourcing its live
// sensor value from the FPGA SIM via the proven path:
//
//   fpga_sim -> mailbox -> kernel hwmon (tempN_input) -> [ this responder ]
//     -> PLDM over MCTP (AF_MCTP) -> pldmd platform-mc terminus discovery
//     -> xyz.openbmc_project.Sensor.Value -> Redfish -> OpenBMC WebUI
//
// It implements just enough PLDM to be discovered and polled by pldmd:
//   base   (type 0): GetTID, SetTID, GetPLDMTypes, GetPLDMVersion,
//                    GetPLDMCommands
//   platform(type 2): GetPDRRepositoryInfo, GetPDR, GetSensorReading
//
// The exported PDR set is a Terminus Locator PDR plus one Numeric Sensor PDR
// describing a temperature sensor (base unit degrees C). GetSensorReading
// returns the current hwmon value read from sysfs.
//
// This is intentionally a small, dependency-light C program: it does not link
// libpldm and defines the AF_MCTP sockaddr locally when the kernel uapi header
// is not present in the build sysroot, so it cross-compiles cleanly for any
// OpenBMC image that ships the MCTP kernel support.

#include <errno.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include <sys/socket.h>
#include <sys/types.h>

// --- AF_MCTP fallback shim --------------------------------------------------
// Recent kernels ship <linux/mctp.h>. When building against an older sysroot
// we define the minimum needed to open and use an MCTP datagram socket.
#if defined(__has_include)
#  if __has_include(<linux/mctp.h>)
#    include <linux/mctp.h>
#    define HAVE_LINUX_MCTP 1
#  endif
#endif

#ifndef HAVE_LINUX_MCTP
#ifndef AF_MCTP
#define AF_MCTP 45
#endif
typedef uint8_t mctp_eid_t;
struct mctp_addr {
	mctp_eid_t s_addr;
};
struct sockaddr_mctp {
	unsigned short int smctp_family; // AF_MCTP
	uint16_t __smctp_pad0;
	unsigned int smctp_network;
	struct mctp_addr smctp_addr;
	uint8_t smctp_type;
	uint8_t smctp_tag;
	uint8_t __smctp_pad1;
};
#define MCTP_TAG_OWNER 0x08
#define MCTP_NET_ANY 0
#define MCTP_ADDR_ANY 0xff
#endif // !HAVE_LINUX_MCTP

// --- MCTP / PLDM constants --------------------------------------------------

#define MCTP_MSG_TYPE_PLDM 0x01

// PLDM header byte 0 bits.
#define PLDM_RQ 0x80
#define PLDM_DATAGRAM 0x40
#define PLDM_INST_MASK 0x1f

// PLDM types.
#define PLDM_TYPE_BASE 0x00
#define PLDM_TYPE_PLATFORM 0x02

// PLDM base commands.
#define PLDM_SET_TID 0x01
#define PLDM_GET_TID 0x02
#define PLDM_GET_PLDM_VERSION 0x03
#define PLDM_GET_PLDM_TYPES 0x04
#define PLDM_GET_PLDM_COMMANDS 0x05

// PLDM platform commands.
#define PLDM_GET_PDR_REPOSITORY_INFO 0x50
#define PLDM_GET_PDR 0x51
#define PLDM_GET_SENSOR_READING 0x11

// PLDM completion codes.
#define PLDM_SUCCESS 0x00
#define PLDM_ERROR 0x01
#define PLDM_ERROR_INVALID_DATA 0x03
#define PLDM_ERROR_UNSUPPORTED_PLDM_CMD 0x05
#define PLDM_ERROR_INVALID_PLDM_TYPE 0x20

// PDR types.
#define PLDM_TERMINUS_LOCATOR_PDR 1
#define PLDM_NUMERIC_SENSOR_PDR 2

// Numeric sensor reading data size / range field format = uint8.
#define PLDM_SENSOR_DATA_SIZE_UINT8 0
// Sensor operational / event state.
#define PLDM_SENSOR_ENABLED 1
#define PLDM_SENSOR_NORMAL 1
#define PLDM_NO_EVENT_GENERATION 0

#define PDR_HANDLE_TERMINUS 1
#define PDR_HANDLE_SENSOR 2

#define SENSOR_ID 1
#define TERMINUS_HANDLE 1
#define CONTAINER_ID 0
#define ENTITY_TYPE_SYS_BOARD 64

// base unit code 2 == degrees Celsius (per PLDM sensor unit enumeration).
#define PLDM_SENSOR_UNIT_DEGRESS_C 2

// --- Configuration ----------------------------------------------------------

static const char *g_hwmon_path =
	"/sys/class/hwmon/hwmon0/temp1_input"; // milli-degrees C
static uint8_t g_tid = 1;

// --- Helpers ----------------------------------------------------------------

static void log_msg(const char *fmt, ...)
{
	va_list ap;
	va_start(ap, fmt);
	fprintf(stderr, "fpga_pldm_mctp: ");
	vfprintf(stderr, fmt, ap);
	fprintf(stderr, "\n");
	va_end(ap);
}

// Read the live sensor value from hwmon (originates in fpga_sim over the
// mailbox). Returns degrees C rounded to nearest integer, or a fallback.
static uint8_t read_sensor_value_c(void)
{
	FILE *f = fopen(g_hwmon_path, "r");
	long milli_c;

	if (f == NULL) {
		log_msg("hwmon read failed (%s): %s; using fallback",
			g_hwmon_path, strerror(errno));
		return 38; // matches fpga_sim tmp75 default 38.25 C
	}
	if (fscanf(f, "%ld", &milli_c) != 1) {
		fclose(f);
		return 38;
	}
	fclose(f);
	return (uint8_t)((milli_c + 500) / 1000);
}

// little-endian store helpers.
static void put_u16(uint8_t *p, uint16_t v)
{
	p[0] = (uint8_t)(v & 0xff);
	p[1] = (uint8_t)((v >> 8) & 0xff);
}

static void put_u32(uint8_t *p, uint32_t v)
{
	p[0] = (uint8_t)(v & 0xff);
	p[1] = (uint8_t)((v >> 8) & 0xff);
	p[2] = (uint8_t)((v >> 16) & 0xff);
	p[3] = (uint8_t)((v >> 24) & 0xff);
}

// --- PDR repository ---------------------------------------------------------
//
// We build the two PDRs once into a flat repository buffer. GetPDR walks it by
// record handle.

#define PDR_COMMON_HDR_LEN 10

// Build a PDR common header at p. Returns pointer just past the header.
static uint8_t *pdr_hdr(uint8_t *p, uint32_t record_handle, uint8_t pdr_type,
			uint16_t data_len)
{
	put_u32(p, record_handle); // recordHandle
	p[4] = 1; // PDRHeaderVersion
	p[5] = pdr_type; // PDRType
	put_u16(p + 6, 0); // recordChangeNumber
	put_u16(p + 8, data_len); // dataLength
	return p + PDR_COMMON_HDR_LEN;
}

static uint8_t g_terminus_pdr[64];
static size_t g_terminus_pdr_len;
static uint8_t g_sensor_pdr[128];
static size_t g_sensor_pdr_len;

static void build_terminus_locator_pdr(void)
{
	uint8_t body[16];
	uint8_t *b = body;

	// Terminus Locator PDR body (type 1).
	put_u16(b, TERMINUS_HANDLE);
	b += 2; // PLDMTerminusHandle
	*b++ = 1; // validity: valid
	*b++ = g_tid; // TID
	put_u16(b, CONTAINER_ID);
	b += 2; // containerID
	*b++ = 0; // terminusLocatorType: UID (0)
	*b++ = 1; // terminusLocatorValueSize
	*b++ = g_tid; // terminusLocatorValue (EID/TID)

	uint16_t body_len = (uint16_t)(b - body);
	uint8_t *p = g_terminus_pdr;
	uint8_t *after = pdr_hdr(p, PDR_HANDLE_TERMINUS,
				 PLDM_TERMINUS_LOCATOR_PDR, body_len);
	memcpy(after, body, body_len);
	g_terminus_pdr_len = PDR_COMMON_HDR_LEN + body_len;
}

static void build_numeric_sensor_pdr(void)
{
	uint8_t body[96];
	memset(body, 0, sizeof(body));
	uint8_t *b = body;

	// Numeric Sensor PDR body (type 2), trimmed to the fields pldmd needs.
	put_u16(b, TERMINUS_HANDLE);
	b += 2; // PLDMTerminusHandle
	put_u16(b, SENSOR_ID);
	b += 2; // sensorID
	put_u16(b, ENTITY_TYPE_SYS_BOARD);
	b += 2; // entityType
	put_u16(b, 1);
	b += 2; // entityInstanceNumber
	put_u16(b, CONTAINER_ID);
	b += 2; // containerID
	*b++ = 0; // sensorInit: noInit
	*b++ = 0; // sensorAuxiliaryNamesPDR: false
	*b++ = PLDM_SENSOR_UNIT_DEGRESS_C; // baseUnit: degrees C
	*b++ = 0; // unitModifier
	*b++ = 0; // rateUnit
	*b++ = 0; // baseOEMUnitHandle
	*b++ = 0; // auxUnit
	*b++ = 0; // auxUnitModifier
	*b++ = 0; // auxRateUnit
	*b++ = 0; // rel
	*b++ = 0; // auxOEMUnitHandle
	*b++ = 0; // isLinear: true(0)
	*b++ = PLDM_SENSOR_DATA_SIZE_UINT8; // sensorDataSize: uint8
	// resolution (real32) = 1.0, offset (real32) = 0.0
	put_u32(b, 0x3f800000);
	b += 4; // resolution 1.0f
	put_u32(b, 0x00000000);
	b += 4; // offset 0.0f
	put_u16(b, 0);
	b += 2; // accuracy
	*b++ = 0; // plusTolerance
	*b++ = 0; // minusTolerance
	*b++ = 0; // hysteresis (uint8)
	*b++ = 0; // supportedThresholds
	*b++ = 0; // thresholdAndHysteresisVolatility
	put_u32(b, 0x3f800000);
	b += 4; // stateTransitionInterval 1.0f
	put_u32(b, 0x3f800000);
	b += 4; // updateInterval 1.0f
	*b++ = 0xff; // maxReadable (uint8)
	*b++ = 0x00; // minReadable (uint8)
	*b++ = PLDM_SENSOR_DATA_SIZE_UINT8; // rangeFieldFormat: uint8
	*b++ = 0; // rangeFieldSupport: none

	uint16_t body_len = (uint16_t)(b - body);
	uint8_t *p = g_sensor_pdr;
	uint8_t *after =
		pdr_hdr(p, PDR_HANDLE_SENSOR, PLDM_NUMERIC_SENSOR_PDR, body_len);
	memcpy(after, body, body_len);
	g_sensor_pdr_len = PDR_COMMON_HDR_LEN + body_len;
}

// Return the PDR record for a given record handle (0 == first). Sets
// next_handle (0 when this is the last record). Returns NULL if not found.
static const uint8_t *pdr_by_handle(uint32_t handle, size_t *len,
				    uint32_t *next_handle)
{
	if (handle == 0 || handle == PDR_HANDLE_TERMINUS) {
		*len = g_terminus_pdr_len;
		*next_handle = PDR_HANDLE_SENSOR;
		return g_terminus_pdr;
	}
	if (handle == PDR_HANDLE_SENSOR) {
		*len = g_sensor_pdr_len;
		*next_handle = 0; // last record
		return g_sensor_pdr;
	}
	return NULL;
}

// --- PLDM request handling --------------------------------------------------
//
// req points at the PLDM header (byte 0). req_len is the PLDM message length
// (excluding the leading MCTP message-type byte). resp is filled with the
// PLDM response message; returns the response length or 0 to drop.

static size_t make_resp_hdr(const uint8_t *req, uint8_t *resp)
{
	// Response: clear Rq, keep instance id + type + command.
	resp[0] = (uint8_t)(req[0] & PLDM_INST_MASK); // Rq=0, D=0
	resp[1] = req[1]; // hdrVer + type
	resp[2] = req[2]; // command
	return 3;
}

static size_t handle_base(const uint8_t *req, size_t req_len, uint8_t *resp)
{
	uint8_t cmd = req[2];
	size_t n = make_resp_hdr(req, resp);

	switch (cmd) {
	case PLDM_GET_TID:
		resp[n++] = PLDM_SUCCESS;
		resp[n++] = g_tid;
		return n;
	case PLDM_SET_TID:
		if (req_len >= 4)
			g_tid = req[3];
		resp[n++] = PLDM_SUCCESS;
		return n;
	case PLDM_GET_PLDM_TYPES:
		resp[n++] = PLDM_SUCCESS;
		// 8-byte bitfield: bit0=base, bit2=platform.
		memset(resp + n, 0, 8);
		resp[n + 0] = (uint8_t)((1u << PLDM_TYPE_BASE) |
					(1u << PLDM_TYPE_PLATFORM));
		n += 8;
		return n;
	case PLDM_GET_PLDM_VERSION:
		resp[n++] = PLDM_SUCCESS;
		put_u32(resp + n, 0);
		n += 4; // nextTransferHandle
		resp[n++] = 0x05; // transferFlag: start+end
		// version 1.0.0 in BCD-ish ver32 (0xF1F0F000).
		put_u32(resp + n, 0xf1f0f000);
		n += 4;
		return n;
	case PLDM_GET_PLDM_COMMANDS: {
		resp[n++] = PLDM_SUCCESS;
		uint8_t bits[32];
		memset(bits, 0, sizeof(bits));
		// Advertise supported base OR platform commands based on the
		// requested type in the payload (req[3]).
		uint8_t type = (req_len >= 4) ? req[3] : PLDM_TYPE_BASE;
		if (type == PLDM_TYPE_BASE) {
			bits[PLDM_SET_TID / 8] |= 1u << (PLDM_SET_TID % 8);
			bits[PLDM_GET_TID / 8] |= 1u << (PLDM_GET_TID % 8);
			bits[PLDM_GET_PLDM_VERSION / 8] |=
				1u << (PLDM_GET_PLDM_VERSION % 8);
			bits[PLDM_GET_PLDM_TYPES / 8] |=
				1u << (PLDM_GET_PLDM_TYPES % 8);
			bits[PLDM_GET_PLDM_COMMANDS / 8] |=
				1u << (PLDM_GET_PLDM_COMMANDS % 8);
		} else if (type == PLDM_TYPE_PLATFORM) {
			bits[PLDM_GET_SENSOR_READING / 8] |=
				1u << (PLDM_GET_SENSOR_READING % 8);
			bits[PLDM_GET_PDR_REPOSITORY_INFO / 8] |=
				1u << (PLDM_GET_PDR_REPOSITORY_INFO % 8);
			bits[PLDM_GET_PDR / 8] |= 1u << (PLDM_GET_PDR % 8);
		}
		memcpy(resp + n, bits, sizeof(bits));
		n += sizeof(bits);
		return n;
	}
	default:
		resp[n++] = PLDM_ERROR_UNSUPPORTED_PLDM_CMD;
		return n;
	}
}

static size_t handle_platform(const uint8_t *req, size_t req_len, uint8_t *resp)
{
	uint8_t cmd = req[2];
	size_t n = make_resp_hdr(req, resp);

	switch (cmd) {
	case PLDM_GET_PDR_REPOSITORY_INFO: {
		resp[n++] = PLDM_SUCCESS;
		resp[n++] = 0; // repositoryState: available
		memset(resp + n, 0, 13);
		n += 13; // updateTime (13 bytes timestamp104)
		memset(resp + n, 0, 13);
		n += 13; // oemUpdateTime
		put_u32(resp + n, 2);
		n += 4; // recordCount
		uint32_t repo_size =
			(uint32_t)(g_terminus_pdr_len + g_sensor_pdr_len);
		put_u32(resp + n, repo_size);
		n += 4; // repositorySize
		put_u32(resp + n, (uint32_t)g_sensor_pdr_len);
		n += 4; // largestRecordSize
		resp[n++] = 0; // dataTransferHandleTimeout
		return n;
	}
	case PLDM_GET_PDR: {
		if (req_len < 3 + 13) {
			resp[n++] = PLDM_ERROR_INVALID_DATA;
			return n;
		}
		// request: recordHandle(4) dataTransferHandle(4)
		// transferOpFlag(1) requestCount(2) recordChangeNumber(2)
		uint32_t handle = (uint32_t)req[3] | ((uint32_t)req[4] << 8) |
				  ((uint32_t)req[5] << 16) |
				  ((uint32_t)req[6] << 24);
		size_t pdr_len;
		uint32_t next;
		const uint8_t *pdr = pdr_by_handle(handle, &pdr_len, &next);
		if (pdr == NULL) {
			resp[n++] = PLDM_ERROR_INVALID_DATA;
			return n;
		}
		resp[n++] = PLDM_SUCCESS;
		put_u32(resp + n, next);
		n += 4; // nextRecordHandle
		put_u32(resp + n, 0);
		n += 4; // nextDataTransferHandle
		resp[n++] = 0x05; // transferFlag: start+end (single-part)
		put_u16(resp + n, (uint16_t)pdr_len);
		n += 2; // responseCount
		memcpy(resp + n, pdr, pdr_len);
		n += pdr_len;
		resp[n++] = 0; // transferCRC (only when multipart; 0 here)
		return n;
	}
	case PLDM_GET_SENSOR_READING: {
		if (req_len < 3 + 3) {
			resp[n++] = PLDM_ERROR_INVALID_DATA;
			return n;
		}
		uint16_t sid = (uint16_t)req[3] | ((uint16_t)req[4] << 8);
		if (sid != SENSOR_ID) {
			resp[n++] = PLDM_ERROR_INVALID_DATA;
			return n;
		}
		resp[n++] = PLDM_SUCCESS;
		resp[n++] = PLDM_SENSOR_DATA_SIZE_UINT8; // sensorDataSize
		resp[n++] = PLDM_SENSOR_ENABLED; // sensorOperationalState
		resp[n++] = PLDM_NO_EVENT_GENERATION; // sensorEventMessageEnable
		resp[n++] = PLDM_SENSOR_NORMAL; // presentState
		resp[n++] = PLDM_SENSOR_NORMAL; // previousState
		resp[n++] = PLDM_SENSOR_NORMAL; // eventState
		resp[n++] = read_sensor_value_c(); // presentReading (uint8)
		return n;
	}
	default:
		resp[n++] = PLDM_ERROR_UNSUPPORTED_PLDM_CMD;
		return n;
	}
}

static size_t handle_pldm(const uint8_t *req, size_t req_len, uint8_t *resp)
{
	if (req_len < 3)
		return 0;

	uint8_t type = req[1] & 0x3f;

	if (type == PLDM_TYPE_BASE)
		return handle_base(req, req_len, resp);
	if (type == PLDM_TYPE_PLATFORM)
		return handle_platform(req, req_len, resp);

	size_t n = make_resp_hdr(req, resp);
	resp[n++] = PLDM_ERROR_INVALID_PLDM_TYPE;
	return n;
}

// --- Main loop --------------------------------------------------------------

int main(int argc, char **argv)
{
	int sock;
	struct sockaddr_mctp addr;

	if (argc > 1)
		g_hwmon_path = argv[1];
	if (argc > 2)
		g_tid = (uint8_t)atoi(argv[2]);

	build_terminus_locator_pdr();
	build_numeric_sensor_pdr();

	sock = socket(AF_MCTP, SOCK_DGRAM, 0);
	if (sock < 0) {
		log_msg("socket(AF_MCTP) failed: %s", strerror(errno));
		return 1;
	}

	memset(&addr, 0, sizeof(addr));
	addr.smctp_family = AF_MCTP;
	addr.smctp_network = MCTP_NET_ANY;
	addr.smctp_addr.s_addr = MCTP_ADDR_ANY;
	addr.smctp_type = MCTP_MSG_TYPE_PLDM;
	addr.smctp_tag = MCTP_TAG_OWNER;

	if (bind(sock, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
		log_msg("bind(AF_MCTP) failed: %s", strerror(errno));
		close(sock);
		return 1;
	}

	log_msg("listening for PLDM on MCTP (tid=%u, hwmon=%s)", g_tid,
		g_hwmon_path);

	for (;;) {
		uint8_t rx[512];
		uint8_t tx[1024];
		struct sockaddr_mctp peer;
		socklen_t peer_len = sizeof(peer);
		ssize_t r;

		memset(&peer, 0, sizeof(peer));
		r = recvfrom(sock, rx, sizeof(rx), 0,
			     (struct sockaddr *)&peer, &peer_len);
		if (r < 0) {
			if (errno == EINTR)
				continue;
			log_msg("recvfrom failed: %s", strerror(errno));
			break;
		}
		if (r < 2 || rx[0] != MCTP_MSG_TYPE_PLDM)
			continue; // not a PLDM message

		// rx[0] is the MCTP message type; PLDM message starts at rx[1].
		size_t resp_len = handle_pldm(rx + 1, (size_t)r - 1, tx + 1);
		if (resp_len == 0)
			continue;
		tx[0] = MCTP_MSG_TYPE_PLDM;

		// Reply to the requester; clear TAG_OWNER so we answer on the
		// tag the requester allocated.
		peer.smctp_tag &= (uint8_t)~MCTP_TAG_OWNER;
		if (sendto(sock, tx, resp_len + 1, 0,
			   (struct sockaddr *)&peer, peer_len) < 0)
			log_msg("sendto failed: %s", strerror(errno));
	}

	close(sock);
	return 0;
}
