from unittest import mock

from function.main import main

import pytest


@pytest.mark.parametrize(
    "method", ("GET", "PUT", "DELETE")
)
def test_main__unsupported_http_request(method):
    request = mock.MagicMock(method=method)
    assert main(request) == (
        {"error": f"{method} method is not supported"},
        500,
        {'Content-Type': 'application/json; charset=utf-8'},
    )


def test_main__invalid_message():
    request = mock.MagicMock(method="POST", json=b"test_bin_data")
    assert main(request) == (
        {"error": f"Function only works with JSON. Error: Object of type bytes is not JSON serializable"},
        415,
        {'Content-Type': 'application/json; charset=utf-8'}
    )
