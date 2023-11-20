//
//  strext.cpp
//
//  Created by Norbert Thies on 18.03.1993.
//  Copyright © 1993 Norbert Thies. All rights reserved.
//

#include  <stdarg.h>
#include  <stdlib.h>
#include  <ctype.h>
#include  <stdio.h>
#include  <string.h>
#include  <time.h>
#include  <sys/errno.h>
#include  <sys/utsname.h>
#include  "strext.h"

/// An empty "C"-string
const char *str_empty_c =  "";

// MARK: Elementary Memory-Operations

/**
 * mem_cpy is simply a replacement of 'memcpy'.
 * 
 * mem_cpy copies 'len' bytes from 'src' to 'dest' and returns 'dest'.
 *
 * @param dest where to copy 'src' to
 * @param src  data to copy
 * @param len  number of bytes to copy;
 *
 * @return dest
 */
void *mem_cpy(void *dest, const void *src, size_t len) {
  if ( dest && src ) {
    unsigned char *d =  (unsigned char *) dest;
    const unsigned char *s =  (const unsigned char *) src;
    while ( len-- > 0 ) *(d++) =  *(s++);
  }
  return dest;
}

/**
 * mem_swap is used to exchange the contents of two memory locations.
 * 
 * mem_swap swaps 'len' bytes from 'p1' and 'p2'.
 * - parameters:
 *   - p1:  first memory location
 *   - p2:  second memory location
 *   - len: number of bytes to copy;
 * - returns: p1 
 */
void *mem_swap(void *p1, void *p2, size_t len) {
  if ( p1 && p2 ) {
    unsigned char ch;
    unsigned char *d =  (unsigned char *) p1;
    unsigned char *s =  (unsigned char *) p2;
    while ( len-- > 0 ) {
      ch =  *s; *s++ =  *d; *d++ =  ch;
  } }
  return p1;
}

/**
 * mem_set is simply a replacement of 'memset'.
 * 
 * mem_set takes the lower 8 bits from the integer 'c' and copies that
 * byte to 'len' bytes at the memory location 'dest'.
 * - parameters:
 *   - dest: memory location to write to
 *   - ch:   characte/byte to copy
 *   - len:  number of bytes to copy to
 * - returns dest
 */
void *mem_set(void *dest, int ch, size_t len) {
  if ( dest ) {
    unsigned char *d =  (unsigned char *) dest;
    unsigned char byte =  (unsigned char) ch;
    while ( len-- > 0 ) *(d++) =  byte;
  }
  return dest;
}

/**
 * mem_cmp is a replacement of 'memcmp'
 * 
 * mem_cmp compares two memory regions.
 * - parameters:
 *   - p1:  First memory location to compare
 *   - p2:  Second memory location to compare
 *   - len: #bytes to compare
 * - returns: 
 *      0, if p1 and p2 hold the same bytes
 *     <0, if the first not equal byte of p1 is smaller than that of p2
 *     >0  otherwise
 */
int mem_cmp(const void *p1, const void *p2, size_t len) {
  if ( p1 && p2 && (len >= 0) ) {
    const unsigned char *a =  (const unsigned char *) p1;
    const unsigned char *b =  (const unsigned char *) p2;
    while ( len-- )
      if ( *a != *b ) return ( (int) *a ) - ( (int) *b );
      else { a++; b++; }
    return 0;
  }
  else return -1;
}

/**
 * mem_move is a replacement of 'memmove'
 * 
 * mem_move moves 'len' bytes from 'src' to 'dest'. 'src' and 'dest'
 * may overlap.
 * - parameters:
 *   - dest: Destination memory location
 *   - src:  Source memory location
 *   - len: #bytes to move
 * - returns: dest
 */
void *mem_move(void *dest, const void *src, size_t len) {
  if ( dest && src ) {
    unsigned char *d =  (unsigned char *) dest;
    const unsigned char *s =  (const unsigned char *) src;
    if ( d < s ) while ( len-- > 0 ) *(d++) =  *(s++);
    else if ( d > s ) {
      d +=  len; s +=  len;
      while ( len-- > 0 ) *(--d) =  *(--s);
  } }
  return dest;
}

/**
 * mem_heap allocates memory and initializes it with a given memory location.
 * 
 * mem_heap allocates 'len' bytes and copies the same ammount of bytes from
 * 'ptr' to the allocated region if ptr!=0.
 * - parameters:
 *   - ptr: Source of initializing area, if != 0
 *   - len: #bytes to allocate (and copy)
 * - returns: the allocated pointer
 */
void *mem_heap(const void *ptr, size_t len) {
  if ( len > 0 ) {
    void *buff =  malloc ( len );
    if ( buff && ptr ) mem_cpy ( buff, ptr, len );
    return buff;
  }
  return 0;
}

/**
 * mem_resize is simply a replacement of 'realloc'.
 *
 * mem_resize assumes that the passed pointer 'ptr' has been
 * allocated. The allocated memory area is resized to 'len' bytes
 * and the newly re-allocated pointer is returned.
 *
 * @param ptr  allocated pointer to memory
 * @param len  number of bytes to (re-)allocate
 *
 * @return reallocated pointer
 */
void *mem_resize(void *ptr, size_t len) {
  return realloc(ptr, len);
}

/**
 * mem_0byte enforces a trailing zero byte.
 *
 * mem_0byte enforces a zero byte at the last byte position of the
 * passed pointer 'ptr'. If the last byte is not 0, the memory is reallocated
 * and an additional zero byte is appended.
 *
 * @param ptr  allocated pointer to memory
 * @param len  number of bytes stored in 'ptr'
 *
 * @return reallocated pointer
 */
void *mem_0byte(void **ptr, size_t *len) {
  unsigned char *p = ((unsigned char *)*ptr) + *len - 1;
  if ( *p ) {
    if ( (p = (unsigned char *)realloc(*ptr, *len+1)) ) {
      p[*len] = 0;
      *ptr = p; *len += 1;
      return p;
    }
    else return 0;
  }
  else return *ptr;
}

/**
 * mem_release frees allocated memor.
 * 
 * mem_release frees the memory the pointer *rptr points to and sets
 * *rptr to 0.
 * - parameters:
 *   - rptr: reference to memory pointer
 */
void mem_release(void **rptr) {
  free(*rptr);
  *rptr = 0;
}

// MARK: - Elementary String-Operations

/**
 * str_len is a replacement of strlen.
 * 
 * - parameters:
 *   - str: string of characters
 * - returns: #bytes stored in 'str'
 */
int str_len(const char *str) {
  if ( str ) {
    const char *mark =  str;
    while ( *str ) str++;
    return (int) ( str - mark );
  }
  else return 0;
}

