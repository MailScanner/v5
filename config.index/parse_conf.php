<?php
$parentDir = dirname( dirname(__FILE__) );
//$fh = fopen('./MailScanner.conf','r');
$fh = fopen($parentDir.'/common/etc/MailScanner/MailScanner.conf','r');
if($fh) {
 while(!feof($fh)) {
  $line = fgets($fh,1024);
  // Clear out pre on every blank line
  if(isset($pre) && preg_match('/$^/',$line)) {
   unset($pre);
  } else {
   if(preg_match('/^#/',$line)) {
    if(isset($pre)) {
     $pre .= $line;
    } else {
     $pre = $line;
    }
   }
  }

  $line = rtrim($line); 
  if( (!preg_match('/^#/',$line) && !preg_match('/^%/',$line)) && (preg_match('/(.*)\s=(.*)/',$line,$match))) {
   $ext = strtolower(str_replace(array(' ','-'),'',rtrim($match[1])));
   $conf[$ext]['name'] = rtrim($match[1]);
   $conf[$ext]['value'] = rtrim($match[2]);
   if(isset($pre)) {
    $conf[$ext]['comment'] = str_replace(array('#','# '),'',rtrim($pre));
   } else {
    $conf[$ext]['comment'] = "";
   }
   unset($pre, $ext);
  }
 }
}
fclose($fh);
unset($fh);
?>
