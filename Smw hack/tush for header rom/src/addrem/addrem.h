#ifndef INC_ADDREM_H
#define INC_ADDREM_H

/* Error codes (negative so they can't be mistaken for filesizes) */
#define ERROR_OPENREAD   (-1) /* Problem opening file to read */
#define ERROR_FAILDETECT (-2) /* File isn't headerless, but doesn't have a 512byte header */

/* Header status */
#define STAT_NOHEADER (10) /* File is unheadered */
#define STAT_HEADER   (11) /* File is headered */

/* Function prototypes */
int remHeader(char *fname);
int addHeader(char *fname);
int chkHeader(char *fname);

#endif /* INC_ADDREM_H */

