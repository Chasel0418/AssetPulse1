"""Gmail 讀取：OAuth 授權、依查詢條件抓信件、抽取內文與 PDF 附件。

第一次跑 `auth` 會開瀏覽器要你登入授權，之後 token 會存在 token.json，
不必每次重新登入。權限只要 gmail.readonly（唯讀）。
"""

from __future__ import annotations

import base64
from dataclasses import dataclass, field
from pathlib import Path

SCOPES = ["https://www.googleapis.com/auth/gmail.readonly"]


@dataclass
class EmailMessage:
    id: str
    subject: str
    sender: str
    body_text: str = ""
    pdf_attachments: list[bytes] = field(default_factory=list)


class GmailClient:
    def __init__(self, credentials_path: str, token_path: str):
        self.credentials_path = credentials_path
        self.token_path = token_path
        self._service = None

    def _build_service(self):
        # 延遲匯入，讓沒裝 Google 套件的環境（例如純測試）也能 import 本模組
        from google.auth.transport.requests import Request
        from google.oauth2.credentials import Credentials
        from google_auth_oauthlib.flow import InstalledAppFlow
        from googleapiclient.discovery import build

        creds = None
        token_file = Path(self.token_path)
        if token_file.exists():
            creds = Credentials.from_authorized_user_file(self.token_path, SCOPES)

        if not creds or not creds.valid:
            if creds and creds.expired and creds.refresh_token:
                creds.refresh(Request())
            else:
                flow = InstalledAppFlow.from_client_secrets_file(
                    self.credentials_path, SCOPES
                )
                creds = flow.run_local_server(port=0)
            token_file.write_text(creds.to_json(), encoding="utf-8")

        return build("gmail", "v1", credentials=creds)

    @property
    def service(self):
        if self._service is None:
            self._service = self._build_service()
        return self._service

    def authorize(self) -> None:
        """強制走一次授權流程（用於 `assetpulse auth`）。"""
        self._service = self._build_service()

    def search(self, query: str, max_results: int = 200) -> list[EmailMessage]:
        resp = (
            self.service.users()
            .messages()
            .list(userId="me", q=query, maxResults=max_results)
            .execute()
        )
        ids = [m["id"] for m in resp.get("messages", [])]
        return [self._fetch(mid) for mid in ids]

    def _fetch(self, message_id: str) -> EmailMessage:
        msg = (
            self.service.users()
            .messages()
            .get(userId="me", id=message_id, format="full")
            .execute()
        )
        payload = msg.get("payload", {})
        headers = {h["name"].lower(): h["value"] for h in payload.get("headers", [])}
        payload["_msg_id"] = message_id
        body_text, pdfs = self._walk_parts(payload)
        return EmailMessage(
            id=message_id,
            subject=headers.get("subject", ""),
            sender=headers.get("from", ""),
            body_text=body_text,
            pdf_attachments=pdfs,
        )

    def _walk_parts(self, payload: dict) -> tuple[str, list[bytes]]:
        text_chunks: list[str] = []
        pdfs: list[bytes] = []

        def visit(part: dict) -> None:
            mime = part.get("mimeType", "")
            body = part.get("body", {})
            filename = part.get("filename", "")

            if mime == "text/plain" and body.get("data"):
                text_chunks.append(_decode(body["data"]))
            elif filename.lower().endswith(".pdf") and body.get("attachmentId"):
                data = (
                    self.service.users()
                    .messages()
                    .attachments()
                    .get(userId="me", messageId=part["_msg_id"], id=body["attachmentId"])
                    .execute()
                )
                pdfs.append(base64.urlsafe_b64decode(data["data"]))

            for sub in part.get("parts", []):
                sub["_msg_id"] = part.get("_msg_id")
                visit(sub)

        visit(payload)
        return "\n".join(text_chunks), pdfs


def _decode(data: str) -> str:
    return base64.urlsafe_b64decode(data).decode("utf-8", errors="replace")
