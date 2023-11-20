// 
//  tty.cpp
//
//  Created by Norbert Thies on 23.11.1993.
//  Copyright © 1993 Norbert Thies. All rights reserved.
//


#include  <stdarg.h>
#include  <stdlib.h>
#include  <fcntl.h>
#include  <unistd.h>
#include  <errno.h>
#include  <sys/ioctl.h>
#include  "strext.h"
#include  "tty.h"

// Linux specifica
#ifndef IUCLC
#  define IUCLC 0
#endif
#ifndef OLCUC
#  define OLCUC 0
#endif

/*
 *  PROCEDURE  int tty_isa ( int fd )
 *             ======================
 *
 *             int fd    :  opened file descriptor;
 *             VALUE     :  1 ==> fd is opened on a tty,
 *                          0 ==> otherwise;
 *             LINKAGE   :  C;
 *
 *  'tty_isa' is used to query whether the passed file descriptor is opened
 *  on a tty.
 */

int tty_isa ( int fd ) {
  struct termios ttc;
  if ( tcgetattr ( fd, &ttc ) < 0 ) return 0;
  else return 1;
}


/*
 *  PROCEDURE  tty_t *tty_open ( int fd ) 
 *             ==========================
 *
 *             int fd        :  file descriptor opened on a tty;
 *             DYNAMIC VALUE :  tty controlling structure if <> 0,
 *                              Error detected otherwise;
 *
 *  'tty_open' is used to allocate the tty_t controlling structure and to
 *  initialize the termios structure.
 */

tty_t *tty_open ( int fd ) {
  if ( fd >= 0 ) {
    tty_t *t =  (tty_t *) calloc ( 1, sizeof ( tty_t ) );
    if ( t ) {
      if ( !tcgetattr ( fd, &( t -> t_oterm ) ) ) {
	mem_cpy ( &( t -> t_term ), &( t -> t_oterm ), 
	          sizeof ( struct termios ) );
	t -> t_fd    =  fd;
	t -> t_erase =  t -> t_oterm.c_cc [VERASE];
	t -> t_intr  =  t -> t_oterm.c_cc [VINTR];
	t -> t_eof   =  t -> t_oterm.c_cc [VEOF];
	t -> t_vmin  =  t -> t_oterm.c_cc [VMIN];
	t -> t_vtime =  t -> t_oterm.c_cc [VTIME];
	t -> t_flags =  0;
	return t;
      }
      free ( t );
  } }
  return 0;
}


/*
 *  PROCEDURE  int tty_reset ( tty_t *tty )
 *             ============================
 *
 *             tty_t *tty :  tty descriptor allocated by tty_open;
 *             VALUE      :  0 ==> Okay,
 *                          -1 ==> Error detected;
 *
 *  'tty_reset' is used to restore the original terminal settings 
 *  (encountered by 'tty_open').
 */

int tty_reset ( tty_t *t ) { 
  if ( t ) {
    int ret =  tcsetattr ( t -> t_fd, TCSADRAIN, &( t -> t_oterm ) );
    if ( t -> t_flags & TTY_OPENED ) t -> t_flags =  TTY_OPENED;
    else t -> t_flags =  0;
    return ret;
  }
  return -1;
}


/*
 *  PROCEDURE  int tty_close ( tty_t *tty )
 *             ============================
 *
 *             tty_t *tty :  tty descriptor allocated by tty_open;
 *             VALUE      :  0 ==> Okay,
 *                          -1 ==> Error detected;
 *
 *  'tty_close' is used to restore the original terminal settings and to
 *  release the allocated tty_t structure.
 */

int tty_close ( tty_t *t ) { 
  if ( t ) {
    int ret =  tty_reset ( t );
    if ( t -> t_fname ) free ( t -> t_fname );
    if ( t -> t_flags & TTY_OPENED ) close ( t -> t_fd );
    free ( t );
    return ret;
  }
  return -1;
}


/*
 *  PROCEDURE  tty_t *tty_fopen ( const char *fn ) 
 *             =================================
 *
 *             const char *fn :  file name of tty to open;
 *             DYNAMIC VALUE  :  tty controlling structure if <> 0,
 *                               Error detected otherwise;
 *
 *  'tty_fopen' is used to allocate the tty_t controlling structure and to
 *  initialize the termios structure.
 */

tty_t *tty_fopen ( const char *fn ) {
  int fd;
  if ( !fn ) fn =  "/dev/tty";
  fd =  open ( fn, O_RDWR | O_NDELAY );
  if ( fd >= 0 ) {
    tty_t *tty =  tty_open ( fd );
    if ( tty ) {
      int fl;
      if ( ( fl =  fcntl ( fd, F_GETFL ) ) != -1 ) {
	fl &= ~O_NDELAY;
	if ( fcntl ( fd, F_SETFL, fl ) != -1 ) {
	  if ( (tty -> t_fname =  str_heap ( fn, 0 )) ) {
	    tty -> t_flags |=  TTY_OPENED;
	    return tty;
      } } }
      tty_close ( tty );
    }
    close ( fd );
  }
  return 0;
}


/*
 *  PROCEDURE  int tty_ignsig ( tty_t *tty, int isign )
 *             ======================================
 *
 *             tty_t *tty  :  tty control descriptor;
 *             int isign :  wait until output is written to tty;
 *             VALUE     :  previous setting;
 *
 *  'tty_ignsig' is used to set/clear ignorance of signals. Ie. if
 *  isign <> 0, then signals interrupting syscalls are ignored, otherwise
 *  not.
 *  By default (after tty_open) signals are *not* ignored.
 */

int tty_ignsig ( tty_t *tty, int isign ) {
  int prev = 0;
  if ( tty ) {
    prev =  tty -> t_flags & TTY_IGNSIG;
    if ( isign ) tty -> t_flags |=  TTY_IGNSIG;
    else tty -> t_flags &= ~TTY_IGNSIG;
  }
  return prev;
}


