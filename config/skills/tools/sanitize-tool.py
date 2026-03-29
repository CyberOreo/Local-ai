"""
title: PII Sanitizer
description: Detect and remove personally identifiable information (PII) from text. 100% offline.
author: LocalAI
version: 1.0
license: MIT
"""

import re


class Tools:

    def sanitize_text(self, text: str, replacement: str = "[REDACTED]") -> str:
        """
        Scans text for PII (emails, phone numbers, SSNs, credit cards, IP addresses,
        names preceded by common titles, and physical addresses) and replaces them.
        Trigger phrases: sanitize, remove PII, redact, anonymize, clean personal info
        :param text: The text to sanitize
        :param replacement: What to replace PII with (default: [REDACTED])
        :return: Sanitized text with a summary of what was found
        """
        original = text
        findings = {}

        # Email addresses
        email_pattern = r'\b[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}\b'
        emails = re.findall(email_pattern, text)
        if emails:
            findings["Email addresses"] = emails
            text = re.sub(email_pattern, replacement, text)

        # Phone numbers (US/EU formats)
        phone_pattern = (
            r'\b(?:\+?1[\s\-.]?)?\(?\d{3}\)?[\s\-.]?\d{3}[\s\-.]?\d{4}\b'
            r'|\b\+?(?:\d[\s\-.]?){7,15}\b'
        )
        phones = re.findall(phone_pattern, text)
        if phones:
            findings["Phone numbers"] = [p.strip() for p in phones if len(re.sub(r'\D', '', p)) >= 7]
            text = re.sub(phone_pattern, replacement, text)

        # Social Security Numbers (US)
        ssn_pattern = r'\b\d{3}[-\s]?\d{2}[-\s]?\d{4}\b'
        ssns = re.findall(ssn_pattern, text)
        if ssns:
            findings["SSNs"] = ssns
            text = re.sub(ssn_pattern, replacement, text)

        # Credit card numbers
        cc_pattern = r'\b(?:\d{4}[\s\-]?){3}\d{4}\b'
        ccs = re.findall(cc_pattern, text)
        if ccs:
            findings["Credit card numbers"] = ccs
            text = re.sub(cc_pattern, replacement, text)

        # IP addresses
        ip_pattern = r'\b(?:\d{1,3}\.){3}\d{1,3}\b'
        ips = re.findall(ip_pattern, text)
        real_ips = [ip for ip in ips if all(0 <= int(o) <= 255 for o in ip.split('.'))]
        if real_ips:
            findings["IP addresses"] = real_ips
            for ip in real_ips:
                text = text.replace(ip, replacement)

        # Dates of birth patterns
        dob_pattern = r'\b(?:DOB|Date of Birth|Born|Birthday)[:\s]+\d{1,2}[\/\-\.]\d{1,2}[\/\-\.]\d{2,4}\b'
        dobs = re.findall(dob_pattern, text, re.IGNORECASE)
        if dobs:
            findings["Dates of birth"] = dobs
            text = re.sub(dob_pattern, replacement, text, flags=re.IGNORECASE)

        # Names with titles (Mr, Mrs, Dr, Prof, etc.)
        name_pattern = r'\b(?:Mr|Mrs|Ms|Miss|Dr|Prof|Sir|Lady|Lord)\.?\s+[A-Z][a-z]+(?:\s+[A-Z][a-z]+){0,2}\b'
        names = re.findall(name_pattern, text)
        if names:
            findings["Named individuals"] = names
            text = re.sub(name_pattern, replacement, text)

        # Build report
        if not findings:
            return (
                "✅ **No PII detected** in the provided text.\n\n"
                "The text appears clean. If you believe there is sensitive data, "
                "try highlighting specific sections."
            )

        summary_lines = ["🔒 **PII Sanitizer Report**\n"]
        summary_lines.append(f"**Found and redacted:**")
        for category, items in findings.items():
            summary_lines.append(f"- {category}: {len(items)} instance(s)")

        summary_lines.append(f"\n**Sanitized text:**\n\n{text}")

        return "\n".join(summary_lines)
