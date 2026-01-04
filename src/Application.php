<?php
declare(strict_types=1);

namespace GoldenGoose;

use zesk\Application as ApplicationBase;
use zesk\Exception\ClassNotFound;
use zesk\HTTP;
use zesk\Request;
use zesk\Response;

class Application extends ApplicationBase {
	/**
	 * @return void
	 * @throws ClassNotFound
	 */
	protected function afterConfigure(): void
	{
		$this->router->addRoute('.', [
			'method'    => $this->homeHandler(...),
			'arguments' => [
				'{request}',
				"Hello, world!",
			],
		]);
		$this->router->addRoute('test', [
			'method'    => $this->homeHandler(...),
			'arguments' => [
				'{request}',
				"Test",
			],
		]);
		$this->router->addRoute('favicon.ico', [
			'method'    => $this->faviconHandler(...),
			'arguments' => ['{request}'],
		]);
	}

	public function homeHandler(Request $request, string $message = null): Response
	{
		return $this->application->responseFactory($request)->json()->setData([
			'message' => $message,
			'path'    => $request->path(),
		]);
	}

	public function faviconHandler(Request $request): Response
	{
		return $this->application->responseFactory($request)->setStatus(HTTP::STATUS_NO_CONTENT)->setContentType('image/ico')->setContent('');
	}
}
