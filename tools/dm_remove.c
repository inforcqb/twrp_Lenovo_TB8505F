/*
 * dm_remove - remove a stale device-mapper device by name.
 *
 * Removes the leftover "userdata" dm-crypt device that TWRP/vold leave
 * behind when a checkpw attempt fails. DM_DEV_REMOVE on a device that was
 * created but never loaded with a table (or that the kernel considers
 * "inactive") can return EINVAL; the robust sequence is:
 *   1. DM_DEV_WAIT (let it settle)
 *   2. DM_DEV_REMOVE
 * Both use the same ioctl buffer layout as Android's ioctl_init():
 * data_size = 4096 (DM_CRYPT_BUF_SIZE), version 4.0.0.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>
#include <sys/ioctl.h>
#include <linux/dm-ioctl.h>

#define DM_CRYPT_BUF_SIZE 4096

static void ioctl_init(struct dm_ioctl *io, size_t dataSize, const char *name)
{
	memset(io, 0, dataSize);
	io->data_size = dataSize;
	io->data_start = sizeof(struct dm_ioctl);
	io->version[0] = 4;
	io->version[1] = 0;
	io->version[2] = 0;
	if (name)
		strncpy(io->name, name, sizeof(io->name) - 1);
}

int main(int argc, char** argv)
{
	char buffer[DM_CRYPT_BUF_SIZE];
	struct dm_ioctl *io = (struct dm_ioctl*)buffer;
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

	/* Wait for the device to settle first (helps with inactive devices). */
	ioctl_init(io, sizeof(buffer), argv[1]);
	rc = ioctl(fd, DM_DEV_WAIT, io);
	if (rc < 0)
		fprintf(stderr, "DM_DEV_WAIT: %s (continuing)\n", strerror(errno));

	/* Now remove it. */
	ioctl_init(io, sizeof(buffer), argv[1]);
	rc = ioctl(fd, DM_DEV_REMOVE, io);
	if (rc < 0) {
		perror("DM_DEV_REMOVE");
		close(fd);
		return 1;
	}

	close(fd);
	printf("removed dm device '%s'\n", argv[1]);
	return 0;
}
