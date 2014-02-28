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
    .url = "/robots.txt"; # Checks php-fpm backend
    .interval = 5s;
    # .url = "/ping"; # does NOT check php-fpm backend health!
    # .interval = 1s;
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
    .url = "/robots.txt"; # Checks php-fpm backend
    .interval = 5s;
    # .url = "/ping"; # does NOT check php-fpm backend health!
    # .interval = 1s;
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
    .interval = 1s;
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
    .interval = 1s;
    .timeout = 0.6s;
    .window = 8;
    .threshold = 6;
    .initial = 6;
  }
  .max_connections = 128;
}

backend fail {
  .host = "localhost";
  .port = "21121";
  .probe = { .url = "/asfasfasf"; .initial = 0; .interval = 1d; }
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
  "72.52.81.238";
  "72.52.81.239";
}




import header;





sub NormReqEncoding {

  set req.http.X-DMN-Debug-Encoding-Changed = "No";
  
  if (req.url ~ "\.(jpe?g|gif|png|ico|woff|ttf|zip|tgz|gz|rar|bz2|pdf|tar|wav|bmp|rtf|flv|swf)(\?[A-Za-z0-9]+)?$") {
    set req.http.X-DMN-Debug-Encoding-Changed = "YES - REMOVED from compressed Media File";
    # Already Compressed
    unset req.http.Accept-Encoding;
  }
  
  if (req.http.Accept-Encoding) {
    if (req.http.Accept-Encoding ~ "gzip") {
      set req.http.X-DMN-Debug-Encoding-Changed = "YES - Normalized GZIP";
      set req.http.Accept-Encoding = "gzip";
    }
    else if (req.http.Accept-Encoding ~ "deflate") {
      set req.http.X-DMN-Debug-Encoding-Changed = "YES - Normalized DEFLATE";
      set req.http.Accept-Encoding = "deflate";
    }
    else {
      set req.http.X-DMN-Debug-Encoding-Changed = "YES - Removed UNKNOWN: " + req.http.Accept-Encoding;
      # unknown algorithm
      unset req.http.Accept-Encoding;
    }
  }
}





sub CheckRestarts {
  ## Setup the backend...
  ## WARNING!
  ##   if you restart a request, it will use the MODIFIED req object
  ##   This means, for instance, if you changed the req.url -
  ##   you may get a DIFFERENT director on restart!!
  ## WARNING!
  if (req.restarts == 2) {
    # We only have 2 backends - so everything must be down
    # Force cached content using fail backend
    set req.backend = fail;
    unset req.http.Cookie;
    unset req.http.Accept-Encoding;
    set req.http.Accept-Language = "en-US,en;q=0";
    set req.grace = 120m;
    set req.http.X-DMN-Debug-Backend-Grace = "Hail Mary! (Trying emergency cache..): " + req.grace;
  }
  else {
    # SAH Serve objects up to 2 hours past their expiry if the backend
    #     is slow to respond.
    if ( req.backend.healthy) {
      set req.grace = 10s;
      set req.http.X-DMN-Debug-Backend-Grace = "Default: " + req.grace;  
    } else {
      #unset req.http.Cookie;
      #unset req.http.Accept-Encoding;
      #set req.http.Accept-Language = "en-US,en;q=0";
      set req.grace = 120m;
      set req.http.X-DMN-Debug-Backend-Grace = "Backend NOT healthy! " + req.grace;
    }
  }
}







