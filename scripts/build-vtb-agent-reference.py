#!/usr/bin/env python3
"""Build docs/vtb-sandbox-ecommerce-agent-reference.md from sandbox HTML sources."""

from __future__ import annotations

import html as html_lib
import re
from dataclasses import dataclass, field
from datetime import date
from html.parser import HTMLParser
from pathlib import Path

DOCS_DIR = Path('/tmp/vtb-docs')
OUT = Path(__file__).resolve().parents[1] / 'docs' / 'vtb-sandbox-ecommerce-agent-reference.md'

PAGES = [
    ('structure', 'simple-integration', 'Simple integration', 'https://sandbox.vtb-bank.kz/ru/integration/structure/simple-integration.html', 'ru_integration_structure_simple-integration.html'),
    ('structure', 'redirect-integration', 'Redirect integration via API', 'https://sandbox.vtb-bank.kz/ru/integration/structure/redirect-integration.html', 'ru_integration_structure_redirect-integration.html'),
    ('structure', 'pay-by-link', 'Payment links (portal)', 'https://sandbox.vtb-bank.kz/ru/integration/structure/pay-by-link.html', 'ru_integration_structure_pay-by-link.html', True),
    ('structure', 'permanent-payment-links', 'Permanent payment links', 'https://sandbox.vtb-bank.kz/ru/integration/structure/permanent-payment-links.html', 'ru_integration_structure_permanent-payment-links.html', True),
    ('structure', 'advanced-integration', 'Advanced integration', 'https://sandbox.vtb-bank.kz/ru/integration/structure/advanced-integration.html', 'ru_integration_structure_advanced-integration.html'),
    ('structure', 'direct-integration', 'Direct payments via API', 'https://sandbox.vtb-bank.kz/ru/integration/structure/direct-integration.html', 'ru_integration_structure_direct-integration.html'),
    ('api', 'scripts', 'Additional API scripts', 'https://sandbox.vtb-bank.kz/ru/integration/api/scripts.html', 'ru_integration_api_scripts.html'),
    ('api', 'rest', 'REST API reference', 'https://sandbox.vtb-bank.kz/ru/integration/api/rest.html', 'ru_integration_api_rest.html'),
    ('api', 'action_codes', 'Action codes', 'https://sandbox.vtb-bank.kz/ru/integration/api/action_codes.html', 'ru_integration_api_action_codes.html'),
    ('reference', 'glossary', 'Glossary', 'https://sandbox.vtb-bank.kz/ru/integration/glossary.html', 'ru_integration_glossary.html'),
    ('reference', 'test-cards', 'Test cards', 'https://sandbox.vtb-bank.kz/ru/integration/structure/test-cards.html', 'ru_integration_structure_test-cards.html'),
    ('reference', 'test-to-production', 'Test to production', 'https://sandbox.vtb-bank.kz/ru/integration/structure/test-to-production.html', 'ru_integration_structure_test-to-production.html'),
    ('reference', 'certification', 'PCI-DSS', 'https://sandbox.vtb-bank.kz/ru/integration/certification.html', 'ru_integration_certification.html'),
    ('reference', 'mp3', 'Merchant portal UI', 'https://sandbox.vtb-bank.kz/ru/integration/mportal3/mp3.html', 'ru_integration_mportal3_mp3.html', True),
    ('reference', 'cms-plugins', 'CMS plugins', 'https://sandbox.vtb-bank.kz/ru/integration/cms/plugins.html', 'ru_integration_cms_plugins.html', True),
    ('reference', 'ofd', 'OFD Bereke', 'https://sandbox.vtb-bank.kz/ru/integration/ofd.html', 'ru_integration_ofd.html', True),
]


def slug_prefix(cat: str, name: str) -> str:
    return f'{cat}--{name}'


