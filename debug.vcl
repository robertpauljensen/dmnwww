# This is a basic VCL configuration file for varnish.  See the vcl(7)
# man page for details on VCL syntax and semantics.
# 
# Default backend definition.  Set this to point to your content
# server.
#

backend www1 {
  .host = "10.30.1.110";
  .port = "10080";
  .probe = {
    .url = "/robots.txt";
    .timeout = 0.6s;
    .window = 8;
    .threshold = 6;
    .initial = 6;
  }
  .max_connections = 128;
}

backend www2 {
  .host = "10.30.1.111";
  .port = "10080";
  .probe = {
    .url = "/robots.txt";
    .timeout = 0.6s;
    .window = 8;
    .threshold = 6;
    .initial = 6;
  }
  .max_connections = 128;
}


backend upload1 {
  .host = "10.30.1.110";
  .port = "10081";
  .probe = {
    .url = "/ping";
    .timeout = 0.6s;
    .window = 8;
    .threshold = 6;
    .initial = 6;
  }
  .max_connections = 128;
}

backend upload2 {
  .host = "10.30.1.111";
  .port = "10081";
  .probe = {
    .url = "/ping";
    .timeout = 0.6s;
    .window = 8;
    .threshold = 6;
    .initial = 6;
  }
  .max_connections = 128;
}


director www round-robin {
  { .backend = www1; }
  { .backend = www2; }
}


director uploads round-robin {
  { .backend = upload1; }
  { .backend = upload2; }
}

acl purgers {
  "localhost";
  "10.30.1.0"/24;
}





sub preserveOrigHeaders {

  set req.http.X-Debug-Orig-Request = req.request;
  set req.http.X-Debug-Orig-Host = req.http.host;
  set req.http.X-Debug-Orig-Port = req.http.port;
  set req.http.X-Debug-Orig-Url  = req.url;
  set req.http.X-Debug-Orig-Client  = client.ip;
  if (req.http.Accept-Encoding) {
    set req.http.X-Debug-Orig-Accept-Encoding =
      req.http.Accept-Encoding;
  }
  set req.http.X-Debug-Restarts = req.restarts;  
  if (req.http.X-Forwarded-For) {
    set req.http.X-Debug-Orig-Forwarded-For = req.http.X-Forwarded-For;
  }

}


