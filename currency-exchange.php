// set API Endpoint and access key (and any options of your choice)
$endpoint = 'live';
$access_key = '6569f27ce6a4c309c0027288f3ded2c6';

// Initialize CURL:
$ch = curl_init('http://apilayer.net/api/'.$endpoint.'?access_key='.$access_key.'');
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);

// Store the data:
$json = curl_exec($ch);
curl_close($ch);

// Decode JSON response:
$exchangeRates = json_decode($json, true);

// Access the exchange rate values, e.g. GBP:
echo $exchangeRates['quotes']['USDGBP'];