/**
 * str_vcpy is a multiple copy version of 'strcpy'.
 * 
 * There are no more than 'len' characters copied from the string 
 * list 'vp' to 'dest'. 
 * If all strings are longer than 'len-1' bytes, len - 1 bytes are 
 * written to '*dest' and a terminating zero byte is added.
 * The last string in the list of strings must be 0.
 * After copying *dest is positioned to the trailing zero byte.
 * - parameters:
 *   - rdst: reference to destination memory location
 *   - len:  size of *rdst
 *   - vp:   pointer to argument list of strings
 * - returns: #bytes copied in total
 */
int str_vcpy(char **rdst, int len, va_list vp) {
  if ( rdst && *rdst && ( len > 0 ) ) {
    char *dst =  *rdst;
    const char *s;
    char *mark =  dst;
    while ( (s =  va_arg ( vp, const char * )) ) {
      while ( ( --len > 0 ) && ( *(dst++) = *(s++) ) );
      if ( len > 0 ) { dst--; len++; }
    }
    *dst =  '\0';
    *rdst =  dst;
    return (int) ( dst - mark );
  }
  return 0;
}

/**
 * str_mcpy is a multiple copy version of 'strcpy'.
 * 
 * There are no more than 'len' characters copied from the string 
 * list 'src' to 'dest'. 
 * If all strings are longer than 'len-1' bytes, len - 1 bytes are 
 * written to '*dest' and a terminating zero byte is added.
 * The last string in the list of strings must be 0.
 * - parameters:
 *   - dst:  destination memory location
 *   - len:  size of *dst
 *   - src:   source string to copy
 * - returns: #bytes copied in total
 *
 * Example:  str_mcpy(dest, len, "/a", "/", "b", 0) would yield:
 *            "/a/b" in 'dest'
 */
int str_mcpy(char *dst, int len, ...) {
  va_list vp;
  int l;
  va_start ( vp, len );
  l =  str_vcpy( &dst, len, vp );
  va_end ( vp );
  return l;
}

/**
 * str_rmcpy is a multiple copy version of str_rcpy. *dest is 
 * positioned to the trailing zero byte.
 */
int str_rmcpy(char **rdst, int len, ...) {
  va_list vp;
  int l;
  va_start ( vp, len );
  l =  str_vcpy( rdst, len, vp );
  va_end ( vp );
  return l;
}

/**
 * str_cpy is a replacement of 'strcpy'.
 *
 * There are no more
 * than 'len' characters copied from 'src' to 'dest'. If 'src' is 
 * longer than 'len', len - 1 bytes are written to 'dest' and a terminating
 * zero byte is added.
 * - parameters:
 *   - dest: where to copy to
 *   - len:  size of dest
 *   - src:  string to copy
 * - returns: #bytes copied
 */
int str_cpy(char *dst, int n, const char *src) {
  return str_mcpy(dst, n, src, (const char *) 0);
}

/**
 * str_rncpy is a replacement of 'strncpy'.
 * 
 * There are no more than 'len' characters copied from 'src' to '*dest'. 
 * If 'src' is longer than 'len' bytes, len - 1 bytes are written to 'dest'
 * and a terminating zero byte is added.
 * While 'len' defines the size of 'dest', n specifies the max. number of
 * characters to copy from 'src' (without counting a zero byte). Ie. let
 * l be the length of 'src' (str_len(src)), then the number of bytes
 * (incl. zero byte) copied to '*dest' evalutes to:
 * min(len, (min(l, n) + 1))
 * After copying, *dest is positioned to the trailing zero byte.
 */
int str_rncpy(char **dst, int len, const char *src, int n) {
  int l =  min(len, n + 1);
  return str_rmcpy(dst, l, src, (const char *) 0);
}

/**
 * str_ncpy is a replacement of 'strncpy'.
 * 
 * Refer to 'str_rncpy' for more information. 
 */
int str_ncpy(char *dst, int len, const char *src, int n) {
  int l =  min(len, n + 1);
  return str_mcpy(dst, l, src, (const char *) 0);
}

/**
 * str_rcpy is a replacement of 'strcpy'.
 * 
 * *rdst is positioned to the terminating zero byte.
 */
int str_rcpy ( char **rdst, int n, const char *src ) {
  return str_rmcpy ( rdst, n, src, (const char *) 0 );
}

/**
 * str_rqcpy is used to quote a string while copying.
 * 
 * Each occurrence of " or \ is preceeded by a \. Also the resulting 
 * string is surrounded by quotes (").
 */
int str_rqcpy(char **dest, int len, const char *src) {
  int ret =  0;
  if ( dest && *dest && src && ( len > 2 ) ) {
    char *d =  *dest;
    const char *s =  src;
    int l =  len;
    *d++ =  '"';
    while ( *s && ( --l > 2 ) ) {
      if ( ( ( *s == '"' ) || ( *s == '\\' ) ) && ( l > 3 ) )
        { *d++ =  '\\'; l--; }
      *d++ =  *s++;
    }
    *d++ =  '"';
    *d =  '\0';
    ret =  (int) ( d - *dest );
    *dest =  d;
  }
  return ret;
}

/**
 * str_rchcpy is used to copy a character 'ch' 'n' times to *dest.
 * 
 * After copying, *dest is positioned to the trailing \0.
 */
int str_rchcpy(char **dest, int len, char ch, int n) {
  if ( dest && *dest && ( len > 0 ) ) {
    int ret, k =  min(len - 1, n);
    char *p =  *dest;
    while ( k-- > 0 ) *p++ =  ch;
    *p =  '\0';
    ret =  (int) ( p - *dest );
    *dest =  p;
    return ret;
  }
  return 0;
}

/// str_chcpy is used to copy a character 'ch' 'n' times to dest.
int str_chcpy(char *dest, int blen, char ch, int n) {
  return str_rchcpy(&dest, blen, ch, n);
}

/**
 * str_vcat is a multiple copy version of 'strcat'.
 * 
 * There are no more than 'l = len - str_len ( *dest )' characters 
 * copied from the string list 'vp' to 'dest'. 
 * If all strings are longer than 'l', l - 1 bytes are written to 
 * '*dest' and a terminating zero byte is added.
 * The last string in the list of strings must be 0.
 */
int str_vcat( char **rdst, int len, va_list vp) {
  if ( rdst && *rdst && ( len > 0 ) ) {
    char *dst =  *rdst;
    while ( *dst && ( len > 0 ) ) { dst++; len--; }
    if ( len > 0 ) {
      int ret =  str_vcpy(&dst, len, vp);
      *rdst =  dst;
      return ret;
  } }
  return 0;
}

/**
 * str_mcat is a multiple copy version of 'strcat'.
 * 
 * Refer to str_vcat for more information. 
 */
