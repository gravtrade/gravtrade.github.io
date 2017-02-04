<?php
$myJSON = file_get_contents('http://apilayer.net/api/live?access_key=6569f27ce6a4c309c0027288f3ded2c6&currencies=USD,AUD,CAD,PLN,MXN&format=1');
echo "myFunc(".$myJSON.");";
?>
