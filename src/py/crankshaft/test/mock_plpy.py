import re


class MockCursor:
    def __init__(self, data):
        self.cursor_pos = 0
        self.data = data

    def fetch(self, batch_size):
        batch = self.data[self.cursor_pos:self.cursor_pos + batch_size]
        self.cursor_pos += batch_size
        return batch


class MockPlPy:
    def __init__(self):
        self._reset()

    def _reset(self):
        self.infos = []
        self.notices = []
        self.debugs = []
        self.logs = []
        self.warnings = []
        self.errors = []
        self.fatals = []
        self.executes = []
        self.results = []
        self.prepares = []
        self.results = []

    def _define_result(self, query, result):
        pattern = re.compile(query, re.IGNORECASE | re.MULTILINE)
        self.results.append([pattern, result])

    def notice(self, msg):
        self.notices.append(msg)

    def debug(self, msg):
        self.notices.append(msg)

    def info(self, msg):
        self.infos.append(msg)

    def error(self, msg):
        self.infos.append(msg)
        self.notices.append(msg)

    def cursor(self, query):
        data = self.execute(query)
        return MockCursor(data)

    # TODO: additional arguments
    def execute(self, query):
        for result in self.results:
            if result[0].match(query):
                return result[1]
        return []
