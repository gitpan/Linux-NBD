#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include <inttypes.h>
#include <unistd.h>
#include <endian.h>

#include <sys/ioctl.h>
#include <netinet/in.h>
#include <byteswap.h>

typedef uint32_t u32;
typedef uint64_t u64;
#include <linux/nbd.h>

#if __BYTE_ORDER == __BIG_ENDIAN
#define ntohll(netlong) (netlong)
#elif __BYTE_ORDER == __LITTLE_ENDIAN
#define ntohll(netlong) __bswap_64(netlong)
#else
error, you should not exist
#endif

MODULE = Linux::NBD		PACKAGE = Linux::NBD::Client

void
_set_sock (int dev, int fd)
	CODE:
        ioctl (dev, NBD_SET_SOCK, (unsigned long)fd);

void
_doit (int dev, int server = 0)
	CODE:
        if (server)
          for (server = 0; server < 4095; server++)
            if (server != dev)
              close (server);

        ioctl (dev, NBD_DO_IT);

        if (server)
          _exit (0);

void
_disconnect (int dev)
	CODE:
        ioctl (dev, NBD_DISCONNECT);

void
_clear_sock (int dev)
	CODE:
        ioctl (dev, NBD_CLEAR_SOCK);

void
_clear_que (int dev)
	CODE:
        ioctl (dev, NBD_CLEAR_QUE);

void
_set_blksize (int dev, unsigned long blocksize)
	CODE:
        ioctl (dev, NBD_SET_BLKSIZE, blocksize);

void
_set_size (int dev, unsigned long size)
	CODE:
        ioctl (dev, NBD_SET_BLKSIZE, size);

void
_set_size_blocks (int dev, unsigned long nblocks)
	CODE:
        ioctl (dev, NBD_SET_SIZE_BLOCKS, nblocks);

MODULE = Linux::NBD		PACKAGE = Linux::NBD::Server

void
_one_request (SV *obj, int fd)
	CODE:
{
        struct nbd_request req;

        if (read (fd, &req, sizeof (req)) == sizeof (req))
          {
            if (req.magic == htonl (NBD_REQUEST_MAGIC))
              {
                req.type = htonl (req.type);

                if (req.type < 2)
                  {
                    u64 from = ntohll (req.from);

                    PUSHMARK (SP);
                    EXTEND (SP, 3);
                    PUSHs (obj);
                    PUSHs (sv_2mortal (newSVpvn (req.handle, sizeof (req.handle))));
                    PUSHs (sv_2mortal (sizeof (UV) < 8 && from > (0xffffffffUL)
                                       ? newSVnv (from)
                                       : newSVuv (from)));
                    PUSHs (sv_2mortal (newSVuv (ntohl (req.len))));
                    PUTBACK;
                    call_method (req.type ? "req_write" : "req_read", G_DISCARD);
                    SPAGAIN;

                    XSRETURN_NO;
                  }
              }
          }

        XSRETURN_YES;
}

SV *
_format_reply (SV *handle, unsigned int error = 0, SV *data = 0)
	CODE:
{
        struct nbd_reply rep;
        STRLEN len;
        char *h = SvPV (handle, len);

        if (len != sizeof (rep.handle))
          croak ("format_reply: illegal handle (length %d, should be %d)", len, sizeof (rep.handle));

        rep.magic = htonl (NBD_REPLY_MAGIC);
        rep.error = htonl (error);
        memcpy (rep.handle, h, sizeof (rep.handle));

        RETVAL = newSVpvn ((char *)&rep, sizeof (rep));

        if (data && !error)
          sv_catsv (RETVAL, data);
}        
        OUTPUT:
        RETVAL

