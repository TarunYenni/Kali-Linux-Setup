---
type: "query"
date: "2026-05-31T06:32:13.141068+00:00"
question: "Why does Main Execution Flow (v1.5) connect Tools & Network Install Flow to Private Repos & Config Sync and PimpmyKali Setup?"
contributor: "graphify"
source_nodes: ["Main Execution Flow (v1.5)", "Clone Private Repos (v1.5)", "PimpmyKali Setup (v1.5)", "Tools Installation (v1.5)", "Network Configuration (v1.5)", "Zsh Configuration (v1.5)"]
---

# Q: Why does Main Execution Flow (v1.5) connect Tools & Network Install Flow to Private Repos & Config Sync and PimpmyKali Setup?

## Answer

Expanded from original query via vocab: [main, execution, flow, tools, repos, private, pimpmy, pmpk, network, installation, config]. Main Execution Flow (v1.5) is the main() flag-dispatcher at kali_setup_v1_5.sh:370-398. It is the only node with EXTRACTED calls edges into all three install communities: do_repos -> Clone Private Repos (community 2 Private Repos & Config Sync), do_pmpk -> PimpmyKali Setup (community 4), do_tools/do_network -> Tools/Network Installation (community 3). The stage functions share almost no edges with each other (do_repos clusters with do_zsh via shared private-repo data; do_pmpk is isolated around the external PimpmyKali project; do_tools/do_network cluster around package install). The only structural link tying these three islands into one program is the sequential dispatcher, which is why it has the highest betweenness centrality (0.099). Removing it fractures the graph into three disconnected install islands. The two references edges from main() to README nodes (Modular Execution Options, Kali Setup Script Overview) are INFERRED not EXTRACTED.

## Source Nodes

- Main Execution Flow (v1.5)
- Clone Private Repos (v1.5)
- PimpmyKali Setup (v1.5)
- Tools Installation (v1.5)
- Network Configuration (v1.5)
- Zsh Configuration (v1.5)