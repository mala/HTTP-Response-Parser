#include "xshelper.h"
#include "picohttpparser/picohttpparser.c"

#define MAX_HEADERS 128

STATIC_INLINE char tou(char const ch)
{
  return ('a' <= ch && ch <= 'z') 
    ? ch - ('a' - 'A')
    : ch;
}

STATIC_INLINE char tol(char const ch)
{
  return ('A' <= ch && ch <= 'Z')
    ? ch - ('A' - 'a')
    : ch;
}

MODULE = HTTP::Response::Parser PACKAGE = HTTP::Response::Parser::XS

PROTOTYPES: DISABLE

void parse_http_response(SV* buf, SV* resref, SV* option)
PPCODE:
{
  const char* buf_str;
  STRLEN buf_len;
  const char* msg;
  size_t msg_len;
  int minor_version, status;
  struct phr_header headers[MAX_HEADERS];
  size_t num_headers;
  size_t i;
  int ret;
  HV* res;
  SV* last_value;
  char tmp[1024];
  HV* h_headers = newHV();
  SV* ref = (SV*)newRV_noinc( (SV*)h_headers );

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
  (void)hv_stores(res, "_protocol", newSVpvf("HTTP/1.%d", minor_version));
  (void)hv_stores(res, "_rc",       newSViv(status));
  /*  printf("status: %d\n", ret);
    printf("msg_len: %d\n", msg_len);
    printf("num_headers: %d\n", num_headers);
  */
  (void)hv_stores(res, "_msg", newSVpvn(msg, msg_len));
  // printf("hoge4\n");
  
  last_value = NULL;

  (void)hv_stores(res, "_headers", ref);

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

      slot = hv_fetch(h_headers, name, name_len, TRUE);
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
          SV* newval = newSVpvn(headers[i].value, headers[i].value_len);

          av_push(values, SvREFCNT_inc_simple_NN(*slot));
          av_push(values, newval);

          slot = hv_store(h_headers, name, name_len,
            newRV_noinc((SV*)values), 0U);
          last_value = newval;
        }
      } else {
        sv_setpvn(*slot, headers[i].value, headers[i].value_len);
        last_value = *slot;
      }
    } else {
      /* continuing lines of a mulitiline header */
      sv_catpvs(last_value, "\n");
      sv_catpvn(last_value, headers[i].value, headers[i].value_len);
    }
  }
  
 done:
  if (SvTRUE(option)) {
    EXTEND(SP, 4);
    mPUSHi(ret);
    mPUSHi(minor_version);
    mPUSHi(status);
    mPUSHp(msg, msg_len);
  } else {
    mPUSHi(ret);
  }
}
