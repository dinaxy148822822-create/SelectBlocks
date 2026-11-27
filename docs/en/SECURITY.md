# Security

SelectBlocks runs as injected native code inside a host app. A bug can crash that app or interact poorly with another tweak. A normal release label is not a security audit or a guarantee of compatibility.

## Reporting a sensitive issue

Do not post access tokens, exploit-ready details involving other users' data, private crash dumps or personal app content in a public issue.

If GitHub displays **Security → Advisories → Report a vulnerability** for this repository, use that private reporting channel. Its availability depends on repository settings; this document does not imply it has been enabled. If it is unavailable, open a minimal public issue asking the maintainer for a private contact route **without disclosing sensitive details**. A response or remediation timeframe is not guaranteed.

## Project boundaries

The project does not implement network telemetry, jailbreak-detection bypasses, credential collection or modifications to thermal/security services. It still inherits risks from the host app, jailbreak injector, toolchain and other loaded tweaks.

Only install assets from a release you trust. Check firmware, package variant and architecture. Know how to disable injection and uninstall before trying a new release. Do not provide GitHub or Apple credentials to anyone offering to install the tweak.

No formal supported-version security maintenance policy or independently audited release series is currently declared.

## По-русски

Не публикуйте секреты и личные данные в Issues. При наличии используйте приватную кнопку сообщения об уязвимости на GitHub; иначе сначала запросите приватный канал, не раскрывая детали. Наличие этого файла не означает, что приватные отчёты включены или что код прошёл аудит.