/*
 *  PROCEDURE  int tty_define ( tty_t *tty, int is_wait ) 
 *             ========================================
 * 
 *             tty_t *tty    :  tty control descriptor;
 *             int is_wait :  wait until output is written to tty;
 *             VALUE       :  0 ==> Okay,
 *                           -1 ==> Error detected;
 *
 *  'tty_define' is used to set the actual terminal settings (in 'tty')
 *  to the device driver. If is_wait <> 0, then the changes take effect
 *  when the last data (in the output queue) is written to the tty.
 *  With exception of 'tty_close' and 'tty_cbreak' this function is the
 *  only modifying the tty device driver parameters.
 */

int tty_define ( tty_t *tty, int is_wait ) {
  if ( tty ) {
    unsigned op =  is_wait? TCSADRAIN : TCSANOW;
    return tcsetattr ( tty -> t_fd, op, &( tty -> t_term ) );
  }
  else return -1;
}


/*
 *  PROCEDURE  int tty_flush ( tty_t *tty, int is_input )
 *             ========================================
 *
 *             tty_t *tty :  tty control descriptor;
 *             int is_input :  if true, flush input queue, else output queue;
 *             VALUE        :  0 ==> Okay,
 *                            -1 ==> Error detected;
 *
 *  'tty_flush' is used to flush the tty's input or output queue.
 */

int tty_flush ( tty_t *tty, int is_input ) {
  if ( tty ) {
    int val =  is_input? TCIFLUSH : TCOFLUSH;
    return tcflush ( tty -> t_fd, val );
  }
  return -1;
}


/*
 *  PROCEDURE  int tty_xon ( tty_t *tty, int isxon )
 *             ===================================
 *
 *             tty_t *tty :  tty control descriptor;
 *             int isxon:  switch XON/XOFF on or off?;
 *             VALUE    :  0 ==> Okay,
 *                        -1 ==> Error detected;
 *
 *  'tty_xon' is used to switch XON/XOFF flow control on or off depending on
 *  the value of 'isxon'. If 'isxon' <> 0, then XON/XOFF flow control
 *  is enabled otherwise disabled. 
 *  If XON/XOFF flow control is enabled the device driver reacts on
 *  received XON/XOFF characters and also sends them depending on
 *  the fill status of the input queue. IXANY is always disabled.
 */

int tty_xon ( tty_t *tty, int isxon ) {
  if ( tty ) {
    tty -> t_term.c_iflag &=  ~IXANY;
    if ( isxon ) tty -> t_term.c_iflag |=  IXON | IXOFF;
    else tty -> t_term.c_iflag &=  ~( IXON | IXOFF );
    return 0;
  }
  else return -1;
}


/*
 *  PROCEDURE  int tty_flowcntl ( tty_t *tty, const char *mode )
 *             ===============================================
 *
 *             tty_t *tty         :  tty control descriptor;
 *             const char *mode :  mode of flow control;
 *             VALUE            :  0 ==> Okay,
 *                                -1 ==> Error detected;
 *
 *  'tty_flowcntl' is used to set immediate flow control handling.
 *  The following modes are available:
 *    "r"  :  RTS/CTS is used for flow control and DTR/CD for 
 *            connectivity (if termiox or CRTSCTS is supported)
 *    "d"  :  DTR/CD is used for flow control and RTS/CTS for 
 *            connectivity (only if termiox is supported)
 *    "x"  :  XON/XOFF flow control is enabled
 *
 *  Unlike most other tty_* functions 'tty_flowcntl' takes effect 
 *  immediately. A following 'tty_define' is not necessary.
 */

int tty_flowcntl ( tty_t *tty, const char *mode ) {
  if ( tty && mode ) {
    unsigned hflag =  0;
#   if defined ( CRTSCTS )
      tty -> t_term.c_cflag &= ~CRTSCTS;
#   endif
    tty -> t_term.c_iflag &= ~( IXANY | IXON | IXOFF );
    while ( *mode ) switch ( *mode++ ) {
      case 'r' :  {
#       if Z_TERMIOX
          hflag |=  RTSXOFF | CTSXON;
#       else
#         if defined ( CRTSCTS )
	    tty -> t_term.c_cflag |=  CRTSCTS;
#         else
	    return -1;
#         endif
#       endif
	break;
      }
      case 'd' :  {
#       if Z_TERMIOX
          hflag |=  DTRXOFF | CDXON;
#       else
	  return -1;
#       endif
	break;
      }
      case 'x' :  tty -> t_term.c_iflag |=  IXON | IXOFF; break;
      default  :  return -1;
    }
    if ( tty_define ( tty, 0 ) ) return -1;
#   if Z_TERMIOX
      if ( hflag ) {
	struct termiox tx;
	if ( !ioctl ( tty -> t_fd, TCGETX, &tx ) ) {
	  tx.x_hflag =  hflag;
	  return ioctl ( tty -> t_fd, TCSETX, &tx );
	}
	else return -1;
      }
#   endif
    return 0;
  }
  return -1;
}


/*
 *  PROCEDURE  int tty_local ( tty_t *tty, int islocal )
 *             =======================================
 *
 *             tty_t *tty   :  tty control descriptor;
 *             int islocal:  switch local mode on or off?;
 *             VALUE      :  0 ==> Okay,
 *                          -1 ==> Error detected;
 *
 *  'tty_local' is used to switch local mode on or off depending on the value
 *  of 'islocal'. If 'islocal' <> 0, then local mode is enabled otherwise
 *  remote mode is set.
 *  In remote mode the following is in effect:
 *    1. modem control is enabled (ie. on CD drop a SIGHUP is sent to the
 *       terminals controlling process) [~CLOCAL]
 *    2. when the last opened file descriptor on the tty is closed the DTR
 *       signal line is dropped for signalling the modem to disconnect
 *       the remote connection [HUPCL]
 *  In local mode the above is disabled (ie. no SIGHUP and no DTR drop).
 */

