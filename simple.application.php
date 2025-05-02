<?php
/**
 *
 */

if (!require_once "vendor/autoload.php") {
	header("HTTP/1.0 500 Server Error");
	echo "Invalid vendor";
}

use GoldenGoose\Application;
use zesk\ApplicationLoader;

$version = json_decode(__DIR__ . "/composer.json")['version'] ?? 'no composer.json';
return ApplicationLoader::application([
		Application::OPTION_APPLICATION_CLASS   => Application::class,
		Application::OPTION_PATH                => __DIR__,
		Application::OPTION_VERSION             => $version,
		Application::OPTION_DEVELOPMENT         => $_SERVER['DEVELOPMENT'] ?? true,
		Application::OPTION_CONFIGURATION_FILES => ['.env'],
	] + (is_array($GLOBALS['ZESK'] ?? null) ? $GLOBALS['ZESK'] : []));