int str_mcat(char *dst, int n, ...) {
  va_list vp;
  int l;
  va_start ( vp, n );
  l =  str_vcat ( &dst, n, vp );
  va_end ( vp );
  return l;
}

/**
 * str_rmcat is a multiple copy version of 'strcat'.
 * 
 * Refer to str_vcat for more information. 
 */
int str_rmcat(char **rdst, int len, ...) {
  va_list vp;
  int l;
  va_start ( vp, len );
  l =  str_vcat ( rdst, len, vp );
  va_end ( vp );
  return l;
}

/// str_cat is a replacement of 'strcat'.
int str_cat(char *dst, int len, const char *src) {
  return str_mcat(dst, len, src, (const char *) 0);
}

/// str_ncat is a replacement of 'strncat'.
int str_ncat(char *dst, int len, const char *src, int n) {
  if ( dst ) {
    int l =  len - str_len ( dst );
    l =  min(l, n + 1);
    return str_mcat(dst, l, src, (const char *) 0);
  }
  else return 0;
}

/// Like str_cat but positions *rdst to the trailing zero byte.
int str_rcat(char **rdst, int len, const char *src) {
  return str_rmcat( rdst, len, src, (const char *) 0);
}
 
/**
 * str_heap allocates memory to store a copy of 'str'.
 * 
 * str_heap allocates n+1 bytes, where n=min(str_len(str),len), and
 * copies the first n bytes from 'str' to the newly allocated string.
 * - parameters:
 *   - str: string to copy
 *   - len: max. number of bytes to copy (0 => all bytes)
 * - returns: the allocated string
 */
char *str_heap(const char *str, int len) {
  char *ret =  0;
  if ( str ) {
    int size, l =  str_len ( str );
    if ( len && len < l ) l =  len;
    size =  ( l + 1 ) * sizeof ( char );
    if ( (ret =  (char *) malloc ( size )) ) {
      mem_cpy ( ret, str, size );
      ret [l] =  '\0';
  } }
  return ret;
}

 /// Releases the memory allocated by 'str_heap' and writes 0 to *rstr.
void str_release(char **rstr) {
  if ( rstr && *rstr ) {
    free ( *rstr );
    *rstr =  0;
} }

/**
 * str_slice slices a substring out of 'str'
 * 
 * The returned string is allocated and is quivalent to 
 * str [from] ... str [to]. If 'to' is left unspecified (-1), 
 * 'to' is set to (strlen(str) - 1).
 * - parameters: 
 *   - str:  string to get substring out of
 *   - from: start position of newly created string (0 is first char)
 *   - to:   end position (-1 => last char)
 * - returns: allocated substring
 */
char *str_slice(const char *str, int from, int to) {
  if ( str ) {
    int maxidx =  str_len ( str ) - 1;
    if ( ( to < 0 ) || ( to > maxidx ) ) to =  maxidx;
    if ( ( from > -1 ) && ( from <= to ) )
      return str_heap(str + from, to - from + 1);
    else return str_heap("", 0);
  }
  else return 0;
}

/// str_chr is a replacement of 'strchr'.
const char *str_chr(const char *s, char c) {
  if ( s ) {
    while ( *s && ( *s != c ) ) s++;
    if ( *s ) return s;
    else return 0;
  }
  else return 0;
}

/// str_rchr is a replacement of 'strrchr'. Ie. it looks for the
/// last occurrence of 'c' in 'str'.
const char *str_rchr(const char *s, char c) {
  if ( s ) {
    const char *mark =  s;
    while ( *s ) s++;
    while ( ( s >= mark ) && ( *s != c ) ) s--;
    if ( s >= mark ) return s;
    else return 0;
  }
  else return 0;
}

/**
 *  str_pbrk is a replacement of 'strpbrk'. 
 *  
 *  The pointer to the first character of 's' occurring in 'str' 
 *  is returned.
 */
const char *str_pbrk(const char *s1, const char *s2 ) {
  const char *mark =  s2;
  if ( s1 && s2 ) {
    while ( *s1 ) {
      while ( *s2 && ( *s1 != *s2 ) ) s2++;
      if ( *s2 ) return s1;
      s2 = mark; s1++;
  } }
  return 0;
}

/**
 *  'str_ccmp' works alike str_cmp.
 *  
 *  Unlike 'str_cmp' the comparision is stopped at the first occurrence 
 *  of the delimiter character 'delim'.
 *  The delimiter character is not used for comparision.
 *  - parameters: 
 *    - s1:    first string to compare
 *    - s2:    second string to compare
 *    - delim: delimiter character
 */
int str_ccmp(const char *s1, const char *s2, char delim) {
  if ( s1 && s2 ) {
    while ( *s1 && ( *s1 == *s2 ) && ( *s1 != delim ) ) { s1++; s2++; }
    if ( ( ( *s1 == delim ) && !*s2 ) || ( ( *s2 == delim ) && !*s1 ) )
      return 0;
    return (int) *s1 - (int) *s2;
  }
  else return -1;
}

/// str_cmp is a replacement of 'strcmp'.
int str_cmp(const char *s1, const char *s2) {
  if ( s1 && s2 ) {
    while ( *s1 && ( *s1 == *s2 ) ) { s1++; s2++; }
    return (int) (*s1) - (int) (*s2);
  }
  else return -1;
}

/// str_ncmp is a replacement of 'strncmp'.
int str_ncmp(const char *s1, const char *s2, int n) {
  if ( s1 && s2 ) {
    if ( n <= 0 ) return 0;
    while ( ( --n > 0 ) && *s1 && ( *s1 == *s2 ) ) { s1++; s2++; }
    return (int) (*s1) - (int) (*s2);
  }
  else return -1;
}

/// str_casecmp is a replacement of 'strcasecmp'.
int str_casecmp(const char *s1, const char *s2) {
  if ( s1 && s2 ) {
    while ( *s1 && ( tolower ( *s1 ) == tolower ( *s2 ) ) ) { s1++; s2++; }
    return (int) tolower ( *s1 ) - (int) tolower ( *s2 );
  }
  else return -1;
}

/// str_ncasecmp is a replacement of 'strncasecmp'.
int str_ncasecmp(const char *s1, const char *s2, int n) {
  if ( s1 && s2 ) {
    if ( n <= 0 ) return 0;
    while ( ( --n > 0 ) && *s1 && ( tolower ( *s1 ) == tolower ( *s2 ) ) )
      { s1++; s2++; }
    return (int) tolower ( *s1 ) - (int) tolower ( *s2 );
  }
  else return -1;
}

// Mark: - Shell pattern matching

