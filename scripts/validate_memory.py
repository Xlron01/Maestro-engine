#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import re
import sys

# ============================================================
# Memory Validator (Linter) — Maestro Engine
# ============================================================

AI_DIR = ".ai"
REQUIRED_ROOT_FILES = ["AGENTS.md", "CHANGELOG.md"]
REQUIRED_AI_FILES = [
    "constitution.md",
    "memory-protocol.md",
    "context-map.md",
    "state.md",
    "roadmap.md",
    "handoffs/latest.md"
]

ALLOWED_STATUSES = [
    "PENDING",
    "IN_PROGRESS",
    "BLOCKED",
    "REVIEW",
    "COMPLETE",
    "CANCELLED"
]

TASK_ID_PATTERN = re.compile(r"TASK-\d{3}")
STATUS_PATTERN = re.compile(r"-\s+\*\*Status:\*\*\s+(\w+)", re.IGNORECASE)

errors = []
warnings = []

def check_file_exists(path):
    if not os.path.exists(path):
        errors.append(f"Missing required file/directory: {path}")
        return False
    return True

def validate_structure():
    print("Checking project structure...")
    check_file_exists(AI_DIR)
    for f in REQUIRED_ROOT_FILES:
        check_file_exists(f)
    for f in REQUIRED_AI_FILES:
        check_file_exists(os.path.join(AI_DIR, f))

def validate_tasks():
    print("Checking task files...")
    task_files = ["active.md", "pending.md", "completed.md"]
    found_tasks = {}
    
    for tf in task_files:
        path = os.path.join(AI_DIR, "tasks", tf)
        if not os.path.exists(path):
            continue
            
        with open(path, "r", encoding="utf-8") as f:
            content = f.read()
            
        # ابحث عن كل معرّف Task ID
        matches = re.findall(r"###\s+\[(TASK-\d{3})\]", content)
        for t_id in matches:
            if t_id in found_tasks:
                errors.append(f"Duplicate Task ID found: {t_id} (first seen in {found_tasks[t_id]}, then in {tf})")
            else:
                found_tasks[t_id] = tf
                
        # ابحث عن الحالات وتأكد من توافقها مع البروتوكول
        status_matches = STATUS_PATTERN.findall(content)
        for stat in status_matches:
            if stat.upper() not in ALLOWED_STATUSES:
                errors.append(f"Invalid status '{stat}' in task file {tf}. Allowed: {ALLOWED_STATUSES}")

def validate_links():
    print("Checking link integrity...")
    # نفحص الروابط التي تبدأ بـ file:/// ونتاكد من وجود الملفات
    file_link_pattern = re.compile(r"\[.*?\]\(file:///([^\)]+)\)")
    
    for root, dirs, files in os.walk("."):
        # استبعاد المجلدات المخفية ومجلدات godot
        dirs[:] = [d for d in dirs if not d.startswith(".") and d not in ["addons", "assets"]]
        for f in files:
            if not f.endswith(".md"):
                continue
            path = os.path.join(root, f)
            with open(path, "r", encoding="utf-8") as file:
                content = file.read()
            
            links = file_link_pattern.findall(content)
            for link in links:
                # تنظيف الرابط من anchors (#) والمسافات المرمزة (%20)
                clean_link = link.split("#")[0].replace("%20", " ")
                # لو الرابط يبدأ بـ / أو يحتوي على c: نحوله لمسار محلي نسبي
                if clean_link.lower().startswith("c:/tmp/maestro engine/"):
                    clean_link = clean_link[22:]
                elif clean_link.startswith("/"):
                    clean_link = clean_link[1:]
                
                # التحقق من وجود الملف
                if clean_link and not os.path.exists(clean_link):
                    warnings.append(f"Broken file link in {path}: {link} (Expected file: {clean_link})")

def main():
    print("====================================================")
    print("  Maestro Memory Validator & Linter")
    print("====================================================")
    
    validate_structure()
    validate_tasks()
    validate_links()
    
    print("\n----------------------------------------------------")
    print(f"Validation Finished: {len(errors)} Errors, {len(warnings)} Warnings")
    print("----------------------------------------------------")
    
    if warnings:
        print("\nWarnings:")
        for w in warnings:
            print(f"  [WARN] {w}")
            
    if errors:
        print("\nErrors:")
        for e in errors:
            print(f"  [ERROR] {e}")
        print("\n[FAIL] Memory integrity validation failed!")
        sys.exit(1)
    else:
        print("\n[SUCCESS] Memory integrity validation passed successfully!")
        sys.exit(0)

if __name__ == "__main__":
    main()
