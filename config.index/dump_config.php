<?php
# this file should have been created by make.sh
require_once('/tmp/conf_array.php');
if(isset($_GET['v'])){
	$display_version = 'v'.$_GET['v'];
}else{
	$display_version = NULL;
}
?>
<html>
<head>
<title>MailScanner Configuration Index</title>
<style type="text/css">
<!--
body {
 margin: 5px 5px 5px 5px; 
 font-family: Tahoma, Arial;
 font-size: 8pt;
}

table {
 border-collapse: collapse;
 font-size: 8pt;
}

th, td {
 border-width: 1px 1px 1px 1px;
 padding: 3px 3px 3px 3px;
 border-style: solid solid solid solid;
 border-color: gray gray gray gray;
 vertical-align: top;
}

th {
 background-color: #F7CE4A;
 color: black;
 white-space: nowrap;
 vertical-align: top;
 text-align: left;
}

-->
</style>
</head>
<body>

<h1>Configuration Index - MailScanner <?php echo $display_version; ?></h1>

<?php
// Build an index by Full Name
foreach($conf as $opt => $val) {
 if(!empty($val['name'])) $index[] = $val['name'];
}
sort($index);

$columns = 4;
echo "<table>\n";
echo " <tr><th colspan=\"$columns\">Index</th></tr>\n";
$i=0;
while($i<count($index)) {
 echo " <tr>\n";
 for($n=0; $n<$columns; $n++) {
 	if(!empty($index[$i])){
	  	echo "  <td><a href=\"#{$index[$i]}\">{$index[$i]}</a></td>\n";
	}else{
		echo "  <td></td>\n";
	}
  $i++;
 }
 echo " </tr>\n";
}
?>
</table>
<p>
<b>Further information</b><br/>
There are <?php echo count($index); ?> configuration options in this version.
</p>
<p>
"First Match" rulesets work through the recipients and stop at the
first address that matches, using that rule's value as the one result of
the configuration option. "First Match" rulesets stop as soon as they
get a match with the recipients processed in an arbitrary order.
</p>
<p>
"All Match" rulesets work through every recipient, concatenating all the
results. "All Match" rulesets are usually used when you want to check
if any of the recipient addresses match. For example, when evaluating a
"Yes/No" option with an "All Matches" ruleset, the result is taken as a
"Yes" if any of the addresses match at all.
</p>
<p>
When you use the name of a configuration option, don't worry about
whitespace and punctuation. The only characters that count are A-Z and
numbers. Any combination of upper and lower case is fine, as are extra
punctuation marks such as '-' and extra (or missing) spaces.
</p>

<table width="100%">
<?php
$a = 0;
// Re-sort with external name
foreach($conf as $skey=>$sval) {
 $new[$sval['external']] = $conf[$skey];
}
$conf = $new;
ksort($conf);

// Output
foreach($conf as $ckey=>$cval) {
 // Skip entries with no nice names
 if(empty($cval['name'])) continue;
 ?>
 <tr>
  <th>Name:</td><td colspan="5"><b><a name="<?php echo $cval['name']; ?>"><?php echo $cval['name']; ?></a></b></td>
 </tr>
 <tr>
  <th>Distro Value:</th>
  <td><?php echo $cval['value']; ?></td>
  <th>Default Value:</th>
  <td colspan="3">
   <?php 
   if($cval['type'] == "yesno") {
    echo $cval['values'][$cval['default']];
   } else {
    echo $cval['default'];
   }
   ?>
  </td>
 </tr>
 <tr>
  <th>Input Type:</th>
  <td>
   <?php if($cval['type'] == "yesno"): ?>
    <table class="maildetail">
     <tr>
      <th>Allowed Values</th>
     </tr>
     <?php foreach($cval['values'] as $vkey=>$vval) { ?>
     <tr>
      <td><?php echo $vval; ?></td>
     </tr>
     <?php } ?>
    </table>
   <?php else:
    switch($cval['type']) {
     case 'file':
      echo "File";
      break;
     case 'dir':
      echo "Directory";
      break;
     case 'number':
      echo "Numeric";
      break;
     case 'command':
      echo "Command";
      break;
     case 'other':
      echo "Mixed";
      break;
     default:
      echo "UNKNOWN";
      break;
    }
   endif; 
   ?>
  </td>
  <th>Ruleset Allowed:</th>
  <td><?php if($cval['ruleset'] == "no") { echo "No"; } else { echo "Yes"; } ?></td>
  <th>Ruleset Type:</th>
  <td>
   <?php
   switch($cval['ruleset']) {
    case 'no':
     echo "N/A";
     break;
    case 'first':
     echo "First Match";
     break;
    case 'all':
     echo "All Match";
     break;
    default:
     echo "UNKNOWN";
     break;
   }
   ?>
  </td>
 </tr>
 <tr>
  <th>Description:</th><td colspan="5"><pre><?php echo htmlentities($cval['desc']); ?></pre></td>
 </tr>
 <?php if($a <> (count($conf)-9)): ?>
 <tr>
  <td colspan="6">&nbsp;</td>
 </tr>
 <?php
 endif;
 $a++;
}
?>
</table>
</body>
</html>
<html><body></body></html>