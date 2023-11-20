// 
//  tty.h
//
//  Created by Norbert Thies on 23.11.1993.
//  Copyright © 1993 Norbert Thies. All rights reserved.
//

#ifndef tty_h
#define tty_h

#include <termios.h>
#include "sysdef.h"

/*
 *  The tty control structure:
 */

typedef struct {
  char            *t_fname;  /* file name of tty */
  int              t_fd;     /* file descriptor on tty */
  int              t_erase;  /* erase character */
  int              t_intr;   /* interrupt character */
  int              t_eof;    /* EOF character */
  unsigned         t_flags;  /* tty processing flags */
  int              t_vmin;   /* actual VMIN value */
  int              t_vtime;  /* actual VTIME value */
  struct termios   t_oterm;  /* original terminal settings */
  struct termios   t_term;   /* actual terminal settings */
} tty_t;


/*
 *  t_flags values:
 */

#define  TTY_CBREAK            1   /* inon canonical, no echo (min=1, time=0) */
#define  TTY_OPENED            2   /* tty has been opened in module */
#define  TTY_IGNSIG            4   /* ignore signals */


/*
 *  The viruptal tty controlling structure:
 */

typedef struct vtty_s {
  char    *vt_mname;  /* name of master tty device */
  char    *vt_sname;  /* name of slave tty device */
  int      vt_mfd;    /* master device file descriptor */
  int      vt_sfd;    /* slave device file descriptor */
  tty_t   *vt_stty;   /* slave tty settings */
  unsigned vt_flags;  /* vtty operation flags */
} vtty_t;


/*
 *  vtty_t -> vt_flags values:
 */

#define  VTF_SETOWN     1   /* set owner and permissions of slave device */
#define  VTF_CTTY       2   /* make the slave device the controlling tty */


BeginCLinkage

/* Exports of tty.c: */
int tty_isa (int fd);
tty_t *tty_open (int fd);
int tty_reset (tty_t *t);
int tty_close (tty_t *t);
tty_t *tty_fopen (const char *fn);
int tty_ignsig (tty_t *t, int isign);
int tty_define (tty_t *tty, int is_wait);
int tty_flush (tty_t *tty, int is_input);
int tty_xon (tty_t *tty, int isxon);
int tty_flowcntl (tty_t *tty, const char *mode);
int tty_local (tty_t *tty, int islocal);
int tty_echo (tty_t *tty, int isecho);
int tty_isecho (tty_t *tty);
int tty_signal (tty_t *tty, int issig);
int tty_baudrate (tty_t *tty, int baudrate);
int tty_exception (tty_t *tty, const char *mode);
int tty_parameter (tty_t *tty, int dbits, int sbits, const char *par);
int tty_canon (tty_t *tty, int iscanon);
int tty_timer (tty_t *tty, int vmin, int vtime);
int tty_cbreak (tty_t *tty, int ison);
int tty_readch (tty_t *t);
int tty_mdmlines (tty_t *tty, unsigned int *bits, int isset);
int tty_setchar (tty_t *tty, const char *mode, ...);
int tty_set (tty_t *tty, const char *par);
int tty_break (tty_t *tty);
int tty_hup (tty_t *tty, int nsec);
int tty_write (tty_t *t, const char *str);
int tty_writech (tty_t *t, char ch);
int tty_gets (tty_t *tty, char *buff, int len);
int tty_negets (tty_t *tty, char *buff, int len);
int tty_winsize (tty_t *tty, int *rows, int *cols, int isset);
char *tty_getstring(tty_t *);
char *tty_negetstring(tty_t *);

EndCLinkage

#endif /* tty_h */
