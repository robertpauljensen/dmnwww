
sub preprocess {
  #
  # Basic pre-processing thats safe for all requests.
  # NOTE: This should NOT be run when restarting a request.
  #
  set req.http.X-Debug-Url-Raw  = req.url;

  # Normalize the query arguments
  set req.url = std.querysort(req.url);
  # Normalize the header, remove the port (in case you're testing this on various TCP ports)
  #set req.http.Host = regsub(req.http.Host, ":[0-9]+", "");

  # Do we want debug output ?
  if(req.url ~ "(\?|&)x-dmn-debug=?") {
    set req.url = regsuball(req.url,"x-dmn-debug(=[%.-_A-z0-9]+&?)?","");
    set req.http.X-DMN-Debug = "Please DETECTED";
  }
  else {
    unset req.http.X-DMN-Debug;  
    # Force debug for now
    set req.http.X-DMN-Debug = "Please";  
  }
  #set req.url = regsub(req.url, "(\?|\&)?\s*$", "");

  
  if ( req.http.Cookie) {
    set req.http.X-DMN-Debug-Cookies-Raw = req.http.Cookie;
  }
  
  # Static files never need cookies...
  if (req.url ~ "\.(css|js|jpe?g|gif|png|ico|woff|ttf|zip|tgz|gz|rar|bz2|pdf|tar|txt|wav|bmp|rtf|flv|swf)(\?[A-Za-z0-9]+)?$" ||
      req.url ~ "\.(css|js)\?ver=.*$" ) {
    set req.http.X-DMN-Debug-Cookies-Unset = "YES - Media File";
    set req.http.purgeCookies = "YES - Media File";
    unset req.http.Cookie;
  }
  
  # We don't care about anything except wordpress cookies
  if ( req.http.Cookie) {
    ## Ok - js is in for loading comment_author_name - get rid of these
    ## TODO: PHPSESSID is the social login plugin. 
    ## It seems to be required if your logging in, so save it for now.
    ## so nuke it
    ## PHPSESSID=fni3n9n509tbf6k3v479jse0d4;
    ##
    ## Strip everything except wordpress cookies and PHPSESSID
    set req.http.Cookie = ";" + req.http.Cookie;
    set req.http.Cookie = regsuball(req.http.Cookie, "; +", ";");
    set req.http.Cookie = regsuball(req.http.Cookie, ";(wp[_-][^=]+|wordpress[_-][^=]+|PHPSESSID[^=]+)=", "; \1=");
    set req.http.Cookie = regsuball(req.http.Cookie, ";[^ ][^;]*", "");
    set req.http.Cookie = regsuball(req.http.Cookie, "^[; ]+|[; ]+$", "");
    set req.http.X-DMN-Debug-Cookies-Cooked = req.http.Cookie;
    
    if ( req.http.Cookie ~ "^;* *$" ) {
      unset req.http.Cookie;
    }
  }
  
  if (req.http.X-Forwarded-For) { 
    set req.http.X-Forwarded-For = req.http.X-Forwarded-For + ", " + client.ip;
  } else {
    set req.http.X-Forwarded-For = client.ip;
  }
}