int tty_local ( tty_t *tty, int islocal ) {
  if ( tty ) {
    if ( islocal ) {
      tty -> t_term.c_cflag |=  CLOCAL;
      tty -> t_term.c_cflag &=  ~HUPCL;
    }
    else {
      tty -> t_term.c_cflag &= ~CLOCAL;
      tty -> t_term.c_cflag |=  HUPCL;
    }
    return 0;
  }
  else return -1;
}


/*
 *  PROCEDURE  int tty_echo ( tty_t *tty, int isecho )
 *             =====================================
 *
 *             tty_t *tty   :  tty control descriptor;
 *             int isecho :  switch echo on or off;
 *             VALUE      :  0 ==> Okay,
 *                          -1 ==> Error detected;
 *
 *  'tty_echo' is used to switch echo mode on or off depending on the value
 *  of 'isecho'. If 'isecho' <> 0, then echo mode is enabled otherwise
 *  non echo mode is set.
 *  In echo mode the following is in effect:
 *    1. ECHO,ECHOE,ECHOKE are set
 *    2. ECHOK,ECHONL,ECHOCTL,ECHOPRT are cleared
 *  In non echo mode all above noted modes are cleared. 
 */

int tty_echo ( tty_t *tty, int isecho ) {
  if ( tty ) {
    tty -> t_term.c_lflag &= ~( ECHO | ECHOE | ECHOKE | ECHOK | 
      ECHOCTL | ECHOPRT );
    if ( isecho ) tty -> t_term.c_lflag |=  ECHO | ECHOE | ECHOKE;
    return 0;
  }
  else return -1;
}


/*
 *  PROCEDURE  int tty_isecho ( tty_t *tty )
 *             =============================
 *
 *             tty_t *tty   :  tty control descriptor;
 *             VALUE        :  1 ==> echo is turned on,
 *                             0 ==> echo is turned off;
 *
 *  'tty_isecho' is used to query whether tty character echo mode has been
 *  turned on or off.
 */

int tty_isecho ( tty_t *tty ) {
  if ( tty )
    return (tty -> t_term.c_lflag & ECHO)? 1 : 0;
  return 0;
}


/*
 *  PROCEDURE  int tty_signal ( tty_t *tty, int issig )
 *             ========================================
 *
 *             tty_t *tty :  tty control descriptor;
 *             int issig  :  switch signal processing on or off;
 *             VALUE      :  0 ==> Okay,
 *                          -1 ==> Error detected;
 *
 *  'tty_signal' is used to switch input signal processing on or off 
 *  depending on the value of 'issig'. Input signal processing, when enabled
 *  checks each received character for special signal processing (eg.:
 *  INTR, QUIT, ...).
 *  If 'issig' <> 0, then input signal processing is enabled otherwise
 *  switched off.
 */

int tty_signal ( tty_t *tty, int issig ) {
  if ( tty ) {
    if ( issig ) tty -> t_term.c_lflag |=  ISIG;
    else tty -> t_term.c_lflag &=  ~ISIG;
    return 0;
  }
  else return -1;
}


/*
 *  PROCEDURE  int tty_baudrate ( tty_t *tty, int baudrate )
 *             ===========================================
 *
 *             tty_t *tty   :  tty control descriptor;
 *             int baudrate :  baudrate to select;
 *             VALUE        :  >= 0 ==> old baudrate,
 *                             Error detected otherwise;
 *
 *  'tty_baudrate' is used to select input/output baudrate on the tty
 *  referenced by 'tty'. If baudrate = -1, no new baudrate is selected,
 *  only the actual baudrate is returned.
 */

int tty_baudrate ( tty_t *tty, int baudrate ) {
  if ( tty ) {
    unsigned long obrate, brate;
    obrate =  cfgetospeed ( &(tty -> t_term) );
    if ( baudrate >= 0 ) {
      switch ( baudrate ) {
	case     0 :  brate =  B0; break;
	case    50 :  brate =  B50; break;
	case    75 :  brate =  B75; break;
	case   110 :  brate =  B110; break;
	case   134 :  brate =  B134; break;
	case   150 :  brate =  B150; break;
	case   200 :  brate =  B200; break;
	case   300 :  brate =  B300; break;
	case   600 :  brate =  B600; break;
	case  1200 :  brate =  B1200; break;
	case  1800 :  brate =  B1800; break;
	case  2400 :  brate =  B2400; break;
	case  4800 :  brate =  B4800; break;
	case  9600 :  brate =  B9600; break;
#       ifdef B19200
	  case 19200 :  brate =  B19200; break;
#       endif
#       ifdef B38400
	  case 38400 :  brate =  B38400; break;
#       endif
	default    :  return -1;
      }
      cfsetispeed ( &(tty -> t_term), brate );
      cfsetospeed ( &(tty -> t_term), brate );
    }
    switch ( obrate ) {
      case     B0 :  obrate =  0; break;
      case    B50 :  obrate =  50; break;
      case    B75 :  obrate =  75; break;
      case   B110 :  obrate =  110; break;
      case   B134 :  obrate =  134; break;
      case   B150 :  obrate =  150; break;
      case   B200 :  obrate =  200; break;
      case   B300 :  obrate =  300; break;
      case   B600 :  obrate =  600; break;
      case  B1200 :  obrate =  1200; break;
      case  B1800 :  obrate =  1800; break;
      case  B2400 :  obrate =  2400; break;
      case  B4800 :  obrate =  4800; break;
      case  B9600 :  obrate =  9600; break;
#     ifdef B19200
	case B19200 :  obrate =  19200; break;
#     endif
#     ifdef B38400
	case B38400 :  obrate =  38400; break;
#     endif
      default    :  return -1;
    }
    return (int) obrate;
  }
  return -1;
}


