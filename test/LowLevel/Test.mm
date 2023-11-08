//
//  TestLowlevel.m
//  Test
//
//  Created by Norbert Thies on 02.01.20.
//  Copyright © 2020 Norbert Thies. All rights reserved.
//

#import  <XCTest/XCTest.h>
#import  "NorthLowLevel.h"

@interface TestLowlevel : XCTestCase

@end

@implementation TestLowlevel

- (void) setUp {
}

- (void) tearDown {
}

double dist ( double d1, double d2 ) {
  double ret =  d1 - d2;
  return (ret < 0.0)? -ret : ret;
}

- (void) testFloat {
  double d; int i;
  XCTAssert(flt_exponent(1.234) == 1);
  d = flt_mantissa(1.234, 10, &i);
  XCTAssert(i == 1);
  XCTAssert(dist(d, 0.1234) < 0.0001);
  d = flt_mantissa ( 0.456e10, 10, &i );
  XCTAssert(i == 10);
  XCTAssert(dist(d, 0.456) < 0.001);
  d = flt_mantissa ( 0.0456e10, 10, &i );
  XCTAssert(i == 9);
  XCTAssert(dist(d, 0.456) < 0.001);
  d = flt_mantissa ( 0.456e-10, 10, &i );
  XCTAssert(i == -10);
  XCTAssert(dist(d, 0.456) < 0.001);
  d = flt_mantissa ( 0.0456e-10, 10, &i );
  XCTAssert(i == -11);
  XCTAssert(dist(d, 0.456) < 0.001);
  d = flt_mantissa ( 4.56e-10, 10, &i );
  XCTAssert(i == -9);
  XCTAssert(dist(d, 0.456) < 0.001);
  d = flt_mantissa ( 1.234e10, 16, &i );
  XCTAssert(i == 9);
  XCTAssert(dist(d, 0.179571) < 0.001);
}

- (void) testString {
  char buff1[1001], buff2[1001];
  mem_set(buff1, 'A', 1000);
  XCTAssert(buff1[999] == 'A');
  buff1[1000] = 0;
  mem_cpy(buff2, buff1, 1001);
  XCTAssert(mem_cmp(buff1, buff2, 1001) == 0);
  mem_set(buff2, 'B', 1000);
  XCTAssert(buff2[0] == 'B');
  mem_swap(buff1, buff2, 1001);
  XCTAssert(buff1[500] == 'B');
  XCTAssert(buff2[500] == 'A');
  mem_set(buff1, 'C', 500);
  mem_move(buff1, buff1+400, 500);
  XCTAssert(buff1[0] == 'C');
  XCTAssert(buff1[99] == 'C');
  XCTAssert(buff1[100] == 'B');
  void *ptr = mem_heap(buff1, 1001);
  XCTAssert(mem_cmp(ptr, buff1, 1001) == 0);
  mem_release(&ptr);
  XCTAssert(ptr == 0);
  XCTAssert(str_len(buff1) == 1000);
  str_cpy(buff1, 1001, "abc");
  XCTAssert(str_len(buff1) == 3);
  XCTAssert(str_cmp(buff1, "abc") == 0);
  str_cpy(buff1, 3, "abcd");
  XCTAssert(str_len(buff1) == 2);
  XCTAssert(str_cmp(buff1, "ab") == 0);
  str_mcpy(buff1, 1001, "ab", "cd", "ef", NIL);
  XCTAssert(str_cmp(buff1, "abcdef") == 0);
  str_ncpy(buff1, 1001, "abcd", 2);
  XCTAssert(str_cmp(buff1, "ab") == 0);
  char *s = buff1;
  str_rqcpy(&s, 1001, "a \"simple\" test with a \\ backslash");
  XCTAssert(str_cmp(buff1, 
    "\"a \\\"simple\\\" test with a \\\\ backslash\"" ) == 0);
  XCTAssert(s == buff1 + str_len(buff1));
  str_chcpy(buff1, 1001, '=', 5);
  XCTAssert(str_cmp(buff1, "=====") == 0);
  str_mcat(buff1, 1001, "a", "b", NIL);
  XCTAssert(str_cmp(buff1, "=====ab") == 0);
  s = str_heap(buff1, 0);
  XCTAssert(str_cmp(s, "=====ab") == 0);
  str_release(&s);
  XCTAssert(s == NIL);
  s = str_heap(buff1, 5);
  XCTAssert(str_cmp(s, "=====") == 0);
  str_release(&s);
  s = str_slice(buff1, 5, -1);
  XCTAssert(str_cmp(s, "ab") == 0);
  str_release(&s);
  s = str_slice(buff1, 5, 5);
  XCTAssert(str_cmp(s, "a") == 0);
  str_release(&s);
  const char *cs = str_chr(buff1, 'a');
  XCTAssert(cs == buff1+5);
  cs = str_rchr(buff1, '=');
  XCTAssert(cs == buff1 + 4);
  cs = str_pbrk(buff1, "ab");
  XCTAssert(cs == buff1+5);
  cs = str_pbrk(buff1, "Ab");
  XCTAssert(cs == buff1+6);
  XCTAssert(str_ccmp("abc=13", "abc=22", '=') == 0);
  XCTAssert(str_ncasecmp("abcdef", "ABCxyz", 3) == 0);
  XCTAssert(str_is_gpattern("ab[c-d]*xy") != 0);
  XCTAssert(str_gmatch("abcfooxy", "ab[c-d]*xy") == 1);
  XCTAssert(str_gmatch("abefooxy", "ab[c-d]*xy") == 0);
  XCTAssert(str_gmatch("abdxy", "ab[c-d]*xy") == 1);
  XCTAssert(str_match("X=abc", "abc", '=') == NIL);
  cs = "X=abc";
  XCTAssert(str_match(cs, "abc", 0) == cs+2);
  str_cpy(buff1, 1001, cs);
  const void *cp = mem_match(buff1, 1001, "abc");
  XCTAssert(cp == buff1+2);
  str_cpy(buff2, 1001, "a b \"c d\" e");
  cs = buff2;
  const char *cs2 = str_substring(&cs, buff1, 1001, 0);
  XCTAssert(cs2 == buff1);
  XCTAssert(str_cmp(cs2, "a") == 0);
  XCTAssert(cs == buff2 + 2);
  cs2 = str_substring(&cs, buff1, 1001, 0);
  XCTAssert(str_cmp(cs2, "b") == 0);
  XCTAssert(cs == buff2 + 4);
  cs2 = str_substring(&cs, buff1, 1001, 0);
  XCTAssert(str_cmp(cs2, "c d") == 0);
  XCTAssert(cs == buff2 + 10);
  cs2 = str_substring(&cs, buff1, 1001, 0);
  XCTAssert(str_cmp(buff1, "e") == 0);
  XCTAssert(cs2 == NIL);
  XCTAssert(cs == buff2 + 11);
  s = str_trim(" bla\n ");
  XCTAssert(str_cmp(s, "bla") == 0);
  str_release(&s);
  str_cpy(buff1, 1001, "abc");
  XCTAssert(str_cmp(str_2upper(buff1), "ABC") == 0);
  XCTAssert(str_cmp(str_2lower(buff1), "abc") == 0);
  XCTAssert(str_cmp(str_reverse(buff1), "cba") == 0);
  s = str_quote("a \"b c\" d\n");
  XCTAssert(str_cmp(s, "\"a \\\"b c\\\" d\\n\"") == 0);
  char *s2 = str_dequote(s);
  XCTAssert(str_cmp(s2, "a \"b c\" d\n") == 0);
  str_release(&s);
  str_release(&s2);
  str_i2roman(buff1, 1001, 1024, 0);
  XCTAssert(str_cmp(buff1, "mxxiv") == 0);
  XCTAssert(str_roman2i(buff1) == 1024);
}

