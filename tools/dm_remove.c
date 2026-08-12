/*
 * dm_remove - remove a stale device-mapper device by name.
 *
 * vold (Android 10 FDE) and TWRP's built-in cryptfs leave the "userdata"
 * dm-crypt device behind when a checkpw attempt fails. A leftover dm-0 then
 * makes every later decrypt attempt fail with:
 *   "Cannot create dm-crypt device userdata: Device or resource busy"
 *
 * The ioctl struct is defined manually to match the Android 4.9 kernel
 * (include/uapi/linux/dm-ioctl.h, DM_VERSION 4.35.0). Using glibc's
 * linux/dm-ioctl.h can mismatch, and the ioctl command must carry the
 * struct size (like the kernel's _IOWR(DM_IOCTL, CMD, struct dm_ioctl)),
 * otherwise the kernel rejects it:
 *   "device-mapper: ioctl: ioctl interface mismatch: kernel(4.35.0), user(x)"
 * data_size must be 4096 (DM_CRYPT_BUF_SIZE), like Android's ioctl_init().
 *
 * Usage: dm_remove <dm-name>     (e.g. dm_remove userdata)
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>
#include <sys/ioctl.h>

#define DM_CRYPT_BUF_SIZE 4096
#define DM_NAME_LEN 128
#define DM_UUID_LEN 129

/* struct dm_ioctl layout, kernel 4.9 (include/uapi/linux/dm-ioctl.h) */
struct dm_ioctl_49 {
	unsigned int version[3];	/* 4.35.0 on Android 4.9 */
	unsigned int data_size;
	unsigned int data_start;
	unsigned int target_count;
	int open_count;
	unsigned int flags;
	unsigned int event_nr;
	unsigned int padding;
	unsigned long long dev;
	char name[DM_NAME_LEN];
	char uuid[DM_UUID_LEN];
	char data[7];
};

/* DM_IOCTL = 0xfd; command numbers from the kernel enum:
 * DM_DEV_REMOVE_CMD = 4, DM_DEV_WAIT_CMD = 8. */
#define DM_IOCTL 0xfd
#define DM_DEV_WAIT_CMD    8
#define DM_DEV_REMOVE_CMD  4

/* _IOWR(type, nr, size) -> (dir<<30)|(size<<16)|(type<<8)|nr */
#define DM_DEV_WAIT_IOCTL    (((3u)<<30) | ((sizeof(struct dm_ioctl_49))<<16) | ((DM_IOCTL)<<8) | DM_DEV_WAIT_CMD)
#define DM_DEV_REMOVE_IOCTL  (((3u)<<30) | ((sizeof(struct dm_ioctl_49))<<16) | ((DM_IOCTL)<<8) | DM_DEV_REMOVE_CMD)

int main(int argc, char** argv)
{
	char buffer[DM_CRYPT_BUF_SIZE];
	struct dm_ioctl_49 *io = (struct dm_ioctl_49*)buffer;
	int fd, rc;

	if (argc < 2) {
		fprintf(stderr, "usage: %s <dm-name>\n", argv[0]);
		return 1;
	}

	fd = open("/dev/device-mapper", O_RDWR | O_CLOEXEC);
	if (fd < 0) {
		perror("open /dev/device-mapper");
		return 1;
	}

	memset(buffer, 0, sizeof(buffer));
	io->version[0] = 4;
	io->version[1] = 35;	/* Android 4.9 kernel DM_VERSION_MINOR */
	io->version[2] = 0;
	io->data_size = sizeof(buffer);
	io->data_start = sizeof(struct dm_ioctl_49);
	strncpy(io->name, argv[1], sizeof(io->name) - 1);

	fprintf(stderr, "dbg: ver=%u.%u.%u data_size=%u data_start=%u cmd=0x%08x\n",
		io->version[0], io->version[1], io->version[2],
		io->data_size, io->data_start, DM_DEV_REMOVE_IOCTL);

	rc = ioctl(fd, DM_DEV_WAIT_IOCTL, io);
	if (rc < 0)
		fprintf(stderr, "DM_DEV_WAIT: %s (continuing)\n", strerror(errno));

	rc = ioctl(fd, DM_DEV_REMOVE_IOCTL, io);
	if (rc < 0) {
		perror("DM_DEV_REMOVE");
		close(fd);
		return 1;
	}

	close(fd);
	printf("removed dm device '%s'\n", argv[1]);
	return 0;
}
