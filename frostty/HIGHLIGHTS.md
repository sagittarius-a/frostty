# Frostty Pattern Configuration

Frostty reads its default configuration from:

```text
~/.config/frostty/config
```

It also loads this optional pattern-only file after `config` when present:

```text
~/.config/frostty/patterns
```

The build wrapper no longer injects a config path into the app bundle. The
runtime detects `Frostty.app` and loads the Frostty config paths directly.

Validate the default config:

```sh
/private/tmp/Frostty.app/Contents/MacOS/ghostty +validate-config --config-file=$HOME/.config/frostty/config
```

Rule format:

```conf
highlight = name=<id> type=token|line regex="<oniguruma-regex>" fg="#RRGGBB" bg="#RRGGBB" priority=<0-65535> enabled=true|false
```

Higher priority wins visually when rules overlap.

## Runtime Tracking

Bind runtime tracking actions in `~/.config/frostty/config`:

```conf
keybind = ctrl+shift+h=highlight_selection
keybind = ctrl+shift+backspace=clear_runtime_highlights

highlight-selection-foreground = #000000
highlight-selection-background = #ffaf00
```

`highlight_selection` creates an in-memory literal token rule from the current
selection. This is intended for volatile debugging values such as a single
leaked pointer, heap chunk address, request ID, PID, TID, nonce, or hash.

The selected value is escaped before compilation, so regex metacharacters are
tracked literally:

```text
0xffff88810a7c9000
chunk[0x5555558123a0]
SHA256:abcd...==
```

Runtime highlights are not written to disk. Use `clear_runtime_highlights` to
remove them without touching the static rules from `config` or `patterns`.

## Core Security Triage

```conf
highlight = name=critical-line type=line regex="\b(CRITICAL|FATAL|PANIC|panic|SIGSEGV|SIGBUS|segmentation fault|core dumped)\b" fg="#ffffff" bg="#7f1d1d" priority=100
highlight = name=error-line type=line regex="\b(ERROR|ERR|failed|failure|denied|blocked|rejected|forbidden|unauthorized)\b" fg="#ffffff" bg="#4c1d1d" priority=900
highlight = name=warning-line type=line regex="\b(WARN|WARNING|deprecated|suspicious|anomal(y|ous))\b" fg="#ffdf5d" bg="#3d2d00" priority=700
highlight = name=success-line type=line regex="\b(OK|PASS|PASSED|SUCCESS|allowed|accepted|authenticated)\b" fg="#50fa7b" bg="#12351f" priority=300
highlight = name=todo-line type=line regex="\b(TODO|FIXME|HACK|XXX|BUG|SECURITY)\b" fg="#000000" bg="#f1fa8c" priority=500
```

## Vulnerability Identifiers

```conf
highlight = name=cve type=token regex="\bCVE-[0-9]{4}-[0-9]{4,7}\b" fg="#ffdf5d" bg="#3d2d00" priority=950
highlight = name=cwe type=token regex="\bCWE-[0-9]{1,5}\b" fg="#ffb86c" bg="#3a2508" priority=850
highlight = name=capec type=token regex="\bCAPEC-[0-9]{1,5}\b" fg="#ffb86c" bg="#3a2508" priority=850
highlight = name=mitre-attack type=token regex="\bT[0-9]{4}(?:\.[0-9]{3})?\b" fg="#bd93f9" bg="#26173f" priority=850
highlight = name=epss type=token regex="\bEPSS[:=][0-9]+(?:\.[0-9]+)?%?\b" fg="#8be9fd" bg="#073642" priority=650
highlight = name=cvss type=token regex="\bCVSS[:=][0-9]+(?:\.[0-9]+)?\b" fg="#8be9fd" bg="#073642" priority=650
```

## Network Indicators

