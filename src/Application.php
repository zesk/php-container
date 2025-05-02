<?php

namespace GoldenGoose;

use zesk\Application as ApplicationBase;
use zesk\Request;

class Application extends ApplicationBase {

	/**
	 * @return void
	 * @throws \zesk\Exception\ClassNotFound
	 * @throws \zesk\Exception\SemanticsException
	 */
	protected function afterConfigure(): void
	{
		$this->router->addRoute("index", [
			"method" => $this->homeHandler(...),
		]);
	}

	public function homeHandler(Request $request)
	{
		echo "Hello world!";
	}
}