- (void) testArgv {
  const char *str = "a:b:c";
  char **av = av_a2av(str, ':');
  XCTAssert(av != 0);
  XCTAssert(av_length(av) == 3);
  XCTAssert(str_cmp(av[0], "a") == 0);
  XCTAssert(str_cmp(av[1], "b") == 0);
  XCTAssert(str_cmp(av[2], "c") == 0);
  XCTAssert(av[3] == 0);
  XCTAssert(av_size(av) == 3);
  av_release(av);
  str = "a \"b c\" d";
  av = av_a2av(str, 0);
  XCTAssert(av_length(av) == 3);
  XCTAssert(str_cmp(av[0], "a") == 0);
  XCTAssert(str_cmp(av[1], "b c") == 0);
  XCTAssert(str_cmp(av[2], "d") == 0);
  XCTAssert(av[3] == 0);
  XCTAssert(av_size(av) == 5);
  char buff[1001];
  int ret = av_av2a(buff, 1001, av, 0);
  XCTAssert(ret == str_len(str));
  XCTAssert(str_cmp(buff, str) == 0);
  av = av_minsert(av, 1, "x", "y", (const char *) 0);
  XCTAssert(av_length(av) == 5);
  XCTAssert(str_cmp(av[1], "x") == 0);
  XCTAssert(str_cmp(av[2], "y") == 0);
  av = av_mappend(av, "A", "B", (const char *) 0);
  XCTAssert(av_length(av) == 7);
  XCTAssert(str_cmp(av[5], "A") == 0);
  XCTAssert(str_cmp(av[6], "B") == 0);
  av_release(av);
}

