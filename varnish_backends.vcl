
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
    #.initial = 5;
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
    #.initial = 5;
  }
  .max_connections = 128;
}


backend www3 {
  .host = "10.30.1.112";
  .port = "10080";
  .probe = {
    .url = "/robots.txt"; # Checks php-fpm backend
    .interval = 5s;
    # .url = "/ping"; # does NOT check php-fpm backend health!
    # .interval = 1s;
    .timeout = 0.6s;
    .window = 8;
    .threshold = 6;
    #.initial = 5;
  }
  .max_connections = 128;
}


backend www4 {
  .host = "10.30.1.113";
  .port = "10080";
  .probe = {
    .url = "/robots.txt"; # Checks php-fpm backend
    .interval = 5s;
    # .url = "/ping"; # does NOT check php-fpm backend health!
    # .interval = 1s;
    .timeout = 0.6s;
    .window = 8;
    .threshold = 6;
    #.initial = 5;
  }
  .max_connections = 128;
}


backend www5 {
  .host = "10.30.1.114";
  .port = "10080";
  .probe = {
    .url = "/robots.txt"; # Checks php-fpm backend
    .interval = 5s;
    # .url = "/ping"; # does NOT check php-fpm backend health!
    # .interval = 1s;
    .timeout = 0.6s;
    .window = 8;
    .threshold = 6;
    #.initial = 5;
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
    #.initial = 5;
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
    #.initial = 5;
  }
  .max_connections = 128;
}

backend upload3 {
  .host = "10.30.1.112";
  .port = "10081";
  .probe = {
    .url = "/ping";
    .interval = 1s;
    .timeout = 0.6s;
    .window = 8;
    .threshold = 6;
    #.initial = 5;
  }
  .max_connections = 128;
}

backend upload4 {
  .host = "10.30.1.113";
  .port = "10081";
  .probe = {
    .url = "/ping";
    .interval = 1s;
    .timeout = 0.6s;
    .window = 8;
    .threshold = 6;
    #.initial = 5;
  }
  .max_connections = 128;
}

backend upload5 {
  .host = "10.30.1.114";
  .port = "10081";
  .probe = {
    .url = "/ping";
    .interval = 1s;
    .timeout = 0.6s;
    .window = 8;
    .threshold = 6;
    #.initial = 5;
  }
  .max_connections = 128;
}

#backend fail {
#  .host = "localhost";
#  .port = "21121";
#  .probe = { .url = "/asfasfasf"; .initial = 0; .interval = 1d; }
#}

acl purgers {
  "localhost";
  "10.30.1.0"/24;
  "72.52.81.238";
  "72.52.81.239";
  "72.52.81.240";
  "72.52.81.241";
}


sub vcl_init {
  new www = directors.round_robin();
  www.add_backend(www1);
  www.add_backend(www2);
  www.add_backend(www3);
  www.add_backend(www4);
  www.add_backend(www5);
  new uploads = directors.round_robin();
  uploads.add_backend(upload1);
  uploads.add_backend(upload2);
  uploads.add_backend(upload3);
  uploads.add_backend(upload4);
  uploads.add_backend(upload5);
  return(ok);
}