/**
 * str_is_gpattern checks for shell meta characters in a string.
 * 
 * str_is_gpattern is used to check 'str' against pattern matching
 * meta characters which are not escaped (preceeded by '\').
 * The following characters are considered meta characters: "*?[".
 */
int str_is_gpattern(const char *str) {
  const char *p =  str;
  while ( *p ) switch ( *(p++) ) {
    case '\\' :  if ( *p ) p++; break;
  /*case '{'  : reserved for advanced (eg tcsh) pattern matching */
    case '['  :
    case '?'  :
    case '*'  :  return 1;
  }
  return 0;
}
    
/*
 *  _altchar
 *  is used to match a single character against an alternative of the
 *  following form:
 *
 *     altchar =  "[" [ "!" ] altitem "]".
 *     altitem =  char | ( "\" char ) | ( char "-" char ).
 */
static int _altchar(const unsigned char **rs, const unsigned char **rp) {
  const unsigned char *s = *rs, *p = *rp;
  int is_reverse =  0, ret =  0,
      was_matched =  0,
      ch =  *(s++), chleft =  -1, chp;
  p++;
  if ( *p == '!' ) { p++; is_reverse =  1; }
  while ( (chp = *(p++)) ) {
    if ( chp == ']' ) { ret =  was_matched? 1 : 0; break; }
    if ( ( chp == '-' ) && ( chleft > 0 ) && ( *p != ']' ) ) {
      if ( is_reverse ) 
	if ( ( ch < chleft ) || ( ch > (int) *(p++) ) ) was_matched++;
	else { ret =  0; break; }
      else 
        if ( ( ch >= chleft ) && ( ch <= (int) *(p++) ) ) was_matched++;
    }
    else {
      if ( chp == '\\' ) chp =  *(p++);
      chleft =  chp;
      if ( is_reverse )
	if ( ch != chleft ) was_matched++;
	else { ret =  0; break; }
      else if ( ch == chleft ) was_matched++;
  } }
  *rs =  s;
  *rp =  p;
  return ret;
}

static int _pattern(const unsigned char **, const unsigned char **);
/*
 *  _item 
 *  is used to match an item:
 *     item  =  char | altchar | "*" | "?" | ( "\" char ).
 */
static int _item(const unsigned char **rs, const unsigned char **rp) {
  const unsigned char *s = *rs, *p = *rp;
  switch ( *p ) {
    case '\0' :  return *s? 0 : 1;
    case '['  :  return _altchar ( rs, rp );
    case '*'  :  while ( *p == '*' ) p++;
		 if ( !*p ) {
		   while ( *s ) s++;
		   *rs =  s; *rp =  p;
		   return 1;
		 }
		 else {
		   const unsigned char *sm = s, *pm = p;
		   while ( *sm ) {
		     if ( _pattern ( &sm, &pm ) ) {
		       *rs = sm; *rp = pm;
		       return 1;
		     }
		     else { sm = ++s; pm = p; }
		 } }
		 *rs =  s; *rp =  p;
		 return 0;
    case '?'  :  if ( !*s ) return 0;
		 else break;
    case '\\' :  p++;
    default   :  if ( *p != *s ) { *rs =  s; *rp =  p; return 0; }
		 else break;
  }
  *rs =  s + 1; *rp =  p + 1;
  return 1;
}

/*
 *  _pattern 
 *  is used to match a pattern:
 *      pattern =  item { item }.
 */
static int _pattern(const unsigned char **rs, const unsigned char **rp) {
  while ( **rp )
    if ( !_item ( rs, rp ) ) return 0;
  if ( **rs || **rp ) return 0;
  else return 1;
}

/**
 * str_gmatch matches a given string against a Shell pattern.
 * 
 * str_gmatch is used to match a given string 'str' against a pattern
 * as used by the bourne shell 'sh'.
 * The pattern must be constructed like follows:
 * @code
 *        pattern =  item { item }.
 *        item    =  char | altchar | "*" | "?" | ( "\" char ).
 *        altchar =  "[" [ "!" ] altitem "]".
 *        altitem =  char | ( "\" char ) | ( char "-" char ).
 * @endcode
 *
 * @param str      string to match against
 * @param pattern  shell pattern
 *
 * @return 1  string was matched
 * @return 0  string wasn't matched
 */
int str_gmatch(const char *str, const char *pattern) {
  const unsigned char *s =  (const unsigned char *) str,
		      *p =  (const unsigned char *) pattern;
  return _pattern(&s, &p);
}

/**
 * str_match searches for a substring.
 * 
 * str_match is used to look for a string 'match' in a given string 'str'.
 * If 'match' could be found, a pointer to the first occurrence of 'match' is returned.
 * Eg.: str_match ( "this is a test", "is", 0 )
 * would return "is a test".
 * If an optional delimiter character has been specified, the search is 
 * stopped at this character. Eg. str_match("X=abc", "abc", '=') would
 * return 0.
 *
 * @param str:   string to search in
 * @param match: string to look for in 'str'
 * @param delim: delimiter character (0 => don't use)
 *
 * @return  pointer to occurrence of 'match' in str, if found
 * @return  0, if 'match' couldn't be found
 */
const char *str_match(const char *str, const char *match, char delim) {
  const char *s =  str, *m =  match;
  if ( !( str && match ) ) return 0;
  if ( s && m && *m ) {
    while ( *s && ( *s != delim ) ) {
      const char *sav =  s;
      m =  match;
      while ( *m && ( *s == *m ) ) { s++; m++; }
      if ( !*m ) return sav;
      else s =  sav + 1;
  } }
  return 0;
}

/**
 * mem_match is used to look for a string 'match' in a memory location 'mem'.
 * 
 * If 'match' could be found, a pointer to the first occurrence of 'match'
 * is returned.
 */
const void *mem_match(const void *mem, int len, const char *match) {
  const char *s =  (const char *) mem, *m =  match;
  if ( !( mem && match ) ) return 0;
  if ( s && m && *m ) {
    while ( len > 0 ) {
      const char *sav =  s;
      int savlen =  len;
      m =  match;
      while ( (len > 0) && *m && ( *s == *m ) ) { s++; m++; len--; }
      if ( !*m ) return (const void *) sav;
      else { s =  sav + 1; len =  savlen - 1; }
  } }
  return 0;
}

/// str_casematch works like str_match but ignores the ASCII character case
const char *str_casematch(const char *str, const char *match, char delim) {
  const char *s =  str, *m =  match;
  if ( !( str && match ) ) return 0;
  if ( s && m && *m ) {
    while ( *s && ( *s != delim ) ) {
      const char *sav =  s;
      m =  match;
      while ( *m && ( tolower ( *s ) == tolower ( *m ) ) ) { s++; m++; }
      if ( !*m ) return sav;
      else s =  sav + 1;
  } }
  return 0;
}