def extract_content(raw: str) -> str:
    m = re.search(r'<div class="content">(.*?)</div>\s*<div class="ntf-content">', raw, re.DOTALL)
    if not m:
        m = re.search(r'<div class="content">(.*?)</div>\s*</div>\s*<footer', raw, re.DOTALL)
    content = m.group(1) if m else ''
    # Drop in-page TOC (renders as broken markdown; use file header index instead).
    content = re.sub(r'<div class="toc-wrapper"[^>]*>.*?</div>\s*', '', content, flags=re.DOTALL)
    content = re.sub(r'<ul id="toc"[^>]*>.*?</ul>\s*', '', content, flags=re.DOTALL)
    return content


def prefix_ids(html: str, prefix: str) -> str:
    id_map: dict[str, str] = {}

    def repl_id(m: re.Match[str]) -> str:
        old = m.group(1)
        new = f'{prefix}--{old}'
        id_map[old] = new
        return f'id="{new}"'

    html = re.sub(r'\bid="([^"]+)"', repl_id, html)

    def repl_href(m: re.Match[str]) -> str:
        href = m.group(1)
        if href.startswith('#'):
            anchor = href[1:]
            return f'href="#{id_map.get(anchor, f"{prefix}--{anchor}")}"'
        return m.group(0)

    return re.sub(r'href="(#[^"]+)"', repl_href, html)


@dataclass
class MdState:
    parts: list[str] = field(default_factory=list)
    list_depth: int = 0
    in_pre: bool = False
    pre_buf: list[str] = field(default_factory=list)
    table_rows: list[list[str]] = field(default_factory=list)
    in_table: bool = False
    skip_depth: int = 0

    def emit(self, s: str = '') -> None:
        self.parts.append(s)

    def flush_table(self) -> None:
        if not self.table_rows:
            self.in_table = False
            return
        rows = self.table_rows
        self.table_rows = []
        self.in_table = False
        if not rows:
            return
        widths = [max(len(r[i]) for r in rows) for i in range(len(rows[0]))]

        def fmt_row(cells: list[str]) -> str:
            return '| ' + ' | '.join(c.ljust(widths[i]) for i, c in enumerate(cells)) + ' |'

        self.emit(fmt_row(rows[0]))
        self.emit(fmt_row(['-' * w for w in widths]))
        for row in rows[1:]:
            self.emit(fmt_row(row))
        self.emit('')