/*
 *  PROCEDURE  int tty_exception ( tty_t *tty, const char *mode )
 *             ================================================
 *
 *             tty_t *tty         :  tty control descriptor;
 *             const char *mode : mode of operation (see below);
 *             VALUE            :  0 ==> Okay,
 *                                -1 ==> Error detected;
 *
 *  'tty_exception' is used to set the handling of special input conditions.
 *  These conditions are:
 *    o  break received
 *    o  framing or parity error received
 *  Depending on 'mode' the following actions may be selected:
 *    "s"  :  generate SIGINT signal on that conditions
 *    "i"  :  ignore conditions
 *    "m"  :  mark conditions
 *  In case of "m" the following codes are generated in the input queue:
 *    break received         :  '\377`, '\0', '\0'
 *    parity or framing error:  '\377', '\0', '\x'
 *      where x is the data of the byte received in error. When ISTRIP is 
 *      not set, a valid char of '\377' is represented as '\377', '\377'.
 *  In case of "s" a signal is sent to the foreground 
 *  process group if the tty in question is the controlling tty of that 
 *  foreground process group.
 */

int tty_exception ( tty_t *tty, const char *mode ) {
  if ( tty && mode ) {
    unsigned long fl =  tty -> t_term.c_iflag & 
      ~( IGNBRK | IGNPAR | BRKINT | PARMRK );
    switch ( *mode ) {
      case 's' :  fl |=  BRKINT; break;
      case 'i' :  fl |=  IGNBRK | IGNPAR; break;
      case 'm' :  fl |=  PARMRK; break;
      default  :  return -1; 
    }
    tty -> t_term.c_iflag =  fl;
    return 0;
  }
  return -1;
}


/*
 *  PROCEDURE  int tty_parameter ( tty_t *tty, int dbits, int sbits, 
 *                                 const char *par )
 *             ===================================================
 *
 *             tty_t *tty         :  tty control descriptor;
 *             int dbits        :  number of data bits (5-8);
 *             int sbits        :  number of stop bits (1-2);
 *             const char *par  :  character identifying parity (see below);
 *             VALUE            :  0 ==> Okay,
 *                                -1 ==> Error detected;
 *
 *  'tty_parameter' is used to set the typical async IO framing parameters.
 *  'par' may be one of:
 *    "n" :  none (no parity checking)
 *    "e" :  even parity (generation and detection)
 *    "o" :  odd parity (generation and detection)
 *    "s" :  no parity generation and detection but input bytes stripped
 *    "E" :  even parity generation but no detection (input bytes stripped)
 *    "O" :  odd parity generation but no detection (input bytes stripped)
 */

int tty_parameter ( tty_t *tty, int dbits, int sbits, const char *par ) {
  if ( tty && par && ( dbits >= 5 ) && ( dbits <= 8 ) && ( sbits >= 1 )
       && ( sbits <= 2 ) ) {
    unsigned long ifl =  tty -> t_term.c_iflag & ~( ISTRIP | INPCK ),
                  cfl =  tty -> t_term.c_cflag & ~( PARENB | PARODD | 
		         CSTOPB | CSIZE );
    switch ( *par ) {
      case 'n' :  break;
      case 'o' :  cfl |=  PARODD;
      case 'e' :  ifl |=  INPCK; cfl |=  PARENB; break;
      case 's' :  ifl |=  ISTRIP; break;
      case 'O' :  cfl |=  PARODD;
      case 'E' :  ifl |=  ISTRIP; cfl |=  PARENB; break;
      default  :  return -1;
    }
    switch ( dbits ) {
      case 6 :  cfl |=  CS6; break;
      case 7 :  cfl |=  CS7; break;
      case 8 :  cfl |=  CS8; break;
    }
    if ( sbits > 1 ) cfl |=  CSTOPB;
    tty -> t_term.c_iflag =  ifl;
    tty -> t_term.c_cflag =  cfl;
    return 0;
  }
  return -1;
}


/*
 *  PROCEDURE  int tty_canon ( tty_t *tty, int iscanon )
 *             =======================================
 *
 *             tty_t *tty   :  tty control descriptor;
 *             int iscannon :  enable/disable canonical input processing;
 *             VALUE        :  0 ==> Okay,
 *                            -1 ==> Error detected;
 *
 *  'tty_canon' is used to set or clear (depending on the value of iscannon)
 *  cannonical input processing.
 *  In cannonical input processing (iscanon <> 0) characters typed are grouped
 *  into a line, echoing and simple line editing are enabled. Non canonical
 *  input processing is identical to CBREAK mode (ie. no echo and editing).
 *  Also in canonical mode input character signal processing is enabled, ie.
 *  typing the interrupt character will deliver a SIGINT signal.
 */

int tty_canon ( tty_t *tty, int iscanon ) {
  if ( tty ) {
    tty -> t_term.c_cflag |=  CREAD;
    if ( iscanon ) {
      tty -> t_term.c_lflag |=  ISIG | ICANON;
      tty -> t_term.c_cc [VMIN] =  tty -> t_vmin;
      tty -> t_term.c_cc [VTIME] =  tty -> t_vtime;
      return tty_echo ( tty, 1 );
    }
    else {
      tty -> t_term.c_lflag &=  ~( ISIG | ICANON );
      tty -> t_term.c_cc [ VMIN ] =  1;
      tty -> t_term.c_cc [ VTIME ] =  0;
      return tty_echo ( tty, 0 );
  } }
  return -1;
}


