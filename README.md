# ph-payroll-mcp

An MCP server that gives any MCP-compatible LLM accurate, current-year Philippine
statutory payroll math — SSS, PhilHealth, Pag-IBIG, and BIR withholding tax — instead
of guessing from stale training data. Every number is computed from versioned reference
tables and cited to its source circular.

![Claude computing a ₱30,000 payslip with ph-payroll-mcp, citing each circular](docs/demo.gif)

*Claude computes a ₱30,000 payslip through `compute_net_pay` and cites the circular behind
every deduction.*

## Quickstart (local, about a minute)

Needs Ruby 3.3 (see `.ruby-version`) and Bundler.

```sh
git clone https://github.com/lmagsino/ph-payroll-mcp.git
cd ph-payroll-mcp
bundle install
bundle exec rackup          # MCP endpoint: http://localhost:9292/mcp
```

Leave it running and connect a client:

**Claude Code**

```sh
claude mcp add --transport http ph-payroll http://localhost:9292/mcp
```

Then ask: *"I earn ₱30,000 a month, employed. What's my net pay, and where does each
deduction come from?"*

**Claude Desktop** — the config file only launches local commands, so bridge to the
HTTP endpoint with [`mcp-remote`](https://www.npmjs.com/package/mcp-remote) (needs
Node.js). In `claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "ph-payroll": {
      "command": "npx",
      "args": ["-y", "mcp-remote", "http://localhost:9292/mcp"]
    }
  }
}
```

**Cursor** — in `~/.cursor/mcp.json` (or `.cursor/mcp.json` in a project):

```json
{
  "mcpServers": {
    "ph-payroll": { "url": "http://localhost:9292/mcp" }
  }
}
```

**VS Code** — in `.vscode/mcp.json`:

```json
{
  "servers": {
    "ph-payroll": { "type": "http", "url": "http://localhost:9292/mcp" }
  }
}
```

**MCP Inspector** — no AI client needed:

```sh
npx @modelcontextprotocol/inspector --cli http://localhost:9292/mcp --method tools/list
npx @modelcontextprotocol/inspector --web --transport http --server-url http://localhost:9292/mcp
```

## Tools

| Tool | What it does |
|---|---|
| `compute_sss_contribution` | SSS contribution by MSC bracket + member type (incl. the WISP/MPF layer above MSC ₱20,000) |
| `compute_philhealth_contribution` | PhilHealth premium (5% split, floor/ceiling) |
| `compute_pagibig_contribution` | Pag-IBIG (HDMF) contribution |
| `compute_withholding_tax` | BIR monthly withholding tax (Revised Withholding Tax table) |
| `compute_13th_month_pay` | 13th month pay + tax-exempt portion |
| `compute_net_pay` | Full monthly payslip: gross → net, each deduction cited |
| `get_contribution_table` | Raw rate table + effective date + source circular |

## Examples

[`examples/`](examples/) holds a captured request and response for every tool, a rendered
[₱30,000 payslip](examples/payslip-30k-employed.md), and a
[Claude Code session](examples/claude-code-session.md) that computes the payslip and
pulls up the SSS table to back it. `bin/capture_examples` regenerates the tool examples
from the running code.

## Why this exists

Philippine contribution brackets change via agency circulars. LLMs either hallucinate
plausible-looking numbers or answer with last year's rates, stated with total
confidence. This server does the arithmetic and cites the source circular for every
number, so the answer is auditable rather than a black box.

MCP is an open standard, not a Claude-specific feature — this server works with any MCP
client that speaks Streamable HTTP.

## Optional: a public URL on Render (free)

`render.yaml` describes a free Render web service with a `/health` check. Connect the
repository in the Render dashboard (New → Blueprint, or New → Web Service) and every
push to `main` deploys. The MCP endpoint is then `https://<service>.onrender.com/mcp`,
with no auth, and it works where a localhost URL cannot:

- **Claude** (claude.ai / Desktop): Settings → Connectors → Add custom connector → paste the URL
- **ChatGPT**: Settings → Connectors → add an MCP server → paste the URL
- Any other remote-capable MCP client: same URL

Tradeoff: free instances sleep after ~15 minutes idle, and the first request after a
sleep takes ~30–50 seconds while the instance wakes. A paid instance removes the wait.

## Transport

This server speaks MCP **Streamable HTTP** through the official
[MCP Ruby SDK](https://github.com/modelcontextprotocol/ruby-sdk): one endpoint,
`POST /mcp`, negotiating protocol `2025-03-26` through `2026-07-28` with the client. It
runs stateless (no `Mcp-Session-Id`, nothing kept between requests) and answers every
request with a single JSON body, since no tool streams progress or calls back to the
client. `GET /mcp` returns 405; there is no SSE endpoint.

## Data sources

Contribution tables are versioned by effective date and stored in
`gem/data/contribution_tables/`, each carrying its `effective_date` and `source_circular`.
Next year's update is a data PR, not a code change. Every value is checked against the
agency's issuance, and [docs/VERIFICATION.md](docs/VERIFICATION.md) records the source
URL, circular number, check date, and whether the source is primary or secondary.

## Development

```sh
bundle exec rspec           # tool adapter and protocol round-trip specs
(cd gem && bundle exec rspec)  # calculator specs, in the ph_payroll gem
bin/validate_tables         # schema-check every rate table (also runs at boot and in CI)
bin/smoke                   # boot Puma; initialize + tools/list + a net-pay call over POST /mcp
bin/capture_examples        # regenerate examples/ after a rate change
```

Rate updates and releases follow [docs/MAINTAINING.md](docs/MAINTAINING.md).

## Disclaimer

This tool is provided for informational and educational purposes only. Statutory
contribution and tax figures are computed from published agency reference tables and may
contain errors or lag official changes. It is **not** professional tax, legal, or payroll
advice. Verify every figure against the cited source circular and the relevant agency
before relying on it for actual remittance or filing.

## Stack

Ruby + Sinatra/Rack + the official [MCP Ruby SDK](https://github.com/modelcontextprotocol/ruby-sdk).
The calculations live in the [`ph_payroll`](gem/) gem, usable without MCP from plain Ruby.
Runs locally with `rackup`; optionally deployed on Render's free tier.

## Author

Leo Magsino — [github.com/lmagsino](https://github.com/lmagsino) · [linkedin.com/in/leomagsinojr](https://linkedin.com/in/leomagsinojr)

## License

MIT — see [LICENSE](LICENSE).
