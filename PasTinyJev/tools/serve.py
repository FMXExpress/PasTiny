"""Serve a PasTinyJev runtime over Jev's wire API.

  python3 tools/serve.py HOST_JEV RUNTIME_DIR [--port 8080]

  POST /v1/systemone  {state, model, questions} -> {model, answers, usage}
  GET  /v1/models

HOST_JEV is a native build of JEV.PAS (fpc -Mtp JEV.PAS); RUNTIME_DIR holds
EXPERTS.CAT and the model files.  Listens on 127.0.0.1 only.  usage.input_tokens
counts letters, the model's tokens.
"""
import argparse
import json
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from jevrun import Runtime, TooLong

MODEL = 'pastinyjev-1.0'
ALIASES = {MODEL, 'pastinyjev-latest', 'jev-latest', 'jev-preview'}


class Handler(BaseHTTPRequestHandler):
    runtime = None

    def reply(self, status, body):
        raw = body.encode() if isinstance(body, str) else json.dumps(body).encode()
        self.send_response(status)
        self.send_header('Content-Type', 'text/plain' if isinstance(body, str) else 'application/json')
        self.send_header('Content-Length', str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)

    def do_GET(self):
        if self.path == '/v1/models':
            self.reply(200, {'object': 'list', 'data': [{'id': m, 'object': 'model'} for m in sorted(ALIASES)]})
        else:
            self.reply(404, {'detail': 'Not Found'})

    def do_POST(self):
        if self.path != '/v1/systemone':
            return self.reply(404, {'detail': 'Not Found'})
        try:
            req = json.loads(self.rfile.read(int(self.headers.get('Content-Length', 0))))
            state, questions = req['state'], req['questions']
            if not isinstance(questions, dict):
                raise KeyError('questions')
        except (ValueError, KeyError, TypeError) as e:
            return self.reply(422, {'detail': [{'type': 'missing', 'loc': ['body', str(e).strip("'")], 'msg': 'Field required'}]})
        if req.get('model', MODEL) not in ALIASES:
            return self.reply(400, {'detail': {'error_type': 'api_usage_error', 'message': 'Unknown model: %s' % req.get('model')}})
        if not isinstance(state, str):
            state = json.dumps(state)
        try:
            answers, letters = self.runtime.decide(state, questions)
        except (TooLong, ValueError, KeyError, TypeError) as e:
            return self.reply(400, 'Question cannot be asked: %s' % e)
        self.reply(200, {'model': MODEL, 'answers': answers, 'usage': {'input_tokens': letters, 'output_tokens': 0}})

    def log_message(self, *args):
        pass


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('exe', type=Path)
    parser.add_argument('runtime', type=Path)
    parser.add_argument('--port', type=int, default=8080)
    args = parser.parse_args()
    Handler.runtime = Runtime(args.exe.resolve(), args.runtime)
    print('PasTinyJev on http://127.0.0.1:%d/v1/systemone' % args.port, flush=True)
    ThreadingHTTPServer(('127.0.0.1', args.port), Handler).serve_forever()
