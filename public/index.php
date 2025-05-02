<?php

namespace GoldenGoose;


use Throwable;

try {
	/* @var $application Application */
	$application = require dirname(__DIR__) . '/simple.application.php';
	$application->index();
} catch (Throwable $throwable) {
	if ($_SERVER['PRODUCTION'] ?? false) {
		header('HTTP/1.1 501 Server Error');
		echo get_class($throwable);
		error_log($throwable->getMessage() . PHP_EOL . $throwable->getTraceAsString());
	} else {
		echo "<h1>" . $throwable->getMessage() . "</h1>";
		echo "<pre>" . $throwable->getTraceAsString() . "</pre>";
	}
}
