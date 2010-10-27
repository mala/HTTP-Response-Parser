#include "xshelper.h"
#include "picohttpparser/picohttpparser.c"

#define MAX_HEADERS 128

#define FORMAT_NONE     0
#define FORMAT_HASHREF  1
#define FORMAT_ARRAYREF 2

STATIC_INLINE char tol(char const ch)
{
  return ('A' <= ch && ch <= 'Z')
    ? ch - ('A' - 'a')
    : ch;
}

STATIC_INLINE
SV* my_new_name(pTHX_ const char* const pv, STRLEN const len) {
    SV* const sv  = sv_2mortal(newSV(len));
    char* const d = SvPVX_mutable(sv);
    STRLEN i;
    for(i = 0; i < len; i++) {
        d[i] = pv[i] == '_' ? '-' : tol(pv[i]);
    }
    SvPOK_on(sv);
    SvCUR_set(sv, len);
    *SvEND(sv) = '\0';
    return sv;
}

static
int do_parse( aTHX_
        /* input: */
        SV* const buf,
        int header_format,
        /* output: */
        int* const minor_version,
        int* const status,
        const char** const msg, size_t* const msg_len,
        SV** const res_headers,
        HV* const special_headers ) {
  struct phr_header headers[MAX_HEADERS];
  size_t num_headers = MAX_HEADERS;
  STRLEN buf_len;
  const char* const buf_str = SvPV_const(buf, buf_len);
  size_t last_len = 0;
  int const ret             = phr_parse_response(buf_str, buf_len,
    minor_version, status, msg, msg_len, headers, &num_headers, last_len);
  SV* last_values[] = { NULL, NULL };
  int const last_values_len = special_headers ? 2 : 1;
  size_t i;

  if (header_format == FORMAT_HASHREF) {
    *res_headers = (SV*)newHV_mortal();
  } else if (header_format == FORMAT_ARRAYREF) {
    *res_headers = (SV*)newAV_mortal();
  }

  for (i = 0; i < num_headers; i++) {
    if (headers[i].name != NULL) {
      SV* const namesv = my_new_name(aTHX_
        headers[i].name, headers[i].name_len);
      SV* const valuesv = newSVpvn_flags(
        headers[i].value, headers[i].value_len, SVs_TEMP);

      if(special_headers) {
          HE* const slot = hv_fetch_ent(special_headers, namesv, FALSE, 0U);
          if (slot) {
            SV* const placeholder = hv_iterval(special_headers, slot);
            SvSetMagicSV_nosteal(placeholder, valuesv);
            last_values[1] = placeholder;
          }
          else {
            last_values[1] = NULL;
          }
      }

      if (header_format == FORMAT_HASHREF) {
        HE* const slot = hv_fetch_ent((HV*)*res_headers, namesv, FALSE, 0U);
        if(!slot) { /* first time */
            (void)hv_store_ent((HV*)*res_headers, namesv,
                SvREFCNT_inc_simple_NN(valuesv), 0U);
        }
        else { /* second time; the header has multiple values */
            SV* sv = hv_iterval((HV*)*res_headers, slot);
            if(!( SvROK(sv) && SvTYPE(SvRV(sv)) == SVt_PVAV )) {
                /* make $value to [$value] and restore it to $res_header */
                AV* const av    = newAV();
                SV* const avref = newRV_noinc((SV*)av);
                (void)av_store(av, 0, SvREFCNT_inc_simple_NN(sv));
                (void)hv_store_ent((HV*)*res_headers, namesv, avref, 0U);
                sv = avref;
            }
            av_push((AV*)SvRV(sv), SvREFCNT_inc_simple_NN(valuesv));
        }
      } else if (header_format == FORMAT_ARRAYREF) {
            av_push((AV*)*res_headers, SvREFCNT_inc_simple_NN(namesv));
            av_push((AV*)*res_headers, SvREFCNT_inc_simple_NN(valuesv));
      }
      last_values[0] = valuesv;
    } else {
      /* continuing lines of a mulitiline header */
      int j;
      for(j = 0; j < last_values_len; j++) {
          if(!last_values[j]) continue;

          sv_catpvs(last_values[j], "\n"); /* XXX: is it correct? */
          sv_catpvn(last_values[j], headers[i].value, headers[i].value_len);
      }
    }
  }
  return ret;
}

MODULE = HTTP::Response::Parser PACKAGE = HTTP::Response::Parser

PROTOTYPES: DISABLE

void
parse_http_response(SV* buf, int header_format, HV* special_headers = NULL)
PPCODE:
{
  int minor_version, status;
  const char* msg;
  size_t msg_len;
  int ret;

  SV *res_headers;

  ret = do_parse(aTHX_ buf, header_format,
    &minor_version, &status, &msg, &msg_len,
    &res_headers, special_headers);
  
  if(ret > 0) {
    EXTEND(SP, 4);
    mPUSHi(ret);
    mPUSHi(minor_version);
    mPUSHi(status);
    mPUSHp(msg, msg_len);
    mPUSHs(newRV_inc(res_headers));
  }
  else {
    EXTEND(SP, 1);
    mPUSHi(ret);
  }
}

void
parse(HV* self, SV* header, SV* content = NULL)
PPCODE:
{
  int minor_version, status;
  const char* msg;
  size_t msg_len;
  SV *res_headers;
  int const ret = do_parse(aTHX_ header, FORMAT_HASHREF /* last_len */,
    &minor_version, &status, &msg, &msg_len, &res_headers, NULL);
  HV* const res = newHV_mortal();
  SV* res_obj;
  SV* header_obj;
  SV** svp;

  if(ret < 0) {
      (void)hv_stores(self, "errcode", newSViv(ret));
      (void)hv_stores(self, "errstr", ret == -1
        ? newSVpvs("Invalid HTTP response")
        : newSVpvs("Insufficient HTTP response"));
      XSRETURN_UNDEF;
  }

  res_obj    = sv_2mortal(newRV_inc((SV*)res));
  header_obj = sv_2mortal(newRV_inc((SV*)res_headers));

  /* build HTTP::Response compatible structure */
  (void)hv_stores(res, "_protocol", newSVpvf("HTTP/1.%d", minor_version));
  (void)hv_stores(res, "_rc",       newSViv(status));
  (void)hv_stores(res, "_msg",      newSVpvn(msg, msg_len));
  (void)hv_stores(res, "_headers",  SvREFCNT_inc_simple_NN(header_obj));

  if(content) {
      (void)hv_stores(res, "_content", newSVsv(content));
  }
  else {
      STRLEN buf_len;
      const char* const buf_str = SvPV_const(header, buf_len);
      (void)hv_stores(res, "_content",
        newSVpvn(buf_str + ret, buf_len - ret));
  }

  /* bless headers and response object if classes are specified */

  svp = hv_fetchs(self, "header_class", FALSE);
  if(svp && SvOK(*svp)) {
     HV* const header_class = gv_stashsv(*svp, GV_ADD);
     sv_bless(header_obj, header_class);
  }

  svp = hv_fetchs(self, "response_class", FALSE);
  if(svp && SvOK(*svp)) {
     HV* const response_class = gv_stashsv(*svp, GV_ADD);
     sv_bless(res_obj, response_class);
  }

  XPUSHs(res_obj);
}
