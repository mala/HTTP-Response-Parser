#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "picohttpparser/picohttpparser.c"

#define MAX_HEADERS 128

__inline char tou(char ch)
{
  if ('a' <= ch && ch <= 'z')
    ch -= 'a' - 'A';
  return ch;
}

__inline char tol(char ch)
{
  if ('A' <= ch && ch <= 'Z')
    ch -= 'A' - 'a';
  return ch;
}

MODULE = HTTP::Response::Parser PACKAGE = HTTP::Response::Parser::XS

int parse_http_response(SV* buf, SV* resref)
PROTOTYPE: $$
CODE:
{
  const char* buf_str;
  STRLEN buf_len;
  const char* msg;
  size_t msg_len;
  int minor_version, status;
  struct phr_header headers[MAX_HEADERS];
  size_t num_headers;
  int ret, i;
  HV* res;
  SV* last_value;
  char tmp[1024];
  
  if ( SvROK(buf) ) {
    buf_str = SvPV( SvRV(buf), buf_len);
  } else {
    buf_str = SvPV(buf, buf_len);
  }
  num_headers = MAX_HEADERS;
  ret = phr_parse_response(buf_str, buf_len, &minor_version, &status, &msg, &msg_len, headers, &num_headers, 0);

  if (ret == -1)
    goto done;
  
  if (!SvROK(resref))
    Perl_croak(aTHX_ "second param to parse_http_response should be a hashref");

  res = (HV*)SvRV(resref);
  if (SvTYPE(res) != SVt_PVHV)
    Perl_croak(aTHX_ "second param to parse_http_response should be a hashref");
  
  // status line parsed
  sprintf(tmp, "HTTP/1.%d", minor_version);
  hv_store(res, "_protocol", sizeof("_protocol") - 1, newSVpv(tmp, 0), 0);
  hv_store(res, "_rc", sizeof("_rc") - 1, newSViv(status), 0);
  /*  printf("status: %d\n", ret);
    printf("msg_len: %d\n", msg_len);
    printf("num_headers: %d\n", num_headers);
  */
  hv_store(res, "_msg", sizeof("_msg") - 1, newSVpvn(msg, msg_len), 0);
  // printf("hoge4\n");
  
  last_value = NULL;

  HV* h_headers = newHV();
  SV* ref = (SV*)newRV_noinc( (SV*)h_headers );
  hv_store(res, "_headers", sizeof("_headers") - 1, ref, 0);

  for (i = 0; i < num_headers; ++i) {
    if (headers[i].name != NULL) {
      const char* name;
      size_t name_len;
      SV** slot;
      if (1) {
	const char* s;
	char* d;
	size_t n;
	// too large field name
        if (sizeof(tmp) < headers[i].name_len) {
          /*
          printf("name_len: %d\n", headers[i].name_len);
          printf("name: %s\n", headers[i].name);
          */
      	  // hv_clear(res);
          ret = -1;
          goto done;
        }
        for (s = headers[i].name, n = headers[i].name_len, d = tmp;
	     n != 0;
	     s++, --n, d++)
          *d = *s == '_' ? '-' : tol(*s);
        name = tmp;
        name_len = headers[i].name_len;
      }

      slot = hv_fetch(h_headers, name, name_len, 1);
      if ( !slot )
        croak("failed to create hash entry");
      if (SvOK(*slot)) {
        
	if (SvROK(*slot)) {
	  AV* values = (AV*)SvRV(*slot);
          SV* newval = newSVpvn(headers[i].value, headers[i].value_len);
          av_push(values, newval);
          last_value = newval;
	} else {
	  AV* values = newAV();
	  SV* old_val = *slot;
	  SvREFCNT_inc(old_val);
          SV* newval = newSVpvn(headers[i].value, headers[i].value_len);

          av_push(values, old_val);
          av_push(values, newval);
          SV* values_ref = (SV*)newRV_noinc( (SV*)values );

          slot = hv_store(h_headers, name, name_len, values_ref, 0);
          last_value = newval;
	}
      } else {
        sv_setpvn(*slot, headers[i].value, headers[i].value_len);
        last_value = *slot;
      }
    } else {
      /* continuing lines of a mulitiline header */
      sv_catpvn(last_value, "\n", 1);
      sv_catpvn(last_value, headers[i].value, headers[i].value_len);
    }
  }
  
 done:
  RETVAL = ret;
}
OUTPUT:
  RETVAL
