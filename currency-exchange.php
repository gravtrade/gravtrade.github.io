<?php 
$json_url = "http://apilayer.net/api/live?access_key=6569f27ce6a4c309c0027288f3ded2c6&currencies=USD,AUD,CAD,PLN,MXN&format=1";
$json = file_get_contents($quotes);
$data = json_decode($json, TRUE);
echo "<pre>";
print_r($data);
echo "</pre>";
?>
