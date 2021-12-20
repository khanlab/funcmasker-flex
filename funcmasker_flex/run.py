#!/usr/bin/env python3
from pathlib import Path

from snakebids.app import SnakeBidsApp


def get_parser():
    """Exposes parser for sphinx doc generation, cwd is the docs dir"""
    app = SnakeBidsApp("../")
    return app.parser


def main():
    app = SnakeBidsApp(Path(__file__).resolve().parents[0])  # run in current folder
    app.run_snakemake()


if __name__ == "__main__":
    main()
