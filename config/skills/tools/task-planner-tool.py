"""
title: Task Planner
description: Breaks complex tasks into a step-by-step plan, tracks progress, and helps Clawbot execute multi-step projects.
author: LocalAI
version: 1.0.0
"""

import json
import os
import datetime
from typing import Optional


class Tools:
    def __init__(self):
        self.plan_file = os.path.join(os.path.expanduser("~"), ".clawbot_tasks.json")

    def _load_plans(self) -> dict:
        if os.path.exists(self.plan_file):
            try:
                with open(self.plan_file, "r") as f:
                    return json.load(f)
            except Exception:
                pass
        return {}

    def _save_plans(self, plans: dict):
        try:
            with open(self.plan_file, "w") as f:
                json.dump(plans, f, indent=2)
        except Exception:
            pass

    def create_plan(self, task_name: str, steps: str) -> str:
        """
        Create a step-by-step plan for a complex task.
        Use this to break a big goal into trackable steps.
        :param task_name: Short name for this task or project (e.g. "website redesign")
        :param steps: Comma-separated list of steps (e.g. "Research competitors, Sketch layout, Write content, Build site, Test")
        :return: Confirmation with the created plan
        """
        plans = self._load_plans()
        step_list = [s.strip() for s in steps.split(",") if s.strip()]
        if not step_list:
            return "Error: Please provide at least one step."

        plan_id = task_name.lower().replace(" ", "_")[:30]
        plans[plan_id] = {
            "name": task_name,
            "created": datetime.datetime.now().isoformat(),
            "steps": [{"text": s, "done": False} for s in step_list],
        }
        self._save_plans(plans)

        lines = [f"Plan created: **{task_name}**\n"]
        for i, s in enumerate(step_list, 1):
            lines.append(f"  {i}. [ ] {s}")
        return "\n".join(lines)

    def check_plan(self, task_name: str) -> str:
        """
        Show the current status of a plan.
        :param task_name: Name of the task or project to check
        :return: Current plan status with completed/pending steps
        """
        plans = self._load_plans()
        plan_id = task_name.lower().replace(" ", "_")[:30]

        # Try partial match
        if plan_id not in plans:
            matches = [k for k in plans if task_name.lower() in k]
            if matches:
                plan_id = matches[0]
            else:
                keys = list(plans.keys())
                if keys:
                    return f"Plan '{task_name}' not found. Available plans: {', '.join(plans[k]['name'] for k in keys)}"
                return "No plans found. Use create_plan to start one."

        plan = plans[plan_id]
        done = sum(1 for s in plan["steps"] if s["done"])
        total = len(plan["steps"])
        pct = int(done / total * 100) if total else 0

        lines = [f"**{plan['name']}** — {done}/{total} steps done ({pct}%)\n"]
        for i, step in enumerate(plan["steps"], 1):
            mark = "x" if step["done"] else " "
            lines.append(f"  {i}. [{mark}] {step['text']}")
        return "\n".join(lines)

    def complete_step(self, task_name: str, step_number: int) -> str:
        """
        Mark a step in a plan as completed.
        :param task_name: Name of the task or project
        :param step_number: The step number to mark done (1-based)
        :return: Updated plan status
        """
        plans = self._load_plans()
        plan_id = task_name.lower().replace(" ", "_")[:30]

        if plan_id not in plans:
            matches = [k for k in plans if task_name.lower() in k]
            if matches:
                plan_id = matches[0]
            else:
                return f"Plan '{task_name}' not found."

        plan = plans[plan_id]
        idx = step_number - 1
        if idx < 0 or idx >= len(plan["steps"]):
            return f"Step {step_number} doesn't exist. Plan has {len(plan['steps'])} steps."

        plan["steps"][idx]["done"] = True
        self._save_plans(plans)

        done = sum(1 for s in plan["steps"] if s["done"])
        total = len(plan["steps"])

        if done == total:
            return f"Step {step_number} done! ALL {total} STEPS COMPLETE - '{plan['name']}' is finished!"

        next_steps = [s["text"] for s in plan["steps"] if not s["done"]]
        return f"Step {step_number} done! ({done}/{total} complete)\nNext up: {next_steps[0]}"

    def list_plans(self) -> str:
        """
        List all active plans and their progress.
        :return: Summary of all plans
        """
        plans = self._load_plans()
        if not plans:
            return "No plans yet. Use create_plan to start a project."

        lines = ["**Active Plans:**\n"]
        for plan_id, plan in plans.items():
            done = sum(1 for s in plan["steps"] if s["done"])
            total = len(plan["steps"])
            pct = int(done / total * 100) if total else 0
            bar = ("=" * int(pct / 10)).ljust(10, "-")
            lines.append(f"  [{bar}] {pct}% — {plan['name']} ({done}/{total} steps)")
        return "\n".join(lines)

    def delete_plan(self, task_name: str) -> str:
        """
        Delete a completed or unwanted plan.
        :param task_name: Name of the task to delete
        :return: Confirmation
        """
        plans = self._load_plans()
        plan_id = task_name.lower().replace(" ", "_")[:30]

        if plan_id not in plans:
            matches = [k for k in plans if task_name.lower() in k]
            if matches:
                plan_id = matches[0]
            else:
                return f"Plan '{task_name}' not found."

        name = plans[plan_id]["name"]
        del plans[plan_id]
        self._save_plans(plans)
        return f"Plan '{name}' deleted."
