
sub sanity_check_url {
  # Throw out some common 'bad' urls
  #
  unset req.http.insane;

  # Throw out some easy crap early
  if (req.url ~ "(?i)w00tw00t" )                 { set req.http.insane = "Yes"; }
  if (req.url ~ "(?i)p=discount-ugg" )           { set req.http.insane = "Yes"; }
  if (req.url ~ "(?i)class=WebGUI::Asset" )      { set req.http.insane = "Yes"; }
  if (req.url ~ "(~|.bak|.swp|.htaccess)$" )     { set req.http.insane = "Yes"; }
  if (req.url ~ "/wp-includes/.*\.php")          { set req.http.insane = "Yes"; }
  if (req.url ~ "uploads/.*\.php$")              { set req.http.insane = "Yes"; }
  if (req.url ~ "(wp-config.php|install.php)$" ) { set req.http.insane = "Yes"; }
  if (req.url ~ "(readme.html|readme.txt)$" )    { set req.http.insane = "Yes"; }
}
