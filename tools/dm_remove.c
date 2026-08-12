/*
 * dm_remove - remove a stale device-mapper device by name.
 *
 * vold (Android 10 FDE) leaves the "userdata" dm-crypt device behind when a
 * checkpw attempt fails after the master key was decrypted. A leftover dm-0
 * then makes every later decrypt attempt fail with:
 *   "Cannot create dm-crypt device userdata: Device or resource busy"
 *
 * This tiny static helper issues DM_DEV_REMOVE so the stale device can be
 * cleaned up before retrying. Built by CI (see .github/workflows/build.yml)
 * with aarch64-linux-gnu-gcc -static and installed to /sbin/dm_remove.
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

int main(int argc, char** argv)
{
	struct dm_ioctl io;
	int fd;

	if (argc < 2) {
		fprintf(stderr, "usage: %s <dm-name>\n", argv[0]);
		return 1;
	}

	fd = open("/dev/device-mapper", O_RDWR);
	if (fd < 0) {
		perror("open /dev/device-mapper");
		return 1;
	}

	memset(&io, 0, sizeof(io));
	io.version[0] = DM_VERSION_MAJOR;
	io.version[1] = DM_VERSION_MINOR;
	io.version[2] = DM_VERSION_PATCHLEVEL;
	io.data_size = sizeof(io);
	io.data_start = sizeof(io);
	strncpy(io.name, argv[1], sizeof(io.name) - 1);
	io.name[sizeof(io.name) - 1] = '\0';

	if (ioctl(fd, DM_DEV_REMOVE, &io) < 0) {
		perror("DM_DEV_REMOVE");
		close(fd);
		return 1;
	}

	close(fd);
	printf("removed dm device '%s'\n", argv[1]);
	return 0;
}
