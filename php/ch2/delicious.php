<?php
  $user = "username";
  $password = "password";

  $request = curl_init();
  curl_setopt($request, CURLOPT_URL,
              'https://api.del.icio.us/v1/posts/recent');
  curl_setopt($request, CURLOPT_USERPWD, "$user:$password");
  curl_setopt($request, CURLOPT_RETURNTRANSFER, true);

  $response = curl_exec($request);
  $xml = simplexml_load_string($response);
  curl_close($request);

  foreach ($xml->post as $post) {
    print "$post[description]: $post[href]\n";
  }
?>