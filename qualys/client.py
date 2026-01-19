#!/usr/bin/env python3
import base64
import requests

class QualysClient:
    """
    Qualys US Platform API base:
      https://qualysapi.qualys.com
    """

    def __init__(self, username: str, password: str, base_url="https://qualysapi.qualys.com"):
        self.base_url = base_url.rstrip("/")
        self.session = requests.Session()

        token = base64.b64encode(f"{username}:{password}".encode()).decode()
        self.session.headers.update({
            "Authorization": f"Basic {token}",
            "X-Requested-With": "GoldenImageFactory"
        })

    def get(self, path: str, params=None, headers=None):
        url = f"{self.base_url}{path}"
        r = self.session.get(url, params=params, headers=headers, timeout=90)
        r.raise_for_status()
        return r

    def post(self, path: str, data=None, headers=None):
        url = f"{self.base_url}{path}"
        r = self.session.post(url, data=data, headers=headers, timeout=180)
        r.raise_for_status()
        return r