/*
 *  PROCEDURE  int tty_timer ( tty_t *tty, int vmin, int vtime ) 
 *             ===============================================
 *
 *             tty_t *tty  :  tty control descriptor;
 *             int vmin  :  min. #chars to wait for;
 *             int vtime :  max. time between two received chars (1/10s);
 *             VALUE     :  0 ==> Okay,
 *                         -1 ==> Error detected;
 *
 *  'tty_timer' disables canonical input processing (ie. grouping chars to
 *  lines) and sets min/time interaction. The following cases are to
 *  distinguish:
 *    
 *    (i)   vmin > 0, vtime > 0
 *          A read call is satisfied either if vmin characters
 *          have been received or vtime * 1/10 s has been expired
 *          till the last char has been received. 
 *          The timer will the first time be enabled after(!) the
 *          first char has been received.
 *    (ii)  vmin > 0, vtime = 0
 *          the timer is deactivated;
 *    (iii) vmin = 0, vtime > 0
 *          a read call is satisfied after vtime * 1/10 s;
 *    (iv)  vmin = 0, vtime = 0
 *          a read call returns immediate (whether chars are
 *          available or not)
 *
 *  After enabling the timer using 'tty_timer' it may be disabled using 
 *  tty_canon ( tty, 1 ). Analogue to tty_canon (tty, 0 ), echoing and
 *  character signal handling is disabled.
 */

int tty_timer ( tty_t *tty, int vmin, int vtime ) {
  if ( tty && ( vmin >= 0 ) && ( vtime >= 0 ) ) {
    tty -> t_term.c_lflag &=  ~ICANON;
    tty -> t_term.c_cc [ VMIN ] =  vmin;
    tty -> t_term.c_cc [ VTIME ] =  vtime;
    return 0;
  }
  return -1;
}


/*
 *  PROCEDURE  int tty_cbreak ( tty_t *tty, int ison )
 *             =====================================
 *
 *             tty_t *tty :  tty controlling structure;
 *             int ison :  if ( ison ) ==> set cbreak; else not;
 *             VALUE    :  0 ==> Okay,
 *                        -1 ==> Error detected;
 *
 *  'tty_cbreak' is used to switch the tty to 'cbreak' mode ie. canonical
 *  input processing and character echoing is disabled, MIN is set to 1 and
 *  TIME to 0.
 *  In case of ison = 0, canonical input processing is enabled and the
 *  standard lflag is restored.
 *  Unlike other tty_* function 'tty_cbreak' implies a 'tty_define',
 *  so the change is immediate.
 */

int tty_cbreak ( tty_t *tty, int ison ) {
  if ( tty ) {
    if ( ison ) {
      if ( tty -> t_flags & TTY_CBREAK ) return 0;
      tty_canon ( tty, 0 );
      tty -> t_flags |= TTY_CBREAK;
    }
    else {
      if ( !( tty -> t_flags & TTY_CBREAK ) ) return 0;
      tty_canon ( tty, 1 );
      tty -> t_flags &= ~TTY_CBREAK;
    }
    return tty_define ( tty, 0 );
  }
  else return -1;
}


/*
 *  PROCEDURE  int tty_readch ( tty_t *tty )
 *             ===========================
 *
 *             tty_t *tty :  tty control descriptor;
 *             VALUE    :  next char read from the tty if <> -1,
 *                         -1 ==> Error detected,
 *                         -2 ==> Signal received;
 *
 *  'tty_readch' is used to read a single character from the tty. If not
 *  already, the tty is switched to CBREAK mode (ie. min=1,time=0).
 */

int tty_readch ( tty_t *t ) {
  if ( t ) {
    char buff;
    int ret;
    if ( !( t -> t_flags & TTY_CBREAK ) ) tty_cbreak ( t, 1 );
    for (;;) {
      if ( ( ret = (int)read ( t -> t_fd, &buff, 1 ) ) == 1 ) 
        return ((int) buff) & 0xff;
      else if ( ( ret == -1 ) && ( errno == EINTR ) ) {
        if ( t -> t_flags & TTY_IGNSIG ) continue;
	else return -2;
      }
      break;
  } }
  return -1;
}


/*
 *  PROCEDURE  int tty_winsize ( tty_t *tty, int *rows, int *cols, int isset )
 *             =============================================================
 *
 *             tty_t *tty  :  tty control descriptor;
 *             int *rows :  #rows of window;
 *             int *cols :  #cols of window;
 *             int isset :  set window size ?;
 *             VALUE     :  0 ==> Okay,
 *                         -1 ==> Error detected;
 *
 *  'tty_winsize' is used to set (or get) the actual window size.
 *  If 'isset' = 0, then the actual number of rows is written to *rows
 *  and the number of columns to *cols.
 *  If isset = 1, the rows and cols are assigned accordingly, the pixels
 *  sizes are set to 0.
 */

int tty_winsize ( tty_t *tty, int *rows, int *cols, int isset ) {
  if ( tty && rows && cols ) {
    struct winsize ws;
    if ( isset ) {
      ws.ws_row =  *rows;
      ws.ws_col =  *cols;
      ws.ws_xpixel =  0;
      ws.ws_ypixel =  0;
      return ioctl ( tty -> t_fd, TIOCSWINSZ, &ws );
    }
    else {
      if ( ioctl ( tty -> t_fd, TIOCGWINSZ, &ws ) ) return -1;
      else {
	*rows =  ws.ws_row;
	*cols =  ws.ws_col;
	return 0;
  } } }
  return -1;
}