sub vcl_recv {
  ## Turn on Debug (if desired)
  ## Preserve the origin headers (if desired)
  ## Handle Purge, Bans, Refresh & 'Odd' verbs
  ##  (NO pre-processing, normalization - just do as we're told!)
  ## Special Cases
  ## Normalize Headers
  ## Normalize URLS
  ## Set Backend
  ##   Handle Uploads Dir ( only when req.request == 'GET' ?)
  ## Force TTL/Caching ?  


  set req.http.X-DMN-Debug = "Please";
  call preserveOrigHeaders;
  

  # allow PURGE from localhost and 192.168.55...
  if (req.request == "PURGE") {
    if (!client.ip ~ purgers) {
      error 405 "Purge Not allowed.";
    }
    return (lookup);
  }
  
  ## TODO: We really should check the required headers are present!
  if (req.request == "BAN") {
    if (!client.ip ~ purgers) {
      error 405 "Ban Not allowed.";
    }
    ban("obj.http.x-url ~ " + req.http.x-ban-url + 
      " && obj.http.x-host ~ " + req.http.x-ban-host);
    error 200 "Banned From Cache";
  }
		       
  ## TODO: add url parm to force refresh ?? 
  if (req.request == "REFRESH") {
    if (!client.ip ~ purgers) {
      # This is to prevent forced refreshes bogging down site
      error 200 "Refresh Not Allowed.";
    }
    set req.request = "GET";
    set req.hash_always_miss = true;
  }
  
  if (req.request != "GET" &&    req.request != "HEAD" &&
      req.request != "PUT" &&    req.request != "POST" &&
      req.request != "TRACE" &&  req.request != "OPTIONS" &&
      req.request != "DELETE") {
        /* Non-RFC2616 or CONNECT which is weird. */
        return (pipe);
      }
    
  if (req.request != "GET" && req.request != "HEAD") {
    /* We only deal with GET and HEAD by default */
    set req.backend = www;
    return (pass);
  }



  ## HANDLE THESE EARLY ...
  # Always pass (pipe) on anything in the transaction (e-commerce)
  # folder. (Safety Feature)
  if (req.url ~ "^/transaction" ) { 
    return (pipe); 
  }
  
  if (req.url ~ "(?i)p=discount-ugg" ) {
    error 404 "Not Found";
  }
  
  
  
  
  
  ## NORMALIZE everything
  ##  Forwarded-For
  ##  Encoding
  ##  URLs
  
  if (req.http.X-Forwarded-For) {
    unset req.http.X-Forwarded-For;
    set req.http.X-Forwarded-For = client.ip;
  }

  ## Normalize Encoding
  ## Not sure this is needed for modern browsers ?
  if (req.http.X-DMN-Debug) {
    set req.http.X-DMN-Debug-Encoding-Changed = "No";
  }
  
  if (req.url ~ "\.(jpe?g|gif|png|ico|woff|ttf|zip|tgz|gz|rar|bz2|pdf|tar|wav|bmp|rtf|flv|swf)$") {
    if (req.http.X-DMN-Debug) {
      set req.http.X-DMN-Debug-Encoding-Changed = 
        "YES - REMOVED from compressed Media File";
    }  
    # Already Compressed
    unset req.http.Accept-Encoding;
  }
  
  if (req.http.Accept-Encoding) {
    if (req.http.Accept-Encoding ~ "gzip") {
      if (req.http.X-DMN-Debug) {
        set req.http.X-DMN-Debug-Encoding-Changed = "YES - Normalized GZIP";
      }  
      set req.http.Accept-Encoding = "gzip";
    }
    else if (req.http.Accept-Encoding ~ "deflate") {
      if (req.http.X-DMN-Debug) {
        set req.http.X-DMN-Debug-Encoding-Changed = 
	   "YES - Normalized DEFLATE";
      }  
      set req.http.Accept-Encoding = "deflate";
    }
    else {
      if (req.http.X-DMN-Debug) {
        set req.http.X-DMN-Debug-Encoding-Changed = 
	   "YES - Removed UNKNOWN: " + req.http.Accept-Encoding;
      }  
      # unknown algorithm
      unset req.http.Accept-Encoding;
    }
  }

  
  ## Normalize URL's
  # SAH - Normalize all the RSS crap
  if (req.url ~ "(?i)^/rss$" || 
      req.url ~ "(?i)^/rss.xml$" ||
      req.url ~ "(?i)^/stories/rss$" ||
      req.url ~ "(?i)^/stories/rss.xml$"  ||
      req.url ~ "(?i)^/stories\?func=viewRss" ||
      req.url ~ "(?i)^/blog/rss"              ||
      req.url ~ "(?i)^/top-stories/rss$"  ||
      req.url ~ "(?i)^/top-stories/rss.xml$" ) {
        set req.url = "/?feed=rss";
  }	

  #if (req.url ~ "^/RSS$" || req.url ~ "^/rss$" ||
  #    req.url ~ "^/RSS.xml$"             || req.url ~ "^/rss.xml$" ||
  #    req.url ~ "^/RSS.XML$"             || req.url ~ "^/rss.XML$" ||
  #    req.url ~ "^/stories/RSS$"         || req.url ~ "^/stories/rss$" ||
  #    req.url ~ "^/stories\?func=viewRss" ||
  #    req.url ~ "^/blog/RSS"              ||
  #    req.url ~ "^/stories/RSS.xml$"     || req.url ~ "^/stories/rss.xml$" ||
  #    req.url ~ "^/top-stories/RSS$"     || req.url ~ "^/top-stories/rss$" ||
  #    req.url ~ "^/top-stories/RSS.xml$" || req.url ~ "^/top-stories/rss.xml$" ) {
  #      set req.url = "/?feed=rss";
  #}	
  
  if (req.url ~ "(?i)^/stories\?func=viewAtom") {
    set req.url ="/?feed=atom";
  }
  


  ## Strip Cookies if possible

  
  ## Simple static files
  if (req.http.X-DMN-Debug) {
    set req.http.X-DMN-Debug-Cookies-Unset = "No";
  }
  if (req.url ~ "\.(jpe?g|gif|png|ico|woff|ttf|zip|tgz|gz|rar|bz2|pdf|tar|wav|bmp|rtf|flv|swf)$") {
    if (req.http.X-DMN-Debug) {
      set req.http.X-DMN-Debug-Cookies-Unset = "YES - Media File";
    }  
    unset req.http.Cookie;
  }
  
  ##
  # Strip RSS/Atom feeds ?
  #if (req.url ~ "\.(css|js|txt|rss|atom)$") {
  if (req.url ~ "\.(css|js|txt)$") {
    if (req.http.X-DMN-Debug) {
      set req.http.X-DMN-Debug-Cookies-Unset = "YES - css/js File";
    }  
    unset req.http.Cookie;
  }
  # Keep the version so we correctly catch updates, but drop cookies
  if (req.url ~ ".*\.(css|js)\?ver=.*" ) {
    if (req.http.X-DMN-Debug) {
      set req.http.X-DMN-Debug-Cookies-Unset = "YES - VERSIONED css/js File";
    }  
    unset req.http.Cookie;
  }



  ## Setup the backend...
  ## WARNING!
  ##   if you restart a request, it will use the MODIFIED req object
  ##   This means, for instance, if you changed the req.url -
  ##   you may get a DIFFERENT director on restart!!
  ## WARNING!
  if (req.http.X-DMN-Use-Uploads || 
       (req.url ~ "^/wp-content/uploads" && req.request == "GET" )) {
    unset req.http.Cookie;
    set req.url = regsub(req.url, "^/wp-content/uploads/", "/");
    set req.http.X-DMN-Debug-Backend-Director = 
      "uploads (strips cookies): " + req.url;
    set req.http.X-DMN-Use-Uploads = "Yes";  
    set req.backend = uploads;  
  } else {
    set req.http.X-DMN-Debug-Backend-Director = "www";
    set req.backend = www;
  }


  # SAH Serve objects up to 20 minutes past their expiry if the backend
  #     is slow to respond.
  if (! req.backend.healthy) {
    set req.grace = 1200s;
    set req.http.X-DMN-Debug-Backend-Grace = "Backend NOT healthy! " + req.grace;
  } else {
    set req.grace = 300s;
    set req.http.X-DMN-Debug-Backend-Grace = "Default: " + req.grace;
  }


  if ( req.http.Cookie ) {
    return( pass );
  } else {
    return( lookup);
  }
  




  # WP Social login screws this up ...
  #if (req.http.host ~ "www.digitalmusicnews.com" &&
  #    req.http.port == "10080" ) {
  #      req.http.port = 80;
  #}
  

  

  # SAH - We can get UNCACHED data direct from backend for testing
  #       so normalize this
  #if (req.http.host ~ "^72.52.81.253") {
  #  set req.http.host = "www.digitalmusicnews.com";
  #}

  ## Pass archives off to static server...
  #if (req.url ~ "^/archives/2012/20121012sfmusictech") {
  #  #set req.url = regsub(req.url, "^/images/", "/");
  #  set req.backend = static;
  #}

  # Remove Google Analytics cookies - will prevent caching of anon content
  # when using GA Javascript. Also you will lose the information of
  # time spend on the site etc..
  #if (req.http.cookie) {
  #  set req.http.Cookie = regsuball(req.http.Cookie, "__utm.=[^;]+(; )?", "");
  #  if (req.http.cookie ~ "^ *$") { remove req.http.cookie; }
  #}
  
  ## If they're logged in - don't cache..
  #if (req.http.Cookie && req.http.Cookie ~ "wgLogin=yes") {
  #  return(pipe);
  #}
  #else {
  #  # Not logged in - Hopefully cookie doesn't matter then :-P
  #  return(lookup);
  #}
  
}		      
		      