sub vcl_recv {
  ## Turn on Debug (if desired)
  ## Preserve the origin headers (if desired)
  ## Handle Purge, Bans, Refresh & 'Odd' verbs
  ##  (NO pre-processing, normalization - just do as we're told!)
  ## Special Cases
  ## Strip Cookies
  ## Normalize Headers
  ## Normalize URLS
  ## Set Backend
  ##   Handle Uploads Dir ( only when req.request == 'GET' ?)
  ## Force TTL/Caching ?  


  set req.http.X-DMN-Debug = "Please";
  set req.http.X-DMN-Debug-Callpath = "vcl_recv";  

  #if (req.http.X-DMN-Debug) {
  #  set req.http.X-Debug-Orig-Request = req.request;
  #  set req.http.X-Debug-Orig-Host = req.http.host;
  #  set req.http.X-Debug-Orig-Port = req.http.port;
  #  set req.http.X-Debug-Orig-Url  = req.url;
  #  set req.http.X-Debug-Orig-Client  = client.ip;
  #  if (req.http.Accept-Encoding) {
  #    set req.http.X-Debug-Orig-Accept-Encoding =
  #      req.http.Accept-Encoding;
  #  }
  #  set req.http.X-Debug-Restarts = req.restarts;  
  #  if (req.http.X-Forwarded-For) {
  #    set req.http.X-Debug-Orig-Forwarded-For = req.http.X-Forwarded-For;
  #  }
  #}  

  

  ## PURGE/BAN/REFRESH
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






  ## Get all the easy stuff out of the way...
  ## admin/login, static files, transaction dir, etc.
  
  # If they're hitting the admin/login page or some Authenticated page
  # just pass and skip all the processing
  if (req.url ~ "^/wp-(login|admin)" ||
      req.url ~ "^/wp-content/plugins/wordpress-social-login/" ||
      req.http.Authorization ) {
    return (pipe);
  }
  
  # Always pass (pipe) on anything in the transaction (e-commerce)
  # folder. (Safety Feature)
  if (req.url ~ "^/transaction" ) { 
    return (pipe); 
  }
  
  # Throw out some easy crap early
  if (req.url ~ "(?i)p=discount-ugg" ) {
    error 777 "Oops";
  }
  if (req.url ~ "(?i)class=WebGUI::Asset" ) {
    error 777 "Oops";
  }


  ## This is our cache primer - strip cookies, and miss
  if (req.http.User-Agent == "DMN Cache Primer" && req.http.X-DMN-Cache-Primer == "Yes") {
    unset req.http.Cookie;
    unset req.http.Accept-Encoding;
    set req.http.Accept-Language = "en-US,en;q=0";
    set req.hash_always_miss = true;
    set req.http.X-DMN-Cache-Primer = "Yes (cookies stripped)";
  }    
  





  if (req.http.X-Forwarded-For) {
    unset req.http.X-Forwarded-For;
    set req.http.X-Forwarded-For = client.ip;
  }





  ## Simple static files
  set req.http.X-DMN-Debug-Cookies-Unset = "No";
  
  # uploaded images, etc.
  if (req.url ~ "^/wp-content/uploads" || req.http.X-DMN-Use-Uploads ) {
    set req.http.X-DMN-Debug-Cookies-Unset = "YES - Uploads File";
    unset req.http.Cookie;
    call NormReqEncoding;
    set req.http.X-DMN-Use-Uploads = "Yes";  
    set req.url = regsub(req.url, "^/wp-content/uploads/", "/");
    set req.http.X-DMN-Debug-Backend-Director = 
       "uploads (strips cookies): " + req.url;
    set req.http.X-DMN-Use-Uploads = "Yes";  
    set req.backend = uploads;
    call CheckRestarts;
    set req.http.X-DMN-Debug-Recv-Returned = "Lookup";
    return(lookup);
  }

  # Any other static files
  if (req.url ~ "\.(css|js|jpe?g|gif|png|ico|woff|ttf|zip|tgz|gz|rar|bz2|pdf|tar|txt|wav|bmp|rtf|flv|swf)(\?[A-Za-z0-9]+)?$" ||
      req.url ~ "\.(css|js)\?ver=.*$" ) {
    set req.http.X-DMN-Debug-Cookies-Unset = "YES - Media File";
    unset req.http.Cookie;
    call NormReqEncoding; 
    set req.http.X-DMN-Debug-Backend-Director = "www";
    set req.backend = www;
    call CheckRestarts;
    set req.http.X-DMN-Debug-Recv-Returned = "Lookup";
    return(lookup);
  }

  # SAH - Normalize all the RSS crap
  if (req.url ~ "(?i)^/rss$" || 
      req.url ~ "(?i)^/rss.xml$" ||
      req.url ~ "(?i)^/stories/rss$" ||
      req.url ~ "(?i)^/stories/rss.xml$"  ||
      req.url ~ "(?i)^/stories\?func=viewRss" ||
      req.url ~ "(?i)^/blog/rss"              ||
      req.url ~ "(?i)^/top-stories/rss$"  ||
      req.url ~ "(?i)^/top-stories/rss.xml$" ||
      req.url == "/\?feed=rss" ) {
    set req.url = "/?feed=rss";
    set req.http.X-DMN-Debug-Cookies-Unset = "YES - RSS Feed";
    unset req.http.Cookie;
    call NormReqEncoding; 
    set req.http.X-DMN-Debug-Backend-Director = "www";
    set req.backend = www;
    call CheckRestarts;
    set req.http.X-DMN-Debug-Recv-Returned = "Lookup";
    return(lookup);
  }	

  if (req.url ~ "(?i)^/stories\?func=viewAtom" ||
      req.url == "/\?feed=atom" ) {
    set req.url ="/?feed=atom";
    set req.http.X-DMN-Debug-Cookies-Unset = "YES - Atom Feed";
    unset req.http.Cookie;
    call NormReqEncoding; 
    set req.http.X-DMN-Debug-Backend-Director = "www";
    set req.backend = www;
    call CheckRestarts;
    set req.http.X-DMN-Debug-Recv-Returned = "Lookup";
    return(lookup);
  }

  # At this point, if they're logged in,
  # They're getting a personalized page - so pass
  if (req.http.cookie ~ "wordpress_logged_in") {
    set req.http.X-DMN-LOGGED-IN = "YES";  
    set req.http.X-DMN-Debug-Cookies-Unset = "NO - Logged In";
    set req.http.X-DMN-Debug-Backend-Director = "www";
    set req.backend = www;
    call CheckRestarts;
    set req.http.X-DMN-Debug-Recv-Returned = "Pass!";
    return(pass);
  }



  ## Finally, for users that are NOT logged in,
  ## Can we jigger it around to serve them cached content?
  ##
  
  ## Front page is easy - its the same for all anonymous visitors
  if (req.url == "/") {
    unset req.http.cookie;
    set req.http.X-DMN-Debug-Cookies-Unset = "YES - Front Door, NOT logged in";
    set req.http.X-DMN-Debug-Backend-Director = "www";
    set req.backend = www;
    call CheckRestarts;
    set req.http.X-DMN-Debug-Recv-Returned = "Lookup";
    return(lookup);
  }

  ## TODO: Once the javascript for comment nickname population gets
  ##       moved into production, we can basically unset req.http.Cookie !!
  ##       for anonymous users, the cookies only hold comment_* 
  ##       and preference settings.
  
  ## For now, see if we can fudge it..
  ## Strip Cookies
  ## TODO: PHPSESSID is the social login plugin. 
  ## It doesn't seem to require it unless your logging in (see above)
  ## so nuke it
  ## PHPSESSID=fni3n9n509tbf6k3v479jse0d4;
  ##
  ## Strip everything except wordpress cookies
  if (req.http.Cookie) {
    set req.http.Cookie = ";" + req.http.Cookie;
    set req.http.Cookie = regsuball(req.http.Cookie, "; +", ";");
    set req.http.Cookie = regsuball(req.http.Cookie, ";(wp[_-][^=]+|wordpress[_-][^=]+|comment[^=]+)=", "; \1=");
    set req.http.Cookie = regsuball(req.http.Cookie, ";[^ ][^;]*", "");
    set req.http.Cookie = regsuball(req.http.Cookie, "^[; ]+|[; ]+$", "");

    set req.http.X-DMN-Debug-Cooked-Cookies = req.http.Cookie;
  }
  
  if ( req.http.Cookie ~ "^ *$" ) {
    unset req.http.Cookie;
  }
  

  ## If we have commenter cookies leftover, we're screwed..
  if ( req.http.Cookie ~ "comment_author" ) {
    set req.http.X-DMN-Debug-Recv-Returned = "Pass!";
    return( pass );
  } else {
    set req.http.X-DMN-Debug-Recv-Returned = "Lookup";
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
  ## Throw out the easy crap
  ## Retry Support
  ## BAN support
  ## Unset cookies if possible
  ## Set TTL if needed

  set req.http.X-DMN-Debug-Callpath =
    req.http.X-DMN-Debug-Callpath + ", vcl_fetch";

  if (req.http.X-DMN-Debug-Backend-Chain) {
    set req.http.X-DMN-Debug-Backend-Chain = 
      req.http.X-DMN-Debug-Backend-Chain + ":" + beresp.backend.name;  
  } else {
    set req.http.X-DMN-Debug-Backend-Chain = beresp.backend.name;  
  }


  ## Don't retry bad bots or spammers -
  ## Don't cache them either (so no hit for pass)
  if (beresp.status == 666 || beresp.status == 777) {
    set beresp.ttl = 0s;
    return(deliver);
  }
  
  ## Retry Support
  ## retry 404's on images as they might not have synced yet..
  ## be careful if you retry 403's as it can cause us issues with things like
  ## the rate limiter on comments (throws a 403 if you comment too fast)
  ## WARNING
  ##   if you retry a request it uses the MODIFIED req!
  ##   This means, for instance, a different director can be selected if
  ##   you've modified the req.url!
  ##

  if (beresp.status == 404 &&
      req.url ~ "\.(jpe?g|gif|png|ico|woff|ttf|zip|tgz|gz|rar|bz2|pdf|tar|wav|bmp|rtf|flv|swf)$") {
    if (req.restarts == 0) {
      set beresp.saintmode = 3s;
      return(restart);
    }
  }


  ## TODO: Figure out POSTs and retry logic
  ## If we're down, punt with old content
  if (beresp.status == 502 || beresp.status == 503) {
    set beresp.saintmode = 10s;
    if ( req.request != "POST" ) {
      return(restart);
    }
    else {
      set beresp.ttl = 3s;
      error 500 "Application Failure";
    }
  }
    
  ## TODO: Figure out POSTs and retry logic
  ## For now, just punt
  ## Do NOT touch POSTs
  if (req.request == "POST") {
    set beresp.ttl = 0s;
    set beresp.http.X-Cacheable = "NO: POST";
    return(deliver);
  }




  ## Throw out the easy crap
  
  # These should never happen as we return(pipe) in vcl_rcv,
  # But Just In Case (tm)
  ## Don't cache admin pages
  if (req.url ~ "^/wp-(login|admin)" ||
      req.url ~ "^/wp-content/plugins/wordpress-social-login/" ||
      req.http.Authorization ) {
    set beresp.ttl = 0s;
    set beresp.http.X-Cacheable = "NO: Admin Area";
    return (deliver);
  }
  
  # Always pass (pipe) on anything in the transaction (e-commerce)
  # folder. (Safety feature)
  if (req.url ~ "^/transaction" ) {
    set beresp.ttl = 0s;
    set beresp.http.X-Cacheable = "NO: Transaction Folder";
    return (deliver); 
  }



  ## BAN Lurker support
  set beresp.http.x-url  = req.url;
  set beresp.http.x-host = req.http.host;

  ## Setup the grace Time
  set beresp.grace = 240m;


  ## This is our cache primer - strip cookies, and force caching
  ## This should be just plain vanilla content - no cookies, 
  ## logged in messages, etc.
  if (req.http.User-Agent == "DMN Cache Primer" &&
      req.http.X-DMN-Cache-Primer) {
    unset beresp.http.set-cookie;
    unset beresp.http.Vary;
    set beresp.ttl = 3600s;
    set beresp.http.Cache-Control = "public, max-age = 3600";
    set beresp.http.X-DMN-Cache-Primer = "Yes (cookies stripped, caching overridden)";
    set beresp.http.X-Cacheable = "YES: Cache Primer: " + beresp.ttl;
    return(deliver);
  }    
  




  set beresp.http.X-Cacheable = "YES: No Changes Made";
  unset beresp.http.X-DMN-Strip-deliver;
  
  if (req.url ~ "(?i)\.(bmp|ico|jpe?g|gif|png)(\?[a-z0-9]+)?$") {
    set beresp.http.X-Cacheable = "YES:Forced Image File: ";
  }
  
  # Strip cookies for static files:
  if (req.url ~ "(?i)\.(js|css|woff|zip|tgz|gz|rar|bz2|pdf|txt|tar|wav|rtf|flv|swf)(\?[a-z0-9]+)?$") {
    set beresp.http.X-Cacheable = "YES:Forced Static File: ";
  }


  # Tagged - so give it a long TTL as the tag will force refresh
  if (req.url ~ "(?i)\.(bmp|ico|jpe?g|gif|png)\?([A-Za-z0-9]+)$" ||
      req.url ~ "(?i)\.(js|css|woff|zip|tgz|gz|rar|bz2|pdf|txt|tar|wav|rtf|flv|swf)\?([A-Za-z0-9]+)$") {
    set beresp.ttl = 7d;
    set beresp.http.Cache-Control = "public, max-age = 604800";
    set beresp.http.X-Cacheable = 
      beresp.http.X-Cacheable + "Tagged! (" + beresp.ttl + ")";
    set beresp.http.X-DMN-Debug-Cookies-Stripped = "Yes - Static File";
    set beresp.http.X-DMN-Strip-deliver = "Yes";
  }
  
  # Tagged - so give it a long TTL as the tag will force refresh
  if (req.url ~ ".*\.(css|js)\?ver=.*" ) {
    unset beresp.http.expires;
    set beresp.ttl = 7d;
    set beresp.http.Cache-Control = "public, max-age = 604800";
    set beresp.http.X-Cacheable = "YES:Forced VERSIONED css/js File: " + beresp.ttl;
    set beresp.http.X-DMN-Debug-Cookies-Stripped = "Yes - Static File";
    set beresp.http.X-DMN-Strip-deliver = "Yes";
  }


  # If its a DMN theme image, cache it for longer..
  # force woff files as we only have 1 font and it never changes
  if (req.url ~ "(?i)DMN2013/img/.*\.(bmp|ico|jpe?g|gif|png)(\?[a-z0-9]+)?$" ||
      req.url ~ "(?i)\.woff$") {
    set beresp.ttl = 7d;
    set beresp.http.Cache-Control = "public, max-age = 604800";
    set beresp.http.X-Cacheable = "YES:Theme Image File: " + beresp.ttl;
    set beresp.http.X-DMN-Debug-Cookies-Stripped = "Yes - Static File";
    set beresp.http.X-DMN-Strip-deliver = "Yes";
  }


  # Not Tagged - These can change more often, so give it short ttl
  if (req.url ~ "(?i)\.(bmp|ico|jpe?g|gif|png)$" ||
      req.url ~ "(?i)\.(js|css|zip|tgz|gz|rar|bz2|pdf|txt|tar|wav|rtf|flv|swf)$") {
    set beresp.ttl = 120s;
    set beresp.http.Cache-Control = "public, max-age = 120";
    set beresp.http.X-Cacheable = 
      beresp.http.X-Cacheable + "Untagged (" + beresp.ttl + ")";
    set beresp.http.X-DMN-Debug-Cookies-Stripped = "Yes - Static File";
    set beresp.http.X-DMN-Strip-deliver = "Yes";
  }


  if (beresp.http.X-DMN-Strip-Deliver) {
    unset beresp.http.X-DMN-Strip-deliver;  
    set beresp.http.X-DMN-Adjust-Age = "Yes";
    unset beresp.http.Set-Cookie;
    unset beresp.http.expires;
    return(deliver);
  }


  ## Not a static file, so if we're logged in, its personalized
  if (req.http.cookie ~ "wordpress_logged_in") {
    set req.http.X-DMN-LOGIN = "YES";
    set beresp.ttl = 0s;
    return(deliver);
  }


  ## If we're not logged in, kill the dam PHPSESSID cookie
  if (beresp.http.Set-Cookie) {
    header.remove(beresp.http.Set-Cookie, "PHPSESSID");
    set beresp.http.X-DMN-Debug-PHPSESSID = "Removed";
    if (beresp.http.Set-Cookie ~ "^ *$") {
      unset beresp.http.Set-Cookie;
      set beresp.http.X-DMN-Debug-PHPSESSID = "Removed, Set-Cookie UNSET";
    }
  }

  
  # Homepage isn't personalized for anonymous,
  # And doesn't really need to set any cookies
  if (req.url == "/") {
    set beresp.ttl = 30s;
    # We just want to cache it here - not sure we want browser to cache
    #unset beresp.http.expires;
    #set beresp.http.Cache-Control = "public, max-age = 30";
    #set beresp.http.X-DMN-Adjust-Age = "Yes";
    #set beresp.http.X-Cacheable = "Foced cache Front Door (" + beresp.ttl + ")";
    return(deliver);
  }
  


  #if (req.url ~ "/permalink/") {
  #    unset beresp.http.expires;
  #    set beresp.ttl = 30s;
  #    set beresp.http.Cache-Control = "public, max-age = 30";
  #    set beresp.http.X-DMN-Adjust-Age = "Yes";
  #    set beresp.http.X-Cacheable = "Foced cache Story Page (" + beresp.ttl + ")";
  #    return(deliver);
  #}
  
  
  # Honour Cache Controls
  if ( beresp.http.Cache-Control ~ "no-cache" ) {
    set beresp.ttl = 0s;
    set beresp.http.X-Cacheable = "NO:Cache-Control=no-cache";
    return(hit_for_pass);
  }
  if ( beresp.http.Cache-Control ~ "private" ) {
    set beresp.ttl = 0s;
    set beresp.http.X-Cacheable = "NO:Cache-Control=private";
    return(hit_for_pass);
  }

  # Only cache responses with no cookies
  if (beresp.http.set-cookie) {
    set beresp.ttl = 0s;
    set beresp.http.X-Cacheable = "NO: SET COOKIE";
    return(hit_for_pass);
  }


  # Varnish determined the object was not cacheable
  if ( beresp.ttl <= 0s ) {
    set beresp.http.X-Cacheable = "NO: Not Cacheable (Unknown Reason)";
  }








  #set beresp.http.X-FrontDoor = "NO";
  
  # Sub Mast can change pretty often...
  #if ( req.url == "/data/submast.gif") {
  #  unset beresp.http.set-cookie;
  #  set beresp.ttl = 300s;
  #  set beresp.http.Cache-Control = "max-age = 300";
  #  set beresp.http.X-Cacheable = "YES: Submast Image";
  #  return(deliver);
  #}
  

      

  #if (req.url == "/top-stories/rss.xml"  ||
  #    req.url == "/stories?func=viewRss" ||
  #    req.url == "/stories?func=viewAtom" ){
  #      unset beresp.http.set-cookie;
  #      set beresp.ttl = 300s;
  #      set beresp.http.Cache-Control ="max-age = 300";
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
  #  set beresp.http.Cache-Control = "must-revalidate, max-age = 180";
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







sub vcl_deliver {

  set req.http.X-DMN-Debug-Callpath =
      req.http.X-DMN-Debug-Callpath + ", vcl_deliver";
  
  if (resp.http.X-DMN-Adjust-Age) {
    #unset resp.http.X-DMN-Adjust-Age;
    set resp.http.X-DMN-Debug-Age = resp.http.age;
    set resp.http.age = "0";
    # set resp.http.expires = obj.ttl;
  }


  if (req.http.X-DMN-Debug) {
    set resp.http.X-Forwarded-For = req.http.X-Forwarded-For ;
    set resp.http.X-DMN-Debug = req.http.X-DMN-Debug ;
    set resp.http.X-DMN-Debug-Callpath =  req.http.X-DMN-Debug-Callpath;
    set resp.http.X-DMN-Debug-Encoding-Changed = req.http.X-DMN-Debug-Encoding-Changed ;
    set resp.http.X-DMN-Debug-Cookies-Unset = req.http.X-DMN-Debug-Cookies-Unset ;
    #set resp.http.X-DMN-Debug-PHPSESSID =  beresp.http.X-DMN-Debug-PHPSESSID;
    if ( req.http.X-DMN-Use-Uploads ) {
      set resp.http.X-DMN-Use-Uploads = req.http.X-DMN-Use-Uploads;
    }
    #if ( req.http.X-DMN-Debug-Cooked-Cookies ) {
    #  set resp.http.X-DMN-Debug-Cooked-Cookies = req.http.X-DMN-Debug-Cooked-Cookies;
    #}
    
    set resp.http.X-DMN-Debug-Backend-Director =
      req.http.X-DMN-Debug-Backend-Director ;
    set resp.http.X-DMN-Debug-Backend-Restarts = req.restarts ;
    set resp.http.X-DMN-Debug-Backend-Chain = req.http.X-DMN-Debug-Backend-Chain;
    set resp.http.X-DMN-Debug-Backend-Grace = req.http.X-DMN-Debug-Backend-Grace;
    set resp.http.X-DMN-Debug-Recv-Returned = req.http.X-DMN-Debug-Recv-Returned;

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
    if (resp.http.set-cookie) {
      unset resp.http.set-cookie;
      set resp.http.X-DMN-WARNING = "set-cookie found on cached response ?";
    }
  }
  
  if (! req.http.X-DMN-Debug ) {
    unset resp.http.X-DMN-Use-Uploads;
    #unset resp.http.X-Varnish;
  }


  ## BAN Lurker Support
  unset resp.http.x-url;
  unset resp.http.x-host;
  unset resp.http.X-Powered-By;
  
}




sub vcl_error {

  set req.http.X-DMN-Debug-Callpath =
    req.http.X-DMN-Debug-Callpath + ", vcl_error";
  

  # Dont retry PURGE/BAN
  if ( req.request == "PURGE" || req.request == "BAN" ) {
    return(deliver);
  }
  
  
  # error 777 ugg boots and webgui spammers..
  # error 666 bad bots
  # We only have 2 backends...more restarts would be silly
  if ((req.restarts < 3) && (!(obj.status == 666 || obj.status == 777)) ) {
    return(restart);
  }
}




sub vcl_hash {

  set req.http.X-DMN-Debug-Callpath =
    req.http.X-DMN-Debug-Callpath + ", vcl_hash";
}





sub vcl_hit {
  set req.http.X-DMN-Debug-Callpath =
    req.http.X-DMN-Debug-Callpath + ", vcl_hit";
  
  if (req.request == "PURGE") {
    purge;
    error 200 "Purged.";
  }
  
}




sub vcl_miss {
  set req.http.X-DMN-Debug-Callpath =
    req.http.X-DMN-Debug-Callpath + ", vcl_miss";
  
  if (req.request == "PURGE") {
    purge;
    error 404 "Not In Cache.";
  }




}



sub vcl_pass {
  set req.http.X-DMN-Debug-Callpath =
    req.http.X-DMN-Debug-Callpath + ", vcl_pass";
  
  set req.http.X-PASSED = "Yep";
}





sub vcl_pipe {
  # Note that only the first request to the backend will have
  # X-Forwarded-For set.  If you use X-Forwarded-For and want to
  # have it set for all requests, make sure to have:
  # set bereq.http.connection = "close";
  # here.  It is not set by default as it might break some broken web
  # applications, like IIS with NTLM authentication.

  set req.http.X-DMN-Debug-Callpath =
      req.http.X-DMN-Debug-Callpath + ", vcl_pipe";

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
