spool wrap_all.log
host wrap iname=coll_util_pkgb.sql oname=coll_util_pkgb.plb
host wrap iname=coll_web_pkgb.sql  oname=coll_web_pkgb.plb
host wrap iname=evnt_api_pkgb.sql  oname=evnt_api_pkgb.plb
host wrap iname=evnt_util_pkgb.sql oname=evnt_util_pkgb.plb
host wrap iname=evnt_web_pkgb.sql  oname=evnt_web_pkgb.plb
host wrap iname=glob_api_pkgb.sql  oname=glob_api_pkgb.plb
host wrap iname=glob_util_pkgb.sql oname=glob_util_pkgb.plb
host wrap iname=glob_web_pkgb.sql  oname=glob_web_pkgb.plb
host wrap iname=web_std_pkgb.sql   oname=web_std_pkgb.plb
host wrap iname=web_nav_pkgb.sql   oname=web_nav_pkgb.plb

prompt ... installing GLOB UTIL PKG
@glob_util_pkgs.sql
@glob_util_pkgb.plb

prompt ... installing COLL UTIL PKG
@coll_util_pkgs.sql
@coll_util_pkgb.plb 

prompt ... installing EVNT UTIL PKG
@evnt_util_pkgs.sql
@evnt_util_pkgb.plb 

prompt ... installing GLOB API PKG
@glob_api_pkgs.sql
@glob_api_pkgb.plb

prompt ... installing EVNT API PKG
@evnt_api_pkgs.sql
@evnt_api_pkgb.plb

prompt ... installing WEB STD PKG
@web_std_pkgs.sql
@web_std_pkgb.plb

prompt ... installing WEB NAV PKG
@web_nav_pkgs.sql
@web_nav_pkgb.plb

prompt ... installing GLOB WEB PKG
@glob_web_pkgs.sql
@glob_web_pkgb.plb

prompt ... installing EVNT WEB PKG
@evnt_web_pkgs.sql
@evnt_web_pkgb.plb

prompt ... installing COLL WEB PKG
@coll_web_pkgs.sql
@coll_web_pkgb.plb

@wrap_chk.sql
spool off

host rm coll_util_pkgb.sql
host rm coll_web_pkgb.sql
host rm evnt_api_pkgb.sql
host rm evnt_util_pkgb.sql
host rm evnt_web_pkgb.sql
host rm glob_api_pkgb.sql
host rm glob_util_pkgb.sql
host rm glob_web_pkgb.sql
host rm web_std_pkgb.sql
host rm web_nav_pkgb.sql