/*
 *  PROCEDURE  int tty_mdmlines ( tty_t *tty, unsigned *bits, int isset )
 *             ========================================================
 *
 *             tty_t *tty       :  tty control descriptor;
 *             unsigned *bits :  modem line bits;
 *             int isset      :  set modem lines?;
 *             VALUE          :  0 ==> Okay,
 *                              -1 ==> Error detected;
 *
 *  'tty_mdmlines' is used to query or set the modem lines of the terminal
 *  referenced by 'tty'. The following bits may be queried/set:
 *    TIOCM_LE    :   line enable
 *    TIOCM_DTR   :   data terminal ready
 *    TIOCM_RTS   :   request to send
 *    TIOCM_ST    :   secondary transmit
 *    TIOCM_SR    :   secondary receive
 *    TIOCM_CTS   :   clear to send
 *    TIOCM_CD    :   carrier detect
 *    TIOCM_RI    :   ring
 *    TIOCM_DSR   :   data set ready
 */

int tty_mdmlines ( tty_t *tty, unsigned *bits, int isset ) {
  if ( tty && bits ) {
    if ( isset ) return ioctl ( tty -> t_fd, TIOCMSET, bits );
    else return ioctl ( tty -> t_fd, TIOCMGET, bits );
  }
  return -1;
}


/*
 *  PROCEDURE  int tty_setchar ( tty_t *tty, const char *mode, ... )
 *             ===================================================
 *
 *             tty_t *tty         :  tty control descriptor;
 *             const char *mode :  defines which special char to set;
 *             VALUE            :  0 ==> Okay,
 *                                -1 ==> Error detected;
 *
 *  'tty_setchar' is used to define several special character handling
 *  terminal input. Each char to define is denoted by a corresponding
 *  flag in 'mode':
 *      "i"  :  next char denotes interrupt char (INTR=^C)
 *      "q"  :  next char denotes quit char (QUIT=^|)
 *      "e"  :  next char denotes erase char (ERASE=<DEL>)
 *      "k"  :  next char denotes kill character (KILL=^U) (deletes line)
 *      "d"  :  next char denotes EOF character (EOF=^D)
 *      "l"  :  next char denotes EOL character (EOL=undefined)
 *      "z"  :  next char denotes suspend character (SUSP=^Z)
 *      "y"  :  next char denotes read suspend character (DSUSP=^Y)
 *      "-"  :  next char denotes stop character (STOP=^S)
 *      "+"  :  next char denotes start character (START=^Q)
 *      "o"  :  next char denotes discard character (DISCARD=^O)
 *      "0"  :  sets all special chars to 0
 *      "D"  :  select default character assignment:
 *        i=<DEL>, q=^C, e=^H, k=^U, d=^D, z=^Z, y=^Y, -=^S, +=^Q, o=^O
 */

int tty_setchar ( tty_t *tty, const char *mode, ... ) {
  va_list vp;
  if ( tty && mode ) {
    int idx, ch;
    va_start ( vp, mode );
    while ( *mode ) {
      switch ( *mode++ ) {
	case 'i' :  idx =  VINTR; break;
	case 'q' :  idx =  VQUIT; break;
	case 'e' :  idx =  VERASE; break;
	case 'k' :  idx =  VKILL; break;
	case 'd' :  idx =  VEOF; break;
	case 'l' :  idx =  VEOL; break;
	case 'z' :  idx =  VSUSP; break;
	case '-' :  idx =  VSTOP; break;
	case '+' :  idx =  VSTART; break;
#       ifdef VDISCARD
	  case 'o' :  idx =  VDISCARD; break;
#       endif
#       ifdef VDSUSP
	  case 'y' :  idx =  VDSUSP; break;
#       endif
	case 'D' :  tty_setchar ( tty, "iqekdzy-+o", 0x7f, 0x03, 0x08, 0x15, 
	            0x04, 0x1a, 0x19, 0x13, 0x11, 0x0f );
		    continue;
	case '0' :  for ( idx = 0; idx < NCCS; idx++ ) 
	              tty -> t_term.c_cc [ idx ] =  (char) 0;
		    continue;
	default  :  va_end ( vp ); return -1;
      }
      ch =  va_arg ( vp, int );
      if ( idx == VMIN ) tty -> t_vmin =  ch;
      if ( idx == VTIME ) tty -> t_vtime =  ch;
      if ( idx == VERASE ) tty -> t_erase =  ch;
      if ( idx == VINTR ) tty -> t_intr =  ch;
      if ( idx == VEOF ) tty -> t_eof =  ch;
      tty -> t_term.c_cc [ idx ] =  (char) ch;
    }
    va_end ( vp );
    return 0;
  }
  return -1;
}


/*
 *  PROCEDURE  int tty_set ( tty_t *tty, const char *par )
 *             =========================================
 *
 *             tty_t *tty         :  tty control descriptor;
 *             const char *par  :  string identifying tty parameter (see below);
 *             VALUE            :  0 ==> Okay,
 *                                -1 ==> Error detected;
 *
 *  'tty_set' is used to set the typical async IO communication parameters.
 *  'par' is expected to be of following syntax:
 *     
 *      par      =  baudrate [ "," cpar [ "," mpar [ "," lpar ] ] ].
 *      baudrate =  digit { digit } # input and output baudrate #.
 *      cpar     =  bdata parity bstop [ flowcntl ].
 *      bdata    =  digit # 5...8 #.
 *      parity   =  "n"  # no parity #   | 
 *                  "e"  # even parity # | 
 *		    "o"  # odd parity #  | 
 *		    "s"  # no parity but strip high (parity) bit # | 
 *		    "E"  # even parity generation but no detection (+strip) # | 
 *		    "O"  # odd parity generation but no detection (+strip) #.
 *      bstop    =  digit # 1...2 #.
 *      flowcntl =  "x" | "r" | "d".
 *      mpar     =  "i" { iflag } "o" { oflag }.
 *      iflag    =  "c"  # map CR -> NL on input # |
 *                  "C"  # ignore CR on input #    |
 *		    "n"  # map NL -> CR on input   |
 *		    "l"  # map uppercase -> lowercase on input #.
 *      oflag    =  "c"  # map CR -> NL on output #    |
 *                  "n"  # map NL -> CR,NL on output # |
 *                  "u"  # map lowercase -> uppercase on output #.
 *      lpar     =  "c"  # switch on canonical mode #        |
 *                  "C"  # switch off canonical mode #       |
 *                  "l"  # use local mode (no modem lines) # |
 *                  "L"  # use dial up mode (modem lines) #  |
 *                  "e"  # switch on echo mode #             |
 *                  "E"  # switch off echo mode #            |
 *                  "s"  # switch on input signals #         |
 *                  "S"  # switch off input signals #.
 *
 *  A specific parameter (baudrate, cpar, mpar, lpar) may be skipped by not
 *  specifying optional parameter or by using ",,".
 *  Eg. ",,,c" will leave the actual setting but canonical mode, selected
 *  using "c". Using 'cpar' without specifying the flowcontrol will
 *  switch off any flowcontrol. Using 'mpar' will first switch off any
 *  mapping flags and then set only the flags specified (eg mpar="io"
 *  will switch off any mapping flags).
 *  Switching on canonical mode will also switch on echo mode and generation
 *  of input signals (eg: the kill character). Using canonical input mode
 *  without echo and signal generation is acconplished by lpar="cES".
 *  Unlike most other tty_* function the settings specified using 'tty_set'
 *  take immediate effect. A call to 'tty_define' is not necessary.
 */

