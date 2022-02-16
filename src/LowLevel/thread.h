//
//  thread.h
//
//  Created by Norbert Thies on 30.06.21.
//  Copyright © 2021 Norbert Thies. All rights reserved.
//

#ifndef thread_h
#define thread_h

#include <pthread.h>
#include "sysdef.h"

BeginCLinkage

pthread_t thread_main();
unsigned long thread_main_id();
unsigned long thread_id(pthread_t);
pthread_t thread_current();

EndCLinkage

#endif /* thread_h */