/**
 * str_substring scans a string for white space delimited substrings.
 *
 * str_substring is used to extract a substring from 'rstr' in the following
 * way:
 *         (1)  each white space character is skipped
 *         (2)  each non white space character is copied to an allocated buffer
 *              until the next white space character or the delimiter character
 *              'delim' is encountered
 *         (3)  if 'delim' wasn't encountered following white space is skipped
 *
 * On return 'str' is positioned either to:
 *      o  'delim' if that character was encountered
 *      o  '\0'    if no more non white characters are available
 *      o  next non white character otherwise
 * The substrings encountered are written to 'buff' where buff must be
 * big enough to store len characters plus one terminating zero byte.
 *
 * Remark: Escaped delimiters are skipped (ie. \'delim' is converted to
 *         'delim' and ignored).
 *         Quoted substrings may be included, white space and escaped quotes
 *         are ignored (ie. \" is converted to " and ignored).
 *
 * Examples:
 *     Let str = 'a b "c d" e', then following successive calls yield:
 *       str_substring ( &str ) = "a" and str = 'b "c d" e'
 *       str_substring ( &str ) = "b" and str = '"c d" e'
 *       str_substring ( &str ) = "c d" and str = 'e'
 *       str_substring ( &str ) = 0 and str = '' ("e" was copied to buff)
 *     Let str = 'a:b:"c d":e:f g:', then following successive calls yield:
 *       str_substring ( &str, ':' ) = "a" and str = 'b:"c d":e:f g:'
 *       str_substring ( &str, ':' ) = "b" and str = '"c d":e:f g:'
 *       str_substring ( &str, ':' ) = "c d" and str = 'e:f g:'
 *       str_substring ( &str, ':' ) = "e" and str = 'f g:'
 *       str_substring ( &str, ':' ) = "f g" and str = ''
 *       str_substring ( &str, ':' ) = 0 and str = '' ("" was copied to buff)
 *
 * - parameters:
 *   - rstr:  reference to string to search in
 *   - buff:  buffer to write substring to
 *   - len:   length of buff
 *   - delim: optional delimiter character, if != 0
 * - returns:
 *   - buff, if a substring was found
 *   - 0 otherwise
 */
const char *str_substring(const char **rstr, char *buff, int len, char delim) {
  const char *s;
  if ( rstr && ( s = *rstr ) && buff ) {
    const char *ret =  0;
    char *d =  buff;
    int n =  len;
    while ( *s && isspace ( *s ) ) s++;
    if ( *s ) {
      while ( *s && ( *s != delim ) ) {
	if ( *s == '"' ) {
	  s++;
	  while ( *s && ( *s != '"' ) ) {
	    if ( ( *s == '\\' ) && ( *(s + 1) == '"' ) ) s++;
	    if ( n-- > 0 ) *(d++) =  *s;
	    s++;
	  }
	  if ( *s == '"' ) s++;
	}
	else {
	  while ( *s && ( *s != '"' ) && ( *s != delim ) && !isspace ( *s ) ) {
	    if ( *s == '\\' )
	      if ( ( *(s + 1) == delim ) || ( *(s + 1) == '"' ) ) s++;
	    if ( n-- > 0 ) *(d++) =  *s;
	    s++;
	  }
	  if ( isspace ( *s ) ) {
	    if ( delim ) {
	      char *mark =  d;
	      while ( *s && isspace ( *s ) ) {
		if ( n-- > 0 ) *(d++) =  *s;
		s++;
	      }
	      if ( !*s || ( *s == delim ) ) d =  mark;
	    }
	    else break;
      } } }
      while ( *s && isspace ( *s ) ) s++;
      if ( delim ) {
	if ( *s == delim ) {
	  ret =  buff;
	  s++;
      } }
      else if ( *s ) ret =  buff;
      *d =  '\0';
      *rstr =  s;
      return ret;
    }
    else *buff =  '\0';
  }
  return 0;
}

/// str_trim returns an allocated string where leading and trailing white space 
/// is removed
char *str_trim(const char *str) {
  int l = str_len(str) + 1;
  char *tmp = (char *) malloc(l * sizeof(char));
  const char *s = str;
  char *d = tmp;
  while (*s && isspace (*s)) s++;
  str_cpy(&d, l, s);
  while ((d > tmp) && isspace(*(d-1))) d--;
  *d = 0;
  char *ret = str_heap(tmp, 0);
  str_release(&tmp);
  return ret;
}

/// str_2upper converts all ASCII characters in 'str' to upper case.
char *str_2upper(char *str) {
  char *p =  str;
  if ( !str ) return 0;
  while ( *p ) { *p =  toupper ( *p ); p++; }
  return str;
}

/// str_2upper converts all ASCII characters in 'str' to lower case.
char *str_2lower ( char *str ) {
  char *p =  str;
  if ( !str ) return 0;
  while ( *p ) { *p =  tolower ( *p ); p++; }
  return str;
}


/**
 *  str_reverse transforms a string to itself in reverse order.
 *  
 *  E.g. "01234" is converted by str_reverse("01234") to
 *  "43210".
 */
char *str_reverse(char *str) {
  if ( str ) {
    char *upper, *lower;
    char tmp;
    upper =  str + str_len ( str ) - 1;
    lower =  str;
    while ( lower < upper ) {
      tmp =  *lower;
      *(lower++) =  *upper;
      *(upper--) =  tmp;
  } }
  return str;
}

 
/*
 *  str_rquote produces a "quoted" string from 'str'. 
 *  
 *  It works similar to 'str_rqcpy' but unlike to that function the 
 *  following additional chars are escaped and the resulting string 
 *  is surrounded by quotes(").
 *
 *       linefeed          :   \n
 *       carriage return   :   \r
 *       backspace         :   \b
 *       tab               :   \t
 *       formfeed          :   \f
 *       vertical tab      :   \v
 *       alert             :   \a
 *
 *  Additionally the newly generated string is surrounded by
 *  quotes (").
 *  Also each occurrence of " or \ is preceeded by a \.
 *  After copying *buff is positioned to the terminating \0.
 */