int tty_set ( tty_t *tty, const char *par ) {
  if ( tty && par ) {
    char brate [20], cpar [20], mpar [20], lpar [20];
    const char *p;
    const char *flowcntl =  0;
    unsigned long val, val2;
    brate [0] = cpar [0] = mpar [0] = lpar [0] =  '\0';
    if ( (p =  str_chr ( par, ',' )) ) {
      str_ncpy ( brate, 20, par, (int)(p - par) );
      if ( (p =  str_chr ( par = p + 1, ',' )) ) {
	str_ncpy ( cpar, 20, par, (int)(p - par) );
	if ( (p =  str_chr ( par = p + 1, ',' )) ) {
	  str_ncpy ( mpar, 20, par, (int)(p - par) );
	  str_cpy ( lpar, 20, p + 1 );
	}
	else str_cpy ( mpar, 20, par );
      }
      else str_cpy ( cpar, 20, par );
    }
    else str_cpy ( brate, 20, par );
    if ( *brate ) {
      if ( ( str_a2l ( &val, brate, 10 ) <= 0 ) ||
	 ( tty_baudrate ( tty, (int) val ) < 0 ) ) return -1;
    }
    if ( *cpar ) {
      if ( str_len ( cpar ) > 2 ) {
	if ( ( str_a2l ( &val, cpar, 10 ) > 0 ) &&
	     ( str_a2l ( &val2, cpar + 2, 10 ) > 0 ) )
	  if ( tty_parameter ( tty, (int) val, (int) val2, cpar + 1 ) ) 
	    return -1;
	if ( cpar [3] ) flowcntl =  cpar + 3;
	else flowcntl =  "";
      }
      else return -1;
    }
    if ( *mpar ) {
      unsigned long ifl =  tty -> t_term.c_iflag,
		    ofl =  tty -> t_term.c_oflag;
      ifl &=  ~( INLCR | ICRNL | IUCLC | IGNCR );
      ofl &=  ~( OPOST | OLCUC | ONLCR | OCRNL );
      p =  mpar;
      while ( *p ) switch ( *p++ ) {
	case 'i' :  {
	  while ( *p ) {
	    switch ( *p++ ) {
	      case 'c' :  ifl |=  ICRNL; continue;
	      case 'C' :  ifl |=  IGNCR; continue;
	      case 'n' :  ifl |=  INLCR; continue;
	      case 'l' :  ifl |=  IUCLC; continue;
	      case 'o' :  p--; break;
	      default  :  return -1;
	    } 
	    break;
	  }
	  tty -> t_term.c_iflag =  ifl;
	  break;
	}
	case 'o' : {
	  while ( *p ) {
	    switch ( *p++ ) {
	      case 'c' :  ofl |=  OPOST | OCRNL; continue;
	      case 'n' :  ofl |=  OPOST | ONLCR; continue;
	      case 'u' :  ofl |=  OPOST | OLCUC; continue;
	      case 'i' :  p--; break;
	      default  :  return -1;
	    }
	    break;
	  }
	  tty -> t_term.c_oflag =  ofl;
	  break;
	}
	default  :  return -1;
    } }
    if ( *lpar ) {
      p =  lpar;
      while ( *p ) switch ( *p++ ) {
	case 'c' :  tty_canon ( tty, 1 ); break;
	case 'C' :  tty_canon ( tty, 0 ); break;
	case 'l' :  tty_local ( tty, 1 ); break;
	case 'L' :  tty_local ( tty, 0 ); break;
	case 'e' :  tty_echo ( tty, 1 ); break;
	case 'E' :  tty_echo ( tty, 0 ); break;
	case 's' :  tty_signal ( tty, 1 ); break;
	case 'S' :  tty_signal ( tty, 0 ); break;
	default  :  return -1;
    } }
    if ( tty_define ( tty, 0 ) ) return -1;
    if ( flowcntl ) 
      if ( tty_flowcntl ( tty, flowcntl ) ) return -1;
    return 0;
  }
  return -1;
}


/*
 *  PROCEDURE  int tty_break ( tty )
 *             =====================
 *
 *             tty_t *tty :  tty control descriptor;
 *             VALUE    :  0 ==> Okay,
 *                        -1 ==> Error detected;
 *
 *  'tty_break' is used to send a "break character" (ie. 0.25s 0).
 */

int tty_break ( tty_t *tty ) {
  if ( tty ) return tcsendbreak ( tty -> t_fd, 0 );
  return -1;
}


