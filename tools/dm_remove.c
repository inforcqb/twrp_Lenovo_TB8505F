/*
 * dm_remove - remove a stale device-mapper device by name.
 *
 * vold (Android 10 FDE) and TWRP's built-in cryptfs leave the "userdata"
 * dm-crypt device behind when a checkpw attempt fails after the master key
 * was decrypted. A leftover dm-0 then makes every later decrypt attempt fail
 * with:
 *   "Cannot create dm-crypt device userdata: Device or resource busy"
 *
 * This tiny static helper issues DM_DEV_REMOVE so the stale device can be
 * cleaned up before retrying. Built by CI (see .github/workflows/build.yml)
 * with aarch64-linux-gnu-gcc -static and installed to /sbin/dm_remove.
 *
 * The ioctl setup mirrors Android's ioctl_init() (system/vold/cryptfs.cpp):
 * data_size must be a large buffer (DM_CRYPT_BUF_SIZE == 4096), NOT
 * sizeof(struct dm_ioctl), and version 4.0.0. A bare sizeof() buffer makes
 * the kernel reject the call with EINVAL.
 *
 * Usage: dm_remove <dm-name>     (e.g. dm_remove userdata)
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <linux/dm-ioctl.h>

#define DM_CRYPT_BUF_SIZE 4096

int main(int argc, char** argv)
{
	char buffer[DM_CRYPT_BUF_SIZE];
	struct dm_ioctl *io = (struct dm_ioctl*)buffer;
	int fd;

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
	io->data_size = sizeof(buffer);		/* full 4096 buffer, like Android */
	io->data_start = sizeof(struct dm_ioctl);
	io->version[0] = 4;
	io->version[1] = 0;
	io->version[2] = 0;
	strncpy(io->name, argv[1], sizeof(io->name) - 1);
	io->name[sizeof(io->name) - 1] = '\0';

	if (ioctl(fd, DM_DEV_REMOVE, io) < 0) {
		perror("DM_DEV_REMOVE");
		close(fd);
		return 1;
	}

	close(fd);
	printf("removed dm device '%s'\n", argv[1]);
	return 0;
}