int str_rquote(char **dest, int blen, const char *src) {
  int ret =  0;
  if ( dest && *dest && src && ( blen > 2 ) ) {
    char *d =  *dest;
    const char *s =  src;
    int l =  blen;
    *d++ =  '"';
    while ( *s && ( --l > 2 ) ) {
      switch ( *s ) {
	case '\n':  if ( l > 3 ) { *d++ =  '\\'; *d++ =  'n'; l --; } break;
	case '\r':  if ( l > 3 ) { *d++ =  '\\'; *d++ =  'r'; l --; } break;
	case '\b':  if ( l > 3 ) { *d++ =  '\\'; *d++ =  'b'; l --; } break;
	case '\t':  if ( l > 3 ) { *d++ =  '\\'; *d++ =  't'; l --; } break;
	case '\f':  if ( l > 3 ) { *d++ =  '\\'; *d++ =  'f'; l --; } break;
	case '\v':  if ( l > 3 ) { *d++ =  '\\'; *d++ =  'v'; l --; } break;
	case '\a':  if ( l > 3 ) { *d++ =  '\\'; *d++ =  'a'; l --; } break;
	case '"' :
	case '\\':  if ( l > 3 ) { *d++ =  '\\'; l--; }
	default  :  *d++ =  *s;
      }
      s++;
    }
    *d++ =  '"';
    *d =  '\0';
    ret =  (int) ( d - *dest );
    *dest =  d;
  }
  return ret;
}
 
/// str_quote produces a "quoted" string. 
/// Refer to str_rquote for more information.
/// - returns: an allocated string storing the quoted result
char *str_quote(const char *str) {
  if ( str ) {
    const char *s =  str;
    char *news =  (char *) 0;
    int len =  3;
    while ( *s ) switch ( *(s++) ) {
      case '\n' : case '\r' : case '\b' : case '\t' : case '\f' :
      case '\v' : case '\a' : case '\\' : case  '"' :  len++;
      default   :  len++; break;
    }
    news =  (char *) malloc ( len );
    if ( news ) {
      char *p =  news;
      str_rquote ( &p, len, str );
      return news;
  } }
  return 0;
}
 

/*
 *  str_rxmlescape produces a string from 'str' where XML special characters
 *  are escaped. 
 *  
 *  This transformation may be used inside XML attributes and inside text elements.
 *  The following characters are substituted:
 *
 *       < : &lt;
 *       > : &gt;
 *       & : &amp;
 *
 *  If is_attribute == true, the following additional transformations are performed:
 *
 *       " : &quot;
 *       ' : &apos;
 *
 *  After copying *buff is positioned to the terminating \0.
 */
int str_rxmlescape(char **dest, int blen, const char *src, int is_attribute) {
  int ret =  0;
  if ( dest && *dest && src && ( blen > 0 ) ) {
    char *d =  *dest;
    const char *s =  src;
    int l =  blen;
    while ( *s && (l > 0) ) {
      switch ( *s ) {
        case '<':  
          l -= str_rcpy(&d, l, "&lt;"); s++;
          continue;
        case '>':
          l -= str_rcpy(&d, l, "&gt;"); s++;
          continue;
        case '&': 
          l -= str_rcpy(&d, l, "&amp;"); s++;
          continue;
        case '\'':
          if (!is_attribute) break;
          l -= str_rcpy(&d, l, "&apos;"); s++;
          continue;
        case '"':
          if (!is_attribute) break;
          l -= str_rcpy(&d, l, "&quot;"); s++;
          continue;
      }
      *d++ = *s++; l--;
    }
    *d =  '\0';
    ret =  (int) ( d - *dest );
    *dest =  d;
  }
  return ret;
}

// Evaluate xmlescape buffer size
static int xmlescape_buffsize(const char *s, int is_attribute) {
  int ret = 0;
  while (*s) {
    switch (*s++) {
      case '<':
      case '>': ret += 4; break;
      case '&': ret += 5; break;
      case '\'':
      case '"': 
        if (is_attribute) ret += 6; 
        else ret++;
        break;
      default:  ret++; break;
    }
  }
  return ret;
}
 
/// str_xmlescape returns an allocated string with XML special characters
/// escaped. Refer to 'str_rxmlescape'.
char *str_xmlescape(const char *str, int is_attribute) {
  if ( str ) {
    int len = xmlescape_buffsize(str, is_attribute) + 1;
    char *news =  (char *) malloc ( len );
    if ( news ) {
      char *p =  news;
      str_rxmlescape ( &p, len, str, is_attribute );
      return news;
  } }
  return 0;
}

#define _ord(v) ( isdigit(v)? ( (v) - '0' ) : 10 + ( toupper(v) - 'A' ) )

/**
 *  str_rdequote is the reverse operation of 'str_rquote'.
 *  
 *  I.e. quotes around a string or parts of a string are removed 
 *  and all escape sequences (such as \n) are replaced 
 *  by their character equivalent.
 *  A sequence of '\c' where c may be any non special character
 *  is replaced by c.
 *  In addition the "trigraphs" \<ooo> and \x<dd> are converted ('o' is
 *  a single octal digit and 'd' is a single hexadecimal digit).
 *  If 'str' starts with a quote(") then the scanning is stopped at a
 *  corresponding quote in 'str' ie. the string '"foo"foo' will write 'foo'
 *  to *buff.
 *  After copying *buff is positioned to the terminating \0-byte.
 */
int str_rdequote(char **dest, int blen, const char *src) {
  if ( dest && *dest && src && ( blen > 1 ) ) {
    char *d =  *dest;
    const char *s =  src;
    int l =  blen, isquoted = 0;
    if ( *s == '"' ) { s++; isquoted++; }
    while ( *s && ( l > 1 ) ) {
      switch ( *s ) {
	case '\\' :  
	  switch ( *(++s) ) {
	    case '\0':  continue;
	    case 'n' :  *(d++) =  '\n'; break;
	    case 'r' :  *(d++) =  '\r'; break;
	    case 'b' :  *(d++) =  '\b'; break;
	    case 't' :  *(d++) =  '\t'; break;
	    case 'f' :  *(d++) =  '\f'; break;
	    case 'a' :  *(d++) =  '\a'; break;
	    case 'v' :  *(d++) =  '\v'; break;
	    case 'x' :  if ( *(s+1) && isxdigit ( *(s+1) ) &&
	                     *(s+2) && isxdigit ( *(s+2) ) ) {
                          *(d++) =  _ord ( *(s+1) ) * 16 + _ord ( *(s+2) );
			  s +=  2;
			  break;
			}
	    default  :  if ( *(s) && isdigit ( *(s) ) &&
	                     *(s+1) && isdigit ( *(s+1) ) &&
	                     *(s+2) && isdigit ( *(s+2) ) ) {
                          *(d++) =  _ord ( *s ) * 64 + 
			            _ord ( *(s+1) ) * 8 + _ord ( *(s+2) );
			  s +=  2;
			  break;
			}
	                else *(d++) =  *s;
	  } break;
	case '"'  :  if ( isquoted ) {
	               *d =  '\0';
		       *dest =  d;
		       return blen - l;
	             }
	default   :  *(d++) =  *s;
      }
      s++; l--;
    }
    *d =  '\0';
    *dest =  d;
    return blen - l;
  }
  return 0;
}
 
