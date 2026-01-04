<?php

namespace GoldenGooseTests;

use zesk\Net\HTTP\Client;
use zesk\PHPUnit\TestCase;

class GooseAPITest extends TestCase {

	function testEndpoints() {
		$host = $this->application->environment()->getString("API_HOST", "127.0.0.1");
		$port = $this->application->environment()->getInt("API_PORT", 80);
		$client = new Client($this->application, "http://$host:$port/");
		$content = $client->go();

		var_dump($content);
		$client = new Client($this->application, "http://$host:$port/test");
		$testContent = $client->go();
		var_dump($testContent);
	}
}
