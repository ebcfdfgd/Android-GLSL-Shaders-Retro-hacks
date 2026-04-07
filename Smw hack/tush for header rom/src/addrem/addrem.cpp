#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "addrem.h"

/* Load the rom into memory */
/* Adapted from anyexample.com */
int loadRom(char *fname, char **fdata) {
	unsigned int fsize;
	FILE *rom = fopen(fname, "rb");
	if (rom == NULL) {
		*fdata = NULL;
		return ERROR_OPENREAD;
	}
	fseek(rom, 0, SEEK_END);
	fsize = ftell(rom);
	fseek(rom, 0, SEEK_SET);
	*fdata = (char *)malloc(fsize + 1);
	if (fsize != fread(*fdata, 1, fsize, rom)) {
		free(*fdata);
		return ERROR_OPENREAD;
	}
	fclose(rom);
	(*fdata)[fsize] = 0;
	return fsize;
}

/* Removes a header from the file specified by 'fname.'
 * - Returns 0 on success, otherwise it returns an error code (see addrem.h) */
int remHeader(char *fname) {
	FILE *rom;
	int fsize;
	char *fdata;

	fsize = loadRom(fname, &fdata);
	if (fsize == ERROR_OPENREAD)
		return ERROR_OPENREAD;

	rom = fopen(fname, "wb");
	fwrite(fdata + 0x200, 1, fsize - 0x200, rom);
	fclose(rom);

	return 0;
}

/* Adds a header to the file specified by 'fname.'
 * - Returns 0 on success, otherwise it returns an error code (see addrem.h) */
int addHeader(char *fname) {
	FILE *rom;
	int fsize;
	char *fdata;
	char header[0x200] = {0};

	fsize = loadRom(fname, &fdata);
	if (fsize == ERROR_OPENREAD)
		return ERROR_OPENREAD;

	rom = fopen(fname, "wb");
	fwrite(header, 1, 0x200, rom); /* Write empty header */
	fwrite(fdata, 1, fsize, rom); /* Write the rom */
	fclose(rom);

	return 0;
}

int chkHeader(char *fname) { /* Check for a header */
	FILE *rom;
	int fsize;

	rom = fopen(fname, "rb");
	if (rom == NULL)
		return ERROR_OPENREAD;
	fseek(rom, 0, SEEK_END);
	fsize = ftell(rom);
	fclose(rom);

	if ((fsize % 0x8000) == 0) /* There's no header */
		return STAT_NOHEADER;
	else if ((fsize % 0x8000) == 0x200) /* There's a header */
		return STAT_HEADER;
	else /* Header isn't the right size */
		return ERROR_FAILDETECT;
}