/// str_dequote is the reverse operation of 'str_quote'.
/// Refer to str_rdequote for more information.
char *str_dequote(const char *str) {
  if ( str ) {
    int l =  str_len ( str ) + 1;
    char *news =  (char *) malloc ( l );
    if ( news ) {
      char *p =  news;
      str_rdequote ( &p, l, str );
      return news;
  } }
  return 0;
}

/**
 * str_error is a replacement for strerror.
 * 
 * If the provided error number errcode == 0, then 'str_error' uses errno
 * to return a string representing the last system error.
 * - returns: static string value
 */
const char *str_error ( int errcode ) {
  if (errcode == -1) errcode =  errno;
  return strerror(errcode);
}

/// str_get is a straightforward safe substitute for 'gets'.
char *str_get(char *buff, int blen) {
  if ( buff && blen > 0 ) {
    buff [ blen - 1 ] =  '\0';
    if (  fgets ( buff, blen - 1, stdin ) ) {
      int len =  str_len ( buff );
      if ( buff [len - 1] == '\n' ) buff [len - 1] =  '\0';
      return buff;
  } }
  return 0;
}

/**
 * str_skip_white skips over white space in a string reference.
 *
 * str_skip_white is used to skip in a string over white space and
 * comments. A comment is each sequence surrounded by # (not beyond
 * end of line) or a sequence of characters from a # to end of line.
 * If 'skip_eol' is true, the string is skipped beyond the end of lines.
 * 'p' is positioned to the first non white character.
 * - returns: 
 *   - 0 if at end of string
 *   - 1 if a non white space char is available
 */
int str_skip_white ( const char **p, int skip_eol ) {
  const char *s =  *p;
  while ( *s ) {
    if ( !isspace(*s) || ( !skip_eol && ( *s == '\n' ) ) ) {
      if ( *s == '#' ) {
        while ( *(++s) && ( *s != '\n' ) && ( *s != '#' ) );
        if ( !*s ) { *p = s; return 0; }
      }
      else { *p = s; return 1; }
    }
    else s++;
  }
  *p = s; return 0;
}

// MARK: - Roman Number Conversion

// Conversion tables to convert roman <-> integer
const char *_ldig [] = { "  M", "MDC", "CLX", "XVI" },
           *_sdig [] = { "  m", "mdc", "clx", "xvi" };
const unsigned short _dval [] =  {
  0, 0, 100, 500, 0, 0, 0, 0, 1, 0, 0, 50, 1000, 0, 0, 0, 0, 0, 0,
  0, 0, 5, 0, 10, 0, 0 };

/**
 * str_i2roman converts an integer into a roman numeral.
 * 
 * str_i2roman is used to convert an integer into a string consisting
 * of roman digits. val must be less than 4000 and greater than 0.
 * 
 * - parameters: 
 *   - buff:    where to write the digits to
 *   - len:     length of buff (incl. \0)
 *   - val:     value to convert
 *   - islarge: use capital roman digits?
 *   
 * - returns: #chars written to 'buff'
 */
int str_i2roman(char *buff, int len, int val, int islarge) {
  if ( buff && ( len > 1 ) ) {
    int i, last = 0, n = len, div = 1000;
    char *p =  buff;
    const char **dig =  islarge? _ldig : _sdig;
    if ( val < 0 ) {
      *p++ =  '-'; n--;
      val =  -val;
    }
    if ( val >= 4000 ) return -1;
    for ( i = 0; i < 4; i++ ) {
      int v =  val / div;
      char *m =  p;
      if ( n < 4 ) return -1;
      for (;;) {
        switch ( v ) {
          case 3 :  *p++ =  dig [i][2];
          case 2 :  *p++ =  dig [i][2];
          case 1 :  *p++ =  dig [i][2];
            break;
          case 4 :  *p++ =  dig [i][2];
            *p++ =  dig [i][1];
            break;
          case 5 :  if ( (last == 4) || (last == 9) )
            *(p-2) =  dig [i][1];
          else *p++ =  dig [i][1];
            break;
          case 6 :
          case 7 :
          case 8 :  *p++ =  dig [i][1]; v -= 5;
            continue;
          case 9 :  if ( ( (last == 4) || (last == 9) ) ) *(p-2) =  dig [i][2];
          else {
            *p++ =  dig [i][2];
            *p++ =  dig [i][0];
          }
            break;
        }
        break;
      }
      val %= div; div /= 10;
      n -= (int) ( p - m );
      last =  v;
    }
    *p =  '\0';
    return len - n;
  }
  return -1;
}

/**
 * str_rroman2i converts a roman numeral to an integer.
 * 
 * str_rroman2i is used to convert a string of roman digits to
 * an integer number. After comparision *rstr is positioned to the
 * first char not beeing a roman digit. The digits may be in lower
 * or upper case.
 */
int str_rroman2i(const char **rstr) {
  if ( rstr && *rstr ) {
    const char *p =  *rstr;
    int val =  0;
    while ( isalpha ( *p ) ) {
      int idx =  toupper ( *p ) - 'A';
      if ( !_dval [ idx ] ) break;
      if ( isalpha ( *(p+1) ) ) {
        int idx2 =  toupper ( *(p+1) ) - 'A';
        if ( _dval [ idx ] < _dval [ idx2 ] ) {
          val +=  _dval [ idx2 ] - _dval [ idx ];
          p +=  2;
          continue;
        } }
      val +=  _dval [ idx ];
      p++;
    }
    return val? val : -1;
  }
  return -1;
}

/// str_roman2i converts a string of roman digits to an integer.
int str_roman2i ( const char *str ) {
  return str_rroman2i ( &str );
}

// MARK: - Bourne Shell Macro Expansion

// _realloc is used by str_mexpand to increase the buffer size by 1024 bytes
static int _realloc ( char **buff, char **ptr, int *size ) {
  char *tmp =  (char *) realloc ( *buff, ( (*size += 1024) + 1 ) 
                                  * sizeof ( char ) );
  if ( tmp ) {
    *ptr =  tmp + ( *ptr - *buff );
    *buff =  tmp;
    return 0;
  }
  else { free(buff); return -1; }
}