sub vcl_fetch {
  ## Retry Support
  ## BAN support
  ## Unset cookies if possible
  ## Set TTL if needed
  ## Set Grace Time


    
  ## Retry Support
  ## retry 404's on images as they might not have synced yet..
  ## be careful if you retry 403's as it can cause us issues with things like
  ## the rate limiter on comments (throws a 403 if you comment too fast)
  ## WARNING
  ##   if you retry a request it uses the MODIFIED req!
  ##   This means, for instance, a different director can be selected if
  ##   you've modified the req.url!
  ##
  if (req.http.X-DMN-Debug) {
    if (req.http.X-DMN-Debug-Backend-Chain) {
      set req.http.X-DMN-Debug-Backend-Chain = 
        req.http.X-DMN-Debug-Backend-Chain + ":" + beresp.backend.name;  
    } else {
      set req.http.X-DMN-Debug-Backend-Chain = beresp.backend.name;  
    }
  }

  if (beresp.status == 404) {
    if (req.url ~ "\.(jpe?g|gif|png|ico|woff|ttf|zip|tgz|gz|rar|bz2|pdf|tar|wav|bmp|rtf|flv|swf)$") {
      if (req.restarts == 0) {
        set beresp.saintmode = 3s;
        return(restart);
      }
    }
  }
  
  
  if (beresp.status == 502 || beresp.status == 503) {
    set beresp.ttl = 0s;
    set beresp.grace = 0s;
    return (hit_for_pass); 
  }
  #if (beresp.status == 502 || beresp.status == 503) {
  #  set beresp.saintmode = 20s;
  #  return(restart);
  #}




  
  ## BAN Lurker support
  set beresp.http.x-url  = req.url;
  set beresp.http.x-host = req.http.host;


  # Always pass (pipe) on anything in the transaction (e-commerce)
  # folder. (Safety feature)
  if (req.url ~ "^/transaction" ) {
    set beresp.ttl = 0s;
    if (req.http.X-DMN-Debug) {
      set beresp.http.X-Cacheable = "NO: Transaction Folder";
    }  
    return (hit_for_pass); 
  }
 
  # Honour Cache Controls
  if ( beresp.http.Cache-Control ~ "no-cache" ) {
    set beresp.ttl = 0s;
    if (req.http.X-DMN-Debug) {
      set beresp.http.X-Cacheable = "NO:Cache-Control=no-cache";
    }  
    return(hit_for_pass);
  }

  if ( beresp.http.Cache-Control ~ "private" ) {
    set beresp.ttl = 0s;
    if (req.http.X-DMN-Debug) {
      set beresp.http.X-Cacheable = "NO:Cache-Control=private";
    }  
    return(hit_for_pass);
  }


  ## Strip out Cookies where possible
  set beresp.http.X-Cacheable = "YES: No Changes Made";

  # Strip cookies for image files:
  if (req.url ~ "\.(bmp|ico|jpe?g|gif|png)$") {
    unset beresp.http.set-cookie;
    set beresp.ttl = 90s;
    set beresp.http.Cache-Control = "max-age=90";
    if (req.http.X-DMN-Debug) {
      set beresp.http.X-Cacheable = "YES:Forced Image File: " + beresp.ttl;
    }  
  }
      
  # Strip cookies for static files:
  if (req.url ~ "\.(js|css|zip|tgz|gz|rar|bz2|pdf|txt|tar|wav|rtf|flv|swf)$") {
    unset beresp.http.set-cookie;
    set beresp.ttl = 3600s;
    set beresp.http.Cache-Control = "max-age=3600";
    if (req.http.X-DMN-Debug) {
      set beresp.http.X-Cacheable = "YES:Forced Static File: " + beresp.ttl;
    }  
  }

  if (req.url ~ ".*\.(css|js)\?ver=.*" ) {
    unset beresp.http.set-cookie;
    set beresp.ttl = 3600s;
    set beresp.http.Cache-Control = "max-age=3600";
    if (req.http.X-DMN-Debug) {
      set beresp.http.X-Cacheable = "YES:Forced VERSIONED css/js File: " + beresp.ttl;
    }  
  }

  

  # Only cache responses with no cookies
  if (beresp.http.set-cookie) {
    set beresp.ttl = 0s;
    if (req.http.X-DMN-Debug) {
      set beresp.http.X-Cacheable = "NO: SET COOKIE";
    }  
    return(hit_for_pass);
  }


  # Varnish determined the object was not cacheable
  if ( beresp.ttl <= 0s ) {
    if (req.http.X-DMN-Debug) {
      set beresp.http.X-Cacheable = "NO: Not Cacheable (Unknown Reason)";
    }  
  }


  ## Setup the grace Time
  set beresp.grace = 30m;







  #set beresp.http.X-FrontDoor = "NO";
  
  # Sub Mast can change pretty often...
  #if ( req.url == "/data/submast.gif") {
  #  unset beresp.http.set-cookie;
  #  set beresp.ttl = 300s;
  #  set beresp.http.Cache-Control = "max-age=300";
  #  set beresp.http.X-Cacheable = "YES: Submast Image";
  #  return(deliver);
  #}
  

      

  #if (req.url == "/top-stories/rss.xml"  ||
  #    req.url == "/stories?func=viewRss" ||
  #    req.url == "/stories?func=viewAtom" ){
  #      unset beresp.http.set-cookie;
  #      set beresp.ttl = 300s;
  #      set beresp.http.Cache-Control ="max-age=300";
  #      set beresp.http.X-Cacheable = "YES:Forced Cache RSS/Atom Feed";
  #      return(deliver);
  #}
      

  ## If they're logged in - don't cache..
  #if (req.http.Cookie && req.http.Cookie ~ "wgLogin=yes") {
  #  set beresp.ttl = 0s;
  #  set beresp.http.X-Cacheable = "NO: Logged in";
  #  return(hit_for_pass);
  #}
		  
			  

  # At this point - they should NOT be logged in and
  # NOT recieving any cookies...
    
  #if (req.url == "/") {
  #  set beresp.http.X-FrontDoor = "Yes";
  #  set beresp.ttl = 180s;
  #  set beresp.http.X-FrontDoor = "Yes";
  #  set beresp.http.X-Cacheable = "YES:Forced Cache Front Door";
  #  set beresp.http.Cache-Control = "must-revalidate, max-age=180";
  #  return(deliver);
  #}

  #return(deliver);
}
	  


