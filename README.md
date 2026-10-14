# ph-payroll-mcp

An MCP server that gives any MCP-compatible LLM accurate, current-year Philippine
statutory payroll math — SSS, PhilHealth, Pag-IBIG, and BIR withholding tax — instead
of guessing from stale training data. Every number is computed from versioned reference
tables and cited to its source circular.

## Why this exists

Philippine contribution brackets change yearly via agency circulars. LLMs either
hallucinate plausible-looking numbers or answer with last year's rates, stated with total
confidence. This server does the arithmetic correctly and cites the source circular for
every number, so the answer is auditable rather than a black box.

MCP is an open standard, not a Claude-specific feature — this server works with any MCP
client: Claude, ChatGPT, Gemini, Copilot, Cursor, and more.

## Tools

| Tool | What it does |
|---|---|
| `compute_sss_contribution` | SSS contribution by MSC bracket + member type (incl. WISP/MPF layer above MSC ₱20,000) |
| `compute_philhealth_contribution` | PhilHealth premium (5% split, floor/ceiling) |
| `compute_pagibig_contribution` | Pag-IBIG (HDMF) contribution |
| `compute_withholding_tax` | BIR period-based Revised Withholding Tax (monthly to start) |
| `compute_13th_month_pay` | 13th month pay + tax-exempt portion |
| `compute_net_pay` | Full monthly payslip: gross → net |
| `get_contribution_table` | Raw bracket table + effective date + source circular |

## Connect it to your AI assistant

URL: `https://ph-payroll-mcp.onrender.com/mcp` — no auth required.

- **Claude** (claude.ai / Desktop): Settings → Connectors → Add custom connector → paste the URL
- **ChatGPT**: Settings → Connectors → Add MCP server → paste the URL
- **Cursor / VS Code / other IDEs**: add the URL to your MCP config file
- Any other MCP client: same URL, standard MCP handshake

## Run locally

```
bundle install
bundle exec rackup           # serves on http://localhost:9292
npx @modelcontextprotocol/inspector
# Transport Type: Streamable HTTP, URL: http://localhost:9292/mcp, then Connect → Tools

bin/smoke                    # end-to-end check: initialize + tools/list + a net-pay call
bin/validate_tables          # validate the rate tables
bundle exec rspec            # unit + adapter tests
```

## Transport

This server speaks MCP **Streamable HTTP** through the official
[MCP Ruby SDK](https://github.com/modelcontextprotocol/ruby-sdk): one endpoint,
`POST /mcp`, negotiating protocol `2025-03-26` through `2026-07-28` with the client. It
runs stateless (no `Mcp-Session-Id`, nothing kept between requests) and answers every
request with a single JSON body, since no tool streams progress or calls back to the
client. `GET /mcp` returns 405; there is no SSE endpoint.

## Deploy

`render.yaml` configures a Render web service (free tier, `/health` check). Push to the
default branch to auto-deploy. Free-tier instances sleep after ~15 min idle; the first
request after a sleep takes ~30–50s to wake (a known portfolio-tier tradeoff — upgrade
the tier to remove it).

## Data sources

Contribution tables are versioned by effective date and stored in
`config/contribution_tables/`, each carrying its `effective_date` and `source_circular`.
Next year's update is a data PR, not a code change. Every value is checked against the
agency's issuance, and [docs/VERIFICATION.md](docs/VERIFICATION.md) records the source
URL, circular number, check date, and whether the source is primary or secondary.

## Disclaimer

This tool is provided for informational and educational purposes only. Statutory
contribution and tax figures are computed from published agency reference tables and may
contain errors or lag official changes. It is **not** professional tax, legal, or payroll
advice. Verify every figure against the cited source circular and the relevant agency
before relying on it for actual remittance or filing.

## Stack

Ruby + Sinatra/Rack + the official [MCP Ruby SDK](https://github.com/modelcontextprotocol/ruby-sdk). Deployed on Render.

## Author

Leo Magsino — [github.com/lmagsino](https://github.com/lmagsino) · [linkedin.com/in/leomagsinojr](https://linkedin.com/in/leomagsinojr)

## License

MIT — see [LICENSE](LICENSE).