```conf
highlight = name=ipv4 type=token regex="\b(?:[0-9]{1,3}\.){3}[0-9]{1,3}\b" fg="#8be9fd" bg="#073642" priority=700
highlight = name=ipv6 type=token regex="\b(?:[A-Fa-f0-9]{1,4}:){2,7}[A-Fa-f0-9]{1,4}\b" fg="#8be9fd" bg="#073642" priority=700
highlight = name=cidr-v4 type=token regex="\b(?:[0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}\b" fg="#8be9fd" bg="#073642" priority=720
highlight = name=mac-address type=token regex="\b(?:[A-Fa-f0-9]{2}[:-]){5}[A-Fa-f0-9]{2}\b" fg="#8be9fd" bg="#073642" priority=650
highlight = name=domain type=token regex="\b(?:[A-Za-z0-9-]{1,63}\.)+[A-Za-z]{2,63}\b" fg="#a4ffff" bg="#073642" priority=450
highlight = name=url type=token regex="\bhttps?://[^[:space:]\"'<>]+\b" fg="#8be9fd" bg="#073642" priority=800
highlight = name=onion type=token regex="\b[A-Za-z2-7]{16,56}\.onion\b" fg="#ff79c6" bg="#3b1630" priority=850
highlight = name=port type=token regex="\b(?:port|dport|sport|dst_port|src_port)[=:][0-9]{1,5}\b" fg="#f1fa8c" bg="#3d2d00" priority=500
```

## Cryptographic Artifacts

```conf
highlight = name=md5 type=token regex="\b[A-Fa-f0-9]{32}\b" fg="#50fa7b" bg="#12351f" priority=600
highlight = name=sha1 type=token regex="\b[A-Fa-f0-9]{40}\b" fg="#50fa7b" bg="#12351f" priority=620
highlight = name=sha256 type=token regex="\b[A-Fa-f0-9]{64}\b" fg="#50fa7b" bg="#12351f" priority=900
highlight = name=sha512 type=token regex="\b[A-Fa-f0-9]{128}\b" fg="#50fa7b" bg="#12351f" priority=900
highlight = name=uuid type=token regex="\b[A-Fa-f0-9]{8}-[A-Fa-f0-9]{4}-[1-5][A-Fa-f0-9]{3}-[89ABab][A-Fa-f0-9]{3}-[A-Fa-f0-9]{12}\b" fg="#bd93f9" bg="#26173f" priority=500
highlight = name=ssh-fingerprint type=token regex="\bSHA256:[A-Za-z0-9+/]{20,}={0,2}\b" fg="#50fa7b" bg="#12351f" priority=800
highlight = name=pgp-fingerprint type=token regex="\b[A-Fa-f0-9]{4}(?:\s[A-Fa-f0-9]{4}){9}\b" fg="#50fa7b" bg="#12351f" priority=700
```

## Secrets And Credentials

```conf
highlight = name=secret-line type=line regex="\b(secret|password|passwd|pwd|token|api[_-]?key|private[_-]?key|credential|bearer|authorization)\b" fg="#ffffff" bg="#6d1f4f" priority=980
highlight = name=aws-access-key type=token regex="\b(?:AKIA|ASIA)[A-Z0-9]{16}\b" fg="#ff5555" bg="#3f1111" priority=1000
highlight = name=aws-secret-label type=token regex="\baws_secret_access_key\b" fg="#ff5555" bg="#3f1111" priority=950
highlight = name=github-token type=token regex="\bgh[pousr]_[A-Za-z0-9_]{36,255}\b" fg="#ff5555" bg="#3f1111" priority=1000
highlight = name=gitlab-token type=token regex="\bglpat-[A-Za-z0-9_-]{20,}\b" fg="#ff5555" bg="#3f1111" priority=1000
highlight = name=slack-token type=token regex="\bxox[baprs]-[A-Za-z0-9-]{10,}\b" fg="#ff5555" bg="#3f1111" priority=1000
highlight = name=jwt type=token regex="\beyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\b" fg="#ff5555" bg="#3f1111" priority=1000
highlight = name=private-key-marker type=line regex="-----BEGIN (?:RSA |DSA |EC |OPENSSH |PGP )?PRIVATE KEY-----" fg="#ffffff" bg="#7f1d1d" priority=1100
highlight = name=basic-auth-url type=token regex="\bhttps?://[^[:space:]\"'<>/@]+:[^[:space:]\"'<>/@]+@[^[:space:]\"'<>]+\b" fg="#ff5555" bg="#3f1111" priority=1000
```

## HTTP And API Logs