/**
 * str_mexpand performs a bourne shell like macro expansion.
 * 
 * str_mexpand is used to expand all macros in 'str' depending on
 * the return values of str_matchfunc_t 'match', which is expected to be:
 *    const char *match(void *ptr, const char *macro)
 *    void *ptr         :  pointer ptr passed to 'str_mexpand'
 *    const char *macro :  name of macro to expand
 * In case of ${m:=n} macros the update function:
 *    int update(void *ptr, const char *macro, const char *value)
 *    void *ptr         :  pointer ptr passed to 'str_mexpand'
 *    const char *macro :  name of macro to update
 *    const char *value :  value of macro
 * is called for inserting a new macro or updating an existing macro 'macro'.
 * If update = 0, no update will be performed.
 *
 * If a macro $<mname> has no current value (ie. match returns 0), it is 
 * substituted by an empty string "".
 * A macro is defined as follows:
 *
 *        macro      =  "$" identifier | 
 *                      "${" msequence "}".
 *        msequence  =  char_sequence [ ":" mop [ char_sequence ] ].
 *        mop        =  "+" | "-" | "!" | "=".
 *        identifier =  letter { letter | digit | "_" }.
 *
 * If the "$" is preceeded by a "\", no substitution is performed but
 * the backslash is removed.
 * If the char_sequence itself contains macro references, these are expanded
 * recursively.
 * 
 * The macro operators mop are expanded as follows:
 *       ${m1:+m2}   -->  if m1 is defined substitute m2 else nil
 *       ${m1:-m2}   -->  if m1 is defined substitute m1 else m2
 *       ${m1:!m2}   -->  if m1 is defined substitute nil else m2
 *       ${m1:=m2}   -->  if m1 is defined substitute m1 
 *                        else ( substitute m2 and define m1 to m2 )
 * - parameters:
 *   - str:    string containing macros
 *   - match:  function to call for macro expansion
 *   - update: function to call for macro updates/definitions
 * 
 * - returns: allocated string with expanded macros
 */
char *str_mexpand ( const char *str, str_matchfunc_t *match, 
                    str_updatefunc_t *update, void *ptr ) {
  if ( str && match ) {
    int size =  1024, l =  0, brackets;
    char *buff =  (char *) malloc(( size + 1 ) * sizeof ( char ));
    char *d =  buff;
    const char *p =  str;
    if ( buff ) {
      while ( (*d = *p) ) {
        if ( l >= size ) 
          if ( _realloc(&buff, &d, &size) ) return 0;
        if ( ( *p == '\\' ) && ( *( p + 1 ) == '$' ) )
          *d =  *(++p);
        else if ( *p == '$' ) {
          if ( ( brackets = ( *(p+1) == '{' ) ) || isalpha(*(p+1)) 
              || ( *(p+1) == '_' ) ) {
            char *mname = 0;
            const char *mark, *val;
            if ( brackets ) {  /* macro of form ${<char_sequence>} */
              brackets =  1;
              mark =  ( p += 2 );
              while ( *p ) {
                if ( *p == '{' ) brackets++;
                else if ( *p == '}' )
                  if ( !--brackets ) break;
                p++;
              }
              if ( brackets ) p =  mark - 2;
              else {
                char *tmp =  str_heap(mark, (int)(p++ - mark));
                if ( tmp ) {
                  if ( !( mname =  str_mexpand(tmp, match, update, ptr) ) ) {
                    free(tmp); free(buff);
                    return 0;
                  }
                  free ( tmp );
                }
                else { free(buff); return (char *) 0; }
            } }
            else {  /* macro of form $<identifier> */
              mark =  ++p;
              while ( isalnum ( *p ) || ( *p == '_' ) ) p++;
              if ( !( mname =  str_heap(mark, (int)(p - mark)) ) )
                { free(buff); return (char *) 0; }
            }
            if ( mname ) {
              char *tval =  (char *) str_chr(mname, ':');
              int scode = 0;
              if ( tval ) switch ( *(tval + 1) ) {
                case '!':
                case '-':
                case '+':
                case '=': scode =  (int) ( *(tval + 1) );
                  *tval =  0;
                  tval +=  2;
                  break;
                default : tval =  0; break;
              }
              val =  match(ptr, mname);
              if ( tval ) switch ( scode ) {
                case '!': if ( !val ) val =  tval; else val = 0; break;
                case '-': if ( !val ) val =  tval; break;
                case '+': if ( val ) val =  tval; break;
                case '=': if ( update && ( !val || !*val ) )
                  update(ptr, mname, val = tval);
                  break;
              }
              if ( val ) {
                int vlen =  str_len ( val );
                if ( ( l + vlen ) >= size ) {
                  size +=  vlen;
                  if ( _realloc(&buff, &d, &size) )
                    { free(mname); return (char *) 0; }
                }
                mem_cpy(d, val, vlen);
                d +=  vlen;
                l +=  vlen;
              }
              free(mname);
              continue;
        } } }
        d++; p++; l++;
      }
      *(++d) =  '\0';
      return (char *) realloc( buff, ( l + 1 ) * sizeof ( char ));
  } }
  return 0;
}

/**
 * Returns an allocated string referencing the passed struct tm time data.
 * 
 * This function converts a struct tm to a string in ISO8601 format, which
 * is "yyyy-mm-dd hh:mm:ss[.uuuuuu]". The micosecond part "uuuuuu" is optional
 * and will only be produced if usec >= 0.
 * 
 * @param t    struct tm pointer as returned from 'localtime'
 * @param usec microseconds to format if >= 0
 *
 * @return allocated string in ISO8601 format
 */
char *str_tm2iso(struct tm *t, int usec) {
  char buff[101];
  if (usec >= 0) {
    snprintf(buff, 100, "%04d-%02d-%02d %02d:%02d:%02d.%06d", t->tm_year+1900,
             t->tm_mon+1, t->tm_mday, t->tm_hour, t->tm_min, t->tm_sec, usec);
  }
  else {
    snprintf(buff, 100, "%04d-%02d-%02d %02d:%02d:%02d", t->tm_year+1900,
             t->tm_mon+1, t->tm_mday, t->tm_hour, t->tm_min, t->tm_sec);
  }
  return str_heap(buff);
}

/**
 * Returns an allocated string referencing the passed struct tm time data.
 * 
 * This function converts a struct tm to a string in short ISO format, which
 * is "dd,hh:mm:ss
 * 
 * @param t    struct tm pointer as returned from 'localtime'
 *
 * @return allocated string in short ISO8601 format
 */
char *str_tm2short(struct tm *t) {
  char buff[101];
  snprintf(buff, 100, "%02d,%02d:%02d:%02d", t->tm_mday, t->tm_hour, 
           t->tm_min, t->tm_sec);
  return str_heap(buff);
}

// The struct utsname singleton
static struct utsname _utsname, *_utsnamep = 0;

inline struct utsname *utsname() {
  if (!_utsnamep) {
    uname(&_utsname);
    _utsnamep = &_utsname;
  }
  return _utsnamep;
}

const char *uts_sysname() { return utsname()->sysname; }
const char *uts_nodename() { return utsname()->nodename; }
const char *uts_release() { return utsname()->release; }
const char *uts_version() { return utsname()->version; }
const char *uts_machine() { return utsname()->machine; }
