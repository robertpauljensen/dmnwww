# This is a basic VCL configuration file for varnish.  See the vcl(7)
# man page for details on VCL syntax and semantics.
# 
# Default backend definition.  Set this to point to your content
# server.
#
backend static {
  .host = "72.52.81.235";
  .port = "8080";
  .max_connections = 8;
}

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
  .max_connections = 8;
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
  .max_connections = 8;
}

director www round-robin {
  { .backend = www1; }
  { .backend = www2; }
}

acl purge {
  "localhost";
  "10.30.1.0"/24;
}

sub vcl_recv {
  set req.backend = www;
  
  if (req.http.X-Forwarded-For) {
    unset req.http.X-Forwarded-For;
    set req.http.X-Forwarded-For = client.ip;
  }

  # SAH Serve objects up to 20 minutes past their expiry if the backend
  #     is slow to respond.
  if (! req.backend.healthy) {
    set req.grace = 1200s;
  } else {
    set req.grace = 300s;
  }

  # WP Social login screws this up ...
  #if (req.http.host ~ "www.digitalmusicnews.com" &&
  #    req.http.port == "10080" ) {
  #      req.http.port = 80;
  #}
  
  # allow PURGE from localhost and 192.168.55...
  if (req.request == "PURGE") {
    if (!client.ip ~ purge) {
      error 405 "Not allowed.";
    }
    return (lookup);
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
    return (pass);
  }

  # Always pass (pipe) on anything in the transaction (e-commerce)
  # folder.
  if (req.url ~ "^/transaction" ) { 
    return (pipe); 
  }
  
  if (req.url ~ "(?i)p=discount-ugg" ) {
    error 404 "Not Found";
  }
  
  #if (req.url ~ "(?i)^/rss$" || 
  #    req.url ~ "(?i)^/rss.xml$" ||
  #    req.url ~ "(?i)^/stories/rss$" ||
  #    req.url ~ "(?i)^/stories/rss.xml$"  ||
  #    req.url ~ "(?i)^/top-stories/rss$"  ||
  #    req.url ~ "(?i)^/top-stories/rss.xml$" ) {
  #      set req.url = "/stories?func=viewRss";
  #}	


  # Normalize everything before we get started...
  
  if (req.url ~ "\.(jpe?g|gif|png|ico|woff|ttf|zip|tgz|gz|rar|bz2|pdf|tar|wav|bmp|rtf|flv|swf)$") {
    unset req.http.Cookie;
    # Already Compressed
    unset req.http.Accept-Encoding;
    return(lookup);
  }
  
  if (req.http.Accept-Encoding) {
    if (req.http.Accept-Encoding ~ "gzip") {
      set req.http.Accept-Encoding = "gzip";
    }
    else if (req.http.Accept-Encoding ~ "deflate") {
      set req.http.Accept-Encoding = "deflate";
    }
    else {
      # unknown algorithm
      unset req.http.Accept-Encoding;
    }
  }

  # Check these after we've determined compression
  if (req.url ~ "\.(css|js|txt)$") {
    unset req.http.Cookie;
    return(lookup);
  }
  # Keep the version so we correctly catch updates, but drop cookies
  if (req.url ~ ".*\.(css|js)\?ver=.*" ) {
    unset req.http.Cookie;
    return(lookup);
  }
  
  
  # SAH - Normalize all the RSS crap
  if (req.url ~ "^/RSS$" || req.url ~ "^/rss$" ||
      req.url ~ "^/RSS.xml$"             || req.url ~ "^/rss.xml$" ||
      req.url ~ "^/RSS.XML$"             || req.url ~ "^/rss.XML$" ||
      req.url ~ "^/stories/RSS$"         || req.url ~ "^/stories/rss$" ||
      req.url ~ "^/stories\?func=viewRss" ||
      req.url ~ "^/blog/RSS"              ||
      req.url ~ "^/stories/RSS.xml$"     || req.url ~ "^/stories/rss.xml$" ||
      req.url ~ "^/top-stories/RSS$"     || req.url ~ "^/top-stories/rss$" ||
      req.url ~ "^/top-stories/RSS.xml$" || req.url ~ "^/top-stories/rss.xml$" ) {
        set req.url = "/?feed=rss";
  }	
  
  if (req.url ~ "^/stories\?func=viewAtom") {
    set req.url ="/?feed=atom";
  }
  
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
  
  if ( req.http.Cookie ) {
    return( pass );
  } else {
    return( lookup);
  }
  
}		      
		      

sub vcl_fetch {
  #if (beresp.status == 502 || beresp.status == 503) {
  #  set beresp.saintmode = 20s;
  #  return(restart);
  #}
  #set beresp.grace = 30m;

  #set beresp.http.X-FrontDoor = "NO";
  
  # Sub Mast can change pretty often...
  #if ( req.url == "/data/submast.gif") {
  #  unset beresp.http.set-cookie;
  #  set beresp.ttl = 300s;
  #  set beresp.http.Cache-Control = "max-age=300";
  #  set beresp.http.X-Cacheable = "YES: Submast Image";
  #  return(deliver);
  #}
  

  # Strip cookies for image files:
  if (req.url ~ "\.(jpg|jpeg|gif|png)$") {
    unset beresp.http.set-cookie;
    set beresp.ttl = 60s;
    set beresp.http.Cache-Control = "max-age=60";
    set beresp.http.X-Cacheable = "YES:Forced Image File";
    return(deliver);
  }
      
  # Strip cookies for static files:
  if (req.url ~ "\.(ico|js|css|zip|tgz|gz|rar|bz2|pdf|txt|tar|wav|bmp|rtf|flv|swf)$") {
    unset beresp.http.set-cookie;
    set beresp.ttl = 3600s;
    set beresp.http.Cache-Control = "max-age=3600";
    set beresp.http.X-Cacheable = "YES:Forced Static File";
    return(deliver);
  }
      

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
		  
  # Always pass (pipe) on anything in the transaction (e-commerce)
  # folder.
  if (req.url ~ "^/transaction" ) {
    set beresp.ttl = 0s;
    set beresp.http.X-Cacheable = "NO: Transaction Folder";
    return (hit_for_pass); 
  }
  

  # Can't strip cookies or we break logins
  # So only cache responses with no cookies
  if (beresp.http.set-cookie) {
    set beresp.ttl = 0s;
    set beresp.http.X-Cacheable = "NO: SET COOKIE";
    return(hit_for_pass);
  }
			  

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

  # Varnish determined the object was not cacheable
  if ( beresp.ttl <= 0s ) {
    set beresp.http.X-Cacheable = "NO: Not Cacheable";
    return(hit_for_pass);
  }
  
  if ( beresp.http.Cache-Control ~ "private" ) {
    set beresp.http.X-Cacheable = "NO:Cache-Control=private";
    return(hit_for_pass);
  }

  if ( beresp.ttl < 300s) {
    set beresp.ttl = 300s;
    set beresp.http.Cache-Control = "max-age=300";
    set beresp.http.X-Cacheable = "YES:Generic FORCED item";
  }
  else {
    set beresp.http.X-Cacheable = "YES: No Changes Made";
  }
  
  return(deliver);
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

sub vcl_hit {
  if (req.request == "PURGE") {
    purge;
    error 200 "Purged.";
  }
}
						
sub vcl_miss {
  if (req.request == "PURGE") {
    purge;
    error 200 "Purged.";
  }
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