```conf
highlight = name=http-5xx type=token regex="\b5[0-9]{2}\b" fg="#ffffff" bg="#7f1d1d" priority=800
highlight = name=http-4xx type=token regex="\b4[0-9]{2}\b" fg="#ffdf5d" bg="#3d2d00" priority=700
highlight = name=http-2xx type=token regex="\b2[0-9]{2}\b" fg="#50fa7b" bg="#12351f" priority=300
highlight = name=http-method type=token regex="\b(GET|POST|PUT|PATCH|DELETE|HEAD|OPTIONS|CONNECT|TRACE)\b" fg="#bd93f9" bg="#26173f" priority=400
highlight = name=auth-header type=token regex="\bAuthorization:\s*(?:Bearer|Basic|Digest)\b" fg="#ff5555" bg="#3f1111" priority=900
highlight = name=set-cookie type=token regex="\bSet-Cookie:\s*[^;[:space:]]+" fg="#ffb86c" bg="#3a2508" priority=650
```

## Linux And Privilege Events

```conf
highlight = name=privileged-user type=token regex="\b(root|sudo|admin|Administrator|SYSTEM|uid=0|euid=0)\b" fg="#ff79c6" bg="#3b1630" priority=850
highlight = name=auth-failure type=line regex="\b(authentication failure|failed password|invalid user|PAM.*failure|sudo.*incorrect password)\b" fg="#ffffff" bg="#7f1d1d" priority=950
highlight = name=auth-success type=line regex="\bAccepted (password|publickey)|session opened for user|sudo:.*COMMAND=\b" fg="#50fa7b" bg="#12351f" priority=500
highlight = name=suid type=token regex="\b(setuid|setgid|SUID|SGID|cap_setuid|cap_setgid)\b" fg="#ff79c6" bg="#3b1630" priority=700
highlight = name=chmod-risk type=token regex="\bchmod\s+(777|666|[0-7]*7[0-7]*|[0-7]*6[0-7]*)\b" fg="#ff5555" bg="#3f1111" priority=750
highlight = name=world-writable type=token regex="\bworld-writable\b" fg="#ff5555" bg="#3f1111" priority=750
```

## Kernel Pointers And Crashes

```conf
highlight = name=kernel-oops type=line regex="\b(BUG:|Oops:|Kernel panic|Unable to handle kernel|general protection fault|page fault|NULL pointer dereference|use-after-free|slab-out-of-bounds)\b" fg="#ffffff" bg="#7f1d1d" priority=1100
highlight = name=kasan-line type=line regex="\b(KASAN|KCSAN|KFENCE|UBSAN):\b" fg="#ffffff" bg="#6d1f4f" priority=1050
highlight = name=kernel-call-trace type=line regex="\b(Call Trace:|RIP:|RSP:|RBP:|CR2:|Code:)\b" fg="#ffdf5d" bg="#3d2d00" priority=800
highlight = name=kernel-pointer type=token regex="\b(?:0x)?ffff[0-9A-Fa-f]{12,16}\b" fg="#50fa7b" bg="#12351f" priority=1000
highlight = name=kernel-poison type=token regex="\b(?:0x)?(?:deadbeef|deadc0de|feedface|badc0ffe|5a5a5a5a|6b6b6b6b|a5a5a5a5)\b" fg="#ff5555" bg="#3f1111" priority=1000
highlight = name=kernel-symbol type=token regex="\b[A-Za-z_][A-Za-z0-9_]*\+[0-9A-Fa-fx]+/[0-9A-Fa-fx]+\b" fg="#8be9fd" bg="#073642" priority=850
highlight = name=kernel-module type=token regex="\b(?:Modules linked in:|Tainted:|Comm:|CPU:|PID:)\b" fg="#bd93f9" bg="#26173f" priority=650
highlight = name=kernel-register type=token regex="\b(?:RIP|RSP|RBP|RAX|RBX|RCX|RDX|RSI|RDI|R8|R9|R10|R11|R12|R13|R14|R15|CR2):\s*0x?[0-9A-Fa-f]+\b" fg="#f1fa8c" bg="#3d2d00" priority=750
```

## Detection Tools