/*
 *  PROCEDURE  int tty_hup ( tty_t *tty, int nsec )
 *             ==================================
 *
 *             tty_t *tty :  tty control descriptor;
 *             int nsec :  #seconds to hang up the line;
 *             VALUE    :  0 ==> Okay,
 *                        -1 ==> Error detected;
 *
 *  'tty_hup' is used to hang up the line described by 'tty' for 'nsec'
 *  seconds. Usually this will drop the DTR line for 'nsec' seconds
 *  which in turn will disconnect the line.
 */

int tty_hup ( tty_t *tty, int nsec ) {
  if ( tty ) {
    struct termios ts;
    mem_cpy ( &ts, &( tty -> t_term ), sizeof ( struct termios ) );
    cfsetispeed ( &ts, B0 );
    cfsetospeed ( &ts, B0 );
    if ( !tcsetattr ( tty -> t_fd, TCSANOW, &ts ) ) {
      if ( nsec > 0 ) sleep ( nsec );
      return tty_define ( tty, 0 );
  } }
  return -1;
}


/*
 *  PROCEDURE  int tty_write ( tty_t *tty, const char *str )
 *             ===========================================
 *
 *             tty_t *tty       :  tty control descritor;
 *             const char *str:  string to write;
 *             VALUE          :  0 ==> Okay,
 *                              -1 ==> Error detected;
 *
 *  'tty_write' is used to write a string to the tty referenced
 *  by 'tty'.
 */

int tty_write ( tty_t *t, const char *str ) {
  if ( t && str && ( t -> t_fd >= 0 ) ) {
    int l =  str_len ( str );
    if ( write ( t -> t_fd, str, l ) == l ) return 0;
  }
  return -1;
}


/*
 *  PROCEDURE  int tty_writech ( tty_t *tty, char ch )
 *             =====================================
 *
 *             tty_t *tty :  tty control descritor;
 *             char ch  :  character to write;
 *             VALUE    :  0 ==> Okay,
 *                        -1 ==> Error detected;
 *
 *  'tty_writech' is used to write a single character to the tty referenced
 *  by 'tty'.
 */

int tty_writech ( tty_t *t, char ch ) {
  if ( t && ( t -> t_fd >= 0 ) )
    if ( write ( t -> t_fd, &ch, 1 ) == 1 ) return 0;
  return -1;
}


/*
 *  PROCEDURE  int tty_gets ( tty_t *tty, char *buff, int len )
 *             ================================================
 *
 *             tty_t *tty   :  tty control descriptor;
 *             char *buff   :  where to store the chars read;
 *             int len      :  length of 'buff' (incl \0);
 *             VALUE        :  >= 0 ==> #chars written to buff,
 *                             -1 ==> Error detected, EOF or interrupt;
 *
 *  'tty_gets' works analogue 'gets' but depending on 'tty_isecho' the
 *  characters typed are echoed to the tty or not.
 *  The terminating newline is not written to buff and buff is guaranteed
 *  to be terminated with a \0.
 */

int tty_gets ( tty_t *tty, char *buff, int len ) {
  if ( tty && buff && (len > 0) ) {
    char *p =  buff;
    int is_break =  0;
    int l =  len;
    int isecho = tty_isecho ( tty );
    int is_cbreak =  tty -> t_flags & TTY_CBREAK;
    tty_flush ( tty, 1 );
    for (;;) {
      int ch =  tty_readch ( tty );
      if ( ch == tty -> t_intr ) { is_break++; break; }
      else if ( ch == tty -> t_eof ) {
	if ( p == buff ) is_break++;
	break;
      }
      else if ( ( ch == '\n' ) || ( ch == '\r' ) ) break;
      else if ( (ch == tty -> t_erase) || (ch == 0x08) || (ch == 0x7f) ) {
	if ( p > buff ) { 
	  p--; l++;
	  if ( isecho ) tty_write ( tty, "\b \b" );
	}
	else tty_writech ( tty, 0x07 );
      }
      else if ( ch < 0x20 ) tty_writech ( tty, 0x07 );
      else if ( l > 1 ) { 
        *(p++) =  (char) ch; l--;
	if ( isecho ) tty_writech ( tty, ch );
    } }
    *p =  '\0';
    tty_writech ( tty, '\n' );
    if ( !is_cbreak ) tty_cbreak ( tty, 0 );
    if ( is_break ) return -1;
    else return len - l;
  }
  return -1;
}

char *tty_getstring(tty_t *tty) {
  char buff[1001];
  buff[0] = 0;
  int l = tty_gets(tty, buff, 1000);
  return str_heap(buff, l);
}


/*
 *  PROCEDURE  int tty_negets ( tty_t *tty, char *buff, int len )
 *             ================================================
 *
 *             tty_t *tty   :  tty control descriptor;
 *             char *buff :  where to store the chars read;
 *             int len    :  length of 'buff' (incl \0);
 *             VALUE      :  >= 0 ==> #chars written to buff,
 *                           -1 ==> Error detected, EOF or interrupt;
 *
 *  'negets' works analogue 'gets' but unlike no char typed is 
 *  written back to the terminal.
 *  The terminating newline is not written to buff and buff is guaranteed
 *  to be terminated by a \0.
 */

int tty_negets ( tty_t *tty, char *buff, int len ) {
  if ( tty ) {
    int ret, wasecho =  tty_isecho ( tty );
    if ( wasecho ) tty_echo ( tty, 0 );
    ret =  tty_gets ( tty, buff, len );
    if ( wasecho ) tty_echo ( tty, 1 );
    return ret;
  }
  return -1;
}

char *tty_negetstring(tty_t *tty) {
  char buff[1001];
  buff[0] = 0;
  int l = tty_negets(tty, buff, 1000);
  return str_heap(buff, l);
}
