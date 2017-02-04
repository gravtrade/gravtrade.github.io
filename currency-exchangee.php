<?php
     $data = file_get_contents(
    'http://apilayer.net/api/live?access_key=6569f27ce6a4c309c0027288f3ded2c6&format=1'.
    'from=USD'.
    '&to=EUR'
);
$json = json_decode($data);
$rate = (float) $json->rate;
	?>