```conf
highlight = name=nmap-open type=line regex="\b[0-9]{1,5}/(?:tcp|udp)\s+open\b" fg="#50fa7b" bg="#12351f" priority=700
highlight = name=nmap-filtered type=line regex="\b[0-9]{1,5}/(?:tcp|udp)\s+filtered\b" fg="#ffdf5d" bg="#3d2d00" priority=500
highlight = name=masscan-open type=line regex="\bDiscovered open port\b" fg="#50fa7b" bg="#12351f" priority=700
highlight = name=suricata-alert type=line regex="\b\[\*\*\].*\[\*\*\]\b" fg="#ffffff" bg="#7f1d1d" priority=950
highlight = name=zeek-notice type=line regex="\b(?:Notice::|Intel::|Signatures::)\w+\b" fg="#ffb86c" bg="#3a2508" priority=750
highlight = name=yara-match type=line regex="\b(?:YARA|yara).*match(?:ed)?\b" fg="#ffffff" bg="#4c1d1d" priority=900
highlight = name=sigma-rule type=token regex="\b(?:sigma|rule_id|title|level)[:=][^[:space:]]+\b" fg="#bd93f9" bg="#26173f" priority=550
```

## Containers And Kubernetes

```conf
highlight = name=container-id type=token regex="\b[A-Fa-f0-9]{12,64}\b" fg="#50fa7b" bg="#12351f" priority=350
highlight = name=k8s-namespace type=token regex="\b(?:namespace|ns)[=:][A-Za-z0-9_.-]+\b" fg="#8be9fd" bg="#073642" priority=500
highlight = name=k8s-pod type=token regex="\bpod/[A-Za-z0-9_.-]+\b" fg="#8be9fd" bg="#073642" priority=550
highlight = name=k8s-secret type=token regex="\bsecret/[A-Za-z0-9_.-]+\b" fg="#ff5555" bg="#3f1111" priority=900
highlight = name=k8s-crashloop type=line regex="\b(CrashLoopBackOff|ImagePullBackOff|ErrImagePull|CreateContainerConfigError)\b" fg="#ffffff" bg="#7f1d1d" priority=950
highlight = name=docker-privileged type=line regex="\b(--privileged|privileged:\s*true|hostNetwork:\s*true|hostPID:\s*true)\b" fg="#ffffff" bg="#7f1d1d" priority=950
```

## Cloud Identifiers

```conf
highlight = name=aws-account-id type=token regex="\b[0-9]{12}\b" fg="#f1fa8c" bg="#3d2d00" priority=450
highlight = name=aws-arn type=token regex="\barn:aws[a-zA-Z-]*:[^[:space:]\"']+\b" fg="#f1fa8c" bg="#3d2d00" priority=700
highlight = name=aws-region type=token regex="\b(?:us|eu|ap|sa|ca|me|af)-(?:north|south|east|west|central|northeast|southeast|southwest)-[0-9]\b" fg="#f1fa8c" bg="#3d2d00" priority=400
highlight = name=gcp-service-account type=token regex="\b[A-Za-z0-9._-]+@[A-Za-z0-9._-]+\.iam\.gserviceaccount\.com\b" fg="#8be9fd" bg="#073642" priority=750
highlight = name=azure-tenant type=token regex="\btenant(?:Id|_id)?[=:][A-Fa-f0-9-]{36}\b" fg="#8be9fd" bg="#073642" priority=650
highlight = name=metadata-service type=token regex="\b169\.254\.169\.254\b" fg="#ff5555" bg="#3f1111" priority=950
```

## Infrastructure As Code

```conf
highlight = name=terraform-destroy type=line regex="\bTerraform will perform the following actions:|Plan: .* to destroy|destroy\b" fg="#ffffff" bg="#7f1d1d" priority=900
highlight = name=terraform-secret type=line regex="\b(sensitive value|sensitive = true|aws_secret_access_key|private_key)\b" fg="#ff5555" bg="#3f1111" priority=950
highlight = name=ansible-failed type=line regex="\b(failed=[1-9][0-9]*|unreachable=[1-9][0-9]*|FAILED!)\b" fg="#ffffff" bg="#7f1d1d" priority=900
highlight = name=ansible-changed type=token regex="\bchanged=[1-9][0-9]*\b" fg="#ffdf5d" bg="#3d2d00" priority=400
highlight = name=policy-deny type=line regex="\b(deny|denied|violation|noncompliant|non-compliant)\b" fg="#ffffff" bg="#4c1d1d" priority=850
```