#     if (beresp.ttl <= 0s ||
#         beresp.http.Set-Cookie ||
#         beresp.http.Vary == "*") {
# 		/*
# 		 * Mark as "Hit-For-Pass" for the next 2 minutes
# 		 */
# 		set beresp.ttl = 120 s;
# 		return (hit_for_pass);
#     }
#     return (deliver);
# }
# 







sub vcl_hit {
  if (req.request == "PURGE") {
    purge;
    error 200 "Purged.";
  }
  
}






sub vcl_miss {
  if (req.request == "PURGE") {
    purge;
    error 404 "Not In Cache.";
  }




}



sub vcl_pass {
  set req.http.X-PASSED = "Yep";
}





sub vcl_deliver {


  if (req.http.X-DMN-Debug) {
    set resp.http.X-Forwarded-For = req.http.X-Forwarded-For ;
    set resp.http.X-DMN-Debug = req.http.X-DMN-Debug ;
    set resp.http.X-DMN-Debug-Encoding-Changed = req.http.X-DMN-Debug-Encoding-Changed ;
    set resp.http.X-DMN-Debug-Cookies-Unset = req.http.X-DMN-Debug-Cookies-Unset ;
    if ( req.http.X-DMN-Use-Uploads ) {
      set resp.http.X-DMN-Use-Uploads = req.http.X-DMN-Use-Uploads;
    }
    
    set resp.http.X-DMN-Debug-Backend-Director =
      req.http.X-DMN-Debug-Backend-Director ;
    set resp.http.X-DMN-Debug-Backend-Restarts = req.restarts ;
    set resp.http.X-DMN-Debug-Backend-Chain = req.http.X-DMN-Debug-Backend-Chain;
    set resp.http.X-DMN-Debug-Backend-Grace = req.http.X-DMN-Debug-Backend-Grace;

    if (req.http.X-Debug-Orig-Request) {
      set resp.http.X-Debug-Orig-Request = req.http.X-Debug-Orig-Request ;
      set resp.http.X-Debug-Orig-Host = req.http.X-Debug-Orig-Host ; 
      set resp.http.X-Debug-Orig-Port = req.http.X-Debug-Orig-Port ;
      set resp.http.X-Debug-Orig-Url  = req.http.X-Debug-Orig-Url  ;
      set resp.http.X-Debug-Orig-Client  = req.http.X-Debug-Orig-Client  ;
      set resp.http.X-Debug-Orig-Accept-Encoding = req.http.X-Debug-Orig-Accept-Encoding ;
      set resp.http.X-Debug-Orig-Forwarded-For = req.http.X-Debug-Orig-Forwarded-For ;
    }
  }


  if (req.http.X-PASSED) {
    set resp.http.X-PASSED = "Yep";
  } else {
    set resp.http.X-PASSED = "Nope";
  }
  
  
  if (obj.hits == 0) {
    set resp.http.X-Cache = "MISS";
  } else {
    set resp.http.X-Cache = "HIT (" + obj.hits + " Times)";
  }
  

  ## BAN Lurker Support
  unset resp.http.x-url;
  unset resp.http.x-host;
  
  if (! req.http.X-DMN-Debug ) {
    unset resp.http.X-DMN-Use-Uploads;
    #unset resp.http.X-Varnish;
  }
}


