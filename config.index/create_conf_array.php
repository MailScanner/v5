#!/usr/bin/php -q
<?php
// Load MailScanner.conf array
// this returns $conf array
//require_once('parse_conf.php');

// this script must be run from a sub directory of the build. example: /msbuild/v4/config.index
// and the "mailscanner" directory must be one up. example: /mydir/v4/mailscanner
$parentDir = dirname( dirname(__FILE__) );

// moved parse_conf.php to here
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
// finish parse_conf.php

$fh = fopen($parentDir.'/common/usr/share/MailScanner/perl/MailScanner/ConfigDefs.pl','r');
if($fh) {
 while(!feof($fh)) {
  $line = fgets($fh,1024);
  if( (preg_match('/^$/',$line)) 
   || (preg_match('/^#/',$line))
   || (preg_match('/^\s/',$line))) {
   // Skip
   continue;
  }
  
  // Remove line endings
  $line = rtrim($line);

  // Handle section headings
  if(preg_match('/^\[(.*)\]$/',$line,$smatch)) {
   $sarray = split(',',$smatch[1]);
   $category = strtolower($sarray[0]);
   $type = strtolower($sarray[1]);
   unset($smatch);
   unset($sarray);
   // echo "Processing category $category, type $type\n";
   continue;
  }

  // Skip any header lines where category & type are unset
  if( (!isset($category)) || (!isset($type)) ) {
   continue;
  }

  // Handle ItoE translation
  if($category == 'translation') {
   $line = strtolower($line);
   if(count($tarray = preg_split('/\s*=\s*/',$line,2))==2) {
    list($int, $ext) = $tarray;
    // echo "Internal: $int, External: $ext\n";
    // Create array maps
    // $ItoE[$int] = $ext;
    $EtoI[$ext] = $int;
    // Add to main array
    $setup[$int]['external'] = $ext;
    unset($tarray);
   }
  }

  // Handle YesNo values
  if($type == 'yesno') {
   $line = strtolower($line);
   if(count($sarray = preg_split('/\s+/',$line))>1) {
    if(!isset($setup[$sarray[0]])) {
     // Create an entry
     $EtoI[$sarray[0]] = $sarray[0];
     $setup[$sarray[0]]['external'] = $sarray[0];
    }
    // Record the value type
    $setup[$sarray[0]]['type'] = $type;
    // Record the ruleset type
    if($category == 'simple') {
     $setup[$sarray[0]]['ruleset'] = 'no';
    } else {
     $setup[$sarray[0]]['ruleset'] = $category;
    }
    // Record the default value
    $setup[$sarray[0]]['default'] = $sarray[1];
    // Record the selectable options (Internal => External)
    $setup[$sarray[0]]['values'] = array();
    while(count($sarray)>2) {
     $setup[$sarray[0]]['values'][array_pop($sarray)] = array_pop($sarray);
    }
   }
  } elseif($category != 'translation') {
   // Handle All other values (e.g. Dir, File, Command, Other)
   if(preg_match('/(\S+)\s*(.*)/',$line,$match)) {
    $match[1] = strtolower($match[1]);
    if(!isset($setup[$match[1]])) {
     // Create an entry
     $EtoI[$match[1]] = $match[1];
     $setup[$match[1]]['external'] = $match[1];
    }
    // Record the value type
    $setup[$match[1]]['type'] = $type;
    // Record the ruleset type
    if($category == 'simple') {
     $setup[$match[1]]['ruleset'] = 'no';
    } else {
     $setup[$match[1]]['ruleset'] = $category;
    }
    // Record the default value
    if(!preg_match('/^#/',$match[2])) {
     $setup[$match[1]]['default'] = $match[2];
    } else {
     $setup[$match[1]]['default'] = "";
    }
   }
  }

 }
 fclose($fh);
}


// Okay - we have MailScanner.conf and EtoI loaded
// let's merge the arrays together and build the
// difinitive list of all possible values.
foreach($conf as $key=>$val) {
 if(!isset($EtoI[$key])) {
  // EtoI lookup failed (sendercontentreport)
  if(isset($setup[$key])) {
   // Use internal value instead
   $setup[$key]['name'] = $val['name'];
   $setup[$key]['desc'] = $val['comment'];
   $setup[$key]['value'] = $val['value'];
  }
 } else {
  $setup[$EtoI[$key]]['name'] = $val['name'];
  $setup[$EtoI[$key]]['desc'] = $val['comment'];
  $setup[$EtoI[$key]]['value'] = $val['value'];
 }
}

// Sort the array
asort($setup);

echo "<?php
/*
** Auto-generated MailScanner GUI configuration guide
*/

";
echo '$conf = ';
var_export($setup);
echo ";\n?>";