## Malware And Incident Response

```conf
highlight = name=malware-keyword type=token regex="\b(malware|ransomware|backdoor|trojan|loader|dropper|beacon|c2|command-and-control|exfiltration)\b" fg="#ffffff" bg="#7f1d1d" priority=950
highlight = name=persistence type=token regex="\b(LaunchAgent|LaunchDaemon|systemd|crontab|RunKey|Startup|Scheduled Task|service install)\b" fg="#ff79c6" bg="#3b1630" priority=700
highlight = name=lateral-movement type=token regex="\b(psexec|wmic|winrm|rdp|smbexec|sshpass|pass-the-hash|kerberoast)\b" fg="#ff79c6" bg="#3b1630" priority=800
highlight = name=encoded-powershell type=line regex="\bpowershell(?:\.exe)?\b.*\s-(?:enc|encodedcommand)\b" fg="#ffffff" bg="#7f1d1d" priority=1000
highlight = name=suspicious-base64 type=token regex="\b[A-Za-z0-9+/]{80,}={0,2}\b" fg="#ffb86c" bg="#3a2508" priority=450
```

## Windows Events

```conf
highlight = name=windows-event-id type=token regex="\b(?:EventID|Event ID|event_id)[=: ]+(4624|4625|4672|4688|4697|4720|4728|4732|7045)\b" fg="#ffdf5d" bg="#3d2d00" priority=700
highlight = name=windows-service-install type=line regex="\b(?:EventID|event_id)[=: ]+7045\b|service was installed" fg="#ffffff" bg="#7f1d1d" priority=900
highlight = name=windows-admin-logon type=line regex="\b(?:EventID|event_id)[=: ]+4672\b|Special privileges assigned" fg="#ff79c6" bg="#3b1630" priority=800
highlight = name=windows-process-create type=token regex="\b(?:EventID|event_id)[=: ]+4688\b" fg="#8be9fd" bg="#073642" priority=500
highlight = name=windows-failed-logon type=line regex="\b(?:EventID|event_id)[=: ]+4625\b|An account failed to log on" fg="#ffffff" bg="#7f1d1d" priority=900
```

## Practical Starter Set

Copy this into `~/.config/frostty/config` for a balanced default:

```conf
highlight = name=critical-line type=line regex="\b(CRITICAL|FATAL|PANIC|panic|SIGSEGV|segmentation fault|core dumped)\b" fg="#ffffff" bg="#7f1d1d" priority=1000
highlight = name=error-line type=line regex="\b(ERROR|failed|denied|forbidden|unauthorized)\b" fg="#ffffff" bg="#4c1d1d" priority=900
highlight = name=secret-line type=line regex="\b(secret|password|passwd|token|api[_-]?key|private[_-]?key|credential|bearer|authorization)\b" fg="#ffffff" bg="#6d1f4f" priority=980
highlight = name=cve type=token regex="\bCVE-[0-9]{4}-[0-9]{4,7}\b" fg="#ffdf5d" bg="#3d2d00" priority=950
highlight = name=sha256 type=token regex="\b[A-Fa-f0-9]{64}\b" fg="#50fa7b" bg="#12351f" priority=900
highlight = name=ipv4 type=token regex="\b(?:[0-9]{1,3}\.){3}[0-9]{1,3}\b" fg="#8be9fd" bg="#073642" priority=700
highlight = name=url type=token regex="\bhttps?://[^[:space:]\"'<>]+\b" fg="#8be9fd" bg="#073642" priority=800
highlight = name=aws-access-key type=token regex="\b(?:AKIA|ASIA)[A-Z0-9]{16}\b" fg="#ff5555" bg="#3f1111" priority=1000
highlight = name=github-token type=token regex="\bgh[pousr]_[A-Za-z0-9_]{36,255}\b" fg="#ff5555" bg="#3f1111" priority=1000
highlight = name=jwt type=token regex="\beyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\b" fg="#ff5555" bg="#3f1111" priority=1000
```
