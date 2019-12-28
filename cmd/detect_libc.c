#include <features.h>
#include <stdbool.h>

bool detect_glibc()
{
  return
#ifdef __GLIBC__
    true;
#else
    false;
#endif
}
