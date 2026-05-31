# Graph Report - .  (2026-05-31)

## Corpus Check
- Corpus is ~2,763 words - fits in a single context window. You may not need a graph.

## Summary
- 51 nodes · 74 edges · 9 communities (5 shown, 4 thin omitted)
- Extraction: 85% EXTRACTED · 15% INFERRED · 0% AMBIGUOUS · INFERRED: 11 edges (avg confidence: 0.87)
- Token cost: 33,000 input · 0 output

## Community Hubs (Navigation)
- [[_COMMUNITY_any.sh Functions (AST)|any.sh Functions (AST)]]
- [[_COMMUNITY_v1.5.sh Functions (AST)|v1.5.sh Functions (AST)]]
- [[_COMMUNITY_Private Repos & Config Sync|Private Repos & Config Sync]]
- [[_COMMUNITY_Tools & Network Install Flow|Tools & Network Install Flow]]
- [[_COMMUNITY_PimpmyKali Setup|PimpmyKali Setup]]
- [[_COMMUNITY_Prerequisite Checks (any)|Prerequisite Checks (any)]]
- [[_COMMUNITY_opt Ownership Fix|/opt Ownership Fix]]
- [[_COMMUNITY_Prerequisite Checks (v1.5)|Prerequisite Checks (v1.5)]]
- [[_COMMUNITY_needrestart Purge (v1.5)|needrestart Purge (v1.5)]]

## God Nodes (most connected - your core abstractions)
1. `kali_setup_any.sh script` - 10 edges
2. `kali_setup_v1_5.sh script` - 10 edges
3. `Main Execution Flow (v1.5)` - 8 edges
4. `Main Execution Flow (any)` - 6 edges
5. `Zsh Configuration (any)` - 4 edges
6. `Zsh Configuration (v1.5)` - 4 edges
7. `do_repos()` - 3 edges
8. `do_repos()` - 3 edges
9. `Clone Private Repos (any)` - 3 edges
10. `PimpmyKali Setup (any)` - 3 edges

## Surprising Connections (you probably didn't know these)
- `Pentest Tools Feature` --semantically_similar_to--> `Tools Installation (v1.5)`  [INFERRED] [semantically similar]
  README.md → kali_setup_v1_5.sh
- `VirtualBox Network Feature` --semantically_similar_to--> `Network Configuration (v1.5)`  [INFERRED] [semantically similar]
  README.md → kali_setup_v1_5.sh
- `Zsh Customization Feature` --semantically_similar_to--> `Zsh Configuration (v1.5)`  [INFERRED] [semantically similar]
  README.md → kali_setup_v1_5.sh
- `Network Configuration (any)` --semantically_similar_to--> `Network Configuration (v1.5)`  [INFERRED] [semantically similar]
  kali_setup_any.sh → kali_setup_v1_5.sh
- `Main Execution Flow (any)` --semantically_similar_to--> `Main Execution Flow (v1.5)`  [INFERRED] [semantically similar]
  kali_setup_any.sh → kali_setup_v1_5.sh

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **kali_setup_any Sequential Setup Flow** — kali_linux_setup_kali_setup_any_main_flow, kali_linux_setup_kali_setup_any_clone_repos, kali_linux_setup_kali_setup_any_pimpmykali_setup, kali_linux_setup_kali_setup_any_tools_install, kali_linux_setup_kali_setup_any_network_config, kali_linux_setup_kali_setup_any_zsh_config [EXTRACTED 1.00]
- **kali_setup_v1_5 Sequential Setup Flow** — kali_linux_setup_kali_setup_v1_5_main_flow, kali_linux_setup_kali_setup_v1_5_clone_repos, kali_linux_setup_kali_setup_v1_5_pimpmykali_setup, kali_linux_setup_kali_setup_v1_5_tools_install, kali_linux_setup_kali_setup_v1_5_network_config, kali_linux_setup_kali_setup_v1_5_zsh_config [EXTRACTED 1.00]

## Communities (9 total, 4 thin omitted)

### Community 0 - "any.sh Functions (AST)"
Cohesion: 0.32
Nodes (11): kali_setup_any.sh script, check_prerequisites(), clone_private_repo(), do_network(), do_network_restore(), do_pmpk(), do_repos(), do_tools() (+3 more)

### Community 1 - "v1.5.sh Functions (AST)"
Cohesion: 0.32
Nodes (11): kali_setup_v1_5.sh script, check_prerequisites(), clone_private_repo(), do_network(), do_network_restore(), do_pmpk(), do_repos(), do_tools() (+3 more)

### Community 2 - "Private Repos & Config Sync"
Cohesion: 0.25
Nodes (11): Config Backup/Restore Mechanism, Clone Private Repos (any), Dependences Private Repo, Main Execution Flow (any), Network Configuration (any), Zsh Configuration (any), Clone Private Repos (v1.5), Solved_Boxes_Data Private Repo (+3 more)

### Community 3 - "Tools & Network Install Flow"
Cohesion: 0.29
Nodes (8): Tools Installation (any), Main Execution Flow (v1.5), Network Configuration (v1.5), Tools Installation (v1.5), Modular Execution Options, VirtualBox Network Feature, Kali Setup Script Overview, Pentest Tools Feature

### Community 4 - "PimpmyKali Setup"
Cohesion: 0.50
Nodes (4): PimpmyKali Setup (any), Purge needrestart (any), PimpmyKali Setup (v1.5), PimpmyKali (Dewalt-arch)

## Knowledge Gaps
- **8 isolated node(s):** `Prerequisite Checks (any)`, `Adjust /opt Ownership (any)`, `Purge needrestart (any)`, `Prerequisite Checks (v1.5)`, `Purge needrestart (v1.5)` (+3 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **4 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Main Execution Flow (v1.5)` connect `Tools & Network Install Flow` to `Private Repos & Config Sync`, `PimpmyKali Setup`?**
  _High betweenness centrality (0.099) - this node is a cross-community bridge._
- **Why does `Main Execution Flow (any)` connect `Private Repos & Config Sync` to `Tools & Network Install Flow`, `PimpmyKali Setup`?**
  _High betweenness centrality (0.070) - this node is a cross-community bridge._
- **Why does `Zsh Configuration (v1.5)` connect `Private Repos & Config Sync` to `Tools & Network Install Flow`?**
  _High betweenness centrality (0.030) - this node is a cross-community bridge._
- **Are the 3 inferred relationships involving `Main Execution Flow (v1.5)` (e.g. with `Main Execution Flow (any)` and `Modular Execution Options`) actually correct?**
  _`Main Execution Flow (v1.5)` has 3 INFERRED edges - model-reasoned connections that need verification._
- **What connects `Prerequisite Checks (any)`, `Adjust /opt Ownership (any)`, `Purge needrestart (any)` to the rest of the system?**
  _8 weakly-connected nodes found - possible documentation gaps or missing edges._