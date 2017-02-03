// set endpoint and your access key
endpoint = 'live'
access_key = '6569f27ce6a4c309c0027288f3ded2c6';

// get the most recent exchange rates via the "live" endpoint:
$.ajax({
    url: 'http://apilayer.net/api/' + endpoint + '?access_key=' + access_key,   
    dataType: 'jsonp',
    success: function(json) {

        // exchange rata data is stored in json.quotes
        alert(json.quotes.USDGBP);
        
        // source currency is stored in json.source
        alert(json.source);
        
        // timestamp can be accessed in json.timestamp
        alert(json.timestamp);
        
    }
});
