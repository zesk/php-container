<?php declare(strict_types=1);

namespace GoldenGoose;

use zesk\Application as ApplicationBase;
use zesk\Request;
use zesk\Response;

class Application extends ApplicationBase
{
	/**
	 * @return void
	 * @throws \zesk\Exception\ClassNotFound
	 * @throws \zesk\Exception\SemanticsException
	 */
	protected function afterConfigure(): void
	{
		$this->router->addRoute('index', [
			'method' => $this->homeHandler(...),
			'arguments' => ['{request}'],
		]);
	}

	public function homeHandler(Request $request): Response
	{
		return $this->application->responseFactory($request)->json()->setData(['message' => 'Hello world!', 'path' => $request->path()]);
	}
}