class HtmlToMd(HTMLParser):
  # noqa: D101 - small converter
    def __init__(self, link_prefix: str):
        super().__init__(convert_charrefs=True)
        self.link_prefix = link_prefix
        self.s = MdState()
        self._heading_level = 0

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        if self.s.skip_depth:
            self.s.skip_depth += 1
            return
        a = {k: (v or '') for k, v in attrs}
        if tag in ('img', 'picture', 'svg', 'video', 'iframe', 'source'):
            self.s.skip_depth = 1
            return
        if tag == 'nav' and a.get('aria-label') == 'breadcrumbs':
            self.s.skip_depth = 1
            return
        if tag in ('h1', 'h2', 'h3', 'h4'):
            self._heading_level = int(tag[1])
        elif tag in ('ul', 'ol'):
            self.s.list_depth += 1
        elif tag == 'li':
            indent = '  ' * (self.s.list_depth - 1)
            self.s.emit(f'{indent}- ', end='')
        elif tag in ('strong', 'b'):
            self.s.emit('**', end='')
        elif tag in ('em', 'i'):
            self.s.emit('*', end='')
        elif tag == 'code' and not self.s.in_pre:
            self.s.emit('`', end='')
        elif tag == 'pre':
            self.s.in_pre = True
            self.s.pre_buf = []
        elif tag == 'a':
            href = a.get('href', '')
            if href.startswith('#'):
                pass
            elif href.startswith('rest.html#'):
                href = f"#api--rest--{href.split('#', 1)[1]}"
            elif href.startswith('../api/rest.html#'):
                href = f"#api--rest--{href.split('#', 1)[1]}"
            elif href.startswith('../api/action_codes.html'):
                href = '#api--action_codes--action-codes'
            elif href.startswith('../api/scripts.html#'):
                href = f"#api--scripts--{href.split('#', 1)[1]}"
            elif href.startswith('/') or href.startswith('http'):
                href = href
            else:
                href = href
            self.s.emit(f'[', end='')
            self._link_href = href
        elif tag == 'table':
            self.s.in_table = True
            self.s.table_rows = []
        elif tag in ('tr',):
            self._row: list[str] = []
        elif tag in ('th', 'td'):
            self._cell: list[str] = []
        elif tag == 'aside':
            kind = a.get('class', '')
            label = 'NOTE'
            if 'warning' in kind:
                label = 'WARNING'
            self.s.emit(f'\n> **{label}:** ', end='')
        elif tag == 'br':
            if self.s.in_pre:
                self.s.pre_buf.append('\n')
            else:
                self.s.emit('\n', end='')

    def handle_endtag(self, tag: str) -> None:
        if self.s.skip_depth:
            self.s.skip_depth -= 1
            return
        if tag in ('h1', 'h2', 'h3', 'h4'):
            level = int(tag[1])
            self.s.emit('\n')
            self._heading_level = 0
        elif tag in ('ul', 'ol'):
            self.s.list_depth = max(0, self.s.list_depth - 1)
            self.s.emit('')
        elif tag in ('strong', 'b'):
            self.s.emit('**', end='')
        elif tag in ('em', 'i'):
            self.s.emit('*', end='')
        elif tag == 'code' and not self.s.in_pre:
            self.s.emit('`', end='')
        elif tag == 'pre':
            self.s.in_pre = False
            lang = ''
            body = ''.join(self.s.pre_buf).strip('\n')
            self.s.emit(f'```{lang}\n{body}\n```\n')
            self.s.pre_buf = []
        elif tag == 'a':
            href = getattr(self, '_link_href', '')
            self.s.emit(f']({href})', end='')
        elif tag == 'p':
            self.s.emit('\n')
        elif tag in ('th', 'td'):
            cell = re.sub(r'\s+', ' ', ''.join(self._cell)).strip()
            self._row.append(cell)
        elif tag == 'tr':
            if self._row and any(c.strip() for c in self._row):
                self.s.table_rows.append(self._row)
        elif tag == 'table':
            self.s.flush_table()
        elif tag == 'aside':
            self.s.emit('\n')

    def handle_data(self, data: str) -> None:
        if self.s.skip_depth:
            return
        text = html_lib.unescape(data)
        if self.s.in_pre:
            self.s.pre_buf.append(text)
            return
        if self.s.in_table and hasattr(self, '_cell'):
            self._cell.append(text)
            return
        if self._heading_level:
            hashes = '#' * (self._heading_level + 1)  # h1 -> ## under section
            line = re.sub(r'\s+', ' ', text).strip()
            if line:
                self.s.emit(f'\n{hashes} {line}\n')
            return
        if self.s.parts and self.s.parts[-1].endswith(('- ', '**', '*', '`', '[')):
            self.s.parts[-1] += text
        else:
            self.s.emit(text, end='')

    def get_markdown(self) -> str:
        out = ''.join(self.s.parts)
        out = re.sub(r'\n{3,}', '\n\n', out)
        return out.strip()


def MdState_emit(self, s: str = '', end: str = '\n') -> None:
    self.parts.append(s + end)


MdState.emit = MdState_emit  # type: ignore[method-assign]


def html_to_md(content: str, prefix: str) -> str:
    content = re.sub(r'<img[^>]*>', '', content, flags=re.I)
    content = re.sub(r'<picture[^>]*>.*?</picture>', '', content, flags=re.I | re.DOTALL)
    content = re.sub(r'<figure[^>]*>.*?</figure>', '', content, flags=re.I | re.DOTALL)
    parser = HtmlToMd(prefix)
    parser.feed(content)
    return parser.get_markdown()


def summarize_portal_only(title: str, source: str) -> str:
    return (
        f'_Portal/UI documentation omitted (screenshots only on live site). '
        f'See {source} if needed._\n'
    )