- (void) testFile {
  printf("FS: %scase sensitive\n", fs_is_case_sensitive(".")? "" : "not ");
  char *dir = fn_abs(".");
  XCTAssert(dir != 0);
  printf("cwd: %s\n", dir);
  char *home = getenv("HOME");
  XCTAssert(home != 0);
  printf("home: %s\n", home);
  str_release(&dir);
  char buff[1000];
  snprintf(buff, 1000, "%s/../..", home);
  dir = fn_abs(buff);
  XCTAssert(dir != 0);
  printf("$HOME/../..: %s\n", dir);
  stat_t st;
  XCTAssert(stat_read(&st, home) == 0);
  XCTAssert(stat_isdir(&st));
  XCTAssert(stat_istype(&st, "d") != 0);
  snprintf(buff, 1000, "%s/test.foo", home);
  char *tmp = fn_basename(buff);
  XCTAssert(str_cmp(tmp, "test.foo") == 0);
  str_release(&tmp);
  tmp = fn_dirname(buff);
  XCTAssert(str_cmp(tmp, home) == 0);
  str_release(&tmp);
  tmp = fn_progname(buff);
  XCTAssert(str_cmp(tmp, "test") == 0);
  str_release(&tmp);
  char *fn1 = fn_tmp("test"), *fn2 = fn_tmp("test");
  printf("fn1: %s\nfn2: %s\n", fn1, fn2);
  fileptr_t fp;
  XCTAssert(file_open(&fp, fn1, "w") == 0);
  XCTAssert(file_writeline(fp, "1234") == 5);
  file_close(&fp);
  XCTAssert(file_copy(fn1, fn2) == -1);
  unlink(fn2);
  XCTAssert(file_copy(fn1, fn2) == 5);
  XCTAssert(file_open(&fp, fn2, "r") == 0);
  tmp = file_readline(fp);
  file_close(&fp);
  XCTAssert(str_cmp(tmp, "1234") == 0);
  str_release(&tmp);
  unlink(fn2);
  XCTAssert(file_trymove(fn1, fn2) == 0);
  XCTAssert(file_copy(fn2, fn1) == 5);
  XCTAssert(file_move(fn1, fn2) == -1);
  unlink(fn1);
  unlink(fn2);
  str_release(&fn2);
  str_release(&fn1);
}

- (void) testMapfile {
  const char test_data [] =  "this is a test";
  const char *fn  =  "./test.map",
             *fn2 =  "./test2.map";
  mapfile_t m1, m2;
  char buff [1024];
  int ret;
  XCTAssert(m1.map(fn) == 0);
  XCTAssert(m1.resize(1000) == 0);
  XCTAssert(m1.size() == 1000);
  XCTAssert(m2.map(fn) == 0);
  XCTAssert(m2.size() == 1000);
  mem_cpy(m1.data(10), test_data, sizeof test_data);
  mem_cpy(buff, m2.data(10), sizeof test_data);
  XCTAssert(str_cmp(test_data, buff) == 0);
  XCTAssert(m2.resize(20000) == 0);
  XCTAssert(m2.size() == 20000);
  mem_cpy(buff, m2.data(10), sizeof test_data);
  XCTAssert(str_cmp(test_data, buff) == 0);
  m1.unmap();
  m2.unmap();
  mapfile_t m3(fn);
  XCTAssert(m3.ok());
  mem_cpy(buff, m3.data(10), sizeof test_data);
  XCTAssert(str_cmp(test_data, buff) == 0);
  m3.sync();
  mapfile_t m4;
  XCTAssert(m4.map(fn2) == 0);
  XCTAssert(m4.ok());
  m4.read(m3.fd());
  mem_cpy(buff, m4.data(10), sizeof test_data);
  XCTAssert(str_cmp(test_data, buff) == 0);
  lseek ( m3.fd (), 0, SEEK_SET );
  m4.read ( m3.fd (), (unsigned long) -1, 2000 );
  mem_cpy ( buff, m4.data ( 2010 ), sizeof test_data );
  XCTAssert(str_cmp(test_data, buff) == 0);
  mem_cpy(buff, m4.data(10), sizeof test_data);
  XCTAssert(str_cmp(test_data, buff) == 0);
  m3.unmap();
  m4.unmap();
  mapfile_t m5;
  XCTAssert(m5.map(fn) == 0);
  XCTAssert(m5.ok());
  XCTAssert(m5.resize(1000) == 0);
  XCTAssert(m5.size() == 1000);
# if !defined(TARGET_OS_IPHONE)
  char cmd [512];
  snprintf ( cmd, 511, "echo 0123 > %s", fn );
  system ( cmd );
  m5.remap();
  XCTAssert(m5.size() == 5);
  mem_cpy ( buff, m5.data ( 0 ), 4 );
  XCTAssert(mem_cmp("0123", buff, 4) == 0);
# endif
  unlink(fn);
  unlink(fn2);
}

//- (void) testTty {
//  char buff[101];
//  tty_t *input = tty_open(0);
//  tty_t *output = tty_open(1);
//  tty_write(output, "login: ");
//  tty_gets(input, buff, 100);
//  tty_write(output, buff);
//  tty_write(output, "\npassword: ");
//  tty_negets(input, buff, 100);
//  tty_write(output, buff);
//  tty_write(output, "\n");
//}

@end
