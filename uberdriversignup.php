<?php
$url = $_GET['url'];
if (isset ($url)) { // decode the url and display it in the iframe
echo '<iframe ... src="'.urldecode($url).'"></iframe>';
} else { // display a static page if no url parameter was received
echo '<iframe ... src="http://www.google.com"></iframe>';
}
?>