def main() -> None:
    chunks: list[str] = []
    headings_index: list[str] = []
    all_eps: dict[str, set[str]] = {}

    header = f"""---
source: https://sandbox.vtb-bank.kz/#ecommerce
scraped: {date.today().isoformat()}
locale: ru
api_version: ecommerce-v1-rest
format: agent-reference-markdown
---

# VTB KZ Sandbox eCommerce — Agent Reference

Offline mirror for coding agents. **Prefer this file over fetching the live docs.**

- Anchor pattern: `{{category}}--{{page}}--{{section-id}}` (headings below).
- Test API base: `https://vtbkz.rbsuat.com/payment/rest/`
- Postman (live): `https://sandbox.vtb-bank.kz/assets/plugins/sandbox_eCommerce.postman_collection.json`

## OldWhale mapping (`oldwhale-backend/src/payments/vtb.client.ts`)

| Env | Default | Maps to |
|-----|---------|---------|
| VTB_API_BASE_URL | https://vtbkz.rbsuat.com/payment/rest/ | REST base URL |
| VTB_USER_NAME / VTB_PASSWORD | Oldwhale-api / Oldwhale | userName, password |
| VTB_TOKEN | (optional) | token (instead of password) |
| VTB_CURRENCY | 398 | currency (KZT minor units context) |
| VTB_LANGUAGE | ru | language |
| VTB_DYNAMIC_CALLBACK_URL | | dynamicCallbackUrl on register |
| VTB_SESSION_TIMEOUT_SECONDS | 1200 | sessionTimeoutSecs |

| Client method | Endpoint | Paid when |
|---------------|----------|-----------|
| registerOrder | register.do | formUrl redirect flow |
| getOrderStatus | getOrderStatusExtended.do | orderStatus == 2 |
| getSessionStatus | getSessionStatus.do | MDORDER query param |

## Endpoint index

"""
    chunks.append(header)

    ep_global: set[str] = set()

    for row in PAGES:
        omit = len(row) > 5 and row[5] is True
        cat, name, title, source_url, filename = row[:5]
        prefix = slug_prefix(cat, name)
        headings_index.append(f'- [{title}](#{prefix})')

        chunks.append(f'\n---\n\n## {title} {{#{prefix}}}\n')
        chunks.append(f'_Source: {source_url}_\n')

        if omit:
            chunks.append(summarize_portal_only(title, source_url))
            continue

        raw = (DOCS_DIR / filename).read_text(encoding='utf-8', errors='replace')
        content = extract_content(raw)
        if not content:
            chunks.append('_No content extracted._\n')
            continue
        content = prefix_ids(content, prefix)
        content = re.sub(r'href="/([^"]+)"', r'href="https://sandbox.vtb-bank.kz/\1"', content)
        content = re.sub(
            r'-----BEGIN (?:RSA )?PRIVATE KEY-----.*?-----END (?:RSA )?PRIVATE KEY-----',
            '[PEM private key example omitted]',
            content,
            flags=re.DOTALL,
        )
        md = html_to_md(content, prefix)
        for m in re.finditer(r'\b([a-z][a-zA-Z0-9]*\.do)\b', md):
            ep_global.add(m.group(1))
            all_eps.setdefault(prefix, set()).add(m.group(1))
        chunks.append(md)
        chunks.append('')

    ep_lines = sorted(f'- `{e}`' for e in ep_global)
    chunks.insert(1, '\n'.join(ep_lines) + '\n\n## Sections\n\n' + '\n'.join(headings_index) + '\n')

    body = '\n'.join(chunks)
    body = re.sub(r'\n{3,}', '\n\n', body)
    # Remove artifacts from stripped sidebar TOC links.
    body = re.sub(r'^\s+\]\(#[^\)]+\)\s*$', '', body, flags=re.MULTILINE)
    body = re.sub(r'\n{3,}', '\n\n', body)

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(body, encoding='utf-8')
    html_path = OUT.with_suffix('.html')
    if html_path.exists():
        html_path.unlink()

    print(f'Wrote {OUT} ({OUT.stat().st_size // 1024} KB, {body.count(chr(10))} lines)')
    print(f'Endpoints: {len(ep_global)}')


if __name__ == '__main__':
    main()