sub vcl_pipe {
  # Note that only the first request to the backend will have
  # X-Forwarded-For set.  If you use X-Forwarded-For and want to
  # have it set for all requests, make sure to have:
  # set bereq.http.connection = "close";
  # here.  It is not set by default as it might break some broken web
  # applications, like IIS with NTLM authentication.


  set bereq.http.connection = "close";
  set req.http.connection = "close";
    
  return (pipe);
}



































# 
# sub vcl_pass {
#     return (pass);
# }
# 
# sub vcl_hash {
#     hash_data(req.url);
#     if (req.http.host) {
#         hash_data(req.http.host);
#     } else {
#         hash_data(server.ip);
#     }
#     return (hash);
# }
# 
# sub vcl_hit {
#     return (deliver);
# }
# 
# sub vcl_miss {
#     return (fetch);
# }
# 
# sub vcl_deliver {
#     return (deliver);
# }
# 
# sub vcl_error {
#     set obj.http.Content-Type = "text/html; charset=utf-8";
#     set obj.http.Retry-After = "5";
#     synthetic {"
# <?xml version="1.0" encoding="utf-8"?>
# <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"
#  "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
# <html>
#   <head>
#     <title>"} + obj.status + " " + obj.response + {"</title>
#   </head>
#   <body>
#     <h1>Error "} + obj.status + " " + obj.response + {"</h1>
#     <p>"} + obj.response + {"</p>
#     <h3>Guru Meditation:</h3>
#     <p>XID: "} + req.xid + {"</p>
#     <hr>
#     <p>Varnish cache server</p>
#   </body>
# </html>
# "};
#     return (deliver);
# }
# 
# sub vcl_init {
# 	return (ok);
# }
# 
# sub vcl_fini {
# 	return (ok);
# }
