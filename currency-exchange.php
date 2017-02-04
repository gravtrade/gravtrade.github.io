<?php

#function to process the input
function process_input($data)
{
 return $data->source;
}

#input url
$url = 'http://apilayer.net/api/live?access_key=6569f27ce6a4c309c0027288f3ded2c6&currencies=USD,AUD,CAD,PLN,MXN&format=1';


#get the data
$json = file_get_contents($url);

#convert to php array
$php_array = json_decode($json);

#process the data and get output
$output = array_map("process_input", $php_array);


#convert the output to json array and print it
echo json_encode($output);
?>
